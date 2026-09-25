# What the five-token limit actually costs, measured

Written 2026-09-25 for [#43701](https://www.redmine.org/issues/43701), after Go
MAEDA asked to keep the limit "to prevent costly database queries" and proposed
[#44464](https://www.redmine.org/issues/44464) (keep the limit, warn the user)
instead.

Neither side had a number. These two scripts produce one.

## Reproducing it

```sh
# a database of its own; do not point this at the normal test database
bin/rails db:create db:schema:load
bin/rails redmine:load_default_data REDMINE_LANG=en
bin/rails runner docs/features/search-token-limit/bench/seed.rb    # 50 000 issues
bin/rails runner docs/features/search-token-limit/bench/run.rb
```

`seed.rb` gives every issue a ~895-character description built from two
vocabularies: 60 `commonN` words that appear in **every** row, and 400 `termN`
words that are selective. That is what makes the two cases below separable.

**Measure with the query cache off.** The first attempt reported 4 ms for every
token count, because Active Record served the identical `SELECT` from its own
cache after the warm-up run. `run.rb` wraps every measurement in
`ActiveRecord::Base.uncached`.

## Measured, PostgreSQL 16, 50 000 issues, median of five runs

| Terms | `contains` (AND), every term matches every row | `contains` (AND), selective terms | `contains any of` (OR), selective terms | global search (issues only) |
|---|---|---|---|---|
| 1 | 375 ms | 443 ms | 459 ms | 748 ms |
| 5 | 1 587 ms | 537 ms | 1 653 ms | 777 ms |
| 10 | 3 226 ms | 230 ms | 2 081 ms | 794 ms |
| 20 | 6 808 ms | 208 ms | 2 120 ms | 850 ms |
| 50 | 6 267 ms | 278 ms | 814 ms | 729 ms |

## What that says

1. **The global search does not get more expensive with more tokens.** From 1 to
   50 tokens it moves between 729 and 850 ms — within the noise. Its cost is
   dominated by the number of rows returned and by the per-class query, not by
   the number of `LIKE` clauses. This is the path the limit was written for, and
   the limit is not buying what it is assumed to buy.
2. **On a filter, more terms is normally cheaper, not dearer.** With selective
   terms, `contains` goes from 443 ms at one term to 208 ms at twenty: each
   extra term both fails earlier per row and shrinks the result set.
3. **There is one real worst case, and it is `contains` with terms that match
   everything**: 375 ms at one term, 6 808 ms at twenty, roughly linear in the
   term count. It is a filter that selects all 50 000 rows, so the user has
   written a query that matches everything — but the cost is real and this is
   the case a maintainer is right to worry about.
4. **`contains any of` grows with the rows it matches, not with the terms.**
   It peaks at twenty terms (2 120 ms, 48 897 rows) and drops back at fifty
   (814 ms) once everything matches and PostgreSQL stops early.

So the honest summary for the issue: removing the limit from text filters does
not make anything faster and does remove a guard. But the guard is in the wrong
place — it does not measurably protect the global search, and on filters it
"protects" by silently returning the wrong answer. A guard on what is actually
expensive (rows scanned, or a statement timeout) would do the job the token
count is failing to do.

## Caveats

PostgreSQL 16, one container, no concurrent load, descriptions of a uniform
~895 characters. MySQL was not measured. The 50-term rows in the AND columns
are below the 20-term rows because PostgreSQL stops evaluating a row at the
first clause that fails, and at that width the plan changes; treat the shape as
the finding, not the individual milliseconds.

---

# Can the query be optimised instead? Measured 2026-09-25

Jan's follow-up question: is there a maintainable way to fix the heavy query,
or is the SQL already optimal? Same database, same 50 000 issues.

## What the query looks like

`Redmine::Database.like` emits, on PostgreSQL:

```sql
description ILIKE '%term%'                      -- without the unaccent extension
unaccent(description) ILIKE unaccent('%term%')  -- with it, picked up automatically
```

A leading `%` means no btree index can be used, so both are a sequential scan
out of the box.

## 1. A GIN trigram index, without unaccent

```sql
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_issues_desc_trgm ON issues USING gin (description gin_trgm_ops);
```

| Query | seq scan | with the index | rows |
|---|---|---|---|
| 5 selective terms, AND | 458 ms | **3.8 ms** | 1 |
| 20 terms present in every row, AND | 2 175 ms | 2 398 ms | 50 000 |
| 20 selective terms, OR | 1 093 ms | 1 033 ms | 46 265 |
| 3 selective terms, OR | 1 087 ms | 1 053 ms | 15 790 |

**120× on the query a user actually means, and nothing at all on the queries
that return most of the table.** PostgreSQL correctly stays on the sequential
scan there: an index cannot prune when 92 % of the rows match.

Cost: the index is **22 MB against a 56 MB table**, built in 6 s, and it makes
writes slower — updating 5 000 descriptions took **226 ms without it and
1 096 ms with it**.

## 2. The same index is useless as soon as `unaccent` is installed

Redmine switches to `unaccent(description) ILIKE unaccent(...)` on its own when
the extension is present. Measured with the trigram index in place:

| | plan | time |
|---|---|---|
| `unaccent(description) ILIKE unaccent('%term313%')` | Seq Scan | 704 ms |
| `immutable_unaccent(description) ILIKE immutable_unaccent('%term313%')` | Bitmap Index Scan | **45 ms** |

Indexing the expression Redmine writes is not possible:

```
ERROR:  functions in index expression must be marked IMMUTABLE
```

`unaccent` is `STABLE`, not `IMMUTABLE`. You can wrap it —

```sql
CREATE FUNCTION immutable_unaccent(text) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
  AS $$ SELECT unaccent('unaccent', $1) $$;
```

— and index *that*, but PostgreSQL only uses the index when the query names the
same expression, and Redmine names `unaccent`. So on an installation with
unaccent enabled, **the text filters cannot use an index at all without a change
in Redmine itself**. That is worth its own issue; it is not part of #43701.

## 3. What this says about the limit

The queries that hurt are the ones that return most of the table, and those are
already slow at five terms: five terms present in every row cost 1 587 ms and
return all 50 000 rows. Capping the input at five does not prevent an expensive
query — it only prevents a *precise* one, which is the cheap kind. **Cost tracks
rows returned, not terms typed.**

So if a guard is wanted, guard the cost:

```yaml
production:
  adapter: postgresql
  variables:
    statement_timeout: 10000
```

Rails passes `variables:` to the connection, PostgreSQL and MySQL both have it,
it needs no code, and it stops exactly the runaway query while leaving every
good one alone. Caveat: set on the connection it applies to migrations and rake
tasks as well, so it belongs on the web role rather than in one shared entry.
