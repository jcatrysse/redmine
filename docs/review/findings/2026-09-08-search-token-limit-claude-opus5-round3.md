# Review run — 2026-09-08 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** `patch/search-token-limit` at `587d9a11b` against
  `origin/master` `bee32a926` (r25037). 0 commits behind trunk, one commit
  ahead, author and committer both Jan Catrysse.
- **Dossier read:** `docs/features/search-token-limit/dossier.md` — yes
- **Status read:** `docs/features/search-token-limit/status.md` — yes
- **Round-1 findings read:** **no, deliberately.**
  `docs/review/findings/2026-09-03-search-token-limit-claude-opus5.md` was not
  opened.
- **Ran the test suite:** yes, both sides, fresh worktrees, own PostgreSQL 16
  databases, Git fixtures extracted, **the same `Gemfile.lock` on both sides**,
  and the four runs serialised rather than concurrent. See **Suite**.
- **Scope covered:** minimality, where the limit moved from and to, every caller
  of `Tokenizer` and of `Search::Fetcher`, the round-trip property of the new
  helper, backward compatibility of the search page, the performance question
  the limit existed for, escaping, the tests as code, INV-10 against
  `7.0-stable-GEOxyz`, lint, and patch hygiene.
- **Scope NOT covered:**
  - **No browser.** The G9 screenshots were read, not reproduced.
  - **MySQL and SQLite.** PostgreSQL 16 only. The dossier's own timings are
    PostgreSQL 16 too, and I did not re-run them — see the question below for
    what I did and did not check about them.
  - **I did not reproduce the timing table.** The 10.9 s figure quoted in Q01 is
    the dossier's measurement, not mine. What I verified is the code path that
    makes it reachable.

## Summary

A good change, and a better one than its title suggests. The bug is not really
in the search box: it is that `Redmine::Search::Tokenizer#tokens` ended with
`.first 5`, and **`Query.tokenized_like_conditions` calls that same tokenizer**.
So every text filter in Redmine — subject, description, notes, `contains`,
`starts with`, `ends with` — has been silently dropping everything after the
fifth word, on a query the user typed themselves and can see. Moving the cap out
of the tokenizer and into `Search::Fetcher`, where the expensive
per-class-per-project fan-out actually happens, puts it where the cost is and
takes it off the path where there is none.

The second half is the detail I would have missed and the patch did not: with
the search page still capped at five, the *Apply issues filter* button used to
hand the issue list the **whole** question, so the filter searched more words
than the results above it. `tokens_to_question(@tokens)` fixes that by rebuilding
a question from the tokens the search actually used, and it re-quotes on the
same `\p{Zs}` class the tokenizer splits on, so the round trip is exact rather
than approximately right.

I have no defect to report. I do have one question, and it is the one a Redmine
committer will ask: the patch removes the only bound that existed on filter
token count, and the dossier's own measurements show what that costs on the `OR`
operators. The dossier argues the bound belongs in `Query#validate_query_filters`
instead. That is a scope judgement, not a code error, so it goes to Jan as a
question rather than a finding.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 1

**Lines in the diff not strictly required by the feature:** 0. Nine files, 92
insertions, 4 deletions; 78 of those insertions are tests. **No locale file is
touched** — the change adds no user-visible string.

## Suite

`/home/user/wt/r3-search-token-limit` (patch tip `587d9a11b`) and
`/home/user/wt/r3-trunk` (pristine r25037), separate databases, same
`Gemfile.lock`, PostgreSQL 16, Ruby 3.3.6.

| What | Result |
|---|---|
| `test:all` with the patch | `5985 runs, 31372 assertions, 48 failures, 82 errors, 92 skips` |
| `test:all` on pristine trunk, same lock | `5977 runs, 31358 assertions, 48 failures, 82 errors, 92 skips` |
| delta | **8 runs**, and **zero extra failures and zero extra errors** |
| failing names | **87 on each side, identical** — `comm` empty in both directions |
| RuboCop 1.90.0 on the 8 changed files | `no offenses detected`; baseline on the same 8 at the merge base: `no offenses detected` |
| `tools/check-patch-clean.sh search-token-limit --submit` | PASS — 9 files, no locale touched, no AI trace, applies to a pristine r25037 checkout, branch and file agree |

The 8 extra runs are the 8 new tests. One existing test in
`test/unit/lib/redmine/search_test.rb` changed rather than being added — it now
asserts seven tokens where it asserted five — which is the tokenizer change made
visible, and it adds no run.

**Why the totals are 48/82.** json 3.0.1 breaks `ActiveSupport::JSON.decode` and
about a hundred core tests with it, measured on pristine trunk, so it affects
both sides equally. See `docs/traps.md`.

**Hypotheses driven and cleared:**

