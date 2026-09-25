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
