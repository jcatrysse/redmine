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

- **Status:** open
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

**Resolution:**

---

## Where I disagree with the previous rounds

I agree with the previous rounds on the shared-version union, request-parameter narrowing, query-count correction and the inherited scalar-`f` failure. Their round-3 probes checked SQL injection and visibility, but the recorded SQL-injection probe used a malformed value that becomes `3` through `to_i`; it did not check a valid id belonging to an unrelated visible project. F01 is therefore a narrower server-side scope defect that their “clean” security probe does not disprove. I also agree that it is not a confidentiality issue because `Version.visible` remains in force.
