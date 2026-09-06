# imap-oauth — IMAP inbound mail authenticated with OAuth 2.0

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** Redmine kan post ophalen uit een Gmail- of
  Office 365-mailbox zonder wachtwoord, met OAuth 2.0. Microsoft heeft
  wachtwoord-login op IMAP uitgezet, dus zonder dit werkt inkomende mail daar
  helemaal niet meer. De eenmalige toestemmingsstap zit erin als één taak, en
  de walkthroughs voor beide providers staan hieronder onder "Setting it up,
  once, per mailbox" klaar voor de wikipagina.
- **Waar het vandaan komt:** 5.1-commit `bbf5c0eb3`, en de patch die daaruit
  kwam hangt al aan je eigen issue #43023 (versie 3, 49 kB).
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen
- **Kans dat Redmine dit aanneemt:** redelijk — het issue staat op naam van
  kerncommitter Marius BĂLTEANU met doelversie 7.1.0, dus ze *willen* de
  functie; wat er nu hangt is te groot (1197 regels, twee nieuwe gems, vier
  nieuwe rake-taken). Deze herschrijving is ~230 regels productiecode, nul
  nieuwe gems en één nieuwe rake-taak in plaats van vier.
- **Wat jij nog moet doen:** zie `status.md` — één note aan #43023. Er staat
  geen keuze meer open: K-06 (de `client_credentials`-grant) besliste je op
  2026-09-03 met optie A, en F07 uit ronde 3 op 2026-09-06 met optie B.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `2563fa6a5` = r24882 van 2026-08-03 bij het
  schrijven (2026-09-03). Op 2026-09-06 opnieuw tegen `bee32a926` = **r25037**
  gezet, 88 commits verder, en de patch is daarop herzet en opnieuw bewezen —
  zie "Evidence". De conclusie hieronder is op r25037 opnieuw nagegaan en
  ongewijzigd.
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

Two new options on the existing `redmine:email:receive_imap`, and one new task
for the one-off setup step. No parallel task family, and no provider knowledge
anywhere in Redmine.

    oauth2_token=TOKEN        an OAuth 2.0 access token, used instead of
                              password= and authenticated with XOAUTH2
    oauth2_credentials=FILE   a YAML file with the OAuth 2.0 client credentials
                              and refresh token; Redmine requests an access
                              token with them on each run

    rake redmine:email:oauth2_authorize oauth2_credentials=FILE

`oauth2_token=` covers the case where the operator's own tooling already holds a
token (Azure managed identity, the `client_credentials` grant, `oauth2l`, a
secrets manager). `oauth2_credentials=` covers the normal unattended case.

`oauth2_authorize` is the authorization code grant, run once per mailbox. It
prints the URL the mailbox owner opens to consent, reads back the address the
browser was redirected to, and prints the `refresh_token:` line to add to the
same file. It is deliberately provider-agnostic: the endpoints, the scope and
any provider-specific query parameters come out of the administrator's file, so
Redmine carries no knowledge of Microsoft's or Google's OAuth quirks.

The credentials file, complete:

```yaml
authorize_url: https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/authorize
token_url: https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/token
client_id: 00000000-0000-0000-0000-000000000000
client_secret: SECRET
scope: https://outlook.office.com/IMAP.AccessAsUser.All offline_access
redirect_uri: http://localhost
refresh_token: REFRESH_TOKEN
```

`authorize_url`, `redirect_uri` and `authorize_params` are read only by
`oauth2_authorize`; `receive_imap` ignores them. A query string already present
in `authorize_url` is kept and merged, the same way `token_url` keeps its own —
some providers put a parameter in the endpoint itself, an Azure AD B2C policy
(`?p=B2C_1_signin`) being the clearest case. The grant's own parameters still
win, so neither the URL nor `authorize_params` can turn the request into a
different grant. `redirect_uri` defaults to
`http://localhost`, and `authorize_params` is a plain map of extra query
parameters: Google needs `access_type: offline` and `prompt: consent` there,
Microsoft needs `offline_access` in the scope instead. That is the one place
where the providers differ, and it is in the administrator's file rather than
in Redmine.

| File | Change |
|---|---|
| `lib/redmine/imap.rb` | authenticate with `XOAUTH2` when an access token is available, `login` otherwise; resolve the token from the two new options |
| `lib/redmine/oauth2_client.rb` | new, ~140 lines: read the credentials file, build the authorization URL, and POST either the refresh token grant or the authorization code grant |
| `lib/tasks/email.rake` | pass the two options through and document them; add the `oauth2_authorize` task and one worked example |
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

