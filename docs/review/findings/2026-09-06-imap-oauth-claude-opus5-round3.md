# Review run — 2026-09-06 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** `patch/imap-oauth` at `fd712001c` against `origin/master` `bee32a926` (r25037)
- **Dossier read:** `docs/features/imap-oauth/dossier.md` — yes
- **Status read:** `docs/features/imap-oauth/status.md` (the "already settled" section) — yes
- **Round-1 findings read:** **no, deliberately.** This is the blind pass of
  ronde 3 (`docs/STATE.md`): `docs/review/findings/2026-09-03-imap-oauth-claude-opus5.md`
  was not opened before or during the review. `status.md` does summarise the
  four round-1 findings and that summary was read, so the pass is blind to the
  reviewer's reasoning but not to the fact that F01–F04 existed.
- **Ran the test suite:** yes, in a fresh worktree of the patch tip with its own
  PostgreSQL 16 database.
  - the two new files together in one process: `23 runs, 81 assertions,
    0 failures, 0 errors, 0 skips` — matches the dossier exactly
  - `bin/rails test test/unit`: see **Suite** below
  - RuboCop 1.90.0 on the five changed files: `4 files inspected, no offenses
    detected` (`lib/tasks/email.rake` is excluded by Redmine's own
    `.rubocop.yml`, so four, not five) — matches the dossier
  - `tools/check-patch-clean.sh imap-oauth --submit`: PASS, re-run today
- **Scope covered:** minimality, feature scope, settings surface, conventions of
  the touched files, backward compatibility, authorization and credential
  handling, escaping (none reached — no view), i18n (none — no user-visible
  string), tests as code, test pollution, the dossier itself, INV-10 (patch
  branch vs `7.0-stable-GEOxyz`), and independent verification of the two claims
  the whole design rests on (the XOAUTH2 mechanism name against the pinned
  net-imap, and that the patch file still applies to current trunk).
- **Scope NOT covered:**
  - **`test:all` was not run.** Only `test/unit`. The dossier's full-suite
    figures (6000 vs 5977 runs, identical 29 failure names) were **not**
    reproduced; the system-test and functional halves are taken on trust here.
  - **The live G9 harness was not re-driven.** `verify-harness/imap_server.rb`
    and `token_endpoint.rb` were read, and the transcripts in `shots/` were
    read, but no new end-to-end run was made. The XOAUTH2 SASL bytes were
    instead checked directly against the installed net-imap (below).
  - **No real Office 365 or Gmail mailbox**, and no real Azure or Google
    console. Both provider walk-throughs in the dossier are unverified here,
    exactly as the dossier itself says.
  - Database portability and SCM symmetry are not applicable: the patch touches
    no query and no repository adapter.

## Summary

This is a patch a Redmine committer could take. It is small for what it does
(618 lines, of which 365 are tests), it adds no gem, no setting, no migration,
no route and no permission, and the unchanged password path is byte-for-byte
what trunk does today. The single design decision that carries the whole patch
— calling `imap.authenticate('XOAUTH2', user, token)` by mechanism name rather
than by a net-imap constant — I checked directly against the net-imap 0.6.6 the
`Gemfile` resolves to, and it produces exactly the XOAUTH2 SASL string the
protocol requires. It works, and it works without the `gmail_xoauth` gem the
patch on #43023 pulls in. The five files are byte-identical on
`patch/imap-oauth` and `7.0-stable-GEOxyz`, so INV-10 holds mechanically.

Nothing here is a blocker and nothing needs to hold up the submission. The one
code defect I found is narrow: `authorize_url` overwrites any query string the
administrator's `authorize_url` already carried, and it does so silently, while
the very same file's `token_url` keeps its query — the two halves of one
credentials file behave differently for no stated reason (F01).

The other findings are about the submission rather than the code, and two of
them cost credibility rather than correctness. `status.md` still tells Jan a
choice is open (K-06) that he closed on 2026-09-03, and `docs/REGISTER.md`
repeats it (F02). And the anticipated-objections table lets the sentence
"nothing else in Redmine reads from stdin" stand unchallenged, when
`redmine:load_default_data` — the task in every installation guide — prompts on
stdin, which is a far better answer than the one given (F03).

