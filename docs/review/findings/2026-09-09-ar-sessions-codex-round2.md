# Review run — 2026-09-09 — ChatGPT Codex (round 2)

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `7.0-stable-GEOxyz` through `bf5b41a0d` against `origin/7.0-stable` `5132aaef6`
- **Dossier read:** `docs/features/ar-sessions/dossier.md` — no (company-local; none exists)
- **Status read:** `docs/features/ar-sessions/status.md` (the "already settled" section) — yes, again after fetching the fixes
- **Ran the test suite:** partly — combined changed-test run was interrupted after 467 s: **1607 runs, 7639 assertions, 0 failures, 0 errors, 11 skips**
- **Scope covered:** all serializer shapes and production session keys; corruption behaviour; store security; migration/deploy/trim paths; OWASP deserialization risk; tests and performance.
- **Scope NOT covered:** PostgreSQL, plugins, production rows and a fresh browser interaction.

## Summary

The prior valid-non-object JSON defect is correctly fixed: only Hash-derived sessions survive, while scalars, arrays, malformed JSON and Marshal payloads become an empty session. Marshal remains out of the request path and secure_session_only remains enabled. I found no new concrete type loss in Redmine core’s stored session shapes.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

## Where I disagree with the previous rounds

The first Codex finding is fixed at both unit and middleware integration levels. I agree with that resolution and the earlier deploy findings; I found no new reason to reject the current local implementation.
