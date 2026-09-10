# Review run — 2026-09-10 — claude-opus5-round4

- **Reviewer:** Claude Code (Opus 5), round 4 (Deel A of `docs/review/prompt-round4.md`)
- **Reviewed:** `patch/version-subprojects` at `6ad109efe` against its base `bee32a926` (r25037), and against real trunk `167e487ee` (r25065) for applicability
- **Dossier read:** `docs/features/version-subprojects/dossier.md` — yes
- **Status read:** `docs/features/version-subprojects/status.md` — yes
- **Ran the test suite:** partly — the two touched files in one process, on the patch and on pristine r25037, plus a purpose-written probe of the endpoint the patch changes. Not `test:all`; the r25037 baseline this dossier quotes (5977 runs) is the one I measured today for `imap-oauth` on the same revision, and it matches.
- **Scope covered:** the whole production diff; **the new request-parameter path into `Query#build_from_params`, probed with malformed input against both the patch and pristine trunk**; the SQL of `fixed_version_values` including whether `project_statement` can resolve against a `Version` relation; the JavaScript change read for what it now puts in a URL; the eleven new tests read as coverage; RuboCop; INV-10 through `tools/check-symmetry.sh`; the dossier read as a submission.
- **Scope NOT covered:** no `test:all`, no `7.0-stable-GEOxyz` suite for this feature, and no browser. I did not measure the query-count claims in the objections table (5 statements against trunk's 2); I read the code paths that produce them but did not count them.

## Summary

There is one real regression here, and it is in the line the patch adds rather
than in anything it inherits. `QueriesController#filter` now feeds request
parameters straight into `Query#build_from_params`, and `Query#add_filters`
calls `fields.each`, so a `f` parameter that is a string instead of an array
turns a 200 into a 500. I probed it on both sides of the same machine: pristine
r25037 answers **HTTP 200** and ignores the parameter; with the patch the same
request raises `NoMethodError: undefined method 'each' for an instance of
String`. The dossier already knows about this crash — it is written up as a
loose end that "does not belong to this patch" and was deliberately left alone
under INV-1 — and that reasoning was right while nothing in the patch routed
into it. It no longer is: the guard belongs at the call site the patch
introduces, one line, without touching `Query#add_filters` at all.

Everything else holds. The union with `shared_versions` instead of a
replacement is the whole point of the patch against `43534-v2.patch`, and the
test that pins it names the versions shared from outside the tree. The
`project_statement` fragment does resolve against a `Version` relation, because
`Version.visible` joins `:project`, so `projects.id` is in scope — I checked
that rather than assuming it. The archived-subproject exclusion has its own
test. RuboCop is clean, INV-10 is mechanically clean, and the fifteen errors in
the touched suites are the json 3.0.2 `ActiveSupport::JSON.decode` family that
this image has on pristine trunk too.

The second finding is a characterisation, not a defect: the objections table
calls the stale value cache "pre-existing for every remote filter", which is
true of the mechanism and not of the consequence — before this patch the target
version list did not depend on any other filter, so a stale cache could not be
observed.

**Counts:** blocker 0 · major 1 · minor 0 · nit 1 · question 0

**Lines in the diff not strictly required by the feature:** 0.

## Evidence I re-measured

| Claim | What I measured | Same? |
|---|---|---|
| pristine trunk r25037: 5977 runs | **5977 runs** (measured today, same revision, matched lock) | yes |
| touched suites green | **359 runs, 1136 assertions, 0 failures, 15 errors** — all fifteen are `ArgumentError: wrong number of arguments (given 2, expected 1)` from `ActiveSupport::JSON.decode` under json 3.0.2; the same file has 11 of them on pristine r25037 and the patch adds 4 JSON-decoding tests | yes, once the environment is subtracted |
| RuboCop on the 4 changed files: 0 | **0** (rubocop 1.90.0) | yes |
| `tools/check-symmetry.sh version-subprojects`: PASS | **PASS** | yes |
| `tools/check-patch-clean.sh version-subprojects --submit`: PASS | **PASS** against real trunk r25065 | yes |
| `project_statement` works against a `Version` relation | **confirmed**: `Version.visible` is `joins(:project).where(...)`, so `projects.id` resolves | yes |
| `/queries/filter` tolerates request junk | **only partly** — see F01 | no |

---

### F01 — the patch turns a 200 into a 500 on the endpoint it changes, through the line it adds

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/controllers/queries_controller.rb:103`
- **Invariant touched:** none

**What is wrong**

The patch adds `q.build_from_params(params.slice(:f, :op, :v))` to
`QueriesController#filter`. `build_from_params` reaches `Query#add_filters`,
whose body is `if fields.present? && operators.present?` then `fields.each`. A
`String` is `present?` and does not respond to `each`, so any request whose `f`
parameter is a scalar raises `NoMethodError` and the endpoint answers 500 where
it used to answer 200 and ignore the parameter.

This is the crash `status.md` and the register already describe as a loose end
in `Query#add_filters`, found in round 3, and deliberately left alone because
"die regel zit in een kernmethode waar deze feature verder niets mee te maken
heeft (INV-1)". That reasoning was correct at the time. It stops being correct
once the feature adds the call that reaches it: the input this endpoint now
consumes is the patch's own, and so is the place to validate it.

**Why a committer would push back**

Because it is a regression the patch causes, on the endpoint the patch is
about, found by sending one ordinary-looking URL. Measured on this machine,
same image, same lock, same fixtures:

```
GET /projects/1/queries/filter?name=fixed_version_id&f=subproject_id&op[subproject_id]==

  pristine trunk r25037   -> HTTP 200
  patch 6ad109efe         -> NoMethodError: undefined method `each` for an instance of String
```

Any authenticated user who may view the project can send it. There is no data
exposure and nothing is written; it is a 500 in the log and a broken response
to an XHR. Two neighbouring shapes are fine and I checked them: a scalar `op`
answers 200, and an unknown filter name answers 200.

**How I verified it**

A probe subclassing `QueriesControllerTest` (so it inherits the fixtures) with
three requests, run twice — once in `/home/user/wt/patch-version-subprojects`,
once in a pristine `bee32a926` worktree with the same `Gemfile.lock` and its own
database. Output above; `PROBE scalar-f` is the only line that differs between
the two runs.

**Suggested direction**

A guard at the call site, not in `Query#add_filters`. Something with the shape
of `if params[:f].is_a?(Array)` around the new line restores trunk's behaviour
for malformed input, keeps the feature for well-formed input, and leaves the
shared core method untouched, so INV-1 stays satisfied. A test in
`queries_controller_test.rb` alongside
`test_filter_should_ignore_request_params_that_are_not_filters` — which covers
`c` and `t` but not a scalar `f` — pins it, and is red on the current patch.
Whether the wider `Query#add_filters` hardening is still worth a separate
redmine.org issue is unchanged by this; it just is not what unblocks this patch.

**Resolution:**

---

### F02 — "pre-existing for every remote filter" is true of the mechanism and not of the consequence

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** "Alternatives considered" and the objections table in `dossier.md`
- **Invariant touched:** none

**What is wrong**

`addFilter` caches a remote filter's value list in `filterOptions['values']`
and never refetches, so a subproject filter changed after the target version
filter was added leaves the older list on screen. The dossier discloses this
plainly, which is the important half, and then attributes it: "That is
pre-existing behaviour of every remote filter and this patch does not change
it."

The cache is pre-existing. The staleness is not. Before this patch the target
version list did not depend on any other filter, so a cached list and a fresh
one were always the same list and no user could observe a difference. This
patch is what makes the value list a function of the other filters, and
therefore what makes the cache observable.

**Why a committer would push back**

Mildly, and only if they try it. The sentence invites the reading "nothing to
see here", when the accurate reading is "this patch introduces the first case
where that cache can show you the wrong thing, and fixing it means touching a
shared code path, which we chose not to do". The second version is a stronger
argument for the same decision, because it is the one a reviewer cannot catch
you out on.

**How I verified it**

Read `addFilter` in `app/assets/javascripts/application-legacy.js`: the cache
assignment is unchanged by the patch, and no other remote filter's values
depend on the filter state. Read-only; I did not drive a browser.

**Suggested direction**

Rewrite the clause: the cache is pre-existing, the observable staleness is new
here, and invalidating it is a separate change to a shared code path. No code
change.

**Resolution:**

---

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks.

**Round 3 found the `add_filters` crash and filed it as somebody else's
problem; the same round's patch is what made it this patch's problem.** The
register says it plainly: "`Query#add_filters` crasht op een `f`-parameter die
geen lijst is ... hij is er bewust uit gehouden (INV-1). Gevonden in ronde 3."
That is the right call for a crash you merely noticed. It is the wrong call
once your own diff adds the only line in the file that hands unvalidated
request parameters to that method — and the two facts are in the same feature,
found in the same round, written down two paragraphs apart. Nobody joined them.
I would not have either, without running it.

**Codex round 2 caught the INV-10 half of this feature and that is why the
symmetry gate exists.** The blocker was that `patch/version-subprojects`
carried a scope narrowing GEOxyz did not, while `status.md` claimed both sides
were the same change. `tools/check-symmetry.sh` now answers that mechanically
and passes here. Worth saying because it is the clearest case in the register
of a review finding turning into a gate rather than into a fix.

**Three of the eleven tests are Go MAEDA's, kept under his own names.** I went
looking for the thing that usually goes wrong when someone adopts a reviewer's
tests — that they are kept but no longer discriminate — and
`test_fixed_version_filter_should_include_subproject_versions_when_displaying_subproject_issues`
is the one that was tightened rather than merely inherited, so it now also
holds with `display_subprojects_issues` off. The dossier says so and the code
matches.

**Nothing in `docs/DECISIONS.md` looks wrong to me.** g16g — lead the note with
the regression in `43534-v2.patch` rather than with our own feature — is the
right order for a note that has to disagree with a core committer's patch.
