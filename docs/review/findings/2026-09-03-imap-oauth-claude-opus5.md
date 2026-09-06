# Review run — 2026-09-03 — claude-opus5

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `patch/imap-oauth` at `d63cb35a5` against `origin/master` `bee32a926`
- **Dossier read:** `docs/features/imap-oauth/dossier.md` — yes
- **Status read:** `docs/features/imap-oauth/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes, partially — the two new files together in one process
  (21 runs, 71 assertions, 0 failures, 0 errors, 0 skips), RuboCop on the changed
  files (4 files inspected, 0 offences), `git am` onto a pristine checkout of the
  **current** trunk tip, and three targeted probes of my own to confirm findings
  F02/F03/F04. I did **not** run the full suite — the dossier's figures for it are
  taken on trust.
- **Scope covered:** minimality, scope, settings surface, conventions of the
  touched files, backward compatibility, authorization, escaping, i18n,
  performance in the hot path, tests-as-code, test pollution, the dossier itself,
  and the credential-handling paths specific to this feature.
- **Scope NOT covered:** the full suite (see above); the live end-to-end run
  against the verify harness (I read `shots/terminal-transcript.txt`, I did not
  re-run it); the two provider consoles (Azure/Google), which cannot be reached
  from here — the walk-throughs are unverified against a real tenant, as the
  status file already says; database portability and SCM symmetry, both genuinely
  n/a for this patch (no SQL, no repository code).

## Summary

A Redmine committer would very likely accept this. It is the rare patch that is
smaller than the one it replaces while doing more: 581 lines against 1197, no new
gem, no new setting, no migration, no route, no permission, and it delivers the
first tests `Redmine::IMAP` has ever had. I went looking for the usual reasons to
send a patch back and did not find them. The conventions match trunk exactly
where I checked them against real trunk code rather than against taste:
`STDIN.gets` is what `load_default_data.rake` and `migrate_from_mantis.rake`
already do, `require_relative '../../../test_helper'` is what every neighbour in
`test/unit/lib/redmine/` does, and `Redmine::Oauth2Client`'s `module` +
`class << self` shape is `Redmine::IMAP`'s own. Backward compatibility is real,
not asserted: with neither new option set, `oauth2_access_token` returns `nil` and
the original `imap.login` line runs, and there is a test pinning the blank-string
case too. The new options cannot leak into issue attributes — I checked
`MailHandler.extract_options_from_env` and it is a strict allowlist that contains
neither of them. The patch still applies cleanly with `git am` to today's trunk
(`bee32a926`), a month past the r24882 it was cut against.

I also ran the one check the status file explicitly asks a later session to
re-do: does the authorize task still know nothing about Microsoft or Google? It
does not. Every provider-specific value — endpoint, scope, redirect URI, and the
`access_type`/`prompt`/`offline_access` quirks — is read out of the
administrator's file. There is no provider name anywhere in the code.

**The single biggest reason a committer would push back is not in the code, it is
in the note Jan is about to post.** The dossier claims the patch "interpolates
neither the token nor the client secret into any string", and it makes that claim
as the direct contrast against the existing patch's real access-token leak.
`lib/tasks/email.rake:193` prints a refresh token into a string. The behaviour is
defensible and the leak comparison is still valid; the sentence as written is
not, and it is the one sentence a committer will grep. That is F01.

The other three findings are small and none of them changes what the shipped code
does. Two are worth the ten minutes because I confirmed them by experiment rather
than by reading: a 200 response with a non-JSON body escapes as a raw
`JSON::ParserError` where every other failure in this class produces a sentence
(F03), and the central happy-path test passes against production code that throws
the HTTP response away entirely (F04).

What surprised me positively: the anticipated-objections table is the best I have
seen in this repository. It answers `OAUTHBEARER`, the `oauth2` gem being in the
`:test` group, the per-run token cost, and "make it a setting" — each in one
paragraph, each correct. And the walk-throughs avoid a trap I fully expected to
find: both of them pick a client type that actually issues a client secret
(Azure **Web**, Google **Desktop app**), which matters because
`read_credentials` requires `client_secret` and a public/native registration
would not have one. Someone thought about that.

**Counts:** blocker 0 · major 1 · minor 3 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0 that I can name.
The split is 174 lines of production code, 339 of tests, and 69 in
`email.rake` of which roughly 45 are `desc` text — and every Redmine rake task
carries a `desc`, so that is convention, not padding. I checked the four comments
in `oauth2_client.rb` against INV-3 and am not raising them: two carry a genuine
non-obvious *why* (why no token cache; that the error field never carries a
credential), and trunk itself has same-shaped method comments, e.g.
`# Extracts MailHandler options from environment variables` above
`MailHandler.extract_options_from_env`.

