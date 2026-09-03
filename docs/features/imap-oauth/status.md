---
slug: imap-oauth
feature: IMAP inbound mail via OAuth 2.0 (Gmail / O365)
commit_51: bbf5c0eb3
geoxyz: live
geoxyz_commit: f117ea32e
upstream: patch klaar
patch: patches/imap-oauth/2026-09-03-r24882-feature.patch
issue: 43023
---

# imap-oauth — status

## Waar het staat

Af, en herschreven. De patch die al een jaar aan Jans eigen issue
[#43023](https://www.redmine.org/issues/43023) hangt is 1197 regels met twee
nieuwe gems en vier nieuwe rake-taken; deze is 351 regels, nul nieuwe gems en
nul nieuwe taken — twee opties op de bestaande `receive_imap`. Alles is
bewezen: volledige suites aan beide kanten, RuboCop nul, de patch applyt op een
schone trunk r24882, en de functie is end-to-end nagelopen tegen een échte
IMAP-server en een échte HTTPS-tokenendpoint, met de issues die daaruit in
Redmine aankwamen als bewijs. De commit staat ook op `7.0-stable-GEOxyz`, dus
GEOxyz kan dit draaien.

De blokkade die in dit statusbestand stond — "de OAuth-autorisatieflow heeft
een mens en echte credentials nodig, dus die kan nooit een test zijn" — is weg,
en niet door hem te omzeilen: die flow zit **niet meer in de patch**. De
beheerder autoriseert één keer buiten Redmine en geeft Redmine het refresh
token. Daarmee is alles wat we leveren testbaar.

## Wat het doet

Redmine haalt inkomende mail uit een mailbox die geen wachtwoord meer accepteert
(Microsoft 365, Gmail), door zich met een OAuth 2.0 access token aan te melden.
Twee nieuwe opties op `rake redmine:email:receive_imap`: `oauth2_token=` voor
een token dat elders gemaakt is, en `oauth2_credentials=<bestand>` waarmee
Redmine per run zelf een token opvraagt met een refresh token.

## Bewijs

- Volledige suite met patch: 5802 runs, 30727 assertions, 27 failures,
  2 errors, 92 skips
- Schone trunk (eigen database, zelfde revisie): 5790 runs, 30686 assertions,
  27 failures, 2 errors, 92 skips — dezelfde 29 faalnamen, `diff` leeg; alle 29
  zijn repository-/changeset-/`SysController`-tests die `svn`, `hg`, `bzr` of
  `cvs` nodig hebben, en die staan niet in dit image
- Volledige suite op `7.0-stable-GEOxyz`: 5827 runs, 31068 assertions,
  0 failures, 0 errors, 39 skips
- De twee nieuwe testbestanden samen in één proces: 12 runs, 43 assertions,
  0 failures, 0 errors
- Rood bewezen op de oude code: 11 van de 12 nieuwe tests vallen om in een
  wegwerp-worktree op schone trunk (12 runs, 7 failures, 4 errors). De ene
  groene is de bewaker die aan beide kanten groen moet zijn. Eerlijk erbij: tien
  van die elf zijn rood door `NameError: uninitialized constant
  Redmine::Oauth2Client`; de enige puur gedragsmatige rode is
  `test_check_should_authenticate_with_xoauth2_when_an_access_token_is_given`,
  die op `lib/redmine/imap.rb:44` faalt omdat trunk daar `login` doet
- RuboCop op de gewijzigde bestanden: 0 (baseline 0). `lib/tasks/email.rake`
  wordt niet gelint (`lib/tasks/**/*` staat in Redmine's eigen `.rubocop.yml`
  onder Exclude), dus daar is menselijke review de enige controle
- `bin/rails zeitwerk:check`: "All is good!" — het nieuwe `lib/redmine`-bestand
  laadt ook onder eager loading, wat productie doet
- `tools/check-patch-clean.sh`: PASS · `tools/check-geoxyz-branch.sh`: PASS
- Patch applyt met `git am` op een verse `origin/master`-checkout: ja
- Screenshots: drie (één before), gelezen: ja. Plus
  `shots/terminal-transcript.txt` met de before-run, de drie geslaagde runs en
  de vijf faalpaden

## Wat Jan nog moet doen

Twee dingen, en het eerste is het echte werk.

**1. Hang `patches/imap-oauth/2026-09-03-r24882-feature.patch` als note aan je
eigen issue [#43023](https://www.redmine.org/issues/43023)** — geen nieuw
issue, dat issue staat op naam van kerncommitter Marius BĂLTEANU met doelversie
7.1.0. Zeg in die note dat dit een **vervanging** is van
`..._version3.patch`, niet een aanvulling, en waarom hij zoveel kleiner is:

- 351 regels in plaats van 1197, en **geen** nieuwe gem. `oauth2` en
  `gmail_xoauth` zijn er beide uit. `gmail_xoauth` was overbodig:
  `Net::IMAP::SASL::XOAuth2Authenticator` zit in de `net-imap ~> 0.6.1` die
  Redmine al pint, en 0.4.x had hem onder de oude naam
  `Net::IMAP::XOauth2Authenticator`. De patch roept de mechanismenaam aan, niet
  de constante, dus hij hangt niet aan die naamswijziging.
- Geen nieuwe taakfamilie. Twee opties op de bestaande `receive_imap` in plaats
  van een tweede `receive_imap_oauth2` die `host`, `port`, `ssl`, `starttls`,
  `folder`, `move_on_success` en `move_on_failure` dupliceert.
- De interactieve autorisatieflow zit er niet in. Die kan per definitie geen
  test hebben en zet Microsofts en Googles endpoints, scopes en
  consent-eigenaardigheden in Redmine's onderhoud. Eenmalig buiten Redmine
  autoriseren kost de beheerder één keer een middag.
- Geen tokencache op schijf, en daarmee vervallen `normalize_token_file`,
  `secure_file`, de YAML-symbolenwhitelist, `mask_token` en de
  refresh-en-herschrijf-tak — ruwweg de helft van de hulpcode.
- **Noem dit ook, het is een echt lek:** de patch die er nu hangt print het
  volledige access token bij `imap_debug=1`, via
  `puts "IMAP DEBUG: effective imap_options=#{imap_options.inspect}"`, waarin
  `imap_options[:password]` het token is. Deze patch heeft geen debugoutput en
  interpoleert token noch client secret in welke string dan ook.
- `Redmine::IMAP` en `Redmine::POP3` hadden **geen enkele test**; deze
  patch levert de eerste (12 tests, 43 assertions).

De Engelse issuetekst staat kant-en-klaar in `dossier.md` vanaf "The problem",
inclusief de tabel met verwachte bezwaren.

**2. Eén keer tegen een echte mailbox bevestigen.** Alles is nagelopen tegen
een lokale IMAP-server en tokenendpoint die het protocol echt spreken, maar
niemand kan namens jou bij een echte Office 365- of Gmail-mailbox. Dat is de
enige stap die jouw handen vraagt: één keer autoriseren, het
credentialsbestand vullen en `rake redmine:email:receive_imap
oauth2_credentials=...` draaien. Het bestand ziet zo uit:

```yaml
token_url: https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/token
client_id: ...
client_secret: ...
refresh_token: ...
scope: https://outlook.office.com/IMAP.AccessAsUser.All offline_access
```

En er staat één keuze voor je open: **K-06** in `docs/DECISIONS.md`, over de
`client_credentials`-grant (app-only, Microsofts aanbeveling voor een
servicemailbox). Er is geen haast: we bouwden verder zonder.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Er is al een issue, en het is Jans eigen: #43023.** Assignee Marius
  BĂLTEANU, doelversie 7.1.0 (was 7.0.0, verschoven 2026-06-29; daarvóór
  "Candidate for next major release"). Drie patches hangen eraan; versie 3
  (`/attachments/download/34823`) is exact de 5.1-commit `bbf5c0eb3`. Maak
  **geen** nieuw issue.
- **De behoefte is aantoonbaar:** [#37688](https://www.redmine.org/issues/37688)
  loopt sinds 2022, status New, geen doelversie, 77 notes vol omwegen (laatste
  2024-03-01): getmail6, een IMAP-proxy, PowerShell op Microsoft Graph, een
  betaalde plugin.
  [#37705](https://www.redmine.org/issues/37705) is het gesloten duplicaat.
- **`gmail_xoauth` is niet nodig** en was dat nooit. Niet opnieuw toevoegen.
- **De `oauth2` gem in de `Gemfile` staat in de `:test`-groep**, met het
  commentaar "for testing oauth provider capabilities" — dat is Doorkeeper, de
  provider-kant. Niet verwarren met client-side OAuth, en niet naar productie
  halen.
- **`app/models/webhook.rb` is het precedent** voor een uitgaand HTTP-verzoek in
  de kern (`Net::HTTP.start` met timeouts). Volg die stijl; er is geen gem voor
  nodig.
- **`MailHandler.extract_options_from_env` gebruikt een allowlist**
  (`app/models/mail_handler.rb:67`). De bestaande patch schoonde `ENV` op vóór
  hij die methode aanriep; dat was niet nodig — nieuwe optienamen kunnen niet
  als issue-attribuut worden gelezen.
- **`lib/redmine/imap.rb` en `lib/tasks/email.rake` zijn identiek op trunk en
  `7.0-stable-GEOxyz`**, en de GEOxyz-branch loopt niet achter op
  `origin/7.0-stable`. De patch is er dus met een gewone cherry-pick op gezet,
  zonder aanpassing. Zelfde geldt voor `config/application.rb` en
  `config/initializers/zeitwerk.rb`, waar het nieuwe bestand van afhangt.
- **Zeitwerk camelizeert `oauth2_client.rb` standaard naar `Oauth2Client`**, dus
  `config/initializers/zeitwerk.rb` hoeft geen regel (`imap` → `IMAP` heeft er
  wél een). Niet toevoegen.
- **Er zijn geen locale-sleutels**, en dat is geen omissie: de patch voegt geen
  door een gebruiker geziene string toe. Geen `-locales.patch`.
- **De verificatieharnas staat in
  `docs/features/imap-oauth/verify-harness/`** en is herbruikbaar: een IMAP-
  server die alleen één `AUTHENTICATE XOAUTH2`-credential accepteert en `LOGIN`
  weigert zoals Exchange Online doet, en een TLS-tokenendpoint. Twee dingen die
  tijd kostten: `net-imap` stuurt **geen** initial response als de greeting geen
  `SASL-IR` adverteert, dus de server moet de `+ `-continuation kunnen; en een
  IMAP-server die `LOGIN` klakkeloos accepteert maakt de before-run **ten
  onrechte groen** (dat gebeurde hier, en er is één issue voor weggegooid).
- **Pak de git-fixtures ook uit in de GEOxyz-worktree**, niet alleen in de
  patch- en de trunk-worktree. Zonder `tmp/test/git_repository` slaan de
  repository-tests stil over: de suite daar gaf eerst `5727 runs` en na het
  uitpakken `5827 runs` — honderd tests die "groen" leken en simpelweg niet
  liepen. De runbook waarschuwt hiervoor; het gebeurde hier alsnog.
- **Een geaccepteerde trunk-patch komt niet in 7.0-stable.** Trunk staat op
  `7.0.0 devel`, dus dit landt in 7.1 of later. De GEOxyz-commit blijft nodig
  tot GEOxyz zelf naar die release gaat.

## Volgende stap voor een sessie

Af — niets te doen, behalve de patch bijwerken als er feedback op #43023 komt.
