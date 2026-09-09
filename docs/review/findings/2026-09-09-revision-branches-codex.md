# Review run — 2026-09-09 — ChatGPT Codex

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/revision-branches` at `53faa9a0f` against `origin/master` `bee32a926`
- **Dossier read:** `docs/features/revision-branches/dossier.md` — yes
- **Status read:** `docs/features/revision-branches/status.md` (the "already settled" section) — yes
- **Ran the test suite:** no — read-only review; repository fixtures were not prepared in a patch worktree.
- **Scope covered:** Git command construction/parsing, unsupported SCM behaviour, setting validation and exclusion patterns, escaping/link generation, issue and repository views, command-count guard, translations, tests, minimality and INV-10.
- **Scope NOT covered:** real Git fixture execution, six SCM adapters beyond interface fallback, pathological repository sizes, browser screenshots and full suite.

## Summary

I found no new defect beyond the performance trade-off Jan has explicitly accepted. Branch names are collected through argument-array SCM invocation rather than a shell string, escaped by normal link helpers, and unavailable SCMs return an empty list. The issue view can still run one Git subprocess per displayed changeset, but it is disabled by default and bounded by the existing repository-log display limit; reopening the accepted no-cache design would add no review value. Regex validation and literal-glob mode are both covered.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

## Where I disagree with the previous rounds

I agree with the previous rounds' regex anchoring, invalid-encoding and command-bound findings and with their present resolutions/documentation. I would normally object to one subprocess per changeset more strongly, but Jan explicitly chose no cache and to retain the settings; the current issue-tab brake makes that accepted cost finite. I therefore do not repeat it as a defect. I found no closure whose factual basis I could overturn by inspection.