---

### F01 — The dossier's "no credential in any string" claim is false as written, and it is the claim the note leads with

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/imap-oauth/dossier.md:388` (the claim) against `lib/tasks/email.rake:193` (the code)
- **Invariant touched:** none

**What is wrong**

The dossier says, in the section headed "**No credential appears in any
message.**": "This patch has no debug output and interpolates neither the token
nor the client secret into any string." The second half is not true.
`lib/tasks/email.rake:193` is `puts "refresh_token: #{refresh_token}"` — a
refresh token interpolated into a string and written to stdout. A refresh token
is the more sensitive of the two credentials in play: an access token expires in
about an hour, a refresh token holds mailbox access until it is revoked.

The *behaviour* is fine and should not change. The operator has just consented in
their own browser and the entire purpose of the task is to hand them the line to
paste into their credentials file; there is nowhere else for it to go. The
problem is only that the sentence claims something stronger than the patch does.

**Why a committer would push back**

This claim is not decoration — it is the load-bearing sentence of the
"why replace `..._version3.patch`" argument, and the register tells Jan to put it
in the note as "**Noem dit ook, het is een echt lek**". So a reviewer reads
"interpolates neither the token nor the client secret into any string", greps the
new patch for `#{`, and the first hit is a token being interpolated. The
substantive point — that the old patch leaks an access token into debug output
that a cron job captures, and this one has no debug output at all — is correct and
survives. But it now has to be re-established by the reader after they have
caught the author overstating, on a patch whose whole pitch is that it is the
careful one. Positioned against a core committer's own attachment on his own
issue, that is an expensive way to lose the first impression.

**How I verified it**

`grep -n 'refresh_token: #{' lib/tasks/email.rake` → `193:      puts "refresh_token: #{refresh_token}"`.
And `grep -n 'interpolates neither' docs/features/imap-oauth/dossier.md` → line 388.
I also confirmed the claim is repeated in `docs/features/imap-oauth/status.md`
and therefore in the generated `docs/REGISTER.md`, so it reaches Jan in three
places.

**Suggested direction**

Scope the claim to what is actually true and let it stay strong, because the true
version is still strong: no credential in any log, any error message, or any debug
output, and the only place a credential is ever printed is the interactive consent
task, to the terminal of the operator who just authorised it, which is the one
place it has to appear. Worth adding the operational consequence in the same
breath, since it is the sort of detail that buys credibility rather than
spending it: that line lands in shell scrollback and in `script`/CI transcripts,
so the "Afterwards" section's `chmod 600` advice could say to clear it. Fix it in
`dossier.md`, `status.md` and the regenerated register together — all three carry
it.

- **Resolution:** fixed, 2026-09-06. The claim is now scoped to what is true and
  the exception is stated in the same breath. `dossier.md` reads "No credential
  appears in any log, any error message or any debug output", then names the one
  place a credential *is* printed — the last line of `oauth2_authorize`, to the
  terminal of the operator who has just consented — and says why that is the one
  place it has to be. The operational consequence the finding asked for is in
  "Afterwards" as its own bullet: clear the scrollback, the shell history and any
  transcript of that session. `status.md` carries the same corrected wording, and
  `docs/REGISTER.md` was regenerated from it, so all three places the old
  sentence reached now say the same thing.


---

### F02 — The IMAP connection is opened, then held idle for up to two minutes while the token is fetched

- **Status:** resolved
- **Severity:** minor
- **Confidence:** probable — the ordering is confirmed by reading; the consequence I did not execute
- **Category:** correctness
- **Where:** `lib/redmine/imap.rb:40-46`
- **Invariant touched:** none

**What is wrong**

`Net::IMAP.new` at line 40 opens the TCP/TLS connection and reads the greeting.
`starttls` may follow at 42. Only then, at line 45, does `oauth2_access_token`
run — and in the `oauth2_credentials` case that makes an outbound HTTPS POST with
`open_timeout: 60, read_timeout: 60`. The socket to the mail server therefore sits
open in non-authenticated state for the whole duration of an internet round trip
that can legitimately take two minutes before it gives up. Nothing needs the IMAP
connection in order to get the token: the credentials come from a file on disk.

