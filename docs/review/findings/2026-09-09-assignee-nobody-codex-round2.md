# Review run — 2026-09-09 — ChatGPT Codex (round 2)

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/assignee-nobody` at `d0243086d` against current trunk `8de368193`
- **Dossier read:** `docs/features/assignee-nobody/dossier.md` — yes
- **Status read:** `docs/features/assignee-nobody/status.md` (the "already settled" section) — yes, again after fetching the fixes
- **Ran the test suite:** partly — combined changed-test run was interrupted after 467 s: **1607 runs, 7639 assertions, 0 failures, 0 errors, 11 skips**
- **Scope covered:** SQL semantics for all operators; fragment grouping; custom-field/type gates; injection/escaping; UI screenshot; tests; performance and INV-10.
- **Scope NOT covered:** PostgreSQL and a new live browser interaction.

## Summary

No new defect. The patch still composes the NULL alternative safely for all operators and confines the pseudo-value to optional non-custom lists. The UI uses Redmine’s existing “nobody” vocabulary and remains keyboard-native through the ordinary multi-select. There is no additional query or authorization surface.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

## Where I disagree with the previous rounds

I agree with the previous rounds and with the first Codex review. The parenthesisation defect remains convincingly fixed; no closed finding became invalid after the latest fetch.
