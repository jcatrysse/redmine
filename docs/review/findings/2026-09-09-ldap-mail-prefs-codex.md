# Review run — 2026-09-09 — ChatGPT Codex

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `7.0-stable-GEOxyz` through `5b4943570` against `origin/7.0-stable` `5132aaef6`
- **Dossier read:** `docs/features/ldap-mail-prefs/dossier.md` — no (none exists; `upstream: nooit`)
- **Status read:** `docs/features/ldap-mail-prefs/status.md` (the "already settled" section) — yes
- **Ran the test suite:** partly — `test/unit/lib/redmine/ldap_notification_defaults_test.rb`: **35 runs, 72 assertions, 0 failures, 0 errors, 0 skips**.
- **Scope covered:** option parsing, LDAP scope, dry-run/apply symmetry, transaction and persistence behaviour, journal creation and undo, error output, tests and minimality.
- **Scope NOT covered:** production LDAP accounts, filesystem durability/permissions, full suite, browser evidence and concurrent invocations.

## Summary

The task is substantially safer than its initial shape: explicit false values remain dry runs, all account writes are transactional, and the populated journal is written before commit. I found one remaining rollback hazard. Undo applies the old values unconditionally, even if an administrator or user changed the same preferences after the bulk run, so a later undo can silently erase newer legitimate choices. That is worth fixing in an operational rollback tool, though it does not affect the forward run.

**Counts:** blocker 0 · major 0 · minor 1 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

### F01 — Undo silently overwrites preference changes made after the bulk run

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/redmine/ldap_notification_defaults.rb:153-188`
- **Invariant touched:** none

**What is wrong**

The journal records both the values applied by the run and each account's previous values, but `undo` ignores the former. It restores `previous` to every surviving account without checking whether the account still has the values that this particular run wrote.

**Why a committer would push back**

Concrete failure path: the bulk task changes an LDAP user's mail notification from `all` to `none`; afterwards that user or an administrator deliberately selects `only_assigned`; later the old journal is undone. Undo silently replaces `only_assigned` with `all`, destroying a change that did not belong to the bulk run. The journal contains enough information to detect this conflict, so silently clobbering it is avoidable.

**How I verified it**

Read `run`, `write_journal`, and `undo` together. `write_journal` stores top-level `values`; `undo` reads only `users`, slices each entry's `previous`, and calls `assign`/`persist` without comparing current values with `journal['values']`. The existing 35-test unit file passes, but contains no intervening-change case; I did not modify it.

**Suggested direction**

Treat undo as a compare-and-restore operation: restore an account only when the fields touched by the journal still equal the values that run applied. Report conflicting accounts and leave them unchanged, with a separate explicit force mechanism only if operations genuinely needs one.

**Resolution:**

---

## Where I disagree with the previous rounds

I agree that the earlier blockers around selection, dry-run, transactions and untestable rake-file logic are fixed, and that the round-3 `apply=0` and journal-before-commit findings were real. I disagree only with treating the undo design as complete after those fixes: the previous rounds established atomicity and availability of the journal, but did not test an intervening legitimate preference change. F01 concerns conflict-safe rollback, not durability or transaction ordering, so it is not a duplicate of their journal findings.