There is a second-order effect from the same ordering. `check` has no `ensure`, so
when the token request raises — revoked refresh token, token endpoint down, proxy
in the way — the connection opened at line 40 is never `logout`/`disconnect`ed. In
the rake path this is close to harmless because the process exits and the OS
reclaims the socket, and trunk already has the same shape for a failing `login`.
I am not raising it as its own finding for that reason, but it disappears for free
with the same reordering.

**Why a committer would push back**

RFC 3501 sets a floor on the autologout timer only for authenticated state; for
non-authenticated connections servers are free to be aggressive, and 30-second
idle drops are common. So the concrete failure path is: the token endpoint is slow
or hanging (a corporate egress proxy is the everyday cause), the mail server drops
the idle unauthenticated connection while Redmine waits, the token finally
arrives, and `imap.authenticate` at line 46 then fails on a dead socket. The
administrator gets an `EOFError` or a `Net::IMAP::Error` naming the *mail server*,
from a cron job, for a fault that was entirely in the *token endpoint*. That is
the single most misleading error this feature can produce, and it is produced by
the ordering rather than by anything in the OAuth code.

**How I verified it**

`grep -n` on the patched `lib/redmine/imap.rb` for the sequence, giving
`40: imap = Net::IMAP.new(...)`, `42: imap.starttls`,
`45: if (access_token = oauth2_access_token(imap_options))`,
`46: imap.authenticate('XOAUTH2', ...)` — so the ordering is not in doubt. The
timeouts are `lib/redmine/oauth2_client.rb`'s `open_timeout: 60, read_timeout: 60`.
I did **not** reproduce the server-side idle drop: that needs a mail server that
does it and a token endpoint that hangs, and I did not build either.

**Suggested direction**

Resolve the token before the connection exists, so that the credential is in hand
by the time anything is dialled and a token failure costs no socket at all. The
guard that decides between `authenticate` and `login` can stay exactly where it
is and keep reading `imap_options[:username].nil?`; only the point at which the
token is obtained needs to move above line 40. Keep it inside the same
username-present condition so the no-username path still makes no HTTP request —
there is already a test asserting that.

- **Resolution:** fixed, 2026-09-06, in `lib/redmine/imap.rb`. The token is now
  obtained *before* `Net::IMAP.new`, on one line guarded by the same
  `imap_options[:username].nil?` condition as before, so the no-username path
  still makes no HTTP request. A failing or slow token endpoint therefore costs
  no socket at all, and the second-order effect the finding named for free — the
  connection leaked by the missing `ensure` when the token request raises — is
  gone with it, because there is no connection yet. Pinned by a new test,
  `test_check_should_not_open_a_connection_when_the_token_cannot_be_obtained`,
  which sets `Net::IMAP.expects(:new).never` and makes
  `Oauth2Client.access_token` raise. Proven red on the old ordering: reverting
  just that hunk gives `1 runs, 1 assertions, 1 failures` on that test alone.


---

### F03 — A 200 response with a non-JSON body escapes as a raw JSON::ParserError, unlike every other failure in the class

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/redmine/oauth2_client.rb:131`
- **Invariant touched:** none

**What is wrong**

`token_from` guards the status code, then does `JSON.parse(response.body)[name]`
with nothing around it. Every other failure mode in this class is deliberately
turned into a sentence that names its cause — a missing credential names the keys,
a non-https endpoint says so, a failed request quotes `error`, an absent token
says "returned no access token", an unparseable pasted address says to paste the
whole address. This one path does not. The asymmetry is visible inside the same
file: `error_code` at line 153 explicitly rescues `JSON::ParserError` for the
*failure* branch, so the success branch was simply not given the same treatment.

**Why a committer would push back**

The failure path is ordinary rather than exotic. An intercepting HTTPS proxy or a
captive portal answers `200` with an HTML page — the very shape of thing that sits
between a Redmine server and `login.microsoftonline.com` in a corporate network.
The administrator then gets `JSON::ParserError: unexpected character: '<html>...'
at line 1 column 1` out of a cron job. That message names neither OAuth, nor the
token endpoint, nor the credentials file, and sends the reader to look for a bug
in Redmine's JSON handling. It is exactly the class of error the rest of this file
goes out of its way to prevent.

**How I verified it**

I wrote a throwaway test against the applied patch, stubbing the token endpoint to
return `Net::HTTPOK` with body `<html>proxy interception page</html>`, and printed
the class and message of what came out:

    RAISED CLASS: JSON::ParserError
    RAISED MSG:   unexpected character: '<html>proxy' at line 1 column 1

Confirmed, not inferred. The probe lived in `/tmp` and touched no file in the
patch.

**Suggested direction**

Make the success branch fail the way the rest of the class fails, so that a body
that is not JSON is reported as the token request not returning a usable token,
naming the endpoint. The existing "returned no `<name>`" message already reads
correctly for this case, so the cheapest honest fix routes into it rather than
adding a fifth distinct message. It also wants the test the other paths all have.

- **Resolution:** fixed, 2026-09-06, in `lib/redmine/oauth2_client.rb`. Body
  parsing moved into one private `json_body(response)` that returns `{}` on
  `JSON::ParserError`; `token_from`'s success branch and `error_code` both go
  through it, so the two branches now fail the same way. A 200 carrying an HTML
  page therefore raises `OAuth 2.0 token request returned no access token`
  instead of `JSON::ParserError`, which is the existing message the finding
  suggested routing into rather than a fifth one. New test
  `test_access_token_should_raise_when_a_successful_response_has_no_json_body`
  uses the finding's own reproduction body, `<html>proxy interception page</html>`.
  Proven red on the old code: reverting the one line back to
  `JSON.parse(response.body)[name]` gives `1 failures` on that test.


---

### F04 — The happy-path test passes against production code that discards the HTTP response

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/unit/lib/redmine/oauth2_client_test.rb:252-259`
- **Invariant touched:** none

