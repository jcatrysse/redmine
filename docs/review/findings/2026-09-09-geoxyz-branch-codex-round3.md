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

- **Status:** fixed
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

- **Resolution:** fixed 2026-09-10 — **the finding is right, and the part that matters is not the skip but the reason I gave for it.** The comment said locale files were "compared as whole keys elsewhere (INV-5)"; I wrote that without checking, and it is false. `check-patch-clean.sh` and `check-geoxyz-branch.sh` both only filter *which* locale filenames may be touched — `grep -v -E '^config/locales/(en|nl|fr|de|es)\\.yml$'` in one, `ALLOWED_LOCALES` in the other — and neither one reads a value. So nothing anywhere compared a translation, while this gate printed a global INV-10 PASS. That is the same class of defect as the blocker it was built to catch, in the tool built to catch it. **Reproduced before fixing**, by the finding's own route: a throwaway branch off the GEOxyz tip with `setting_my_page_max_issuequery_blocks` set to `BROKEN TRANSLATION`, then `GEOXYZ=codex-symmetry-probe tools/check-symmetry.sh mypage-query-blocks` — exit 0, `PASS no unexplained divergence`. **The fix compares values per key with a real YAML parser**, not lines, because the suggested direction's "keep ordering and unrelated upstream locale changes out of it" cannot be done line-wise: trunk and 7.0-stable order and neighbour the keys differently, and a line comparison of `nl.yml` is therefore noise in both directions. Both sides are flattened to `key -> value` (nested keys become `date.formats.default`, so pluralisation and format subtrees are covered too, and the locale root `en:`/`nl:` is dropped since it differs by definition), and only the keys whose value the patch itself changed against its merge-base are compared — which is what leaves unrelated upstream drift out. A key the patch adds that is missing on GEOxyz reports as `absent on GEOxyz` rather than as an equal-value pass. Where zero locale keys were checked before, **46 now are**: 5 for `mypage-query-blocks`, 30 for `revision-branches`, 1 for `webhook-issue-closed`, 5 for `webhook-tracker-filter`, 5 for `wiki-export-attachments`; the other four slugs add no locale key of their own and the output now says so instead of silently saying nothing. **The self-test is implemented as asked, and it goes through the real code path** rather than testing the comparator in isolation — testing the comparator would not have caught this defect, because the comparator was never the problem, the `continue` above it was. `--self-test` finds a locale key the slug's patch actually adds, rebuilds GEOxyz's tree with that one value broken, and requires the whole script to exit non-zero on it. It creates no branch and touches no worktree: the tree is assembled in a temporary index with `git read-tree` / `update-index` / `write-tree` and committed with `commit-tree`, leaving unreferenced objects. `--self-test --all` reports `ok` for all five slugs that have locale keys, across `en.yml` and `de.yml`, and `note … nothing to break` for the four that do not. **Driven red the only way that proves anything here:** with the `config/locales/*` skip put back, `--self-test mypage-query-blocks` prints `FAIL … the gate passed with setting_my_page_max_issuequery_blocks broken on one side only — it is blind again` and exits 1. So the regression this finding is about now fails its own gate. `--all` against the real branches is PASS, re-run after the probe branch was deleted. **On severity:** blocker is right and I am not arguing it down. A quality gate that reports PASS over a category an invariant names explicitly is worse than no gate, because it is the thing a later session will point at instead of reading the files.

---

## Where I disagree with the previous rounds

I agree that the branch-currentness and version-subprojects INV-10 blockers are fixed. I disagree with treating the new mechanical symmetry check as complete coverage: its own locale exclusion leaves a directly reproducible false PASS over a category INV-10 names explicitly.
