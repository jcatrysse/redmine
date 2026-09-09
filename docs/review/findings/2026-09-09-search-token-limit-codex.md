# Review run — 2026-09-09 — ChatGPT Codex

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/search-token-limit` at `587d9a11b` against `origin/master` `bee32a926`
- **Dossier read:** `docs/features/search-token-limit/dossier.md` — yes
- **Status read:** `docs/features/search-token-limit/status.md` (the "already settled" section) — yes
- **Ran the test suite:** no — read-only review.
- **Scope covered:** tokenizer semantics, global-search limit preservation, unlimited text-filter call path, search-to-filter link fidelity, phrase reconstruction, tests, minimality and INV-10.
- **Scope NOT covered:** full suite, database timing at adversarial token counts, browser screenshots and every third-party caller of `Fetcher`.

## Summary

I found no new correctness defect. Moving the five-token cap from the tokenizer to `Fetcher` preserves the global-search cost boundary while allowing `IssueQuery`'s cheaper single-class filter path to opt out explicitly. Reconstructing the “apply as issue filter” question from the actual limited tokens prevents the link from silently searching more words than the result page displayed. The absence of a separate user-input ceiling is a real performance policy choice, but K-18 explicitly settles it and the dossier reports measurements rather than hiding the risk.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

## Where I disagree with the previous rounds

I agree with the previous review's important corrections: `any_searchable` needed the explicit unlimited fetcher path, and the search-to-filter link needed to carry the tokens actually searched. I also agree that an unlimited OR-filter can be expensive. I do not file that as a defect because K-18 explicitly chooses submission without a new validation ceiling and the dossier now includes measured costs. I found no additional disagreement.
