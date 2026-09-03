# imap-oauth — IMAP inbound mail authenticated with OAuth 2.0

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** Redmine kan post ophalen uit een Gmail- of
  Office 365-mailbox zonder wachtwoord, met OAuth 2.0. Microsoft heeft
  wachtwoord-login op IMAP uitgezet, dus zonder dit werkt inkomende mail daar
  helemaal niet meer.
- **Waar het vandaan komt:** 5.1-commit `bbf5c0eb3`, en de patch die daaruit
  kwam hangt al aan je eigen issue #43023 (versie 3, 49 kB).
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen
- **Kans dat Redmine dit aanneemt:** redelijk — het issue staat op naam van
  kerncommitter Marius BĂLTEANU met doelversie 7.1.0, dus ze *willen* de
  functie; wat er nu hangt is te groot (1197 regels, twee nieuwe gems, vier
  nieuwe rake-taken). Deze herschrijving is ~90 regels productiecode, nul
  nieuwe gems en nul nieuwe rake-taken.
- **Wat jij nog moet doen:** zie `status.md` — één note aan #43023, plus één
  keuze (K-nn in `docs/DECISIONS.md`).

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `2563fa6a5` = r24882 van 2026-08-03. De mirror
  liep 1 maand achter op het moment van schrijven (2026-09-03).
- **Lost trunk dit al op?** Nee. `lib/redmine/imap.rb` doet onvoorwaardelijk
  `imap.login(username, password)` en kent geen enkel SASL-mechanisme.
  `lib/tasks/email.rake` biedt alleen `password=`. Er is geen OAuth-client in
  Redmine; de `oauth2` gem in de `Gemfile` staat in de **test**-groep, met het
  commentaar "for testing oauth provider capabilities" — dat is de
  Doorkeeper-kant (Redmine *is* een OAuth-provider), niet de client-kant.
