# Review run — 2026-09-09 — ChatGPT Codex (round 2)

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/wiki-export-attachments` at `eed205828` against current trunk `8de368193` with Rubyzip 3.6
- **Dossier read:** `docs/features/wiki-export-attachments/dossier.md` — yes
- **Status read:** `docs/features/wiki-export-attachments/status.md` (the "already settled" section) — yes, again after fetching the fixes
- **Ran the test suite:** partly — combined stable-branch changed-test run was interrupted after 467 s at **1607 runs, 7639 assertions, 0 failures, 0 errors, 11 skips**; current-trunk apply checks passed
- **Scope covered:** current-trunk applicability; archive paths/collisions/traversal; hierarchy/orphans; size/memory limits; permissions/readability; modal accessibility and i18n; Rubyzip API evidence and INV-10.
- **Scope NOT covered:** A fresh current-trunk Rubyzip 3.6 execution in this container and platform extraction matrix.

## Summary

The former submission blocker is closed: both exported patches apply to real current trunk and the branch is based there. The archive design handles the dangerous collision cases and does not interpolate user names into filesystem paths without sanitization. The modal matches Redmine’s established export pattern. No new defect found by static and visual review.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

## Where I disagree with the previous rounds

I reverse the previous temporal blocker because the refreshed patch now applies to r25063 and its dossier contains matched-lock Rubyzip 3.6 evidence. I agree with earlier collision, permission and hierarchy resolutions.
