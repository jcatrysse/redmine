# Review run — 2026-09-09 — ChatGPT Codex

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `7.0-stable-GEOxyz` through `22daa7c96` (three feature commits, no patch branch), against `origin/7.0-stable` `5132aaef6`
- **Dossier read:** `docs/features/ar-sessions/dossier.md` — no (none exists; this is a company-local feature marked `upstream: nooit`)
- **Status read:** `docs/features/ar-sessions/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes, partly — the two feature test files together on SQLite: **22 runs, 76 assertions, 0 failures, 0 errors, 0 skips**. I did not run `test:all`; PostgreSQL and the prescribed Ruby 3.3.6 are not installed in this container, and the full-suite claim is therefore not independently re-measured here.
- **Scope covered:** all three feature commits and their eight changed files; serializer behaviour through the real session middleware; all production session reads in `app/` and `lib/`; the gem's serializer and store implementations; migration, deploy check and task by inspection; minimality; `git diff --check`; the focused suite figures; the status and decisions.
- **Scope NOT covered:** the full suite and system tests; PostgreSQL, MySQL and production data; a live browser run; plugin session payloads; concurrent requests and production-scale performance; the screenshots themselves; a same-lock baseline run (there is no committed lockfile).

## Summary

I would not call the JSON transition completely safe as it stands, although the focused evidence is strong and reproduced exactly. The custom serializer turns malformed JSON into an empty session, but it accepts syntactically valid JSON of the wrong shape; an array in `sessions.data` then reaches Rails and makes the user's next request a 500 instead of logging them out. I reproduced that through the real middleware, not just by calling the serializer. This matters because graceful handling of damaged or pre-transition rows is the sole reason this custom serializer exists.

The switch away from Marshal is otherwise well targeted: the normal login, revocation and nested query round trip are covered at the correct integration level, and the 22 focused tests reproduce the status file's combined **22 runs, 76 assertions** exactly (on SQLite rather than its claimed PostgreSQL environment). The deploy check is unusually thorough for a private operational change. The status file does, however, still contain one obsolete bullet saying the serializer remains Marshal, directly contradicting both the implementation and the settled K-17 decision; that should not remain in the deployment record.

**Counts:** blocker 0 · major 0 · minor 2 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0. The migration, store configuration, serializer, deploy check/task and their tests all serve either the database-store switch or its safe deployment.

---

### F01 — Valid non-object JSON still turns a damaged session row into a 500

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/redmine/session_data_serializer.rb:31-37`
- **Invariant touched:** none

**What is wrong**

`SessionDataSerializer.load` rescues `JSON::ParserError`, but the inherited JSON serializer deliberately returns any valid top-level JSON value that is not an object. Consequently values such as `[]`, `"text"`, or `1` are accepted as session data rather than treated as an unreadable row. Rails requires the loaded session to be hash-like and calls `stringify_keys` on it.

**Why a committer would push back**

Concrete failure path: a row for a signed-in user contains the valid JSON value `[]` (through accidental corruption, a manual database edit, a plugin, or any limited database-write primitive). On the user's next request the custom serializer returns an `Array`; `ActionDispatch::Request::Session#load!` calls `stringify_keys`, raises `NoMethodError`, and `/my/account` responds 500. A malformed value such as `not json at all` instead becomes `{}` and logs the user out. The distinction is accidental and violates the class's stated purpose of making an unreadable old or damaged row a clean logout rather than a request failure.

**How I verified it**

I ran an ephemeral integration test from `ruby -e` without changing the codebase. It logged in `jsmith`, replaced the live row's `data` with `[]`, requested `/my/account`, and expected the same login redirect used by the existing malformed-row test. Result: **1 run, 4 assertions, 1 failure**; the response was **500 Internal Server Error**, with `NoMethodError: undefined method 'stringify_keys' for an instance of Array` at `action_dispatch/request/session.rb:276`. I also read `activerecord-session_store` 2.3.0's `JsonSerializer.load`, which returns non-Hash JSON values unchanged.

**Suggested direction**

Define the serializer's accepted post-parse shape explicitly. Any decoded payload that cannot produce the hash Rails expects should follow the same empty-session path as malformed JSON, with integration coverage for at least one syntactically valid non-object value. Keep the fixing session responsible for deciding whether that check belongs in this subclass or in a narrower wrapper around the gem serializer.

**Resolution:**

---

### F02 — The settled section still says the serializer remains Marshal

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/ar-sessions/status.md`, under “Wat er al bekend is”
- **Invariant touched:** INV-8

**What is wrong**

The status first records that K-17 selected JSON and that commit `22daa7c96` implements it, but its settled-trade-offs list later says, in bold, **“De serializer blijft Marshal.”** The following explanation says JSON would break `session[:issue_query]`, even though the same document now records an integration test proving the query survives the JSON round trip. This is obsolete evidence left behind by the change made on the review date.

**Why a committer would push back**

There is no upstream dossier for this private feature, so this status file is the operational and review record. A future deployer or reviewer following the explicit instruction to treat the “already settled” section as authoritative is told to preserve the insecure serializer that the latest commit intentionally removed. At minimum that makes the record impossible to use to verify the deployed design; at worst it can steer a later maintenance change back to Marshal.

**How I verified it**

Read the full status file before reading previous reviews and compared the contradictory bullet with `config/application.rb`, `lib/redmine/session_data_serializer.rb`, K-17 in `docs/DECISIONS.md`, and the earlier “Bewijs — ronde 3” section in the same status file. All four say JSON; only this stale settled bullet says Marshal.

**Suggested direction**

Remove or replace the obsolete settled bullet so the section records the actual settled design: JSON, the custom empty-session compatibility behaviour, and the tested query round trip. Do not reopen K-17.

**Resolution:**

---

## Where I disagree with the previous rounds

The round-3 review found the important Marshal problem and its resolution moved the design in the right direction. I disagree only with the breadth of the resolution's statement that a row the serializer “cannot parse” now becomes an empty session and that this makes pre-existing/bad rows a logout rather than an outage. The new tests prove malformed JSON and Marshal payloads, but not valid JSON with an invalid session shape; F01 is a concrete counterexample that still produces a 500 through the real middleware. None of the previous findings or resolutions mentions that case.

I agree with the previous rounds' closed findings on `secure_session_only`, the deploy-time table check, the trim-period reporting, the irreversible migration and the PostgreSQL `text` choice. I found no reason to reopen them. I also agree that JSON's conversion of nested symbol keys is not itself a defect here: the focused query integration test exercises that application path and passed in my run.

The earlier round's serializer resolution and the current status narrative correctly say JSON, while the status file's settled section still says Marshal. I treat that as a new documentation defect rather than disagreement over the chosen design: K-17 is settled, and the stale bullet is simply no longer true.
