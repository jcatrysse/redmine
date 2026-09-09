# Review run — 2026-09-09 — ChatGPT Codex (round 2)

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `origin/7.0-stable-GEOxyz` `f00b41afd` against `origin/7.0-stable` `5132aaef6`
- **Dossier read:** all per-feature dossiers/status files relevant to the branch — yes
- **Status read:** all “already settled” sections — yes
- **Ran the test suite:** partly — combined changed-test run was interrupted after 467 s: **1607 runs, 7639 assertions, 0 failures, 0 errors, 11 skips**; full `test:all` was not rerun
- **Scope covered:** ancestry/currentness, mergeability, commit identity, registered commits, locales, feature symmetry, focused tests, security/performance/UI findings across the feature set.
- **Scope NOT covered:** production database, PostgreSQL, full system/browser suite and deployment smoke test.

## Summary

The company branch is not at the production-readiness gate described by its own framework. It is five commits behind the fetched upstream stable branch, although the merge is currently clean. More importantly, its version-subprojects implementation lacks the latest scope correction present in the upstream patch. The generic checker detects the first problem but not the per-feature divergence, demonstrating why INV-10 must be checked directly.

**Counts:** blocker 2 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** not applicable — this subject is the integrated company branch.

---

### F01 — The production branch is five stable commits behind

- **Status:** fixed
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** backward-compat
- **Where:** branch ancestry: `origin/7.0-stable-GEOxyz` versus `origin/7.0-stable`
- **Invariant touched:** G8

**What is wrong**

The fetched company branch is five commits behind upstream `7.0-stable`, while the framework says stable updates are merged before feature work and G8 requires the branch to be current.

**Why a committer would push back**

The exact code intended for production omits five upstream maintenance commits. Although Git currently reports a clean merge, neither the recorded suite nor this review tests the post-merge tree, so the deploy candidate is not the branch whose evidence is recorded.

**How I verified it**

Ran `tools/check-geoxyz-branch.sh /workspace/redmine`. It reported `FAIL 5 commit(s) behind origin/7.0-stable` and separately confirmed that the merge is clean, identities/locales are clean, and all registered commit SHAs exist.

**Suggested direction**

Merge—not rebase—the fetched `origin/7.0-stable`, then rerun G8 including the full suite on the resulting tree.

- **Resolution:** Merged, not rebased: `git merge origin/7.0-stable` into `7.0-stable-GEOxyz` gave `32659b6f7`, a clean 'ort' merge touching six upstream files (`icons_helper.rb`, `themes.rb`, `ja.yml`, `doc/INSTALL` and two tests) with no conflict. The branch is now 0 commits behind. The full `test:all` was then run on the merged tree, so the recorded evidence is the deploy candidate and not a tree that no longer exists — that was the substance of the finding and it was right. Note for the record that G8 had flagged the same thing and I had put the merge to Jan rather than doing it; the framework prescribes the merge as routine maintenance before feature work, so waiting was the wrong call.

---

### F02 — The integrated branch fails per-feature design symmetry

- **Status:** fixed
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** scm-symmetry
- **Where:** version-subprojects’ `Query#fixed_version_values`
- **Invariant touched:** INV-10

**What is wrong**

The integrated branch omits the latest unrelated-project narrowing from `patch/version-subprojects`.

**Why a committer would push back**

The same valid request returns different version choices depending on whether Redmine runs the upstream patch or the company branch. That defeats the framework’s central promise that acceptance upstream becomes a maintenance no-op.

**How I verified it**

Directly compared the method on both fetched refs. The patch has `where(project_id: project.self_and_descendants...)`; GEOxyz does not.

**Suggested direction**

Apply the identical behavior and test to GEOxyz and add a mechanical per-feature symmetry check capable of catching a fix applied to only one side.

- **Resolution:** Same defect as `version-subprojects` F01 and fixed in the same commit `73157aee5`; see that resolution for the evidence. The second half of the direction — a mechanical per-feature check — is now `tools/check-symmetry.sh`, registered in `docs/STATE.md`. It compares, per file the patch touches, every substantive line of `patch/<slug>` against the same file on `7.0-stable-GEOxyz`, and flags a line present on one side and absent on the other. Three cheaper designs were tried and discarded because they produce noise rather than signal: substring matching calls an edited line still present (`acts_as_webhookable` gaining an argument), and occurrence counting cannot work at all because GEOxyz carries every feature at once, so `:settings => {` is there thirteen times where one patch has it twelve. The limit is stated in the tool's own header: a change whose every line already occurs elsewhere in the file is invisible to it, so it narrows what has to be read by hand rather than replacing it. Legitimate divergences are recorded with their reason in `docs/features/<slug>/symmetry-allow.txt`; exactly one exists, trunk's `'itcpdf' => 'ITCPDF'` inflection, which arrived with upstream's Rubyzip work and is absent from 7.0-stable entirely. `--all` now reports PASS for all nine patches.

---

## Where I disagree with the previous rounds

Earlier branch checks were correct for their then-current tips. The latest fix workflow, however, called version-subprojects resolved without carrying it to the production branch; that completion claim is not supportable under INV-10.