What surprised me positively: the tests are real tests. They call the production
code, the happy-path stub runs the actual `Net::HTTP.start` rather than
returning a canned value, and the failure-path coverage (an HTML page from an
intercepting proxy, a 200 with no token, a pasted string that is not an address)
is better than most core code has.

**Counts:** blocker 0 · major 0 · minor 3 · nit 3 · question 1

**Lines in the diff not strictly required by the feature:** 0. I looked for
reformatting, renamed variables and tidied neighbours and found none; the single
deleted line is the `imap.login` call the patch replaces with a conditional. The
two-line comment above the token fetch in `check` is the one item a
minimality-minded committer might query, and it earns its place: it explains why
the statement is where it is, not what it does.

## Suite

Run in `/home/user/wt/review-imap-oauth`, patch tip `fd712001c`, own
`redmine_test` database on PostgreSQL 16, Ruby 3.3.6, net-imap 0.6.6.

| What | Result |
|---|---|
| `imap_test.rb` + `oauth2_client_test.rb` in one process | `23 runs, 81 assertions, 0 failures, 0 errors, 0 skips` |
| `bin/rails test test/unit` | `2799 runs, 11583 assertions, 0 failures, 1 errors, 67 skips` (285s) |
| RuboCop on the changed files | `4 files inspected, no offenses detected` |
| `tools/check-patch-clean.sh imap-oauth --submit` | PASS |
| INV-10: the five files on `patch/imap-oauth` vs `7.0-stable-GEOxyz` | identical, all five |

Independent check of the load-bearing claim, run against the bundled gem:

```
$ bundle exec ruby -e 'require "net/imap"
  a = Net::IMAP::SASL.authenticator("XOAUTH2", "redmine@example.net", "an-access-token")
  puts a.class; puts a.process(nil).inspect'
Net::IMAP::SASL::XOAuth2Authenticator
"user=redmine@example.netauth=Bearer an-access-token"
```

The single `test/unit` error is `UserTest#test_destroy_should_nullify_changesets`,
which fails on `ActiveRecord::RecordInvalid: Validation failed: Type is invalid`
while building a `Repository` — it needs an SCM type this image has no binary
for. It is one of the 29 names the dossier lists as failing identically on both
sides (`1 UserTest`), and the patch touches no repository, changeset or user
code, so it cannot be caused by it. I did **not** re-run pristine trunk to
reproduce the both-sides comparison; that part of the dossier's evidence is
taken on trust.

That is the `user=<username>^Aauth=Bearer <token>^A^A` form the harness in
`verify-harness/imap_server.rb` checks byte for byte, produced here by the
mechanism-name call and nothing else, on the net-imap the `Gemfile` pins.

---

### F01 — `authorize_url` silently discards a query string that the configured authorize endpoint already carries, while `token_url` keeps its own

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed (the discard, and the asymmetry); speculative (how
  often a provider needs it)
- **Category:** correctness
- **Where:** `lib/redmine/oauth2_client.rb:44` — `uri.query = URI.encode_www_form(params)` in `authorize_url`
- **Invariant touched:** none

**What is wrong**

`authorize_url` parses `credentials['authorize_url']` and then assigns
`uri.query` outright. Any query string the administrator put in that URL is
thrown away without a word. `post_to_token_endpoint` does not do this: it builds
the request with `Net::HTTP::Post.new(uri)`, which keeps `uri.request_uri`, so a
`token_url` with a query keeps it. One credentials file, two keys that look
alike, two different behaviours.

**Why a committer would push back**

Concrete path. An administrator whose provider documents an authorize endpoint
with a parameter baked into it — Azure AD B2C's
`https://tenant.b2clogin.com/tenant.onmicrosoft.com/oauth2/v2.0/authorize?p=B2C_1_signin`
is the clearest example — pastes that URL into `authorize_url`. The task prints
a consent URL with the `p` parameter gone, the provider answers with its own
opaque error, and nothing in Redmine's output points at the cause. Verified:

```
authorize_url: https://tenant.b2clogin.com/tenant.onmicrosoft.com/oauth2/v2.0/authorize?p=B2C_1_signin
->  https://tenant.b2clogin.com/tenant.onmicrosoft.com/oauth2/v2.0/authorize?response_type=code&client_id=cid&redirect_uri=http%3A%2F%2Flocalhost
```

The everyday version needs no exotic provider: an administrator who wants one
extra parameter and appends it to `authorize_url` instead of using
`authorize_params` gets it dropped in silence. `authorize_params` is the
documented way, and there is a test that extra parameters cannot override
`response_type` or `client_id` — so the design intent is clear. The defect is
that the wrong way fails invisibly rather than loudly.

Minor and not major on purpose: Microsoft's and Google's ordinary endpoints, the
two in the walk-throughs, carry no query string, so the documented paths are
unaffected.

**How I verified it**

Called the production method with such a file in the patch worktree and printed
the result (output above). Then confirmed the other half:
`Net::HTTP::Post.new(URI.parse("https://login.example.net/token?p=B2C_1_signin")).path`
=> `/token?p=B2C_1_signin`.

**Suggested direction**

Either merge the existing query into `params` before assigning, so both keys
behave alike, or refuse an `authorize_url` that carries one with a message
naming `authorize_params` as the place for extra parameters. Silence is the only
outcome that should not survive. Whichever is chosen, one sentence in the
`oauth2_authorize` `desc` saying where extra parameters go would carry most of
the value on its own.

**Resolution:**

---

### F02 — `status.md` and the dossier tell Jan that K-06 is still open; he closed it three days ago

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/imap-oauth/status.md:215`, `docs/features/imap-oauth/dossier.md:21` and `:235`, mirrored into `docs/REGISTER.md` under "Openstaand voor Jan"
- **Invariant touched:** none

**What is wrong**

`docs/DECISIONS.md:195-199`, under "Beslist (Jan) — 2026-09-03, imap-oauth",
records the decision verbatim: *"K-06, de `client_credentials`-grant: optie A.
Alleen de refresh-token-grant gaat mee in de inzending. … K-06 is hiermee
gesloten."* The feature's own files still say the opposite:

- `status.md:215` — "En er staat één keuze voor je open: **K-06** … Er is geen
  haast: we bouwden verder zonder."
- `dossier.md:21` — "plus één keuze (K-nn in `docs/DECISIONS.md`)"
- `dossier.md:235` — "Logged as an open choice for Jan."

Because `docs/REGISTER.md` is generated from `status.md`, the register's
"Openstaand voor Jan" section carries the stale sentence too.

**Why a committer would push back**

A committer never sees this — this one is aimed at Jan. The failure path is his:
he opens `docs/REGISTER.md` to find out what is waiting on him, is told to
decide something he already decided, and either spends the time again or starts
distrusting the register. The whole point of the per-feature status file is that
it is the memory; a memory that contradicts `DECISIONS.md` is worse than no
memory, because a reader cannot tell which of the two is current without
checking both.

**How I verified it**

Read all four locations. `grep -n "K-06" docs/DECISIONS.md` gives both the open
block (`:138`) and the closing decision (`:197`); the open block was never marked
closed in place, which is presumably how the status file kept pointing at it.

**Suggested direction**

Replace the three sentences with the decision and its consequence — app-only is
covered by `oauth2_token=`, and option B is about six lines if GEOxyz ever wants
it — then regenerate the register. It would also be worth marking the K-06 block
at `DECISIONS.md:138` as closed where it stands, since that is the block a reader
lands on first, though that file is appended to rather than edited and a
framework session owns that call.

**Resolution:**

---

### F03 — the objections table concedes "nothing else in Redmine reads from stdin", which is not true, and the true answer is much stronger

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/imap-oauth/dossier.md:576` (the "Why is there an interactive rake task at all?" row)
- **Invariant touched:** none