**The shape attached to #43023 today.** Four new rake tasks —
`o365_oauth2_init`, `google_oauth2_init`, `receive_imap_oauth2`,
`oauth2_status` — plus a `help` task, two provider documents, two gems, and a
token cache written to `config/` with `chmod 0600`. 1197 lines. It has been on
the issue for over a year and has slipped two target versions. The one-off
authorization step it provides is kept here, in one task; the rest is rejected
for three reasons, in order of weight:

1. *Two provider-specific init tasks means Redmine tracks two providers' OAuth
   quirks.* They hardcode each provider's endpoint paths, scope list and
   consent parameters, in Redmine's code. `oauth2_authorize` does the same job
   as one task, with every provider-specific value in the administrator's
   credentials file — which is where the client id and secret already have to
   live. Redmine ends up knowing nothing about Microsoft or Google, and the two
   walk-throughs go on the `EmailConfiguration` wiki page, where Redmine
   already keeps this kind of guidance and where they can be corrected without
   a release.
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
one third of the design rather than as the whole of it.

**Leave the one-off authorization to external tools and document that.**
Considered and rejected. It is doable — two `curl` commands, or Google's OAuth
playground — but the first of those two commands means hand-encoding a scope
into a query string, and the authorization code it produces is single use and
expires in minutes, so one typo means starting over. A step that an
administrator has to get right in one attempt with no feedback is the wrong
place to save fifty lines. `oauth2_authorize` builds the URL, and its error
messages name the actual mistake: the authorization was refused, the code has
already been used, only the code was pasted instead of the whole address.

**Support the `client_credentials` grant as well as `refresh_token`.** About six
more lines, and it is what Microsoft recommends for a service mailbox
(app-only access, no user consent). Deliberately left out of the first patch to
keep one grant type under review; `oauth2_token=` already covers it for anyone
who mints the token themselves, which is how an Azure managed identity or a
secrets manager would feed this today.

**Read the credentials from `configuration.yml`.** Rejected: `configuration.yml`
is per-environment, not per-mailbox, and an installation fetching two mailboxes
would have nowhere to put the second set. The IMAP options are already
per-invocation for exactly this reason.

**Pass the client secret and refresh token as `ENV` options.** Rejected: they
would be visible in `ps` output for the whole run, to every user on the host. A
file the administrator can `chmod 600` is the reason there is a file at all.
`oauth2_token=` is an `ENV` option and does carry a credential, deliberately:
an access token expires within the hour, it is the one value an operator's own
tooling already holds, and it sits exactly where `password=` has sat since
Redmine grew IMAP support. A refresh token and a client secret are neither
short-lived nor already on that command line, so they stay in the file.

# Tests

Neither `Redmine::IMAP` nor `Redmine::POP3` had a single test before this patch;
`test/unit/lib/redmine/imap_test.rb` is the first.

