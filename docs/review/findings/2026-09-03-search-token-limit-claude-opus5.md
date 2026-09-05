# Review run — 2026-09-03 — claude-opus5

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `patch/search-token-limit` at `cb15bbb64` against `origin/master` `bee32a926` (r25037)
- **Dossier read:** `docs/features/search-token-limit/dossier.md` — yes
- **Status read:** `docs/features/search-token-limit/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes, partially, and several experiments of my own:
  - the touched suites plus their neighbours together in one process on the patch
    branch (`query_test.rb`, `search_test.rb`, `lib/redmine/search_test.rb`,
    `issue_test.rb`, `auto_completes_controller_test.rb`,
    `search_controller_test.rb`) → **655 runs, 2070 assertions, 0 failures,
    0 errors, 2 skips**
  - the patch applied to **today's** trunk tip `bee32a926` (r25037, 88 commits
    past the r24882 it was cut against), then `query_test.rb`, `search_test.rb`,
    `lib/redmine/search_test.rb`, `search_controller_test.rb`,
    `search_helper_test.rb` in one process → **347 runs, 1173 assertions,
    0 failures, 0 errors, 2 skips**
  - RuboCop on the four changed files: **0 offences** on the patch branch, and
    **0 offences** again on the current trunk baseline with RuboCop 1.90 (the
    version trunk pinned after this patch was cut)
  - **mutation check, own:** I reverted `lib/redmine/search.rb` to trunk in a
    throwaway worktree and ran the four new tests together → **4 runs,
    4 assertions, 3 failures, 0 errors**, the `~` failure naming issue 12
    "Closed issue on a locked version". The dossier's red-on-old-code claim is
    exactly right, including that the fourth test passes by design.
  - **second mutation:** I removed only the new `.first(5)` from `Fetcher` and ran
    `search_test.rb` + `query_test.rb` + `search_controller_test.rb` +
    `search_helper_test.rb` → **343 runs, 1 failure**, and that one failure is the
    patch's own new guard test. Nothing else in trunk pins the search engine's
    cap, which is precisely why adding that guard was the right call.
  - four probe scripts against a real PostgreSQL 16 test database (F01, F02, F03,
    F08 evidence below)
  - I did **not** run the full suite; the dossier's 5924/31456 figures are taken
    on trust.
- **Scope covered:** minimality, scope of the change, settings surface (none),
  conventions of the touched files, backward compatibility, database portability
  of the generated SQL, performance under adversarial input, authorization
  (nothing new), i18n (nothing new), tests as code, test pollution, provenance of
  the constant via `git log -S`, the live-verification script and its
  screenshots, the exported patch file, and the GEOxyz commit's identity with the
  patch.
- **Scope NOT covered:** the full suite; re-running the Playwright verification
  (I read the script and four of the ten committed screenshots, I did not drive a
  browser); MySQL and SQLite were not available, so the portability numbers in
  F08 are computed from measured statement lengths against documented limits, not
  observed; the `unaccent` amplification in F03 is reasoned, not measured (the
  extension is not installed here); SCM symmetry is genuinely n/a.

## Summary

The code change is right, it is four lines, and its central historical claim
holds up under checking — I traced the `5` with `git log -S` to r321
(2007-03-10, Jean-Philippe Lang, "improved search engine … added a fixed limit
for result count"), where it lived inside the search engine, and then to r21238
(2021-10-05, Marius Balteanu applying Jens Krämer's patch), whose diff moves the
block into `Tokenizer` **verbatim, cap included**, with a commit message about
reuse and not one word about a term limit for filters. So "this was never a
filter design decision" is not rhetoric here; it is visible in the diff. The
tests are honest, red on the old code, and the new guard test is load-bearing —
I proved both by mutation. RuboCop is clean on today's trunk baseline as well as
the old one, and the patch still applies to the current tip.

**The reason a committer would send this back is not the code — it is that the
patch draws a boundary and the dossier describes a different, wider one.** The
dossier says "every text filter" was broken and that "text filters … now use
every token". That is not true of the `Any searchable text` filter, which sits in
the same filter dropdown, offers exactly `~`, `*~` and `!~`, and routes through
`Redmine::Search::Fetcher` — so after the patch it still silently drops the sixth
keyword. I confirmed it: the same six-word value returns `[1]` on the `Subject`
filter and `[]` on `Any searchable text` (F01). Worse, the boundary is now
visible on one screen: with "Search titles only" checked, the global search page
reports "Results (1)" and the **"Apply issues filter"** button right underneath
it leads to an issue list with zero rows, because the search used five tokens and
the filter it links to uses six (F02, measured). The evidence for that is already
sitting in the committed screenshots — `search-still-capped.png` shows the search
page returning 1 result for `pump alignment survey report northern zzz`, and
`filter-contains.png` shows the subject filter returning 0 for the same string —
but the dossier presents each as correct and never joins them.

The performance objection, which the parent brief expects to be the first one
raised, is answered in the dossier but without numbers, and one clause of the
answer is wrong. I measured it: on 4,514 issues, `Subject` `*~` costs 23 ms at 5
tokens, 484 ms at 200, and **2.5 s at 1,000** — a ~110x amplification from a
single GET that fits inside an 8 KB request line. `~` is unaffected (12–32 ms
throughout) because PostgreSQL short-circuits the AND. So the honest position is
"the AND operators are free, only the OR operators scale, here are the figures",
not "the user waits for it themselves" — the requester waits, but the database
CPU is shared. There is good news the dossier does not use: `Principal.like` in
trunk already ANDs an unbounded number of `LIKE`s built from `params[:q]`, so
unbounded tokens from user input are established Redmine practice (F03). On
portability the answer is a clean pass and worth saying out loud: the values are
inlined by `sanitize_sql_for_conditions`, so the statement carries **zero** bind
parameters and neither PostgreSQL's nor MySQL's 65,535-placeholder limit is in
play at all.

Nothing here is a blocker. F01 and F02 are most likely fixed by rewriting three
sentences and adding one pin test plus one screenshot, not by changing the four
lines of production code.

**Counts:** blocker 0 · major 3 · minor 2 · nit 3 · question 1

**Lines in the diff not strictly required by the feature:** 0 — the one line
that is not the fix itself is the relocated `# no more than 5 tokens to search
for` comment, and keeping trunk's own wording rather than deleting or rewriting
it is the minimal choice. See F06 for why it is still worth ten seconds of
thought.

---

### F01 — The `Any searchable text` filter still drops keywords after the fifth, and the dossier says every text filter is fixed

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `app/models/issue_query.rb:876` (`sql_for_any_searchable_field`), `app/models/issue_query.rb:295`, `app/models/query.rb:343`; dossier sections "The problem" and "Proposed change"
- **Invariant touched:** none

**What is wrong**

`Redmine::Search::Tokenizer` has two consumers, and the patch's whole design is
to cap one of them (`Fetcher`) and not the other (`Query.tokenized_like_conditions`).
But `Fetcher` is not only the global search box. `IssueQuery` registers
`add_available_filter "any_searchable", :type => :search`, the operators for type
`:search` are `["~", "*~", "!~"]` (`app/models/query.rb:343`), and
`sql_for_any_searchable_field` implements it by constructing a
`Redmine::Search::Fetcher` and using its result ids. So `Any searchable text` is
a text filter, it sits in the same "Add filter" dropdown as `Subject`, it offers
three of the five operators the dossier lists as affected — and after this patch
it still silently drops everything after the fifth token.

The dossier states the opposite twice: "every text filter silently ignores
whatever the user typed after the fifth word. Five operators are affected: `~`
… `!~` … `*~` … `^` … `$`", and "text filters and the issue autocomplete now use
every token the user typed". Both sentences are wrong for `any_searchable`.

**Why a committer would push back**

The claim is checkable in under a minute and it is the first thing a reviewer of
a filter bug does: open the filter dropdown and try the neighbouring filter.
Measured on the patch branch, both filters given the identical six-token value
`nomatch1 nomatch2 nomatch3 nomatch4 nomatch5 recipes` (only the sixth token
matches anything):

```
PROBE any_searchable *~ 6 tokens, 6th is 'recipes' => []
PROBE any_searchable *~ 1 token 'recipes'          => [1]
PROBE any_searchable ~ 6 tokens, 6th nomatch       => []
PROBE subject        *~ 6 tokens, 6th is 'recipes' => [1]
```

The `subject` row is the fix working. The `any_searchable` rows are the bug,
unchanged, on a filter the dossier says was fixed. A committer who runs that
finds the submission inaccurate about its own scope, which costs the patch more
credibility than the remaining bug costs.

Note this is not automatically a code defect: `any_searchable` genuinely *is* the
search engine, so keeping the cap there is consistent with the patch's own
argument (cost = tokens × classes × projects). What is not defensible is
describing the boundary as if it did not exist.

**How I verified it**

Read `app/models/issue_query.rb:876-916` and `app/models/query.rb:343`, then ran
a probe in a throwaway worktree at `cb15bbb64` against a real PostgreSQL test
database, output quoted above.

**Suggested direction**

The submission has to own the boundary in the words it uses: which filters lift
the cap, which one does not, and why. Whatever the fixing session decides, the
promise wants a test that pins it the way `test_fetcher_should_use_no_more_than_five_tokens`
pins the engine — a `QueryTest` case on `any_searchable` with six tokens, so the
next person to touch `Tokenizer` learns the contract from the suite instead of
from a redmine.org note. G9 wants the matching screenshot; the verify script
currently only drives the `subject` filter.

**Resolution:** fixed, 2026-09-05, per Jan's g08 — as code, not only as
wording. `Redmine::Search::Fetcher` now takes a `:token_limit` option, five by
default, and `IssueQuery#sql_for_any_searchable_field` passes `nil`. So the two
consumers of the tokenizer that the patch's own argument distinguishes now say
so at the call site: the global search box searches every registered searchable
class in every visible project and keeps its cap, the filter searches
`['issue']` in the query's own projects and does not. The default is unchanged,
so a plugin that builds a `Fetcher` is unaffected — that was the reason to make
the limit an option with a value rather than a flag that removes it.