**What is wrong**

The objection is stated as *"Why is there an interactive rake task at all?
Nothing else in Redmine reads from stdin."* and the answer argues from necessity
— only the mailbox owner can consent — without disputing the premise. The
premise is false. Trunk r25037 reads from stdin in four rake tasks:

```
lib/tasks/email.rake:29              MailHandler.safe_receive(STDIN.read, …)
lib/tasks/load_default_data.rake:33  lang = STDIN.gets.chomp!
lib/tasks/migrate_from_mantis.rake:472, 485, 492
lib/tasks/migrate_from_trac.rake:686, 735, 743
```

`redmine:load_default_data` is not an obscure one: it is the task every
installation runs, it prompts `Select language:` and blocks on `STDIN.gets`, and
it sits in the same `lib/tasks` directory as the new task.

**Why a committer would push back**

They would not push back — they would notice that the patch author does not seem
to know the directory they are patching, which is worse. A note that concedes a
false premise invites the reply "actually, `load_default_data` does exactly
this", and having a committer make your argument for you is a wasted round trip
on an issue that has already slipped two target versions.

**How I verified it**

`grep -rn "STDIN\|\$stdin" lib/tasks/*.rake` on the patch tip, then read
`lib/tasks/load_default_data.rake:20-40`.

**Suggested direction**

Turn the concession into the answer: an interactive prompt in a rake task is an
existing Redmine pattern, `redmine:load_default_data` is the precedent, and this
task follows it. The necessity argument stays as the second half.

**Resolution:**

---

### F04 — a token response whose body is valid JSON but not an object raises `NoMethodError` or `TypeError` instead of the patch's own message

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed (the behaviour); speculative (that a provider or
  proxy sends such a body)
- **Category:** correctness
- **Where:** `lib/redmine/oauth2_client.rb:157-162` (`json_body`), used at `:126` and `:134`
- **Invariant touched:** none

**What is wrong**

`json_body` rescues `JSON::ParserError` and returns `{}`, which is what makes an
HTML error page read as "returned no access token" instead of a raw parser
error. But it returns whatever `JSON.parse` produced when the parse succeeds,
and a top-level JSON value that is not an object is a successful parse. The
callers then index it with a string key:

| body | `JSON.parse` | `[…]` |
|---|---|---|
| `null` | `nil` | `NoMethodError` |
| `[]` | `[]` | `TypeError: no implicit conversion of String into Integer` |
| `123` | `123` | `TypeError` |
| `"OK"` | `"OK"` | `nil` — handled, by luck |
| *(empty)* | `ParserError` | `{}` — handled |

**Why a committer would push back**

They probably would not; this is a nit and it is marked one. It is here because
it is the same defect class the patch already went out of its way to handle one
line above, and closing it is a single `is_a?(Hash)` guard. The trigger is
unusual — a token endpoint or an interception layer answering `[]` or `null` —
which is exactly why the failure would land as an unexplained `NoMethodError` on
an administrator with no way to guess the cause.

**How I verified it**

```
$ bundle exec ruby -rjson -e '["null","[]","\"OK\"","123",""].each { … }'
"null"   -> nil  ; ["access_token"] => RAISE:NoMethodError
"[]"     -> []   ; ["access_token"] => RAISE:TypeError
"\"OK\"" -> "OK" ; ["access_token"] => nil
"123"    -> 123  ; ["access_token"] => RAISE:TypeError
""       -> ParserError
```

Against the bundled `json` gem in the patch worktree. The production code path
itself was not driven with such a body.

**Suggested direction**

Have `json_body` yield `{}` for anything that is not a `Hash`, so every
non-conforming body — unparseable, or merely not an object — reaches the same
two messages the patch already writes.

**Resolution:**

---

