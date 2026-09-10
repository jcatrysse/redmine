# Review run — 2026-09-09 — ChatGPT Codex (round 3)

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** freshly fetched `origin/7.0-stable-GEOxyz` `32659b6f7` and all current patch branches
- **Dossier read:** all feature dossiers/status files — yes
- **Status read:** all settled-trade-off sections — yes
- **Ran the test suite:** relied on the newly recorded merged-tree full suite (**6164 runs, 0 failures, 0 errors**) and reran mechanical gates; no third full suite
- **Scope covered:** stable ancestry, mergeability, commit identity, registry, per-feature behavior, locales, security/performance/UI findings and the new symmetry gate itself.
- **Scope NOT covered:** production database, fresh PostgreSQL/system/browser execution and deployment smoke test.

## Summary

The two production-branch blockers from Codex round 2 are fixed: upstream stable is merged and the version-subprojects narrowing exists on both sides. The new `check-symmetry.sh` catches the exact missing-code-hunk incident, but it entirely skips locale files while presenting a global INV-10 PASS. I proved that a broken user-visible translation on GEOxyz still passes the gate. Because INV-10 explicitly requires identical translations and no other checker compares their values, this is a false-green quality gate and must be corrected before it can support a production-ready claim.

**Counts:** blocker 1 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** not applicable.

---

### F01 — The symmetry gate ignores every translation value

- **Status:** open
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** scm-symmetry
- **Where:** `tools/check-symmetry.sh`, `case "$f" in config/locales/*) continue`
- **Invariant touched:** INV-5, INV-10

**What is wrong**

The new gate skips every locale file. Its comment says locales are compared as whole keys elsewhere, but the other gates only constrain which locale filenames may be touched and whether YAML parses; they do not compare the translated values between the patch and GEOxyz.

**Why a committer would push back**

Concrete path: change `setting_my_page_max_issuequery_blocks` on GEOxyz to `BROKEN TRANSLATION` while leaving the upstream patch correct, then run the advertised symmetry gate. It reports `PASS no unexplained divergence`, even though users see different text and INV-10 explicitly requires identical translations.

**How I verified it**

Created a temporary branch from the fetched GEOxyz tip, changed only that English locale value, committed it, and ran `GEOXYZ=codex-symmetry-probe REPO=/workspace/redmine tools/check-symmetry.sh mypage-query-blocks`. Exit was 0 with `every substantive line of the patch is on both sides`. The temporary branch/worktree was then deleted.

**Suggested direction**

Compare the exact values of locale keys added or changed by each patch, across all five allowed locales. Keep ordering and unrelated upstream locale changes out of the comparison, but do not skip the user-visible values. Add a self-test that mutates one value on only one side and requires a failing exit status.

**Resolution:**

---

## Where I disagree with the previous rounds

I agree that the branch-currentness and version-subprojects INV-10 blockers are fixed. I disagree with treating the new mechanical symmetry check as complete coverage: its own locale exclusion leaves a directly reproducible false PASS over a category INV-10 names explicitly.
