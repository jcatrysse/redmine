# Review run — 2026-09-09 — ChatGPT Codex (round 2)

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** upstream `patch/version-subprojects` at `6ad109efe` and the deployed `7.0-stable-GEOxyz` at `f00b41afd`
- **Dossier read:** `docs/features/version-subprojects/dossier.md` — yes
- **Status read:** `docs/features/version-subprojects/status.md` (the "already settled" section) — yes, again after fetching the fix
- **Ran the test suite:** the upstream fix has recorded focused evidence; the combined GEOxyz run exercises the still-unfixed company implementation
- **Scope covered:** original scope defect and fix; authorization; query composition/performance; malformed parameters; UI cache/UX; patch hygiene and byte-level INV-10 comparison.
- **Scope NOT covered:** PostgreSQL plans, a new live browser interaction and a refreshed GEOxyz implementation because it does not exist on the fetched branch.

## Summary

The upstream patch fixes the unrelated-project result correctly at its own value-list call site, but the same fix was not applied to the branch GEOxyz actually runs. The status still says both sides carry the same change. This is an explicit INV-10 violation and makes the feature set non-production-ready even though the upstream patch itself passes its gate. The upstream narrowing remains visibility-safe and uses a subquery rather than adding a round trip.

**Counts:** blocker 1 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

### F01 — The Codex scope fix is absent from `7.0-stable-GEOxyz`

- **Status:** fixed
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** scm-symmetry
- **Where:** `app/models/query.rb:660-675` on the two target branches
- **Invariant touched:** INV-10

**What is wrong**

`patch/version-subprojects` now restricts the added `Version.visible` scope with `project.self_and_descendants.where.not(status: archived)`. The deployed GEOxyz branch still has the earlier union with only `.where(project_statement)`, which is the exact code that reproduced the unrelated-project result.

**Why a committer would push back**

Concrete path: deploy the current company branch and send the valid unrelated-project filter request from the first Codex finding; the unrelated visible version is still returned. Apply the advertised upstream patch and it is excluded. The company and upstream deliverables therefore implement different behavior while `status.md` claims they are the same.

**How I verified it**

Fetched both remote branches afresh and printed the complete `fixed_version_values` method from each. The narrowing and its regression tests exist only on `origin/patch/version-subprojects`; `origin/7.0-stable-GEOxyz` ends at `f00b41afd` and its method is still the pre-fix form. The register lists only the older GEOxyz commits.

**Suggested direction**

Apply the same narrow value-list design and regression test to `7.0-stable-GEOxyz`, rerun the GEOxyz focused and full suites, record its new commit, then run a direct per-feature diff rather than relying only on the generic branch checker.

- **Resolution:** Correct, and my miss: I applied the imap-oauth `state` fix to GEOxyz in the same round and did not do the same for this one, while `status.md` claimed both sides carried "letterlijk dezelfde wijziging". The narrowing and both regression tests are now on `7.0-stable-GEOxyz` as `73157aee5`, byte-identical to the patch (verified line by line, and the only remaining difference in `query.rb` and `queries_controller_test.rb` between the two worktrees belongs to `assignee-nobody`). `test_filter_should_not_offer_versions_of_a_project_outside_the_tree` was driven red on GEOxyz before the fix — the unrelated `OnlineStore - Unrelated project version` was in the JSON — and green after; the archived-subproject test passes either way there and is defensive, which is now said so in the dossier rather than implied. RuboCop on the four changed files: 1 offence before, 1 after, the pre-existing `Style/DirectiveScope` on line 1546 that belongs to `assignee-nobody`. And, per the suggested direction, the per-feature comparison is now mechanical: `tools/check-symmetry.sh` compares every substantive line of each patch against the same file on GEOxyz. It reports FAIL for this slug against the pre-fix tip `f00b41afd` (20 divergences) and `ok` against the new one.

---

## Where I disagree with the previous rounds

I agree with the first Codex finding and the upstream resolution. I disagree with the resolution’s implied completion: it discusses only the patch call site and does not deliver INV-10 to GEOxyz. The earlier reviews could not assess this later divergence.