### F05 — the dossier rejects `ENV` for credentials on `ps` grounds, then ships `oauth2_token=` as an `ENV` credential without saying why that one is different

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/imap-oauth/dossier.md:242-244` ("Pass the client secret and refresh token as `ENV` options") against `:118-121` and `lib/tasks/email.rake:45-46`
- **Invariant touched:** none

**What is wrong**

Two statements in the same document, neither wrong, never reconciled:

- *"Rejected: they would be visible in `ps` output for the whole run, to every
  user on the host. A file the administrator can `chmod 600` is the reason there
  is a file at all."*
- and the first of the two new options, `oauth2_token=TOKEN`, which puts a
  bearer credential on that same command line.

The distinction that resolves it is real and simple — a refresh token and a
client secret are long-lived, an access token expires in an hour, and
`password=` has been on that command line since forever — but the dossier never
draws it.

**Why a committer would push back**

This is the kind of gap a reviewer picks up in one reading, and it makes the
security reasoning look unexamined — a bad look on a patch whose selling point
over the incumbent is precisely that the incumbent leaks a token. Concrete
consequence: a reviewer asks the question, the answer takes a round trip, and
the note has already spent its first impression.

**How I verified it**

Read-only: both passages of the dossier and the two option lines in
`lib/tasks/email.rake`.

**Suggested direction**

One clause in the rejected-alternative paragraph: `oauth2_token=` is on the
command line because an access token is short-lived and because it sits exactly
where `password=` already sits; the refresh token and the client secret are not,
because they are not.

**Resolution:**

---

### F06 — small departures from the two files the patch cites as its own precedent

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `lib/redmine/oauth2_client.rb:117-120`, `lib/tasks/email.rake:186-187`
- **Invariant touched:** none

**What is wrong**

Three of them, all cosmetic, all in code that names a core file as its model:

1. `app/models/webhook.rb` — the outbound-HTTP precedent the dossier cites by
   name — sets `open_timeout`, `read_timeout` **and** `write_timeout`, all 60.
   `post_to_token_endpoint` sets the first two. A form POST of a few hundred
   bytes will not stall on the write, so this is style, not risk.
2. That same file writes `::Net::HTTP` and `::Net::HTTP::Post` with the leading
   `::`; `Redmine::Oauth2Client` writes them bare. It is the only precedent in
   `app/` and `lib/redmine/`, so n=1, but it is the n the dossier chose.
3. `lib/tasks/load_default_data.rake:31-33`, the closest thing in the repo to
   the new interactive task, does `STDOUT.flush` before `STDIN.gets`;
   `oauth2_authorize` does not. I checked whether this costs anything and it
   does not: under a pty, `print "Then paste: "` is on screen before `gets`
   blocks. Consistency only.

**Why a committer would push back**

They would not, on any of the three. They are here because the dossier's
argument is "we followed the conventions of the files we point at", and a
reviewer who checks that claim finds three places where it is not quite true.
Each is a one-token change.

**How I verified it**

Read `app/models/webhook.rb:30-75` and `lib/tasks/load_default_data.rake:20-40`
on the patch tip; `grep -rn "Net::HTTP" lib/redmine/ app/ --include=*.rb` returns
`webhook.rb` and nothing else. For point 3, forked a pty and read what had been
written before `gets` blocked: `Then paste: ` — already flushed.

**Suggested direction**

Take all three or none; they are worth exactly one commit and no discussion.

**Resolution:**

---

### F07 — should the note offer to split the patch at the `oauth2_authorize` line before a committer asks?

- **Status:** open
- **Severity:** question
- **Confidence:** n/a — this is a question for Jan, not a defect
- **Category:** scope
- **Where:** the whole patch; `docs/features/imap-oauth/dossier.md`, "Anticipated objections"
- **Invariant touched:** none — and **this is not a proposal to reopen a settled
  decision.** Jan decided on 2026-09-03 that the one-off consent step must be in
  the patch and must be doable by anyone ("het mag geen stunt en vliegwerk
  zijn"). That decision stands and the question below assumes it.

**What is the question**

The patch contains two things that stand on their own: the fetch-side change
(two options on `receive_imap`, `Oauth2Client.access_token`, roughly 90 lines
with its tests) and the one-off consent helper (`oauth2_authorize`,
`Oauth2Client.authorize_url` and `refresh_token`, roughly 120 lines with its
tests). A committer with limited time can accept the first in an afternoon; the
second is the half that invites discussion, because it is interactive, because
it reads stdin, and because it is where the provider-shaped questions live.

The reason to raise it: on **#29664**, Holger Just's note 37 asked for exactly
this — a monolithic patch broken into separate pieces, each with its own
justification — and `webhook-tracker-filter` and `webhook-issue-closed` are in
this register precisely because that request was honoured. The same committer
reflex is likely on #43023.

The counter-argument is Jan's own and it is strong: shipping only the fetch side
closes nothing for an administrator who has no external tooling, which is the
situation #37688 has been stuck in since 2022. Splitting the *submission* would
recreate that.

So the question is narrow, and it is about the note rather than the code: should
the note say, in one sentence, that the patch separates cleanly at that line if
the committer prefers to take the fetch side first? Offering it costs nothing
and pre-empts the objection; not offering it keeps the ask simple and avoids
inviting a split nobody asked for.

- **Opties:** A) leave the note as it is — one patch, one ask; the design is
  defended in the objections table already. B) add one sentence offering the
  split if the committer prefers, without splitting the attachment.
- **Aanbeveling:** B, and only as a sentence — the patch stays one file. It
  costs a line and it turns the most likely committer objection into something
  Jan has already answered.
- **Haast?** No. It changes no code and blocks nothing; the note can go out
  either way.

**How I verified it**

Read-only. Counted the two halves of the diff by hunk; read the #29664 history
as recorded in `docs/features/webhook-tracker-filter/status.md` and
`docs/DECISIONS.md`.

**Suggested direction**

Jan's call. If B, the sentence belongs next to the "replacement, not an
addition" framing, not in the objections table.

**Resolution:**

---

### F08 — the three timeout assertions assert `Net::HTTP`'s own defaults, so they hold on code that passes no timeouts at all

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/unit/lib/redmine/oauth2_client_test.rb`, `test_access_token_should_return_the_token_of_a_refresh_token_grant`
- **Invariant touched:** INV-8 — this is the "green does not mean proven" case,
  in miniature