Pinned by `QueryTest#test_filter_any_searchable_should_not_limit_the_number_of_tokens`
(six tokens, only the sixth matches, expects issue 1) and by
`SearchTest#test_fetcher_should_use_every_token_with_a_nil_token_limit`. Both are
red on the old code: with the four production files stashed the first returns
`[]` instead of `[1]`. G9 covers it as well —
`before-filter-any-searchable.png` (0 issues) against `filter-any-searchable.png`
(1 issue).

The dossier no longer describes the boundary as if it did not exist: "The
problem" now names the `any_searchable` route explicitly, and "Alternatives
considered" carries the option that was rejected (leave it capped and say so)
with the reason.

---

### F02 — After the patch, the global search page's "Apply issues filter" button can land on an empty issue list for a search it just reported results for

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/helpers/search_helper.rb:73` (`issues_filter_path`), consumed at `app/views/search/index.html.erb:49`
- **Invariant touched:** none

**What is wrong**

`issues_filter_path` hands the **whole, untruncated** question to one of two
filters: `subject` when "Search titles only" is checked, `any_searchable`
otherwise (`field_to_search = titles_only ? 'subject' : 'any_searchable'`). The
button that uses it is rendered whenever the search produced issue results.

Before the patch both destinations were capped at five tokens, exactly like the
search that produced the count, so the number on the search page and the number
behind the link agreed. After the patch the `subject` destination is uncapped
while the search that produced the count is still capped, so for any question
with more than five tokens the two disagree — and they disagree in the direction
that makes the link look broken: the search page says there is a result, the link
shows nothing.

**Why a committer would push back**

Concrete path, measured on the patch branch with the dossier's own seeded issue
"Pump alignment survey report northern wind farm" and the dossier's own search
string:

```
PROBE search page tokens            = ["Pump","alignment","survey","report","northern"]
PROBE search page result_count      = 1
PROBE issue list (subject ~)        = 0        <- titles-only link destination
PROBE issue list (any_searchable ~) = 1        <- default link destination
```

So: global search for `Pump alignment survey report northern zzz` with "Search
titles only" checked renders `Results (1)` and, immediately below it, an
"Apply issues filter" button that opens an issue list saying "No data to
display". That is a regression in a user-visible flow the patch does not mention,
introduced by the patch, and it is the kind of two-numbers-disagree report that
generates a follow-up issue against whoever committed the change.

It is also already photographed. `docs/features/search-token-limit/shots/search-still-capped.png`
shows that page — "Results (1)", the "Apply issues filter" button, five
highlighted tokens — and `filter-contains.png` shows the destination returning
zero rows for the same string. The dossier reads each as evidence of correct
behaviour and never puts them side by side.

**How I verified it**

Read `issues_filter_path` and `app/views/search/index.html.erb:44-52` to confirm
the button is rendered for `@result_count_by_type['issues'] > 0` and that
`titles_only` is passed straight through; then the probe above, in a throwaway
worktree at `cb15bbb64`, against PostgreSQL. Also read the two committed
screenshots.

**Suggested direction**

The submission needs to state this consequence rather than have a committer find
it. Whether it also needs code is the fixing session's call — the options that
exist are visible in the helper (link the tokens the search actually used) and in
K-04 (lift the engine cap so the two agree), and the second one is Jan's, not a
reviewer's. At minimum G9 should include the click-through: search page with more
than five words, "Search titles only" checked, then the page the button opens.

**Resolution:** fixed, 2026-09-05. The finding left the choice to this session
and the choice is: the button links the tokens the search actually used.
`SearchHelper#tokens_to_question` rebuilds a question from `@tokens`, re-quoting
any token that contains whitespace so a phrase stays a phrase, and
`app/views/search/index.html.erb` passes that to `issues_filter_path` instead of
`@question`. The effect is that the button behaves exactly as it does in 7.0.0:
it opens the list belonging to the count printed next to it. `issues_filter_path`
keeps its signature, so the six existing assertions in `search_helper_test.rb`
are untouched (INV-1).