| Test | What it proves |
|---|---|
| `ImapTest#test_check_should_login_with_the_password` | the unchanged path: with no OAuth option, `check` calls `imap.login` and never `imap.authenticate`. Green on trunk as well — this is the guard that the patch changes nothing for existing installations |
| `ImapTest#test_check_should_authenticate_with_xoauth2_when_an_access_token_is_given` | `oauth2_token=` authenticates with `XOAUTH2` and the token, and `login` is not called even though a password is also present |
| `ImapTest#test_check_should_authenticate_with_the_token_requested_from_the_credentials_file` | `oauth2_credentials=` asks `Redmine::Oauth2Client` for a token with that path, and authenticates with what it returns |
| `ImapTest#test_check_should_not_open_a_connection_when_the_token_cannot_be_obtained` | the token is obtained **before** the IMAP connection is opened: when the token request raises, `Net::IMAP.new` is never called. Without that ordering the mail server holds an idle, unauthenticated connection for the whole of an outbound HTTPS round trip, and drops it on its own autologout timer, so a token-endpoint fault surfaces as an `EOFError` naming the *mail server* |
| `ImapTest#test_check_should_login_with_the_password_when_the_oauth2_options_are_blank` | an empty `oauth2_token=` or `oauth2_credentials=` on the command line falls back to the password rather than authenticating with an empty token |
| `Oauth2ClientTest#test_access_token_should_return_the_token_of_a_refresh_token_grant` | the request is a `refresh_token` grant carrying exactly `grant_type`, `client_id`, `client_secret` and `refresh_token`, POSTed to the path in `token_url`, and the `access_token` of the response is returned. Also that all three timeouts really reach `Net::HTTP.start`: the stubbed connection is moved off the default first, because `Net::HTTP` defaults all three to 60 and asserting 60 on a fresh connection asserts nothing |
| `Oauth2ClientTest#test_access_token_should_send_the_scope_when_given` | `scope` is sent when the file has one (Microsoft requires it; Google does not) |
| `Oauth2ClientTest#test_access_token_should_raise_when_a_credential_is_missing` | a file missing `client_secret` and `refresh_token` names both, and no HTTP request is made |
| `Oauth2ClientTest#test_access_token_should_raise_when_the_file_does_not_contain_a_hash` | a file that is not a YAML mapping is rejected instead of raising `NoMethodError` deeper down |
| `Oauth2ClientTest#test_access_token_should_raise_when_the_token_url_is_not_https` | an `http://` token endpoint is refused before the request, so a client secret is never sent in clear |
| `Oauth2ClientTest#test_access_token_should_raise_with_the_error_code_of_a_failed_request` | a 400 response yields `OAuth 2.0 token request failed with 400 Bad Request (invalid_grant)` — the provider's error code, which is the whole diagnosis, and nothing else from the body |
| `Oauth2ClientTest#test_access_token_should_raise_when_a_failed_request_has_no_json_body` | a 502 with an HTML body still gives a clean message rather than a `JSON::ParserError` masking the real failure |
| `Oauth2ClientTest#test_access_token_should_raise_when_a_successful_response_has_no_json_body` | a **200** carrying an HTML page — what an intercepting proxy or a captive portal answers — reads as a token request that returned no token, not as a `JSON::ParserError` about Redmine's JSON handling |
| `Oauth2ClientTest#test_access_token_should_raise_when_the_response_holds_no_token` | a 200 without an `access_token` is an error, not a `nil` token handed to the IMAP server |
| `Oauth2ClientTest#test_authorize_url_should_carry_the_authorization_code_grant_parameters` | the consent URL is the `authorize_url` from the file, with exactly `response_type=code`, the client id and the redirect URI |
| `Oauth2ClientTest#test_authorize_url_should_use_the_configured_redirect_uri_and_extra_parameters` | a non-default `redirect_uri`, the scope, and `authorize_params` (Google's `access_type` and `prompt`) all reach the URL |
| `Oauth2ClientTest#test_authorize_url_should_not_let_the_extra_parameters_override_the_grant` | `authorize_params` cannot replace `response_type` or `client_id`, so a mistake in the file cannot silently turn the request into a different grant |
| `Oauth2ClientTest#test_authorize_url_should_keep_the_parameters_already_in_the_authorize_url` | a query string the administrator left in `authorize_url` survives into the consent URL instead of being silently dropped — an Azure AD B2C policy parameter is the case that made this matter |
| `Oauth2ClientTest#test_authorize_url_should_not_let_the_parameters_in_the_url_override_the_grant` | and it still cannot take over the grant: `response_type=token&client_id=someone-else` in the endpoint URL loses to the patch's own values. Green before the fix too, because before it there was nothing to override — it guards the new behaviour rather than proving it |
| `Oauth2ClientTest#test_access_token_should_raise_when_the_response_body_is_json_but_not_an_object` | a `200` whose body is `[]` reads as "returned no access token" instead of raising `TypeError` out of a hash lookup |
| `Oauth2ClientTest#test_access_token_should_raise_when_a_failed_response_body_is_json_but_not_an_object` | the same on the failure side: a `400` body of `null` gives the plain message rather than `NoMethodError` |
| `Oauth2ClientTest#test_authorize_url_should_raise_when_the_authorize_url_is_not_https` | the same https guard as the token endpoint |
| `Oauth2ClientTest#test_refresh_token_should_exchange_the_code_from_the_redirect_address` | the code is pulled out of a pasted address that also carries `session_state` and a trailing newline, and exchanged with `grant_type=authorization_code` and the same `redirect_uri` |
| `Oauth2ClientTest#test_refresh_token_should_raise_when_the_provider_refused_the_authorization` | `?error=access_denied` is reported as a refusal, and no request is made |
| `Oauth2ClientTest#test_refresh_token_should_raise_when_the_address_carries_no_code` | pasting only the code instead of the whole address says so |
| `Oauth2ClientTest#test_refresh_token_should_raise_when_the_address_cannot_be_parsed` | pasting something that is not an address at all gives the same advice rather than a `URI::InvalidURIError`. This test found a real bug on its first run: the guard returned a plain `{}` where `CGI.parse` returns a hash defaulting to `[]`, so the next line raised `NoMethodError` |
| `Oauth2ClientTest#test_refresh_token_should_raise_when_the_response_holds_no_refresh_token` | a provider that returns only an access token, which is what happens when `offline_access` or `access_type: offline` is missing, is reported as such |

**Evidence (INV-8 — figures, not claims).** All figures below are from
2026-09-06, on trunk **r25037** (`bee32a926`), after the patch was refreshed
against current trunk and the four round-1 review findings were fixed. The
r24882 figures they replace are in the branch history.

- **full** suite (`test:all`, so including the system tests) with the patch
  → `5904 runs, 30984 assertions, 27 failures, 2 errors, 92 skips`
- **full** suite on a pristine `origin/master` r25037 worktree, own database
  → `5877 runs, 30889 assertions, 27 failures, 2 errors, 92 skips`
- 5904 - 5877 = **27**, exactly the number of tests in the two new files.
- the failing test **names** are **identical** on the two sides: 29 each,
  `diff` empty. All 29 are repository, changeset and `SysController` tests that
  need `svn`, `hg`, `bzr` or `cvs`, none of which exist in this image: 14
  `RepositoriesControllerTest`, 8 `Redmine::ApiTest::RepositoriesTest`, 5
  `SysControllerTest`, 1 `Redmine::ApiTest::IssuesTest`, 1 `UserTest`.
- **Worth saying, because it nearly went in as a finding.** An earlier pass ran
  all three suites at once on a four-core machine and each side picked up one
  extra failure — `OauthProviderSystemTest#test_application_creation_and_authorization`
  on the patched side, `IssuesSystemTest#test_update_issue_status` on the
  pristine-trunk side. Both are Selenium system tests, both are green in
  isolation (`OauthProviderSystemTest` alone: `1 runs, 16 assertions,
  0 failures`), and both disappear when the suites are run one at a time, which
  is where the figures above come from. Neither test touches IMAP or OAuth
  client code; `OauthProviderSystemTest` is the Doorkeeper **provider** side,
  which this patch does not go near. Nothing was skipped or disabled to get
  here — the suites were simply not made to fight each other for cores.
- the two new files run together in one process: `27 runs, 96 assertions,
  0 failures, 0 errors, 0 skips`
- **The absolute totals moved between review rounds and the difference is not
  this patch.** Round 2 measured `6000` and `5977` for the same two sides; round
  3 measures `5904` and `5877`, in a fresh container on the same trunk revision.
  Both sides dropped by roughly the same hundred runs, both keep the identical
  27 failures / 2 errors / 92 skips and the same 29 failing names, and the
  patch-minus-trunk delta is exactly the number of new tests in each round (23
  then, 27 now). What varies is how many system tests the image runs, not what
  the patch does. The delta and the name diff are the figures to read; the
  absolute totals are only comparable within one run pair.
- RuboCop on the four changed files: `0` offences (baseline on the same files at
  the merge base: `0`). `lib/tasks/email.rake` is not linted — `lib/tasks/**/*`
  is excluded in Redmine's own `.rubocop.yml`, so that file had human review
  only.
- each new test verified red on the old code, by mutation rather than by
  assertion, one hunk at a time:
  - reverting the token fetch back below `Net::IMAP.new` →
    `test_check_should_not_open_a_connection_when_the_token_cannot_be_obtained`
    gives `1 runs, 1 assertions, 1 failures`
  - reverting `json_body` back to `JSON.parse(response.body)[name]` →
    `test_access_token_should_raise_when_a_successful_response_has_no_json_body`
    gives `1 failures`
  - making `post_to_token_endpoint` call `http.request` and then evaluate to
    `nil`, which is the mutation round-1 finding F04 used, turns
    `oauth2_client_test.rb` from `18 runs, 0 failures` into
    `18 runs, 5 failures, 3 errors`. Under the old stub the same mutation left
    all seventeen tests green — that was the finding.
  - and, from the original round: the 21 tests of the first version were
    verified red on pristine trunk as `21 runs, 15 assertions, 12 failures,
    8 errors`, with the single green one, `test_check_should_login_with_the_password`,
    identified by **name** rather than by counting — it is the guard that must
    be green on both sides.
- `bin/rails zeitwerk:check`: `All is good!` — the new `lib/redmine` file also
  loads under eager loading, which is what production does.
- patch applies to pristine `origin/master` r25037: yes —
  `tools/check-patch-clean.sh imap-oauth --submit` PASS, which checks the
  **patch file** against a fresh trunk checkout, that it touches only Redmine
  paths (5 files), that there is no AI trace in header or message, and that the
  file and the `patch/imap-oauth` branch are the same change.

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
  shows what happens when it does not). It also serves the authorization
  endpoint and redirects like a provider's consent screen, so the one-off
  `oauth2_authorize` step could be driven for real too.

