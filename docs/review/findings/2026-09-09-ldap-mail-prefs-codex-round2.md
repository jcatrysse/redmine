# Review run — 2026-09-09 — ChatGPT Codex (round 2)

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `7.0-stable-GEOxyz` through `f00b41afd` against `origin/7.0-stable` `5132aaef6`
- **Dossier read:** `docs/features/ldap-mail-prefs/dossier.md` — no (company-local; none exists)
- **Status read:** `docs/features/ldap-mail-prefs/status.md` (the "already settled" section) — yes, again after fetching the fix
- **Ran the test suite:** partly — combined run reached **1607 runs, 7639 assertions, 0 failures, 0 errors, 11 skips** before interruption; separate adversarial probe reproduced F01 with **1 run, 1 assertion, 1 failure**
- **Scope covered:** parsing; LDAP scope; dry-run/apply; transaction and filesystem boundaries; journal trust, replay and concurrency; undo conflicts; error output; sensitive data and performance.
- **Scope NOT covered:** production LDAP accounts, concurrent live UI edits during undo, filesystem failure injection and PostgreSQL.

## Summary

The compare-before-restore fix correctly protects changes made after an applied bulk run, but undo still trusts journals created by a **dry run**. Those journals say `applied: false`; nevertheless, if an account later happens to acquire the proposed values legitimately, undo treats that as evidence that the dry run wrote them and restores stale values. That is a concrete data-loss path and should be closed before calling the rollback facility production-ready. The forward task, transaction boundary, explicit booleans and normal applied-journal undo remain sound.

**Counts:** blocker 0 · major 0 · minor 1 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

### F01 — Undo accepts a journal whose run never applied anything

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/redmine/ldap_notification_defaults.rb:159-205`
- **Invariant touched:** none

**What is wrong**

Every report-only run writes a journal with `"applied": false`, but `undo` never checks that field. Its new conflict guard compares current preferences only with `journal['values']`, so coincidence or a later legitimate edit can make a dry-run journal look like an applied run that is safe to reverse.

**Why a committer would push back**

Concrete path: a dry run records that `all` would become `none`; it writes no account. Later the user independently selects `none`. Running `undo ... apply=1` with the dry-run journal sees the expected `none`, assumes the bulk run owns it, and changes the account back to stale `all`. The tool destroys a post-run choice even though the original run never changed anything.

**How I verified it**

Read the journal writer and undo together: the writer records `applied?`, while undo reads `users` and `values` but not `applied`. I also ran an ephemeral unit probe following the sequence above; the user ended on `all`, confirming the stale restore. The committed test suite has applied-journal conflict cases but no dry-run-journal undo case.

**Suggested direction**

Refuse an applied undo when `journal['applied']` is not exactly `true`, with an explicit operator message. Add a regression test that creates a report-only journal, later sets the proposed value independently, and proves undo cannot restore it.

**Resolution:**

---

## Where I disagree with the previous rounds

The first Codex conflict finding was valid and its compare-and-restore fix is useful, but its resolution calls the undo safe without considering whether the journal represents a run that wrote at all. This is a new edge in that fix’s trust predicate, not a reopening of transaction durability.