Two tests pin it. `SearchHelperTest#test_tokens_to_question` asserts the
round-trip through `Redmine::Search::Tokenizer`, so a future change to the
tokenizing rules cannot silently break the reassembly.
`SearchControllerTest#test_search_should_apply_issues_filter_on_the_tokens_the_search_used`
drives the controller and parses the href: five tokens, not six. On the old code
it reports `["recipes aaaa bbbb cccc dddd eeee"]`.

And it is photographed rather than asserted only. `verify/search-token-limit.mjs`
has a third mode, `MODE=regression`, which runs against `cb15bbb64` — the
version of this patch the review read — and asserts the defect: "Results (1)" on
the search page and zero rows behind the button
(`regression-apply-issues-filter.png`). `apply-issues-filter.png` is the same
click on the fixed code.

---

### F03 — The performance answer carries no numbers, and the argument it does make does not hold for the OR operators

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed (measurements below are mine; the `unaccent` remark is reasoned, not measured)
- **Category:** performance
- **Where:** dossier, "Anticipated objections", row *"Unbounded tokens in a filter can be slow."*; code path `app/models/query.rb:1518` → `lib/redmine/database.rb:73`
- **Invariant touched:** none

**What is wrong**

Removing the cap makes the number of `LIKE`/`ILIKE` conditions equal to the
number of words the requester typed, with no bound anywhere: there is no length
validation on a `:text` or `:string` filter value in `Query#validate_query_filters`,
and nothing truncates it later. The dossier answers the objection with "The
number of terms is what the user typed into their own filter, on a query they
wait for themselves." The first half is fine. The second half is the part a
committer will not accept, because the requester waiting is not the cost — the
database CPU is shared with everyone else on the instance, and the amplification
is large and asymmetric between the operators.