**The whole chain was run in order, not the three legs separately.**
`oauth2_authorize` printed a consent URL; that URL was followed the way a
browser follows it, which produced a redirect to
`http://localhost?code=the-consent-code&session_state=fake`; that address was
pasted back, and the task printed `refresh_token: a-refresh-token-from-consent`.
That line was appended to the credentials file, and `receive_imap` with nothing
but `oauth2_credentials=` pointing at that file fetched a message and created
issue #15. The token endpoint's own log shows both grants arriving in order,
first `authorization_code`, then `refresh_token`, with the scope intact:

    authorize endpoint: client_id=a-client-id scope=https://outlook.office.com/IMAP.AccessAsUser.All offline_access redirect_uri=http://localhost
    token endpoint: {"grant_type"=>"authorization_code", "code"=>"the-consent-code", ...}
    token endpoint: {"grant_type"=>"refresh_token", ...}

Nothing left the machine and no real credentials were used. Screenshots in
`docs/features/imap-oauth/shots/`, terminal transcripts in
`shots/terminal-transcript.txt`.

| Function | Screenshot | What it shows |
|---|---|---|
| The mailbox before any mail is fetched | `before-issues-list.png` | nine issues in the verification project, none from mail. Taken against the **pristine trunk** worktree |
| Mail fetched with a token minted by Redmine, and with a token supplied on the command line | `issues-list.png` | issues #12 (`oauth2_credentials=`), #13 (`oauth2_token=`) and #14 (the unchanged `password=` path) |
| The issue built from the fetched mail | `issue-from-xoauth2-mail.png` | Bug #12, author Dev Verify0 resolved from the `From:` header, description as sent |
| Mail fetched with a refresh token that `oauth2_authorize` itself produced | `issues-list.png` | issue #15, the end of the three-step chain above |
| The two behaviour changes of review round 2, before and after | `round2-issues-list.png` | issues #11 (fixed code) and #12 (the code as round 1 reviewed it) side by side: the happy path is byte-for-byte unaffected by the fixes |
| The issue the fixed code built from the fetched mail | `round2-issue-from-xoauth2-mail.png` | Bug #11, author Dev Verify0 resolved from the `From:` header, so `MailHandler` really ran rather than IMAP merely connecting |

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

