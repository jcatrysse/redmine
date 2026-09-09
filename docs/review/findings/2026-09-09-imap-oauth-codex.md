# Review run — 2026-09-09 — ChatGPT Codex

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/imap-oauth` at `10efe8761` against `origin/master` `bee32a926`
- **Dossier read:** `docs/features/imap-oauth/dossier.md` — yes
- **Status read:** `docs/features/imap-oauth/status.md` (the "already settled" section) — yes
- **Ran the test suite:** no — read-only review; the real authorization flow additionally requires a human and provider credentials.
- **Scope covered:** authorization URL and code exchange, refresh grant, endpoint validation, error handling, IMAP authentication and connection lifetime, secret exposure, task interface, tests, minimality and dossier claims.
- **Scope NOT covered:** a real Gmail/Microsoft consent flow, provider-specific token behaviour, full suite, browser verification and live IMAP.

## Summary

I would not submit the interactive authorization helper unchanged. It implements the authorization-code flow without generating and validating OAuth `state`, so the pasted callback is not tied to the authorization request this process started. That permits authorization-response substitution: a callback generated in another authorization attempt can be pasted and exchanged, binding inbound mail to the wrong mailbox. The refresh-token and XOAUTH2 paths are otherwise carefully separated, HTTPS-only, and avoid opening IMAP before token acquisition succeeds.

**Counts:** blocker 0 · major 1 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

---

### F01 — The authorization-code flow has no `state` binding

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** security
- **Where:** `lib/redmine/oauth2_client.rb:39-69,88-108`
- **Invariant touched:** none

**What is wrong**

`authorize_url` sends `response_type`, `client_id`, `redirect_uri` and optional provider parameters, but creates no unpredictable `state`. `refresh_token` extracts only `code` from whichever URL is pasted and therefore cannot verify that the response belongs to the authorization request printed by this invocation.

**Why a committer would push back**

Concrete failure path: an attacker or mistaken operator obtains a valid callback URL from a separate authorization attempt for a different mailbox/client session and gets that URL pasted at this prompt. The task accepts its code without any request correlation and writes the returned refresh token into the administrator's workflow; subsequent `receive_imap` runs authenticate to the substituted mailbox and import its messages into Redmine. Interactive copy/paste changes the transport, not the OAuth response-substitution risk.

**How I verified it**

Read the complete helper and its 325-line test file. A repository-wide search of the branch for `state` finds no generated nonce, persisted expected value or comparison; the only related test deliberately accepts an unrelated provider parameter named `session_state`. Not executed against a provider.

**Suggested direction**

Generate a high-entropy `state` value for each authorization invocation, include it in the authorization URL, retain it only for the lifetime of the interactive task, and require an exact match in the pasted redirect before exchanging the code. Add discriminating tests for matching, missing and mismatched state.

**Resolution:**

---

## Where I disagree with the previous rounds

The previous rounds were thorough on endpoint query preservation, connection ordering, malformed JSON, timeout assertions, secret wording and patch splitting, and I agree with those resolutions. I disagree with their overall clean outcome after those fixes: neither round considered OAuth request/response correlation, and F01 is independent of all their closed findings. Accepting a provider's `session_state` parameter is not equivalent to generating and validating the OAuth `state` value.