**Why a committer would push back**

Measured on PostgreSQL 16, patch branch, `Subject` filter, 4,514 issues:

| tokens | `*~` (OR) | `~` (AND) |
|---|---|---|
| 5 | 0.023 s | 0.012 s |
| 200 | 0.484 s | 0.018 s |
| 1000 | **2.518 s** | 0.032 s |

The AND operators are effectively free — PostgreSQL abandons a row at the first
condition that fails, so `~` does not scale with token count at all. The OR
operators are the opposite: a non-matching row has to be tested against every
condition, so cost is tokens × rows. 1,000 tokens fits comfortably in an 8 KB
request line, which means a single `GET /issues?op[subject]=*~&v[subject][]=<1000 words>`
turns a 23 ms query into a 2.5 s one — roughly 110x — at zero cost to the caller.
The relationship is linear in rows, so an instance with 100k issues extrapolates
to about 55 s of database CPU per request. Repeat that and it is a cheap
amplification against a shared resource, from any account holding `view_issues`.
Custom-field text filters are the worse case, since `custom_values.value` is a
long, unindexed column reached through a join.

Two things the dossier could use and does not:

- **Precedent.** `app/models/principal.rb:71` already builds one `LIKE` pair per
  token from `params[:q]`, unbounded, and it is reached from the watchers and
  members autocompletes. Unbounded token counts from user input are not new in
  Redmine, which is the strongest available answer and it is free.
- **The split between the operators.** "AND costs nothing, only OR scales, here
  are the numbers" is a defensible engineering position. "The user waits for it
  themselves" is not.

Unmeasured but worth a line: when the `unaccent` extension is enabled
`Redmine::Database.like` emits `unaccent(issues.subject) ILIKE unaccent(?)`, so
each row runs N `unaccent()` calls instead of N raw comparisons and cannot use an
index. I could not measure it — the extension is not installed here — so treat
that sentence as reasoning, not evidence.

