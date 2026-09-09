# Review run — 2026-09-09 — ChatGPT Codex

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/version-subprojects` at `a6d7b7392` against `origin/master` `bee32a926`
- **Dossier read:** `docs/features/version-subprojects/dossier.md` — yes
- **Status read:** `docs/features/version-subprojects/status.md` (the "already settled" section) — yes
- **Ran the test suite:** partly — an ephemeral controller regression probe: **1 run, 3 assertions, 1 expected failure**, confirming that the unrelated version is returned. The committed focused suites were not run.
- **Scope covered:** remote-filter request construction, strong parameter subset, project/subproject scoping, version visibility, selected-filter dependency, tests, minimality and INV-10.
- **Scope NOT covered:** full suite, browser/network race behaviour, all query subclasses and three-database SQL execution.

## Summary

The ordinary UI flow is well designed: only filter parameters are sent, the server rebuilds only those filters, and unshared versions are offered when the selected subproject brings them into scope. I found one server-side scoping weakness. A hand-crafted remote-filter request may supply any numeric project id as a selected `subproject_id`; `project_statement` trusts it without intersecting it with the current project's descendants, so versions from an unrelated visible project can appear in this endpoint's result. This is not an authorization bypass because `Version.visible` still applies, but it is a concrete wrong result and weakens the server-side contract.

**Counts:** blocker 0 · major 0 · minor 1 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

### F01 — A forged subproject filter can pull versions from an unrelated project

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/models/query.rb:965-979`, reached from `QueriesController#filter`
- **Invariant touched:** none

**What is wrong**

For operator `=`, `project_statement` constructs the accepted ids as `[project.id] + values_for('subproject_id').map(&:to_i)`. It calculates the real descendant ids immediately above but does not intersect the submitted values with them. The new controller behaviour feeds request filters into this method when constructing remote fixed-version values.

**Why a committer would push back**

Concrete failure path: a user who can view projects A and unrelated B requests A's `queries/filter` endpoint with `name=fixed_version_id`, `f[]=subproject_id`, `op[subproject_id]==`, and `v[subproject_id][]=<B id>`. The JSON response includes B's visible unshared versions even though B is not A or one of A's subprojects. The UI does not generate this request, but the controller must not rely on option-list integrity for project scoping.

**How I verified it**

Traced `QueriesController#filter` into `Query#build_from_params`, `fixed_version_values`, and `project_statement`. I then ran an ephemeral controller test as admin, created an unshared version on unrelated project 2, requested project 1's filter endpoint with `v[subproject_id][]=2`, and asserted that version absent. Result: **1 run, 3 assertions, 1 failure**; the returned ids included the new version.

**Suggested direction**

Constrain submitted subproject ids to the current project plus its actual, non-archived descendants before using them in the version query. Add a controller regression test with two visible but unrelated projects and assert the unrelated version is absent.

- **Resolution:** fixed 2026-09-09 — **the finding is right, and it is right about something three previous rounds probed for and missed.** Their round-3 SQL-injection probe used a malformed value that `to_i` turns into `3`, a real subproject; this uses a *valid* id of a project outside the tree, which is a different question and gets a different answer. Reproduced before fixing: a controller test creating an unshared version on project 2 and requesting project 1's filter endpoint with `v[subproject_id][]=2` fails on the unfixed branch with that version in the JSON. **Fixed on this patch's own call site rather than in `project_statement`, and that is the substantive choice here.** `project_statement` is untouched upstream code — checked, our diff to `query.rb` is only the three lines in `fixed_version_values` — so changing it would alter every issue query that carries a subproject filter, which is a separate change with its own tests and its own risk. INV-1 is explicit that an upstream line's own looseness is upstream's, to be named rather than folded into an unrelated patch. So `fixed_version_values` now narrows to `project.self_and_descendants` excluding archived projects *in addition to* `project_statement`, which makes this patch's endpoint correct whatever `project_statement` accepts. `self_and_descendants` is used this way elsewhere in core (`app/models/project.rb`, `app/models/issue.rb`), and the narrowing is a subselect rather than a second round trip. **What is reported rather than fixed:** that `project_statement`'s `=` branch builds `[project.id] + values_for('subproject_id').map(&:to_i)` without intersecting the submitted ids with the descendants it computed one line earlier. That is now a row in the dossier's objections table, phrased so a committer can decide whether they want the same narrowing inside `project_statement` — where it would also cover the issue query, which is their call and not ours. **Tests:** the unrelated-project one is red without the fix and green with it. A second test asserts an archived subproject's version is never offered; it passes on **both** sides — `project_statement` already excludes archived projects from `subprojects_ids`, so it is a guard documenting existing behaviour, not evidence, and it is labelled that way. The 17 filter tests pass together, RuboCop is 0 on the four changed files, and the full-suite figures are in `status.md`. **Agreed on severity and on scope:** minor, and not a confidentiality issue — `Version.visible` was and is in force, so this was a wrong answer rather than a leak.

---

## Where I disagree with the previous rounds

I agree with the previous rounds on the shared-version union, request-parameter narrowing, query-count correction and the inherited scalar-`f` failure. Their round-3 probes checked SQL injection and visibility, but the recorded SQL-injection probe used a malformed value that becomes `3` through `to_i`; it did not check a valid id belonging to an unrelated visible project. F01 is therefore a narrower server-side scope defect that their “clean” security probe does not disprove. I also agree that it is not a confidentiality issue because `Version.visible` remains in force.
