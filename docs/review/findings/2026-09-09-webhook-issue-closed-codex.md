# Review run — 2026-09-09 — ChatGPT Codex

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/webhook-issue-closed` at `f3234c1ec` against `origin/master` `bee32a926`
- **Dossier read:** `docs/features/webhook-issue-closed/dossier.md` — yes
- **Status read:** `docs/features/webhook-issue-closed/status.md` (the "already settled" section) — yes
- **Ran the test suite:** no — read-only review.
- **Scope covered:** issue lifecycle callbacks, first and repeated closure, reopen/non-close cases, journal visibility, event subscription, payload timestamp and tests, minimality and INV-10.
- **Scope NOT covered:** full suite, actual background delivery, transaction retry behaviour, API consumers and browser verification.

## Summary

I found no new defect. `closed_on` is only changed by the existing `closing?` callback and is deliberately preserved on reopen, so `saved_change_to_closed_on?` distinguishes creation/transition into a closed status without firing for reopen, closed-to-closed, notes, or ordinary edits. The closed payload reuses the updated-event journal visibility logic and adds the event to the standard webhook subscription surface. Tests cover the lifecycle boundaries and the queued payload rather than merely asserting that a callback exists.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

## Where I disagree with the previous rounds

I agree with the previous rounds, including their documented residual that a second save of the same issue in one transaction can suppress `issue.closed`. I would ordinarily keep that open as a minor, but the owner explicitly accepted and documented the trade-off after a concrete probe, so I do not re-litigate it. The callback ordering for an issue created closed is likewise surprising but honestly documented. I found no new defect and no prior closure I can refute.
