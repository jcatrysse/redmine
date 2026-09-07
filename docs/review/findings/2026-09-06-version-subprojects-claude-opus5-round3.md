# Review run — 2026-09-06 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** `patch/version-subprojects` at `a6d7b7392` against `origin/master` `bee32a926` (r25037)
- **Dossier read:** `docs/features/version-subprojects/dossier.md` — yes
- **Status read:** `docs/features/version-subprojects/status.md` (the "already settled" section) — yes
- **Round-1 findings read:** **no, deliberately.** This is the blind pass of
  ronde 3 (`docs/STATE.md`): `docs/review/findings/2026-09-03-version-subprojects-claude-opus5.md`
  was not opened before or during the review. `status.md` names two round-2
  outcomes in passing (the `TimeEntryQuery` test, and F03 / K-12 on
  `descendants` sharing) and those sentences were read, so the pass is blind to
  the round-1 reasoning but not to the fact that it existed.
- **Ran the test suite:** yes, in a fresh worktree of the patch tip with its own
  PostgreSQL 16 database and the Git fixture repository extracted.
  - the two touched files together in one process: `357 runs, 1173 assertions,
    0 failures, 0 errors, 0 skips`
  - `test:all`: see **Suite** below
  - RuboCop 1.90.0 on the four changed Ruby files: `4 files inspected, no
    offenses detected`
  - `tools/check-patch-clean.sh version-subprojects --submit`: PASS, re-run today
- **Scope covered:** minimality, feature scope, settings surface, conventions,
  backward compatibility, authorization (driven, not just read), SQL injection
  through the newly reachable parameters, database portability, performance and
  query counts (measured), tests as code, whether each new test is red on trunk
  (measured per test), the JavaScript change, i18n (none — the patch adds no
  string), and the dossier itself.
- **Scope NOT covered:**
  - **No browser.** The JavaScript was read, not executed. The G9 screenshots
    in `shots/` were read, not reproduced.
  - **MySQL and SQLite.** Everything ran on PostgreSQL 16. The patch adds one
    `WHERE` built from an existing helper, so the risk is low, but I did not
    check the other two adapters.
  - **No large dataset.** Query counts were measured on Redmine's fixtures.

## Summary

This one is in good shape and I found little to say about it. The change is
tiny — four lines of production Ruby, two of controller, nine of JavaScript —
and the design decision that carries it is the right one: `fixed_version_values`
takes the **union** of `project.shared_versions` and the versions owned by the
projects the query covers, rather than replacing the first with the second. That
matters because the competing patch on the issue, Go MAEDA's `43534-v2.patch`,
does replace it, and I measured what that costs: on Redmine's own fixtures the
list goes from **6 entries to 5**, and the one that disappears is
`OnlineStore - Systemwide visible version`, shared from outside the project
tree. The dossier's headline number is exactly right.

I set out to break it in six ways and five of them came back clean, which is
worth as much as a finding on a patch this far along: the newly reachable
`build_from_params` cannot be SQL-injected (`subproject_id` values go through
`to_i`); it cannot leak a private subproject's versions (`Version.visible`
enforces `:view_issues`, and anonymous sees nothing while a member of the
private child correctly does); the permission check runs *before* the new call,
not after; only `fixed_version_values` reads `project_statement`, so the
controller change does not quietly alter every other filter's values; and the
value-list caching I expected to undercut the feature is already written up in
the dossier under "Alternatives considered" and in the objections table.

I also re-measured the two numbers a committer is most likely to test. Each new
test's red-or-green status against unpatched production code matches the dossier
**test for test**: the same six fail, and the same three are green on trunk by
design, which the dossier names individually with its reasons. And the query
count is `6 against 2` on the first call in a process — `projects` 3, `settings`
1, `versions` 2 versus trunk's `projects` 1, `versions` 1 — which is the
dossier's own figure.

The single finding is a crash on malformed input, and it is only half this
patch's fault: trunk already raises the identical error from `/issues`.

**Counts:** blocker 0 · major 0 · minor 1 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

## Suite

