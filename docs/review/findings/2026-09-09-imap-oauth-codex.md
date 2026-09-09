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

- **Status:** fixed
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

- **Resolution:** fixed 2026-09-09 — **the finding is right and it is the one real defect three previous rounds walked past.** Confirmed before touching anything: `grep -rn state` over the branch returns only the provider's unrelated `session_state` in a test, so there was no nonce, nothing retained and nothing compared, and the rake task called `authorize_url` and then `refresh_token` with no value passing between them. Implemented as the suggested direction asks. `authorize_url` generates 32 bytes with `SecureRandom.urlsafe_base64` per invocation, puts it in the URL as `state`, and **returns the URL and the state together as a pair**; `refresh_token(credentials_file, redirect_url, state)` now requires it and compares it with the `state` in the pasted address using `ActiveSupport::SecurityUtils.secure_compare` before the code is exchanged. Returning the pair rather than stashing the state in a class variable is deliberate: it makes forgetting the state a signature error instead of a silent security regression, which is what the original shape allowed. **One decision inside the fix that the suggested direction did not settle, and it changes an operator-visible message:** the code is *read* before the state is checked and only *used* after. Checking state first would turn a genuine provider refusal (`?error=access_denied`, which carries no code) into "No state parameter" instead of "The authorization was refused", which is a worse message for the administrator and buys nothing — nothing is exchanged before the state check either way. Recorded in `status.md` so a later session does not "tidy" the order. **Driven red first, and stated honestly:** four new tests pin the property and fail on the old code — the state must be in the URL and differ between invocations, a mismatched state must raise, an address with no state must raise, and a blank expected state must raise. On the old code 14 of 26 tests fail in total, but **ten of those are only the changed signature rippling through** (`authorize_url` now returns a pair, `refresh_token` takes a third argument); those ten are not evidence of anything and are not counted as such. With the fix: `oauth2_client_test.rb` `26 runs, 92 assertions, 0 failures, 0 errors`, and with `imap_test.rb` in one process `31 runs, 109 assertions, 0 failures, 0 errors, 0 skips`. Full suite: `6008 runs, 31819 assertions, 27 failures, 2 errors, 92 skips`, and the 29 failing names are the **identical set** to the pristine trunk baseline measured today (`diff` empty) — the repository and `sys` tests of an image without `svn`, `hg`, `bzr` and `cvs`, none of which touches IMAP or OAuth. RuboCop 0 on the four changed files. Branch amended to `45893a712` with the identity spelled out, re-exported as `patches/imap-oauth/2026-09-09-r25037-feature.patch`, and `tools/check-patch-clean.sh imap-oauth --submit` reports PASS including that it applies to current trunk r25063. **What still cannot be proven here, and the finding's own scope note says the same:** whether a given provider actually echoes `state`. RFC 6749 §4.1.2 makes echoing it REQUIRED when the request carried it, and Microsoft and Google both do, but a provider that does not would now fail the check where it previously succeeded. That is written into the dossier's objections table with the RFC reference rather than left as an assumption.

---

## Where I disagree with the previous rounds

The previous rounds were thorough on endpoint query preservation, connection ordering, malformed JSON, timeout assertions, secret wording and patch splitting, and I agree with those resolutions. I disagree with their overall clean outcome after those fixes: neither round considered OAuth request/response correlation, and F01 is independent of all their closed findings. Accepting a provider's `session_state` parameter is not equivalent to generating and validating the OAuth `state` value.