**Round 2 added two more, and they are before/after pairs rather than single
observations, because both are about what the code does *differently* now.**
Same harness, same driver, same credentials file; only the code differs. The
IMAP server's own log is the witness for the second one — it says whether a
socket was opened at all. Full transcript in `shots/round2-terminal-transcript.txt`.

| Case | Before (`d63cb35a5`) | After |
|---|---|---|
| token endpoint answers 200 with an HTML page (an intercepting proxy) | `JSON::ParserError: unexpected character: '<html>proxy' at line 1 column 1`, and **1 IMAP connection** opened and then abandoned | `OAuth 2.0 token request returned no access token`, and **0 IMAP connections** |
| refresh token revoked, endpoint answers 400 `invalid_grant` | correct message, but **1 IMAP connection** opened before the token was ever asked for, and never logged out — `check` has no `ensure` | same message, **0 IMAP connections** |
| the happy path, for control | 1 connection, `authenticated=true`, issue #12 created | 1 connection, `authenticated=true`, issue #11 created |

And the six failure paths of the one-off `oauth2_authorize` step, which is
where an administrator setting this up for the first time will actually make
mistakes:

| Case | Observed |
|---|---|
| `oauth2_credentials=` not given | `Missing oauth2_credentials=FILE` |
| `authorize_url` missing from the file | `<file> is missing authorize_url` |
| `authorize_url` is `http://` | `authorize_url must be an https URL` |
| the mailbox owner clicked deny | `The authorization was refused (access_denied)` |
| only the code pasted, not the whole address | `No code parameter in the address, paste the whole address the browser was redirected to` |
| something pasted that is not an address at all | the same message, rather than `URI::InvalidURIError` |
| the code already used or expired | `OAuth 2.0 token request failed with 400 Bad Request (invalid_grant)` |

**No credential appears in any log, any error message or any debug output.**
That was checked deliberately, because the patch on #43023 prints the full
access token when `imap_debug=1` is set: it does `puts imap_options.inspect`,
and `imap_options[:password]` is the token. This patch has no debug output at
all, and no credential is interpolated into any message it raises: the failure
messages above name the file, the key or the provider's `error` code, never a
value.