Run in `/home/user/wt/review-version-subprojects`, patch tip `a6d7b7392`, own
`versub` database on PostgreSQL 16, Ruby 3.3.6.

| What | Result |
|---|---|
| `query_test.rb` + `queries_controller_test.rb` in one process | `357 runs, 1173 assertions, 0 failures, 0 errors, 0 skips` |
| `test:all` | `5986 runs, 31733 assertions, 27 failures, 2 errors, 92 skips` — **digit for digit the dossier's own figure** |
| RuboCop on the four changed `.rb` files | `4 files inspected, no offenses detected` |
| `tools/check-patch-clean.sh version-subprojects --submit` | PASS (5 files, no locale touched, no AI trace, applies to pristine r25037, patch file agrees with the branch) |

**The full-suite figure reproduces exactly.** The dossier records
`5986 runs, 31733 assertions, 27 failures, 2 errors, 92 skips` for the patch
side and I measure the same five numbers, which is the cleanest reproduction of
a dossier figure I have managed in this round. The 29 failing names are also
identical to the pristine trunk r25037 baseline I measured myself earlier today
(`diff` empty). One caveat on that comparison, stated so it is not read as more
than it is: my trunk baseline run had no Git fixture repository extracted, so
its *totals* are not comparable to this run's. The *names* are, because all 29
need `svn`, `hg`, `bzr` or `cvs`, none of which this image has either way.

**A process note against myself, because it affects how the first attempt at
these figures should be read.** My first `test:all` run overlapped with probe
scripts of my own that wrote to the *same* test database. Two processes sharing
one database is not safe even with transactional fixtures, so that run was
discarded rather than reported, the database was rebuilt with
`db:migrate:reset`, and the figure above comes from a clean run with nothing
else touching it.

**Independently reproduced from the dossier.**

```
# each new test against unpatched query.rb + queries_controller.rb
..._include_versions_shared_from_outside_the_project_tree          0 failures  <- green by design
..._include_subproject_versions_when_displaying_subproject_issues  1 failures
..._not_include_subproject_versions_when_not_displaying_...        0 failures  <- green by design
..._respect_selected_subprojects                                   1 failures
..._include_all_subproject_versions_when_filtering_any_subproject  1 failures
..._return_the_issues_of_an_offered_subproject_version             1 failures
test_time_entry_query_fixed_version_filter_should_include_...      1 failures
QueriesControllerTest#test_filter_should_take_the_current_...      1 failures
QueriesControllerTest#test_filter_should_ignore_request_params...  0 failures  <- green by design
```

Six red, three green, and the three green are exactly the three the dossier
names as guards.

**The regression the note is built on, measured.** `project.shared_versions`
versus the replacement approach, on fixtures, as admin on project 1:

```
admin, default settings
   shared_versions       : [ecookbook/0.1, ecookbook/1.0, ecookbook/2.0,
                            onlinestore/Systemwide visible version,
                            private-child/Private Version of public subproject,
                            subproject1/2.0]
   replacement would LOSE: [onlinestore/Systemwide visible version]
   union 6   vs   replacement 5
```

**And the feature itself does what it says**, which the fixtures alone do not
show. On stock fixtures the new clause adds nothing, because every subproject
version there is already shared with the parent. Create the case the feature
exists for — a version on subproject 3 with `sharing => 'none'` — and:

```
   in shared_versions (trunk)? false
   in new clause (patch)?      true
```

**Hypotheses driven and cleared** (all against the running application, not by
reading):

| Hypothesis | Outcome |
|---|---|
| SQL injection through the now-reachable `v[subproject_id]` | clean — `"3) OR 1=1 --"` returns the normal list, HTTP 200; `project_statement` sends the values through `to_i` |
| the new clause leaks versions of a private subproject | clean — anonymous does not see a `sharing => 'none'` version on the private child; jsmith does, and he is a member of it |
| `build_from_params` runs before the permission check | clean — it is placed after `raise Unauthorized` |
| the controller change alters every filter's values, not just versions | clean — `project_statement` is read by `fixed_version_values` and by nothing else among the `*_values` methods |
| the `preload(:project)` masks an N+1 in the other half of the union | clean — `project.shared_versions` costs `projects` 1 / `versions` 1 with no per-row query, so there is no N+1 on either side |
| the cached value list goes stale when the subproject filter changes | **true, and already documented** — `addFilter` caches in `filterOptions['values']` and never refetches. Named in the dossier under "Alternatives considered" and in the objections table, so not a finding |