| Hypothesis | Outcome |
|---|---|
| moving `.first 5` out of the tokenizer changes a caller nobody looked at | **this is the point of the patch, and there are exactly two callers.** `grep -rn Tokenizer` over `app/` and `lib/` returns `Redmine::Search::Fetcher#initialize` (which regains the cap as an option) and `Query.tokenized_like_conditions:1519` (which is the text filter, and is the thing being fixed). Two of the new tests pin the second |
| `Fetcher` loses its cap by accident for the search page | clean — `options.delete(:token_limit) {5}` keeps 5 as the default, `IssueQuery` is the only caller passing `nil`, and there is a test for each direction |
| `tokens_to_question` does not round-trip | clean — it quotes exactly when the token matches `/\p{Zs}/`, which is the same class `Tokenizer` splits on. A token can only contain a space by having come from a `"…"` group, and that group is `"[^"]+"`, so a space-bearing token can never contain a quote and `"#{token}"` is always well formed. There is a test that feeds its output back through the tokenizer |
| the button now carries a different question than the user typed | true and deliberate — it carries the tokens the search **used**, which is the fix. Single-character tokens the tokenizer drops are absent from the link, and they would have been dropped again on the filter side anyway |
| the helper produces markup and needs escaping | clean — it returns a plain String used as a query-string value through `issues_filter_path`; no `html_safe`, no interpolation into markup |
| `sql_for_in_or_null`-style splicing or SQL injection through the extra tokens | clean — `tokenized_like_conditions` passes every token through `sanitize_sql_like` and `sanitize_sql_for_conditions`; the patch does not touch that method at all |
| the search page's own behaviour changed | clean — `SearchController` does not pass `token_limit`, so it keeps 5, and `@tokens = fetcher.tokens` is unchanged |
| INV-10: GEOxyz has drifted | clean — all 13 added lines are present verbatim on `7.0-stable-GEOxyz` and no removed line survives there |

---

### Q01 — the patch removes the only bound on filter token count, and the dossier says the replacement belongs elsewhere

- **Status:** open
- **Severity:** question
- **Confidence:** confirmed (the code path; the timings are the dossier's, not re-run by me)
- **Category:** performance
- **Where:** `lib/redmine/search.rb` — the `.first 5` removed from `Tokenizer#tokens`, which is what `Query.tokenized_like_conditions` (`app/models/query.rb:1519`) relies on
- **Invariant touched:** none

**The question**

Should this patch also add the bound it argues for, or submit without one?

**Why it is worth asking**

`Query.tokenized_like_conditions` builds one `LIKE` per token. Before the patch
the tokenizer capped that at five, everywhere, including for input that arrives
in a query string. After it there is no cap at all on the filter side. The
dossier measures the consequence honestly and does not hide the bad row —
PostgreSQL 16, 50 000 issues, `Subject` filter, `*~` against `~`:

```
   1 token   0.054 s / 0.051 s
   5 tokens  0.184 s / 0.053 s
  50 tokens  0.554 s / 0.032 s
 200 tokens  2.233 s / 0.046 s
1000 tokens 10.930 s / 0.123 s
```

The asymmetry is real and correctly explained: `~` and `!~` join with `AND`, so
the database abandons a row at the first failing condition and the cost is flat;
`*~`, `^` and `$` join with `OR`, so a non-matching row is tested against every
condition and the cost is tokens × rows. Roughly a thousand tokens fit in an
8 KB request line, which is the last row of that table, and any user who may
view the issue list can send it. That is a 60-fold increase in database CPU per
request against the previous cap, introduced deliberately.

The dossier's answer is that a bound on user input belongs on the filter value
in `Query#validate_query_filters`, where it would cover every operator and every
filter, rather than in the tokenizer "where it silently changes the answer
instead of refusing the question". I think that argument is right. It is also an
argument for a change this patch does not make, which leaves the patch strictly
more exposed than trunk on a path a committer will look at.

The counterweight, also from the dossier and also checked: `Principal.like` in
`app/models/principal.rb` already builds one `LIKE` pair per token of
`params[:q]` with no cap, and it is reached from the watchers and members
autocompletes. So unbounded token counts from user input are not new to Redmine
with this patch — but they are new to *this* code path.

**Why this is a question and not a finding**

Because the trade-off is recorded, argued and measured in the dossier already,
and the framework's rule is that a deliberate choice already written down is not
a defect. It is exactly the class of decision CLAUDE.md reserves for Jan: how
much to give up to get a patch accepted, and whether to widen the patch to
pre-empt an objection or to answer it in the issue.

**How I verified it**

Traced the call path rather than the timings: confirmed `Query.tokenized_like_conditions`
takes its tokens from `Redmine::Search::Tokenizer`, that the patch does not touch
that method, and that removing `.first 5` therefore changes its behaviour by
construction — which the patch's own two `sql_contains` tests assert. Read the
operator table in `tokenized_like_conditions` to confirm which operators use
`OR` (`starts_with`, `ends_with`, and `all_words == false`) and which use `AND`.
Confirmed `Principal.like` has no cap. I did **not** rebuild a 50 000-issue
database or re-run the timing table.

**Two ways to answer it, for Jan to choose between**

- **Submit as it is** and put the timing table in the issue, with the argument
  that the bound belongs in `validate_query_filters` and is a separate change.
  Cheapest, and honest; the risk is a reviewer asking for the bound before
  accepting, which costs a round trip.
- **Add the bound to this patch** — a length or token-count check on the filter
  value in `Query#validate_query_filters`, which refuses the question rather
  than silently truncating it. Larger diff, touches a method this feature has no
  other reason to touch, and needs its own number chosen (which is a second
  Class B decision).

**Resolution:**
