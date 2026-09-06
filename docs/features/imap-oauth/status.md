---
slug: imap-oauth
feature: IMAP inbound mail via OAuth 2.0 (Gmail / O365)
commit_51: bbf5c0eb3
geoxyz: live
geoxyz_commit: 1a6d462a8 + d92dff560 + 5c937ddbd
upstream: patch klaar
patch: patches/imap-oauth/2026-09-03-r24882-feature.patch
issue: 43023
---

# imap-oauth — status

## Waar het staat

Af, en herschreven. De patch die al een jaar aan Jans eigen issue
[#43023](https://www.redmine.org/issues/43023) hangt is 1197 regels met twee
nieuwe gems en vier nieuwe rake-taken; deze is 351 regels, nul nieuwe gems en
nul nieuwe taakfamilies: twee opties op de bestaande `receive_imap`, plus één
taak voor de eenmalige toestemmingsstap. Alles is bewezen: volledige suites aan
beide kanten, RuboCop nul, de patch applyt op een schone trunk r24882, en de
hele keten is end-to-end gedraaid tegen een échte IMAP-server en een échte
HTTPS-tokenendpoint, met de issues die daaruit in Redmine aankwamen als bewijs.
Twee commits staan op `7.0-stable-GEOxyz`.

**Jan vroeg (2026-09-03) om stap 1 zelf ook doenbaar te maken**, en dat heeft
het ontwerp op één punt veranderd. Eerst zat de toestemmingsstap er helemaal
niet in en moest de beheerder het refresh token buiten Redmine regelen. Nu is
er één taak, `redmine:email:oauth2_authorize`, die het doet. Wat er nadrukkelijk
**niet** terug is gekomen: de twee provider-specifieke init-taken uit de oude
code. De nieuwe taak weet niets over Microsoft of Google; de endpoints, de scope
en de provider-eigenaardigheden staan in het credentialsbestand van de
beheerder. De walkthroughs voor beide providers staan kant-en-klaar in
`dossier.md` onder "Setting it up, once, per mailbox", bedoeld voor de
`EmailConfiguration`-wikipagina van Redmine.

Daarmee is ook de blokkade weg die in dit bestand stond — "de
OAuth-autorisatieflow heeft een mens en echte credentials nodig, dus die kan
nooit een test zijn". De enige regel die een mens vraagt is `STDIN.gets`; al het
overige (de URL bouwen, de code uit het geplakte adres halen, hem inwisselen,
alle faalpaden) is gewone geteste code, en de hele keten is met een lokale
nep-provider echt gedraaid.

## Wat het doet

Redmine haalt inkomende mail uit een mailbox die geen wachtwoord meer accepteert
(Microsoft 365, Gmail), door zich met een OAuth 2.0 access token aan te melden.
Twee nieuwe opties op `rake redmine:email:receive_imap`: `oauth2_token=` voor
een token dat elders gemaakt is, en `oauth2_credentials=<bestand>` waarmee
Redmine per run zelf een token opvraagt met een refresh token. En één nieuwe
taak, `rake redmine:email:oauth2_authorize`, die dat refresh token één keer per
mailbox ophaalt: hij print een URL, de mailboxeigenaar geeft in zijn browser
toestemming, plakt het adres terug waar hij op uitkwam, en de taak print de
regel die in het credentialsbestand moet.

## Bewijs

- Volledige suite met patch: 5811 runs, 30751 assertions, 27 failures,
  2 errors, 92 skips
- Schone trunk (eigen database, zelfde revisie): 5790 runs, 30686 assertions,
  27 failures, 2 errors, 92 skips — dezelfde 29 faalnamen, `diff` leeg; alle 29
  zijn repository-/changeset-/`SysController`-tests die `svn`, `hg`, `bzr` of
  `cvs` nodig hebben, en die staan niet in dit image. 5811 - 5790 = 21, precies
  het aantal nieuwe tests
- Volledige suite op `7.0-stable-GEOxyz` met alleen deze feature erop:
  5836 runs, 31100 assertions, 0 failures, 0 errors, 39 skips.
  En nog een keer op de **branchtip zoals hij na de push is**, dus met de twee
  features die parallelle sessies er ondertussen op zetten
  (`revision-branches`, `webhook-tracker-filter`): 5856 runs, 31168 assertions,
  0 failures, 0 errors, 39 skips. Dat tweede aantal is de branch die GEOxyz
  echt draait; het eerste is alleen deze feature
- De twee nieuwe testbestanden samen in één proces: 21 runs, 71 assertions,
  0 failures, 0 errors
- Rood bewezen op de oude code: 20 van de 21 nieuwe tests vallen om in een
  wegwerp-worktree op schone trunk (21 runs, 12 failures, 8 errors). De ene
  groene is de bewaker die aan beide kanten groen moet zijn, en dat is per
  **naam** vastgesteld en niet door te tellen: de lijst testmethodenamen minus
  de namen in de faaluitvoer laat precies `test_check_should_login_with_the_password`
  over. Eerlijk erbij: negentien van die twintig zijn rood door
  `NameError: uninitialized constant Redmine::Oauth2Client`; de enige puur
  gedragsmatige rode is
  `test_check_should_authenticate_with_xoauth2_when_an_access_token_is_given`,
  die op `lib/redmine/imap.rb:44` faalt omdat trunk daar `login` doet
- Eén nieuwe test vond bij zijn eerste run een echte fout in mijn eigen code:
  de vangnet-tak voor een onparseerbaar geplakt adres gaf `{}` terug waar
  `CGI.parse` een hash met default `[]` geeft, dus de regel erna gaf
  `NoMethodError`. Nu `CGI.parse('')`
- RuboCop op de gewijzigde bestanden: 0 (baseline 0). `lib/tasks/email.rake`
  wordt niet gelint (`lib/tasks/**/*` staat in Redmine's eigen `.rubocop.yml`
  onder Exclude), dus daar is menselijke review de enige controle
- `bin/rails zeitwerk:check`: "All is good!" — het nieuwe `lib/redmine`-bestand
  laadt ook onder eager loading, wat productie doet
- `tools/check-patch-clean.sh`: PASS · `tools/check-geoxyz-branch.sh`: PASS
  (current met `origin/7.0-stable`, geen AI-sporen, 0 lint-offences op 29
  gewijzigde Ruby-bestanden, locales binnen de vijf)
- Patch applyt met `git am` op een verse `origin/master`-checkout: ja
- Screenshots: drie (één before), gelezen: ja. Plus
  `shots/terminal-transcript.txt`: de before-run op schone trunk, de vier
  geslaagde runs, de vijf faalpaden van het ophalen en de zes faalpaden van de
  toestemmingsstap
- De hele keten is in volgorde gedraaid, niet de drie stukken los:
  `oauth2_authorize` printte een URL, die URL is gevolgd zoals een browser hem
  volgt, het redirect-adres is teruggeplakt, de taak printte de
  `refresh_token:`-regel, die regel ging in het bestand, en `receive_imap`
  maakte daarmee issue #15 aan. Het log van de tokenendpoint laat beide grants
  in de juiste volgorde langskomen

## Wat Jan nog moet doen

Twee dingen, en het eerste is het echte werk.

**1. Hang `patches/imap-oauth/2026-09-03-r24882-feature.patch` als note aan je
eigen issue [#43023](https://www.redmine.org/issues/43023)** — geen nieuw
issue, dat issue staat op naam van kerncommitter Marius BĂLTEANU met doelversie
7.1.0. Zeg in die note dat dit een **vervanging** is van
`..._version3.patch`, niet een aanvulling, en waarom hij zoveel kleiner is:

- 581 regels in plaats van 1197, en **geen** nieuwe gem. `oauth2` en
  `gmail_xoauth` zijn er beide uit. `gmail_xoauth` was overbodig:
  `Net::IMAP::SASL::XOAuth2Authenticator` zit in de `net-imap ~> 0.6.1` die
  Redmine al pint, en 0.4.x had hem onder de oude naam
  `Net::IMAP::XOauth2Authenticator`. De patch roept de mechanismenaam aan, niet
  de constante, dus hij hangt niet aan die naamswijziging.
- Geen nieuwe taakfamilie. Twee opties op de bestaande `receive_imap` in plaats
  van een tweede `receive_imap_oauth2` die `host`, `port`, `ssl`, `starttls`,
  `folder`, `move_on_success` en `move_on_failure` dupliceert.
- **Eén** taak voor de toestemmingsstap in plaats van twee provider-specifieke,
  en die ene weet niets over Microsoft of Google: de endpoints, de scope en de
  extra queryparameters komen uit het credentialsbestand. Googles
  `access_type=offline` en `prompt=consent` en Microsofts `offline_access` zijn
  dus waarden in dat bestand, geen code in Redmine. De walkthroughs horen op de
  `EmailConfiguration`-wikipagina, waar Redmine dit soort uitleg al zet en waar
  een providerwijziging zonder release gecorrigeerd kan worden.
- Geen tokencache op schijf, en daarmee vervallen `normalize_token_file`,
  `secure_file`, de YAML-symbolenwhitelist, `mask_token` en de
  refresh-en-herschrijf-tak — ruwweg de helft van de hulpcode.
- **Noem dit ook, het is een echt lek:** de patch die er nu hangt print het
  volledige access token bij `imap_debug=1`, via
  `puts "IMAP DEBUG: effective imap_options=#{imap_options.inspect}"`, waarin
  `imap_options[:password]` het token is. Deze patch heeft geen debugoutput, en
  er staat geen credential in welk log, welke foutmelding of welke debugregel
  dan ook. **Zeg het precies zo en niet sterker** — er is één plek waar een
  credential wél geprint wordt, en dat is de laatste regel van
  `oauth2_authorize`, naar de terminal van de beheerder die net zelf toestemming
  gaf, omdat hem die regel geven het hele doel van die taak is. Dat staat er in
  `dossier.md` bij, met het gevolg erbij (scrollback en transcripts wissen).
  De oudere, te sterke formulering ("interpoleert token noch client secret in
  welke string dan ook") is op 2026-09-06 rechtgezet na reviewbevinding F01;
  gebruik die niet meer.
- `Redmine::IMAP` en `Redmine::POP3` hadden **geen enkele test**; deze
  patch levert de eerste (12 tests, 43 assertions).

De Engelse issuetekst staat kant-en-klaar in `dossier.md` vanaf "The problem",
inclusief de tabel met verwachte bezwaren.

**2. Eén keer tegen een echte mailbox bevestigen.** Alles is nagelopen tegen
een lokale IMAP-server en tokenendpoint die het protocol echt spreken, maar
niemand kan namens jou bij een echte Office 365- of Gmail-mailbox. Dat is de
enige stap die jouw handen vraagt, en hij is nu ook de test van de
walkthroughs zelf:

1. registreer de applicatie zoals in `dossier.md` onder "Setting it up, once,
   per mailbox" beschreven staat
2. schrijf het credentialsbestand, alles behalve `refresh_token`
3. `rake redmine:email:oauth2_authorize oauth2_credentials=/etc/redmine/imap_oauth2.yml`
4. zet de regel die hij print in het bestand
5. `rake redmine:email:receive_imap host=outlook.office365.com port=993 ssl=1
   username=... oauth2_credentials=... project=...`

**Let op bij die walkthroughs:** de stappen in de Azure- en Google-consoles zijn
naar beste weten opgeschreven en niet tegen een echt tenant uitgevoerd, want dat
kan hier niet. Als een menu ergens anders staat of een stap ontbreekt, corrigeer
het in `dossier.md` voordat de wikipagina de deur uit gaat. Wat wél getest is,
is alles wat Redmine zelf doet.

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
- **De toestemmingsstap zit er wél in, maar provider-agnostisch.** Dat is een
  bewuste terugdraai van het eerste ontwerp van deze sessie, op Jans vraag
  (2026-09-03) om stap 1 doenbaar te houden. Wat er niet terugkomt: twee
  provider-specifieke init-taken, scope-lijsten of endpoint-paden in Redmine's
  code, en de tokencache. Ga dus niet opnieuw afwegen of de taak weg moet;
  ga wél na of hij nog steeds niets over de providers weet.
- **`authorize_params` bestaat om precies één reden:** Google heeft
  `access_type=offline` plus `prompt=consent` nodig om een refresh token te
  geven, Microsoft doet het met `offline_access` in de scope. Zonder die
  parameters eindigt de taak op "returned no refresh token", en dat is de meest
  voorkomende beginnersfout. Hij staat daarom nadrukkelijk in beide
  walkthroughs.
- **De verificatieharnas staat in
  `docs/features/imap-oauth/verify-harness/`** en is herbruikbaar: een IMAP-
  server die alleen één `AUTHENTICATE XOAUTH2`-credential accepteert en `LOGIN`
  weigert zoals Exchange Online doet, en een TLS-tokenendpoint die ook de
  autorisatie-endpoint en de `authorization_code`-grant nadoet. Twee dingen die
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