**What is wrong**

`expect_token_request` stubs `Net::HTTP.start` with both `.yields(http)` and
`.returns(response)`. The real `Net::HTTP.start` given a block returns the
block's value; the stub returns `response` no matter what the block evaluates to.
`post_to_token_endpoint` relies entirely on the block's value being handed back —
that is its return statement. So the one link the test appears to be exercising is
the one link the stub replaces. `assert_equal 'an-access-token',
Redmine::Oauth2Client.access_token(file)` is therefore asserting on the stub's
configuration rather than on the code path, and it would go on passing if
`post_to_token_endpoint` stopped returning the response altogether.

**Why a committer would push back**

Less because of this patch than because of the next one: a future edit inside that
block — adding a retry, logging the status, anything that changes the last
expression — breaks the feature completely in production, since every token
request would come back `nil` and raise "returned no access token" on every cron
run, and the suite stays green. This is close to the "test that reimplements the
code it tests" pattern in the framework's forbidden list: it passes even when the
production code is wrong. It is not a defect in the shipped behaviour — the
production code is correct today, and the live harness run recorded in
`shots/terminal-transcript.txt` did exercise the real return path end to end
against a real TLS token endpoint, which is why I am calling this minor rather
than major.

**How I verified it**

By mutation, in the applied worktree. I changed the block in
`post_to_token_endpoint` to call `http.request(request)` and then evaluate to
`nil`, discarding the response, and re-ran the file:

    17 runs, 57 assertions, 0 failures, 0 errors, 0 skips

All seventeen tests pass against production code that throws the HTTP response
away. I restored the file afterwards and confirmed `git diff --stat` was empty.

**Suggested direction**

The stub should behave like the method it replaces and hand back what the block
produced, so that the return path is actually under test — Mocha's `yields` does
not do this on its own, so this needs a stub whose return value comes from the
block rather than from a fixed `.returns`. Worth noting the honest alternative:
if that is more machinery than the case deserves, say in the dossier that this
link is covered by the harness run rather than by a unit test. What should not
stand is the current position, where the test looks like it covers the return
value and does not.

- **Resolution:** fixed, 2026-09-06, in
  `test/unit/lib/redmine/oauth2_client_test.rb`. Mocha cannot make a stub return
  its block's value, so `expect_token_request` no longer stubs `Net::HTTP.start`
  at all: it builds a real `Net::HTTP`, stubs only `do_start`, `do_finish` and
  `request` on it, and hands it back from `Net::HTTP.new`. The real
  `Net::HTTP.start` then runs, and the return value the client depends on comes
  from the real method rather than from `.returns`. No connection is opened —
  `do_start` is the method that dials. The connection parameters the old
  `.with(...)` asserted are not lost, they are asserted more directly: the helper
  returns the connection and the happy-path test checks `use_ssl?`,
  `open_timeout` and `read_timeout` on it. Proven by re-running the finding's own
  mutation — `post_to_token_endpoint` calling `http.request` and then evaluating
  to `nil` — which used to give `17 runs, 0 failures` and now gives
  `18 runs, 5 failures, 3 errors`.