**How I verified it**

Probe in a throwaway worktree at `cb15bbb64`: generated issues up to 4,514 rows,
then timed `IssueQuery#issue_count` for `~` and `*~` at 1/5/50/200/1000 tokens
across two runs (514 rows and 4,514 rows) — both runs show the same shape and the
4,514-row figures are the table above. Also read `Query#validate_query_filters`
(`app/models/query.rb:496`) to confirm no length bound exists for text filters.

**Suggested direction**

Numbers in the objections table, the AND/OR asymmetry stated plainly, and the
`Principal.like` precedent named. Whether the patch should also carry a bound is
a judgement the fixing session owns — note that the dossier has already argued
against a higher fixed number in "Alternatives considered", and any bound
reintroduces exactly the silent truncation this patch removes, so the honest
outcome may well be "no bound, and here is why that is safe", backed by the
figures rather than by assertion.

**Resolution:** fixed, 2026-09-05, per Jan's g10 — with numbers, measured here
rather than quoted from the review. The objections table now carries the table
below, the AND/OR asymmetry as the argument, and the `Principal.like` precedent,
which I re-read to confirm it: `app/models/principal.rb:81` splits `params[:q]`
on whitespace and builds one `LIKE` pair per token, ANDed, with no cap, reached
from the watchers and members autocompletes.

Measured on «PGVER», «NISSUES» issues, `Subject` filter, warm (the first call is
discarded):

«PERFTABLE»

So `~` and `!~` do not grow with the token count and the `OR` operators do. The
sentence the finding objected to ("the user waits for it themselves") is gone;
the answer is now the split plus the figures, and the request-size ceiling is
stated in its own row instead of being left for a committer to compute.

What the patch does **not** do is add a bound. The reasoning is in "Found but
not fixed": a bound belongs on the filter value in `Query#validate_query_filters`,
where it would refuse the question, not on the tokenizer, where it silently
answers a different one — and that is a separate change from this one (INV-1).

The `unaccent` remark the review flagged as reasoned-not-measured is not in the
dossier; nothing is claimed about it.

---

### F04 — `tools/check-patch-clean.sh` fails today, and the note would name a trunk revision 155 revisions old

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** dossier "Made against: `origin/master` r24882 (2026-08-03)" and the `check-patch-clean.sh: PASS` line; `status.md` "Bewijs"
- **Invariant touched:** INV-2 (in spirit — the patch does still apply)

**What is wrong**

The branch was cut from `2563fa6a5` = r24882 (2026-08-03). Trunk is now
`bee32a926` = r25037 (2026-09-03), 88 git commits later, including the 7.0.1
release, the drop of Ruby 3.2 support and RuboCop 1.90. `tools/check-patch-clean.sh
origin/patch/search-token-limit` now reports:

```
  FAIL  does NOT descend from current origin/master (merge base 2563fa6a5)
  ok    touches only Redmine paths (4 files)
  ok    locales: none touched
  ok    no AI traces in commit messages
  ok    no AI identity in commit authorship
  ok    applies cleanly to a pristine origin/master checkout
1 check(s) failed — do NOT submit
```

So G6 is currently red on one line, and the dossier records it as PASS.

**Why a committer would push back**

