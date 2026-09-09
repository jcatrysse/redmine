# Review run — 2026-09-09 — ChatGPT Codex

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/assignee-nobody` at `d0243086d` against `origin/master` `bee32a926`
- **Dossier read:** `docs/features/assignee-nobody/dossier.md` — yes
- **Status read:** `docs/features/assignee-nobody/status.md` (the "already settled" section) — yes
- **Ran the test suite:** partly — after pinning the reviewer worktree to json `< 3` as current trunk does, the three touched suites together passed: **382 runs, 1236 assertions, 0 failures, 0 errors, 0 skips**.
- **Scope covered:** SQL generation for all seven operators, optional/custom-list type gates, fragment composition, UI values, tests, minimality, patch hygiene, dossier claims and INV-10 by comparing the corresponding GEOxyz diff.
- **Scope NOT covered:** full `test:all`, PostgreSQL execution, browser screenshots and every plugin caller of `sql_for_field`.

## Summary

I found no new defect that should hold this patch. The important design choice is correct: `none` is removed before ordinary integer-list SQL is generated and is folded back as a parenthesised NULL branch, including the history operators. The two `UserQuery` tests discriminate the composition bug that a superficially correct issue-query test would miss. The touched suites are green in this environment; I did not run `test:all` and do not imply that broader claim.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

## Where I disagree with the previous rounds

I agree with the previous rounds' only substantive correctness finding: the NULL-folded fragment had to be parenthesised for callers that splice it under `AND`, and the current patch plus the two `UserQuery` regressions resolve it convincingly. I also agree with the closed test-quality and dossier corrections. Unlike round 1, I would accept the current patch; I found no unresolved case they had called clean.