---

### F01 — a scalar `f` with a matching `op` raises an unhandled `NoMethodError` on the filter endpoint

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/controllers/queries_controller.rb`, `filter` — `q.build_from_params(params.slice(:f, :op, :v))`; the raise itself is in `Query#add_filters` (`app/models/query.rb:774`)
- **Invariant touched:** none

**What is wrong**

`Query#add_filters` guards with `if fields.present? && operators.present?` and
then calls `fields.each`. `present?` is true for a non-empty String, so a
request that sends `f` as a scalar rather than an array, *together with* an
`op`, reaches `String#each` and raises. The action rescues only
`ActiveRecord::RecordNotFound`, so the request ends as a 500.

**Why a committer would push back**

Concrete path, verified against the running controller:

```
GET /queries/filter?name=fixed_version_id&project_id=ecookbook
                   &f=subproject_id&op[subproject_id]==

PROBE f not array -> RAISED NoMethodError: undefined method `each' for an instance of String
```

Any user who may view the query class can produce it. Nothing leaks and nothing
changes state — it is an unhandled exception and a 500 page, which is why this
is minor rather than major.

**It is half core's, and that matters for how it should be answered.** The same
input already raises on trunk through a different door, because
`IssuesController#retrieve_query` feeds the same `add_filters`:

```
GET /issues?set_filter=1&f=subproject_id&op[subproject_id]==   (pristine trunk)
PROBE issues#index scalar f + op -> RAISED NoMethodError: undefined method `each' ...
PROBE issues#index scalar f only -> HTTP 200        <- the guard catches this one
```

So the patch does not introduce the defect; it adds a second entry point to it.
What makes it worth reporting anyway is that the dossier *does* reason about
exactly this class of input — it explains that `c` and `t` are sliced away
precisely so "a scalar `c=subject` still returns JSON instead of raising", and
there is a test for it, `test_filter_should_ignore_request_params_that_are_not_filters`.
The hardening was deliberate and it stops one field short of the one that still
crashes.

**How I verified it**

Drove `QueriesController#filter` through `Redmine::ControllerTest` with seven
shapes of malformed input (scalar `v`, scalar `op`, scalar `f`, SQL in `v`, an
unknown filter name, a nested hash where an array belongs, and the happy path).
Six returned HTTP 200 with the correct list; scalar `f` raised. Then drove
`IssuesController#index` on the same worktree with the same two shapes to
establish that core already raises, since `retrieve_query` is untouched by this
patch.

**Suggested direction**

The smallest honest answer is one line in `Query#add_filters` — accept only an
Array, or wrap the field list — but that is core's method and outside this
feature (INV-1), so it belongs in its own trunk issue rather than in this patch.
Inside this patch the cheap option is to slice defensively in the controller, or
to say in the note that the endpoint inherits `add_filters`' existing behaviour
on malformed input. Either is fine; silently leaving a documented hardening
argument one field short is the part worth fixing.

- **Resolution:** fixed 2026-09-06, in the dossier — **no code change, deliberately.** The finding was that the objections table claimed the `slice(:f, :op, :v)` stops a scalar from raising, when it only stops that for `c` and `t`. The `build_from_params` row now states the boundary exactly: the slice removes crash surface that would have been *new to this endpoint* (`c` and `t` are read nowhere else in `filter`, so a scalar `c=subject` would have raised here and nowhere else), and it changes nothing about `f` and `op`, which still reach `Query#add_filters` — where a scalar `f` with a matching `op` raises `NoMethodError`, exactly as `/issues?set_filter=1` does on unpatched trunk through the same method. Hardening `add_filters` is a one-line change to a core method this feature has no other reason to touch, so it is named as a separate trunk issue rather than folded in (INV-1). Recorded for Jan under "Wat Jan nog moet doen".