There is exactly one place where a credential is printed, and it is the one
place it has to be: the last line of `oauth2_authorize` prints
`refresh_token: <token>` to the terminal of the operator who has just consented
in their own browser, because handing them that line to paste is the whole
purpose of the task. Two things follow, and the "Afterwards" section says both:
that line lands in shell scrollback and in any `script`/CI transcript of the
session, so clear it; and the credentials file it goes into is `chmod 600`.

Screenshots read, not just generated: yes — `before-issues-list.png` was
checked for the *absence* of the three mail subjects, `issues-list.png` for all
three present with the right trackers, and `issue-from-xoauth2-mail.png` for the
author having been resolved to the Redmine user behind the `From:` address
(which proves `MailHandler` ran, not just that IMAP connected).

# Setting it up, once, per mailbox

This is the text for the `EmailConfiguration` wiki page. Redmine keeps provider
walk-throughs on the wiki rather than in `doc/`, which holds only `INSTALL`,
`UPGRADING`, `CHANGELOG`, `COPYING`, `README_FOR_APP`, `RUNNING_TESTS` and
`licenses`; `config/configuration.yml.example` already points at that wiki page
for mail, and the two task descriptions now point at it as well.

Both providers follow the same three steps: register an application, write a
credentials file, run `redmine:email:oauth2_authorize` once.

**The browser part is not a stunt, and it works on a server with no browser.**
The task prints a URL. Open it on your own laptop, sign in as the mailbox
owner, approve. The provider then redirects your browser to
`http://localhost`, which shows "This site can't be reached" - that is
expected and it is the whole point: the address bar now holds
`http://localhost/?code=0.AXoA...`. Copy that entire address and paste it back
into the terminal. Nothing has to be reachable, nothing listens on that port,
and the redirect happens in your browser and not on the server.

## Microsoft 365 / Exchange Online

1. Microsoft Entra admin center, **App registrations**, **New registration**.
   Name it something recognisable, keep "Accounts in this organizational
   directory only", and add a redirect URI of platform **Web** with the value
   `http://localhost`. Under the Web platform, `http://localhost` is the one
   address allowed without https.
2. Note the **Application (client) ID** and the **Directory (tenant) ID** from
   the overview page.
3. **Certificates & secrets**, **New client secret**. Copy the value now; it is
   shown once.
4. **API permissions**, **Add a permission**, **APIs my organization uses**,
   search for *Office 365 Exchange Online*, **Delegated permissions**, tick
   `IMAP.AccessAsUser.All`. Add it, and grant admin consent if your tenant
   requires it.
5. Make sure IMAP is on for the mailbox. In Exchange Online PowerShell:
   `Set-CASMailbox -Identity mailbox@example.com -ImapEnabled $true`

Credentials file, `/etc/redmine/imap_oauth2.yml`:

```yaml
authorize_url: https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/authorize
token_url: https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/token
client_id: APPLICATION_CLIENT_ID
client_secret: CLIENT_SECRET_VALUE
scope: https://outlook.office.com/IMAP.AccessAsUser.All offline_access
redirect_uri: http://localhost
```

`offline_access` in the scope is what makes Microsoft hand back a refresh
token. Without it the authorize task ends with "returned no refresh token".

Then:

```
rake redmine:email:oauth2_authorize RAILS_ENV=production \
  oauth2_credentials=/etc/redmine/imap_oauth2.yml
```

Add the `refresh_token:` line it prints to the same file, and fetch mail with:

```
rake redmine:email:receive_imap RAILS_ENV=production \
  host=outlook.office365.com port=993 ssl=1 \
  username=mailbox@example.com \
  oauth2_credentials=/etc/redmine/imap_oauth2.yml \
  project=support
```

## Gmail and Google Workspace

1. Google Cloud console, create or pick a project, and **enable the Gmail API**
   for it.
2. **OAuth consent screen**: choose *Internal* for a Workspace domain. For a
   personal Gmail account only *External* is available, and an External app
   left in *Testing* has its refresh tokens expire after seven days - publish
   the app, or expect to re-authorize weekly.
3. **Credentials**, **Create credentials**, **OAuth client ID**, application
   type **Desktop app**. Note the client ID and client secret. A Desktop app
   client is the one that accepts a `http://localhost` redirect.
4. Enable IMAP in the mailbox itself: Gmail settings, *Forwarding and POP/IMAP*,
   *Enable IMAP*.

Credentials file:

```yaml
authorize_url: https://accounts.google.com/o/oauth2/v2/auth
token_url: https://oauth2.googleapis.com/token
client_id: SOMETHING.apps.googleusercontent.com
client_secret: CLIENT_SECRET
scope: https://mail.google.com/
redirect_uri: http://localhost
authorize_params:
  access_type: offline
  prompt: consent
```

Google's equivalent of `offline_access` is `access_type: offline`, and it only
returns a refresh token on the *first* consent, so `prompt: consent` keeps it
working when you re-authorize. Those two are exactly why `authorize_params`
exists: the provider's quirks live in the administrator's file, not in
Redmine's code.

Then the same two commands, with `host=imap.gmail.com port=993 ssl=1`.

## Afterwards

- The file holds a client secret and a refresh token. Give it to the Redmine
  user only: `chown redmine: /etc/redmine/imap_oauth2.yml && chmod 600` it.
- `oauth2_authorize` printed the refresh token to your terminal. Clear the
  scrollback and the shell history of that session, and delete any transcript
  of it, once the line is in the file.
- A refresh token is long lived but not eternal. It stops working if it is
  revoked, if the account's password policy forces it, or in the Google
  *Testing* case above. Re-run `oauth2_authorize` and replace the line; nothing
  else changes.
- `receive_imap` says which of the two it is:
  `invalid_grant` means the refresh token is no longer accepted, `invalid_client`
  means the client id or secret is wrong.

# Anticipated objections