- **Found:** not in the blind read. It surfaced while fixing F06, when the
  mutation that was supposed to turn a new `write_timeout` assertion red left it
  green. Recorded here rather than fixed silently, because the whole point of
  the findings file is that it is the record.

**What is wrong**

The happy-path test asserts `assert_equal 60, http.open_timeout` and the same
for `read_timeout`. `Net::HTTP` defaults **all three** timeouts to 60, and
`expect_token_request` hands the test a freshly built `Net::HTTP.new(...)`. So
the assertions describe the object the test itself constructed, not anything
`Oauth2Client` did. They would hold if `post_to_token_endpoint` passed no
timeouts whatsoever.

**Why a committer would push back**

They would not see it — this one is aimed at us. It matters because the dossier
lists this test under "what it proves", and what it proves is less than it says.
Verified by mutation: with every timeout removed from the production call, the
test stays green.

```
$ bundle exec ruby -rnet/http -e 'h = Net::HTTP.new("x", 443)
  puts "open=#{h.open_timeout} read=#{h.read_timeout} write=#{h.write_timeout}"'
open=60 read=60 write=60

# production call reduced to: ::Net::HTTP.start(uri.host, uri.port, use_ssl: true)
$ ruby -Itest test/unit/.../oauth2_client_test.rb -n "/refresh_token_grant/"
1 runs, 9 assertions, 0 failures, 0 errors, 0 skips
```

**How I verified it**

The two commands above, in `/home/user/wt/patch-imap-oauth`, then the same
mutation again after the fix (below) to confirm it now fails.

**Suggested direction**

Move the stubbed connection off the default before handing it over, so 60 can
only come from the code under test.

**Resolution:**