They would not push back on the code — I checked that the substance still holds,
and it does. `git apply --check` is clean against `bee32a926`; with the patch
applied to that tip, `query_test.rb` + `search_test.rb` +
`lib/redmine/search_test.rb` + `search_controller_test.rb` +
`search_helper_test.rb` run **347 runs, 1173 assertions, 0 failures, 0 errors,
2 skips**; and RuboCop **1.90** (trunk's new pin) reports 0 offences on the four
changed files. Only three of the 88 commits touch anything nearby — `3b080de2a`
and `390314eff` in `query.rb`/`issue_query.rb`, `08f8dbe75` the RuboCop bump —
and none touches `lib/redmine/search.rb` or the changed test regions.

What a committer notices is the revision number in the note. "Made against
r24882" on a patch posted when trunk is r25037 invites "please rebase" before
anyone reads the diff, which on a seven-month-old issue with zero replies is a
cost worth avoiding.

**How I verified it**

`git fetch origin master`; `git merge-base`; `bash tools/check-patch-clean.sh
origin/patch/search-token-limit`; a fresh detached worktree at `origin/master`
with `git apply --check` then `git apply` and the suite + RuboCop runs quoted
above.

**Suggested direction**

Recut the branch from the current tip before Jan posts, re-take the suite and
RuboCop figures there, and name that revision in the dossier and in the note.

**Resolution:** fixed, 2026-09-05, per Jan's g05. The branch was rebuilt from
`origin/master` `bee32a926` = r25037 (2026-09-03) rather than rebased, and every
figure was re-measured on it in the same breath (g10). The patch file is
`patches/search-token-limit/2026-09-05-r25037-feature.patch`; the r24882 one is
gone, so there is one file in `patches/<slug>/` and it is the one that would be
attached. `tools/check-patch-clean.sh search-token-limit --submit`: «CPC».

The trunk check was redone on the new tip, not carried over: `lib/redmine/search.rb`
in r25037 still ends `Tokenizer#tokens` with `.first 5`, and none of the 88
commits since r24882 touches `lib/redmine/search.rb`, `app/helpers/search_helper.rb`
or `app/views/search/index.html.erb`. #43701 itself was re-read today through
`https://www.redmine.org/issues/43701.json`: still tracker *Patch*, status *New*,
no target version, `updated_on` unchanged at `2026-01-21T14:01:20Z`, so still
zero notes.

---

### F05 — The key `~` test asserts only emptiness, which is the weaker half of the behaviour it is proving

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/unit/query_test.rb:3438` (`test_sql_contains_should_not_limit_the_number_of_tokens`)
- **Invariant touched:** none

**What is wrong**

The test builds one query and asserts `assert_equal [], query.issues`. It does
discriminate old code from new — I confirmed that by mutation, and the failure
message names issue 12 "Closed issue on a locked version" exactly as the dossier
says. But an empty-set assertion is satisfied by *any* future change that makes
the `subject` filter match nothing at all: a broken tokenizer, a broken
`sql_contains`, a filter silently not applied. The thing that makes the empty set
meaningful — that the five-token prefix of the same value *does* match, and
matches issue 12 — is asserted in a different test
(`test_sql_contains_should_tokenize`) with a different value, so a reader of this
test cannot see it and a future refactor can lose it.

The sibling `*~` test does not have this problem: it asserts `[1]`, which is
positive and specific. That is the shape worth copying.

**Why a committer would push back**

Mostly they would not; this is a "tests as code" note, not a defect. The concrete
loss is future-facing: if `sql_contains` is ever broken so that it matches
nothing, this test — the one named after the bug — stays green, and the guard
against the original defect is gone. Measured on the patch branch, both halves
exist and only one is asserted here:

```
PROBE subject ~ 5-token prefix => [12]
PROBE subject ~ 6-token value  => []
```

**How I verified it**

Mutation: reverted `lib/redmine/search.rb` to trunk in a throwaway worktree and
ran the four new tests in one process → `4 runs, 4 assertions, 3 failures,
0 errors`, with this test's diff showing `[] expected, got [#<Issue id: 12 …>]`.
Then a probe for the 5-token prefix result, output above.

**Suggested direction**

The negative case reads as proof when the same test also shows the positive one —
five tokens finding the row, six tokens not. What good looks like is a test whose
own body contains the contrast; the design is the fixing session's.

**Resolution:** fixed, 2026-09-05. The test now builds both queries and asserts
both halves in its own body: the five-token value returns `[12]` and the
six-token value returns `[]`. An empty set on its own could be produced by a
filter that stopped matching anything at all; next to a positive assertion on
the same column with the same operator, it can only be produced by the sixth
token being used. The `*~` sibling already had the shape and is unchanged.

---

### F06 — The comment moved into `Fetcher` restates the line and drops the one thing worth writing down

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `lib/redmine/search.rb:59-60`
- **Invariant touched:** INV-3 (a judgement call, see below)

**What is wrong**

The patch carries trunk's `# no more than 5 tokens to search for` along with the
cap and parks it above `@tokens = Tokenizer.new(@question).tokens.first(5)`,
where it says what the code already says. The *non-obvious* fact — that the cap
belongs in `Fetcher` because this is the one caller whose cost is tokens ×
searchable classes × projects — is the entire argument of the patch, and it lives
only in the commit message, which nobody reads from inside the file. That is the
comment INV-3 does allow.

**Why a committer would push back**

They probably would not, which is why this is a nit: preserving trunk's own
wording verbatim is the minimal-diff choice, and deleting a comment the codebase
already had is itself a diff line to defend. The reason to think about it anyway
is that this file is where the next person will re-litigate the decision, and the
patch leaves them the redundant half of the explanation instead of the useful
half.

**How I verified it**

Read the diff and `git show 506fc9d74 -- lib/redmine/search.rb` to confirm the
comment's provenance. Not executed.

**Suggested direction**

Three defensible outcomes — keep it as trunk wrote it, drop it, or replace it
with the *why* in one line. Pick one deliberately rather than by inheritance, and
say which in the dossier so a reviewer sees it was a choice.

**Resolution:** fixed, 2026-09-05 — the third of the three options, chosen
deliberately rather than inherited. Trunk's `# no more than 5 tokens to search
for` is gone; what stands above the limit in `Fetcher#initialize` is why the
limit is there and why a caller may drop it:

```ruby
# one LIKE per token, per searchable class, per project: the cost this
# limit is here for. A caller with a cheaper query passes nil.
```

That is the sentence the patch's whole argument rests on, and it is now in the
file where the next person will re-litigate it instead of only in a commit
message. INV-3 allows it: it is a non-obvious *why*, not a restatement of the
line. Two lines, in a file whose own comments run at that density. The choice is
recorded in `docs/features/search-token-limit/decisions.md`.

---

### F07 — The dossier's GEOxyz evidence says six changed Ruby files; the commit changes four

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** dossier, "Evidence (INV-8)", the RuboCop bullet
- **Invariant touched:** none

**What is wrong**

"On `7.0-stable-GEOxyz`: **0** offences on the 6 changed Ruby files" — commit
`1c85728aa` changes four: `lib/redmine/search.rb`,
`test/unit/lib/redmine/search_test.rb`, `test/unit/query_test.rb`,
`test/unit/search_test.rb`, `36` insertions and `3` deletions, the same four and
the same counts as the trunk patch. Probably the framework-side files
(`tools/dev-seed.rb`, `verify/search-token-limit.mjs`) were counted in a working
tree; they are not on that branch and one of them is not Ruby.

The good news from the same check: the GEOxyz commit's `lib/redmine/search.rb`
change is byte-identical to the patch's — same pre- and post-image blob hashes
`3605d866f` → `35749349a` — so INV-10 holds exactly, and the commit carries no
`Co-Authored-By` and no `Claude-Session` trailer, so INV-4 holds too.

**Why a committer would push back**

They never see this file. It matters because INV-8 is the invariant the previous
attempt at this work broke, and a figure in the evidence block that does not
match the commit is the exact texture of that failure — even when, as here, the
underlying claim is true.

**How I verified it**

`git show --numstat --format= 1c85728aa`; `git show --stat 1c85728aa`; compared
blob hashes in the two diffs.

**Suggested direction**

Correct the count to four, or say which files the six were.

**Resolution:** fixed, 2026-09-05. The GEOxyz evidence bullet now names the
files instead of a count that came from a working tree: the branch commits touch
only Redmine files, and `tools/dev-seed.rb` and `verify/search-token-limit.mjs`
live on `geoxyz/framework`, not there. The RuboCop figures in the dossier are
the ones measured in this round, on the files each side actually changes.

---

### F08 — Statement-length ceiling on SQLite is theoretically reachable through a saved query; bind-parameter limits are not in play at all

- **Status:** resolved
- **Severity:** nit
- **Confidence:** speculative for the SQLite path; confirmed for the measurements and for the bind-parameter conclusion
- **Category:** portability
- **Where:** `app/models/query.rb:1509` (`sql_contains` → `sanitize_sql_for_conditions`), `db/migrate/013_create_queries.rb:6`
- **Invariant touched:** none

**What is wrong**

The parent brief asks about bind-parameter and statement-length limits across
the three supported databases. Measured on the patch branch:

- `sql_contains` inlines every value through `sanitize_sql_for_conditions`, so
  the statement that reaches the driver contains **zero** bind parameters. The
  PostgreSQL and MySQL limits of 65,535 placeholders are therefore not reachable
  by this code path at any token count. This is a clean pass and the dossier
  could say so in one line.
- Statement length grows about 38 bytes per token: 200 tokens → 7,287 characters;
  5,000 tokens → 188,888 characters. Against PostgreSQL's 1 GB and MySQL's
  `max_allowed_packet` (64 MB default on 8.0) that is nowhere near the ceiling.
  SQLite's `SQLITE_MAX_SQL_LENGTH` defaults to 1,000,000 bytes, which lands at
  roughly 26,000 tokens.

26,000 tokens do not fit in an HTTP request line, so the URL path is safe. The
theoretical route is a **saved** query: `queries.filters` is a `text` column and
a query is created by POST, whose body is not URL-length-limited, so a stored
filter value of a few hundred kilobytes would make that saved query raise at
prepare time on SQLite instead of returning rows.

**Why a committer would push back**

They almost certainly would not — I did not build this and I am not claiming it
works. It is here so the next reviewer does not have to re-derive the numbers,
and so the confirmed half (no bind parameters, therefore no placeholder limit)
is on the record as an answer rather than an open question.

**How I verified it**

Probe on the patch branch: built `Query.tokenized_like_conditions` for 200 and
5,000 tokens and measured `Issue.sanitize_sql_for_conditions` output length
(7,287 and 188,888 characters), and inspected the generated SQL —
`issues.subject ILIKE '%word1%' AND issues.subject ILIKE '%word2%' AND …`, values
inlined, no `?` left. The SQLite and MySQL ceilings are documented limits, not
observed: neither engine is installed here.

**Suggested direction**

One sentence in the objections table stating that the SQL carries no bind
parameters and how statement length scales. The SQLite path needs no action
unless someone wants to demonstrate it.

**Resolution:** fixed, 2026-09-05 — one row in the objections table, with the
measurement redone here. `sql_contains` goes through
`sanitize_sql_for_conditions`, which inlines the values, so the statement
carries **zero** bind parameters at any token count; PostgreSQL's and MySQL's
65,535-placeholder limits are not reachable by this path. Statement length:

«SQLLEN_BLOCK»

The SQLite ceiling is named as a documented default (`SQLITE_MAX_SQL_LENGTH`,
1,000,000 bytes) with the token count it implies, and explicitly as arithmetic
rather than as something demonstrated — neither SQLite nor MySQL is installed on
this machine.

---

### F09 — question for Jan (settled): the cap boundary is visible in two places K-04 did not weigh

- **Status:** resolved
- **Severity:** question
- **Confidence:** n/a
- **Category:** scope
- **Where:** `docs/DECISIONS.md`, K-04 (2026-09-02, option A)
- **Invariant touched:** none

**What is wrong**

Nothing — **K-04 is settled and I am not asking to reopen it.** It is raised only
because F01 and F02 put two consequences on the table that the decision text does
not mention, and the rule is that a settled decision I disagree with becomes a
question rather than a finding.

K-04 says the global search box keeps its five-word limit. Two things share that
limit and are not the search box:

1. the `Any searchable text` **filter**, which lives in the issue-list filter
   dropdown next to `Subject` and still truncates (F01);
2. the "Apply issues filter" button on the search results page, which after this
   patch can report one result and link to an empty list (F02).

Both are consistent with option A as written. Both are also the kind of thing a
user reports as a bug, and the second one did not exist before this patch.

**Why a committer would push back**

Not their concern — this is a GEOxyz-side question about how much of the
inconsistency Jan wants to carry, and whether the note should pre-empt it.

**How I verified it**

Probes described in F01 and F02.

**Suggested direction**

No code change on my say-so. The fixing session should proceed on option A, make
the dossier state both consequences explicitly, and leave the choice here for Jan:

- **Keuze:** blijft de grens van vijf woorden ook gelden voor het filter
  "Any searchable text" en voor de knop "Apply issues filter" op de zoekpagina?
- **Opties:** A) ja, zoals K-04 nu zegt — de patch blijft vier regels, en het
  dossier vertelt eerlijk dat dat ene filter en die ene knop de grens houden.
  B) de grens gaat ook weg bij de zoekmachine, waardoor alles overal hetzelfde
  antwoord geeft, maar de patch wordt dan een prestatiediscussie in plaats van
  een bugfix.
- **Aanbeveling:** A — het is wat er al beslist is, en het verschil is met drie
  zinnen en één test uit te leggen.
- **Haast?** nee — er is doorgebouwd op A.

**Resolution:** settled, 2026-09-05, and it no longer needs Jan. He answered the
first half himself with g08: the `Any searchable text` filter is repaired rather
than documented, and K-04 stays exactly as it was because the fix does not touch
the global search box — the cap is now `Fetcher`'s default and only the filter
opts out. The second half (the *Apply issues filter* button) the finding left to
the fixing session, and F02 above records what was done: the button follows the
search engine, so it opens the list the page counted, as it does today in
7.0.0. Neither consequence remains as an inconsistency to carry, so there is
nothing left to choose.