- **Bestaand issue op redmine.org?** Ja, drie, en dat is beslissend:
  - [#43023](https://www.redmine.org/issues/43023) "IMAP email retrieval via
    OAuth2" — **Jans eigen issue**, aangemaakt 2025-07-16, assignee Marius
    BĂLTEANU, doelversie **7.1.0** (was 7.0.0, verschoven op 2026-06-29, en
    daarvóór "Candidate for next major release"). Drie patches hangen eraan;
    versie 3 (`/attachments/download/34823`) is precies commit `bbf5c0eb3`.
  - [#37688](https://www.redmine.org/issues/37688) "Move to modern
    authentication (OAuth 2.0) from IMAP…" — Raja Govindan, 2022-09-19, open,
    77 notes, vrijwel uitsluitend omwegen: getmail6 met
    `getmail-gmail-xoauth-tokens`, een IMAP-proxy die basic auth naar OAuth
    vertaalt, een PowerShell-script op Microsoft Graph, en een betaalde plugin.
    Dat is het bewijs van de behoefte, en het bewijs dat de kern het vandaag
    niet kan.
  - [#37705](https://www.redmine.org/issues/37705) — duplicaat van #37688,
    gesloten.
  - Gezocht op: `OAuth IMAP` (all_words, niet titles_only) en `XOAUTH2`
    (0 resultaten).
- **Verandert iets in trunk het ontwerp?** Ja, twee dingen, en beide in ons
  voordeel:
  1. `net-imap` is in trunk gepind op `~> 0.6.1` en heeft
     `Net::IMAP::SASL::XOAuth2Authenticator` ingebouwd, dus
     `imap.authenticate('XOAUTH2', username, token)` werkt zonder gem. De
     `gmail_xoauth`-gem uit de bestaande patch is overbodig — de `~> 0.4.24`
     die GEOxyz's 5.1-branch vandaag pint heeft hem ook, onder de oude naam
     `Net::IMAP::XOauth2Authenticator`. De patch roept bewust de
     **mechanismenaam** aan (`authenticate('XOAUTH2', ...)`) en niet die
     constante, want die is in 0.4 al deprecated.
  2. `app/models/webhook.rb` (nieuw in 7.0) doet uitgaande
     `Net::HTTP.start`-POSTs met timeouts. Er is dus precedent in de kern voor
     een uitgaand HTTP-verzoek, en er is een stijl om te volgen.

---

# The problem

Redmine can fetch incoming mail over IMAP with `rake redmine:email:receive_imap`,
which authenticates with `imap.login(username, password)` — the IMAP `LOGIN`
command, with a password. Microsoft disabled basic authentication for IMAP on
Exchange Online, and Google restricts it to accounts with an application
password. For a Microsoft 365 mailbox there is no password Redmine can send any
more, so `receive_imap` simply cannot connect. This is what
[#37688](https://www.redmine.org/issues/37688) has been about since 2022.

What administrators do instead, all of it visible in that issue: run `getmail6`
with `getmail-gmail-xoauth-tokens` and pipe into `redmine:email:read`; deploy an
IMAP proxy that speaks basic authentication to Redmine and OAuth 2.0 to the
provider; drive Microsoft Graph from a PowerShell script; or buy a plugin. Every
one of these exists only to hold an OAuth 2.0 access token, because Redmine
cannot.

The gap is narrow. `Net::IMAP` has shipped `XOAUTH2` and `OAUTHBEARER`
authenticators since net-imap 0.4, and Redmine already pins `net-imap ~> 0.6.1`.
What is missing is a way to tell `Redmine::IMAP` to use one of them, and a way
for an unattended cron job to hold a credential that does not expire after an
hour.

# Why this belongs in core

`Redmine::IMAP.check` is called from a rake task and takes a fixed option hash;
there is no hook, no setting and no class to subclass. A plugin can only reach
it by reopening `Redmine::IMAP` and replacing `check` wholesale — a 40-line
method it would then have to keep in step with core, including the
`move_on_success` / `move_on_failure` flag handling. That is the definition of a
patch a plugin should not be carrying.

More to the point, this is not a feature on top of Redmine's mail handling; it
is the authentication of that mail handling. Redmine already owns
`imap.login(...)`, `apop`, `ssl` and `starttls` for the same connection. The
mechanism used to authenticate belongs in the same place as the other three.

# Proposed change

Two new options on the existing `redmine:email:receive_imap` task. No new task
family, no new task, no interactive flow inside Redmine.

    oauth2_token=TOKEN        an OAuth 2.0 access token, used instead of
                              password= and authenticated with XOAUTH2
    oauth2_credentials=FILE   a YAML file with the OAuth 2.0 client credentials
                              and refresh token; Redmine requests an access
                              token with them on each run

`oauth2_token=` covers the case where the operator's own tooling already holds a
token (Azure managed identity, the `client_credentials` grant, `oauth2l`, a
secrets manager). `oauth2_credentials=` covers the normal unattended case: the
administrator authorises once, out of band, and gives Redmine the long-lived
refresh token.

The credentials file:

```yaml
token_url: https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/token
client_id: 00000000-0000-0000-0000-000000000000
client_secret: SECRET
refresh_token: REFRESH_TOKEN
scope: https://outlook.office.com/IMAP.AccessAsUser.All offline_access
```

| File | Change |
|---|---|
| `lib/redmine/imap.rb` | authenticate with `XOAUTH2` when an access token is available, `login` otherwise; resolve the token from the two new options |
| `lib/redmine/oauth2_client.rb` | new, ~55 lines: read the credentials file, POST the refresh token grant, return the access token |
| `lib/tasks/email.rake` | pass the two options through; document them, and add one worked example per provider |
| `test/unit/lib/redmine/imap_test.rb` | new: first tests for `Redmine::IMAP` |
| `test/unit/lib/redmine/oauth2_client_test.rb` | new |

**New setting / migration / gem / route / permission:** none.

- **No gem.** `Net::IMAP::SASL::XOAuth2Authenticator` is in the pinned
  `net-imap ~> 0.6.1`, and the patch reaches it through the mechanism name
  rather than the constant, so it does not care which of net-imap's two names
  is current. `Net::HTTP` and `JSON` are stdlib, and `app/models/webhook.rb`
  already establishes how core makes an outbound HTTP request. The patch on
  #43023 adds `oauth2` and `gmail_xoauth`; both are avoidable.
- **No setting.** Every option is per-invocation, like `host` and `folder`. A
  site with two mailboxes needs two cron lines, not two settings.
- **No migration, route or permission.** Nothing is stored in the database and
  nothing is reachable over HTTP.

**Translations (INV-5):** none. The patch adds no user-visible string. The rake
task's option documentation and `desc` are English-only throughout
`lib/tasks/email.rake`, as everywhere in `lib/tasks`, and the two failure
messages are exceptions raised out of a rake task — the same treatment
`Redmine::IMAP` gives its existing failures, which are not localised either.
There is therefore no locale table in this dossier and no `-locales.patch`.

**Backward compatibility:** total. Both options default to absent; when neither
is given the code path is `imap.login(username, password)`, byte for byte what
trunk does. No existing invocation changes behaviour, and `receive_pop3` is not
touched.

# Alternatives considered

**Put the whole authorization flow in Redmine (what is attached to #43023
today).** Four new rake tasks — `o365_oauth2_init`, `google_oauth2_init`,
`receive_imap_oauth2`, `oauth2_status` — plus a `help` task, two provider
documents, two gems, and a token cache written to `config/` with `chmod 0600`.
1197 lines. It has been on the issue for over a year and has slipped two target
versions. Rejected for three reasons, in order of weight:

1. *The interactive part cannot be maintained and cannot be tested.* It prints
   an authorize URL, waits on `STDIN` for the operator to paste back a redirect
   URL, and exchanges the code. That needs a human and real provider
   credentials, so it can never have a test, and it hardcodes each provider's
   scope list and endpoint paths — Microsoft's and Google's, which Redmine would
   then be on the hook to track. Doing the one-time authorization out of band
   (Google's OAuth playground, `az`, `oauth2l`, a five-line script) costs the
   administrator one afternoon, once, and costs Redmine nothing forever.
2. *The token cache is what makes it complicated.* Almost half the helper code
   in that patch — `normalize_token_file`, `secure_file`, the `PERMITTED`
   whitelist of YAML symbols, `mask_token`, the refresh-and-rewrite branch —
   exists only because an access token is written to disk and read back. Not
   caching it removes all of it. The cost is one HTTPS POST per fetch run, next
   to an IMAP session that is about to open anyway.
3. *A parallel task family duplicates the fetch loop's option surface.*
   `receive_imap_oauth2` re-implements `host`, `port`, `ssl`, `starttls`,
   `folder`, `move_on_success` and `move_on_failure`, and re-derives the
   `MailHandler` options, so every future change to `receive_imap` has to be
   made twice. Options on the existing task cannot drift.

**Accept only `oauth2_token=` and leave token minting out entirely.** A
six-line patch, and it would be accepted quickly, but it does not close
#37688: the administrator still needs an external tool to turn a refresh token
into an access token every hour, which is exactly today's situation. Kept as
half of the design rather than as the whole of it.

**Support the `client_credentials` grant as well as `refresh_token`.** About six
more lines, and it is what Microsoft recommends for a service mailbox
(app-only access, no user consent). Deliberately left out of the first patch to
keep one grant type under review; `oauth2_token=` already covers it for anyone
who mints the token themselves. Logged as an open choice for Jan.

**Read the credentials from `configuration.yml`.** Rejected: `configuration.yml`
is per-environment, not per-mailbox, and an installation fetching two mailboxes
would have nowhere to put the second set. The IMAP options are already
per-invocation for exactly this reason.

**Pass the client secret and refresh token as `ENV` options.** Rejected: they
would be visible in `ps` output for the whole run, to every user on the host. A
file the administrator can `chmod 600` is the reason there is a file at all.

# Tests

Neither `Redmine::IMAP` nor `Redmine::POP3` had a single test before this patch;
`test/unit/lib/redmine/imap_test.rb` is the first.

| Test | What it proves |
|---|---|
| `ImapTest#test_check_should_login_with_the_password` | the unchanged path: with no OAuth option, `check` calls `imap.login` and never `imap.authenticate`. Green on trunk as well — this is the guard that the patch changes nothing for existing installations |
| `ImapTest#test_check_should_authenticate_with_xoauth2_when_an_access_token_is_given` | `oauth2_token=` authenticates with `XOAUTH2` and the token, and `login` is not called even though a password is also present |
| `ImapTest#test_check_should_authenticate_with_the_token_requested_from_the_credentials_file` | `oauth2_credentials=` asks `Redmine::Oauth2Client` for a token with that path, and authenticates with what it returns |
| `ImapTest#test_check_should_login_with_the_password_when_the_oauth2_options_are_blank` | an empty `oauth2_token=` or `oauth2_credentials=` on the command line falls back to the password rather than authenticating with an empty token |
| `Oauth2ClientTest#test_access_token_should_return_the_token_of_a_refresh_token_grant` | the request is a `refresh_token` grant carrying exactly `grant_type`, `client_id`, `client_secret` and `refresh_token`, POSTed to the path in `token_url`, and the `access_token` of the response is returned |
| `Oauth2ClientTest#test_access_token_should_send_the_scope_when_given` | `scope` is sent when the file has one (Microsoft requires it; Google does not) |
| `Oauth2ClientTest#test_access_token_should_raise_when_a_credential_is_missing` | a file missing `client_secret` and `refresh_token` names both, and no HTTP request is made |
| `Oauth2ClientTest#test_access_token_should_raise_when_the_file_does_not_contain_a_hash` | a file that is not a YAML mapping is rejected instead of raising `NoMethodError` deeper down |
| `Oauth2ClientTest#test_access_token_should_raise_when_the_token_url_is_not_https` | an `http://` token endpoint is refused before the request, so a client secret is never sent in clear |
| `Oauth2ClientTest#test_access_token_should_raise_with_the_error_code_of_a_failed_request` | a 400 response yields `OAuth 2.0 token request failed with 400 Bad Request (invalid_grant)` — the provider's error code, which is the whole diagnosis, and nothing else from the body |
| `Oauth2ClientTest#test_access_token_should_raise_when_a_failed_request_has_no_json_body` | a 502 with an HTML body still gives a clean message rather than a `JSON::ParserError` masking the real failure |
| `Oauth2ClientTest#test_access_token_should_raise_when_the_response_holds_no_token` | a 200 without an `access_token` is an error, not a `nil` token handed to the IMAP server |

**Evidence (INV-8 — figures, not claims):**

- **full** suite with the patch: `RAILS_ENV=test bundle exec ruby bin/rails test`
  → ``5802 runs, 30727 assertions, 27 failures, 2 errors, 92 skips``
- **full** suite on a pristine trunk worktree at the same revision, own
  database → `5790 runs, 30686 assertions, 27 failures, 2 errors, 92 skips`
- the failing test names are **identical** on both sides (`diff` empty):
  29 names, and 5802 - 5790 = 12 is exactly the number of
  new tests. All 29 are repository, changeset and `SysController` tests that
  need `svn`, `hg`, `bzr` or `cvs`, none of which exist in this image.
- the two new files run together in one process: `12 runs, 43 assertions,
  0 failures, 0 errors, 0 skips`
- RuboCop on the changed files: `0` offences (baseline at the merge base on the
  same files: `0`). `lib/tasks/email.rake` is not linted — `lib/tasks/**/*` is
  excluded in Redmine's own `.rubocop.yml`, so that file had human review only.
- each new test verified red on the old code: the two files were copied into a
  throwaway pristine-trunk worktree with its own database and run there →
  `12 runs, 10 assertions, 7 failures, 4 errors`. **11 of the 12 are red**, and
  the single green one is
  `test_check_should_login_with_the_password` — the guard, which must be green
  on both sides. Being honest about *why* each is red: the eight
  `Oauth2ClientTest` cases and
  `ImapTest#test_check_should_authenticate_with_the_token_requested_from_the_credentials_file`
  and `..._when_the_oauth2_options_are_blank` fail with
  `NameError: uninitialized constant Redmine::Oauth2Client`, which is real but
  is the class not existing rather than behaviour differing. The one test whose
  red is purely behavioural is
  `test_check_should_authenticate_with_xoauth2_when_an_access_token_is_given`,
  which fails at `lib/redmine/imap.rb:44` — trunk calls `login` exactly where
  the patch calls `authenticate`.
- patch applies to pristine `origin/master` r24882: yes — `git am` on a fresh detached worktree at
  `origin/master`, 5 files changed, 351 insertions
- `tools/check-patch-clean.sh`: PASS (descends from trunk, only Redmine paths, no locales, no AI
  trace in the message or the authorship, applies to a pristine checkout)

# Live verification (G9)

A rake task has no page to photograph, so this went one step further than a
screenshot: the feature was driven end to end against a **real IMAP server on a
real socket** and a **real HTTPS token endpoint**, and the evidence is the issue
that arrived in Redmine. Both servers are in
`docs/features/imap-oauth/verify-harness/`:

- `imap_server.rb` speaks IMAP on 127.0.0.1:1143, holds one message, and
  accepts exactly one `AUTHENTICATE XOAUTH2` credential — it verifies the
  base64 SASL response byte for byte against
  `user=<username>\x01auth=Bearer <token>\x01\x01`. It refuses `LOGIN` with
  `NO [AUTHENTICATIONFAILED] basic authentication is disabled`, which is what
  Exchange Online now does.
- `token_endpoint.rb` serves the token endpoint over TLS with a self-signed
  certificate, so the client's certificate verification is genuinely exercised
  (the run points `SSL_CERT_FILE` at that certificate; the failure table below
  shows what happens when it does not).

Nothing left the machine and no real credentials were used. Screenshots in
`docs/features/imap-oauth/shots/`, terminal transcripts in
`shots/terminal-transcript.txt`.

| Function | Screenshot | What it shows |
|---|---|---|
| The mailbox before any mail is fetched | `before-issues-list.png` | nine issues in the verification project, none from mail. Taken against the **pristine trunk** worktree |
| Mail fetched with a token minted by Redmine, and with a token supplied on the command line | `issues-list.png` | issues #12 (`oauth2_credentials=`), #13 (`oauth2_token=`) and #14 (the unchanged `password=` path) |
| The issue built from the fetched mail | `issue-from-xoauth2-mail.png` | Bug #12, author Dev Verify0 resolved from the `From:` header, description as sent |

The before/after pair is the point: on trunk the same command line fails,
because `oauth2_credentials=` is not an option it knows and it falls back to
`LOGIN`:

    Net::IMAP::NoResponseError: basic authentication is disabled
    lib/redmine/imap.rb:44:in `check'

Failure paths verified, all five with the patch applied:

| Case | Expected | Observed |
|---|---|---|
| refresh token revoked (endpoint answers 400 `invalid_grant`) | the provider's reason, named | `OAuth 2.0 token request failed with 400 Bad Request (invalid_grant)` |
| `token_url` is `http://` | refused before anything is sent | `token_url must be an https URL`, and the endpoint logged no request |
| token endpoint's certificate not trusted | TLS verification is really on | `OpenSSL::SSL::SSLError: ... certificate verify failed (self-signed certificate)` |
| credentials file absent | says which path | `Errno::ENOENT: No such file or directory @ rb_sysopen - /etc/redmine/nope.yml` |
| access token rejected by the mailbox | the server's own reason | `Net::IMAP::NoResponseError: Invalid credentials` |
| no OAuth option at all | byte-identical to trunk | the IMAP server logged `LOGIN redmine@example.net a-mailbox-password`, and issue #14 was created |

**No credential appears in any message.** That was checked deliberately,
because the patch on #43023 prints the full access token when `imap_debug=1` is
set: it does `puts imap_options.inspect`, and `imap_options[:password]` is the
token. This patch has no debug output and interpolates neither the token nor the
client secret into any string.

Screenshots read, not just generated: yes — `before-issues-list.png` was
checked for the *absence* of the three mail subjects, `issues-list.png` for all
three present with the right trackers, and `issue-from-xoauth2-mail.png` for the
author having been resolved to the Redmine user behind the `From:` address
(which proves `MailHandler` ran, not just that IMAP connected).

# Anticipated objections

| Objection | Answer |
|---|---|
| "This does not do the OAuth authorization flow, so an administrator still has manual work." | Once, out of band, to get a refresh token — the same one-off consent step every OAuth setup needs, and there are five well-trodden ways to do it (Google's OAuth playground, `az`, `oauth2l`, `getmail-gmail-xoauth-tokens`, a five-line script). After that the cron job runs unattended forever. What is *not* in Redmine is the part that would need Redmine to track two providers' authorize endpoints, scope lists and consent quirks. |
| "Why not use the `oauth2` gem, which is already in the Gemfile?" | It is in the `:test` group, for testing Redmine's own OAuth **provider** (Doorkeeper). Using it here would move a test dependency into production for one form POST. `Net::HTTP` and `JSON` are stdlib, and `app/models/webhook.rb` already establishes how core makes an outbound HTTP request. |
| "Why not `gmail_xoauth`, as the earlier patch does?" | Redundant. `Net::IMAP::SASL::XOAuth2Authenticator` is in the pinned `net-imap ~> 0.6.1`, and 0.4.x already carried it as `Net::IMAP::XOauth2Authenticator`. The patch calls the mechanism by name — `imap.authenticate('XOAUTH2', username, token)` — rather than the constant, so it does not depend on which of the two names a given net-imap exposes. |
| "An access token per run is wasteful." | One form POST next to an IMAP session that is about to open anyway. In exchange, nothing is written to disk, so there is no token file to create, permission, rotate, corrupt or leak — and roughly half the helper code in the earlier patch existed only to manage that file. If a busy site ever needs caching it can be added behind the same option without changing the interface. |
| "`OAUTHBEARER` is the standard; `XOAUTH2` is obsolete." | True, and Google and Microsoft both document `XOAUTH2` and both still accept it; `OAUTHBEARER` support is uneven. Hardcoding the mechanism keeps the option surface at two rather than three. Making it an option later is a one-line change in the same method. |
| "The client secret sits in a file on disk." | As do the database password and the SMTP password, in `config/database.yml` and `config/configuration.yml`. The alternative was `ENV` options on the rake command line, which would put the secret in `ps` output for every user on the host. |
| "`receive_pop3` gets nothing." | Deliberate — INV-1, and POP3 over OAuth is a much rarer ask. `Redmine::Oauth2Client` is not IMAP-specific, so wiring it into `Redmine::POP3` later is a few lines. |
| "This should be a setting so it can be configured in the interface." | The IMAP host, port, folder and password are not settings either; a mailbox is per-invocation, and a site fetching two mailboxes needs two cron lines. Making these settings would allow exactly one mailbox. |

---

## Submission

- **Issue:** [#43023](https://www.redmine.org/issues/43023) — bestaat al, Jans
  eigen issue, assignee Marius BĂLTEANU, doelversie 7.1.0. **Geen nieuw issue.**
- **Patch attached:** `patches/imap-oauth/2026-09-03-r24882-feature.patch`
  (16 kB, 433 regels patchbestand, 351 regels wijziging). Eén bestand — er zijn
  geen locale-sleutels, dus geen `-locales.patch`.
- **Made against:** `origin/master` r24882 (`2563fa6a5`, 2026-08-03)
- **Status:** klaar om ingediend te worden; Jan hangt hem aan het issue
- **Positioneren als vervanging van `..._version3.patch`,** niet als aanvulling.
  Zie `status.md`, "Wat Jan nog moet doen", voor de vijf punten die in die note
  horen.
- **Feedback en wat ermee gebeurde:** nog niets.

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `f117ea32e` — een `git cherry-pick` van de
  patchcommit, zonder één aanpassing. `lib/redmine/imap.rb`,
  `lib/tasks/email.rake`, `config/application.rb` en
  `config/initializers/zeitwerk.rb` zijn byte-identiek op trunk en op
  `7.0-stable-GEOxyz`, en de branch loopt niet achter op `origin/7.0-stable`.
- **Suites daar groen:** `5827 runs, 31068 assertions, 0 failures, 0 errors,
  39 skips`. De twee nieuwe testbestanden samen in één proces daar:
  `12 runs, 43 assertions, 0 failures, 0 errors`. RuboCop op de gewijzigde
  bestanden: 0.
- **`nl.yml` toegevoegd:** n.v.t. — de patch voegt geen door een gebruiker
  geziene string toe, dus er is geen enkele locale-sleutel. Dat geldt aan beide
  kanten identiek (INV-10).
- **Afwijking GEOxyz ↔ upstream:** geen. Dezelfde commit, dezelfde code.
- **`tools/check-geoxyz-branch.sh`:** PASS — current met `origin/7.0-stable`,
  7 eigen commits, geen AI-sporen, 0 lint-offences op 16 gewijzigde
  Ruby-bestanden, locales binnen de vijf.
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus pas als GEOxyz zelf naar de release
  gaat die hem draagt — 7.1.0 als #43023 zijn huidige doelversie houdt.