| Objection | Answer |
|---|---|
| "The one-off authorization needs a browser, and my Redmine server has none." | The redirect happens in *your* browser, not on the server. Run the task over SSH, open the printed URL on your own machine, and paste the address back into the terminal. Nothing has to listen on `localhost` and nothing has to be reachable from the provider. |
| "Why is there an interactive rake task at all? Nothing else in Redmine reads from stdin." | Redmine already does, in the same directory: `redmine:load_default_data` — the task every installation runs — prints `Select language:` and blocks on `STDIN.gets`, and `migrate_from_trac` and `migrate_from_mantis` prompt repeatedly. So the pattern is not new, and this task follows it. On the substance: only the mailbox owner can consent, and there is no non-interactive way to obtain a refresh token for a delegated grant. The alternative is telling administrators to hand-build an authorization URL and `curl` a single-use code within its expiry, which is the kind of instruction that gets one attempt and no feedback. The interactive part is four lines of the task; everything under it is ordinary, tested code. |
| "Then Redmine now carries Microsoft's and Google's OAuth details after all." | It does not. `oauth2_authorize` reads the authorization endpoint, the scope, the redirect URI and any extra query parameters out of the administrator's file. Google's `access_type=offline` and `prompt=consent`, and Microsoft's `offline_access` scope, are values in that file. The two walk-throughs belong on the `EmailConfiguration` wiki page, where a provider changing its console can be corrected without a Redmine release. |
| "Why not use the `oauth2` gem, which is already in the Gemfile?" | It is in the `:test` group, for testing Redmine's own OAuth **provider** (Doorkeeper). Using it here would move a test dependency into production for one form POST. `Net::HTTP` and `JSON` are stdlib, and `app/models/webhook.rb` already establishes how core makes an outbound HTTP request. |
| "Why not `gmail_xoauth`, as the earlier patch does?" | Redundant. `Net::IMAP::SASL::XOAuth2Authenticator` is in the pinned `net-imap ~> 0.6.1`, and 0.4.x already carried it as `Net::IMAP::XOauth2Authenticator`. The patch calls the mechanism by name — `imap.authenticate('XOAUTH2', username, token)` — rather than the constant, so it does not depend on which of the two names a given net-imap exposes. |
| "An access token per run is wasteful." | One form POST next to an IMAP session that is about to open anyway. In exchange, nothing is written to disk, so there is no token file to create, permission, rotate, corrupt or leak — and roughly half the helper code in the earlier patch existed only to manage that file. If a busy site ever needs caching it can be added behind the same option without changing the interface. |
| "`OAUTHBEARER` is the standard; `XOAUTH2` is obsolete." | True, and Google and Microsoft both document `XOAUTH2` and both still accept it; `OAUTHBEARER` support is uneven. Hardcoding the mechanism keeps the option surface at two rather than three. Making it an option later is a one-line change in the same method. |
| "The client secret sits in a file on disk." | As do the database password and the SMTP password, in `config/database.yml` and `config/configuration.yml`. The alternative was `ENV` options on the rake command line, which would put the secret in `ps` output for every user on the host. |
| "`receive_pop3` gets nothing." | Deliberate — INV-1, and POP3 over OAuth is a much rarer ask. `Redmine::Oauth2Client` is not IMAP-specific, so wiring it into `Redmine::POP3` later is a few lines. |
| "This is two changes: authenticating a fetch, and an interactive setup helper. Split it." | It splits cleanly, and if you prefer to take the fetch side first, say so and it will be resubmitted as two: `oauth2_token=`, `oauth2_credentials=` and `Oauth2Client.access_token` on one side, `oauth2_authorize` with `authorize_url` and `refresh_token` on the other. It is submitted as one because the fetch side alone closes nothing for an administrator who has no external tooling to mint a refresh token, which is the situation [#37688](https://www.redmine.org/issues/37688) has been in since 2022. The helper is what turns this from a building block into a feature someone can actually deploy. |
| "This should be a setting so it can be configured in the interface." | The IMAP host, port, folder and password are not settings either; a mailbox is per-invocation, and a site fetching two mailboxes needs two cron lines. Making these settings would allow exactly one mailbox. |

---

## Submission

- **Issue:** [#43023](https://www.redmine.org/issues/43023) — bestaat al, Jans
  eigen issue, assignee Marius BĂLTEANU, doelversie 7.1.0. **Geen nieuw issue.**
- **Patch attached:** `patches/imap-oauth/2026-09-06-r25037-feature.patch`
  (711 regels patchbestand, 618 regels wijziging over 5 bestanden). Eén bestand
  — er zijn geen locale-sleutels, dus geen `-locales.patch`.
- **Made against:** `origin/master` r25037 (`bee32a926`, huidige trunk-tip op
  2026-09-06). De eerdere versie stond op r24882; die is bewaard als
  `archive/patch-imap-oauth-r24882-before-round2` zodat de SHA `d63cb35a5`
  waar reviewronde 1 naar verwijst oplosbaar blijft.
- **Status:** klaar om ingediend te worden; Jan hangt hem aan het issue
- **Positioneren als vervanging van `..._version3.patch`,** niet als aanvulling.
  Zie `status.md`, "Wat Jan nog moet doen", voor de vijf punten die in die note
  horen.
- **Feedback en wat ermee gebeurde:** nog niets.

## GEOxyz

- **Commits op `7.0-stable-GEOxyz`:** `1a6d462a8` (het ophalen), `d92dff560`
  (de toestemmingsstap) en `5c937ddbd` (de twee codefixes uit reviewronde 2),
  samen exact de inhoud van de patchcommit, zonder één aanpassing. Drie commits
  omdat elke vorige al gepusht was toen de volgende erbij kwam; op een
  gepubliceerde branch wordt niet geamendeerd. De eerste twee SHA's zijn die
  van ná de identiteitsherschrijving van 2026-09-06 (K-13); ze heetten daarvóór
  `f117ea32e` en `21c232ce1`. `lib/redmine/imap.rb`,
  `lib/tasks/email.rake`, `config/application.rb` en
  `config/initializers/zeitwerk.rb` zijn byte-identiek op trunk en op
  `7.0-stable-GEOxyz`, en de branch loopt niet achter op `origin/7.0-stable`.
- **Suites daar groen:** de volledige `test:all` op de branchtip van
  2026-09-06, dus inclusief de features die parallelle sessies er ondertussen
  op zetten en inclusief de codefixes van ronde 2:
  `6123 runs, 32351 assertions, 0 failures, 0 errors, 39 skips`. De twee nieuwe
  testbestanden samen in één proces daar: `23 runs, 81 assertions, 0 failures,
  0 errors`. RuboCop op de vier gewijzigde bestanden: 0.
  De eerdere cijfers (`5836` met alleen deze feature, `5856` op de tip van
  2026-09-03) staan in de branchhistorie.
- **`nl.yml` toegevoegd:** n.v.t. — de patch voegt geen door een gebruiker
  geziene string toe, dus er is geen enkele locale-sleutel. Dat geldt aan beide
  kanten identiek (INV-10).
- **Afwijking GEOxyz ↔ upstream:** geen. Dezelfde commit, dezelfde code.
- **`tools/check-geoxyz-branch.sh`:** PASS (2026-09-06) — current met
  `origin/7.0-stable`, geen AI-sporen in de eigen commits, 1 lint-offence op 66
  gewijzigde Ruby-bestanden en die staat al op een eigen regel van
  `origin/7.0-stable` (baseline 1), locales binnen de vijf.
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus pas als GEOxyz zelf naar de release
  gaat die hem draagt — 7.1.0 als #43023 zijn huidige doelversie houdt.
