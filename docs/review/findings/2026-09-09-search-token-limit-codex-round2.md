# Review run — 2026-09-09 — ChatGPT Codex (round 2)

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/search-token-limit` at `587d9a11b` against current trunk `8de368193`
- **Dossier read:** `docs/features/search-token-limit/dossier.md` — yes
- **Status read:** `docs/features/search-token-limit/status.md` (the "already settled" section) — yes, again after fetching the fixes
- **Ran the test suite:** partly — combined changed-test run was interrupted after 467 s: **1607 runs, 7639 assertions, 0 failures, 0 errors, 11 skips**
- **Scope covered:** tokenizer/fetcher boundary; filter/global-search semantics; reconstructed link query; SQL cost; injection; tests and INV-10.
- **Scope NOT covered:** A new large-dataset benchmark and live browser interaction.

## Summary

No new correctness or security defect. The global search retains five-token cost control, while the explicitly cheaper issue-filter path uses all tokens. SQL remains parameterized. The unbounded filter cost is documented with measurements and explicitly accepted by K-18 rather than hidden.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

## Where I disagree with the previous rounds

I agree with the previous corrections to any-searchable and the apply-filter link. I do not reopen K-18.
