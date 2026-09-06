---
slug: imap-oauth
feature: IMAP inbound mail via OAuth 2.0 (Gmail / O365)
commit_51: bbf5c0eb3
geoxyz: live
geoxyz_commit: 1a6d462a8 + d92dff560 + 5c937ddbd + 75f355fa8
upstream: patch klaar
patch: patches/imap-oauth/2026-09-06-r25037-feature.patch
issue: 43023
---

# imap-oauth — status

## Waar het staat

Af, herschreven, en op 2026-09-06 door reviewronde 2 heen. De patch die al een
jaar aan Jans eigen issue [#43023](https://www.redmine.org/issues/43023) hangt
is 1197 regels met twee nieuwe gems en vier nieuwe rake-taken; deze is 618
regels wijziging, nul nieuwe gems en nul nieuwe taakfamilies: twee opties op de
bestaande `receive_imap`, plus één taak voor de eenmalige toestemmingsstap.
Alles is bewezen: volledige suites aan beide kanten, RuboCop nul, de patch
applyt op een schone trunk **r25037**, en de hele keten is end-to-end gedraaid
tegen een échte IMAP-server en een échte HTTPS-tokenendpoint, met de issues die
daaruit in Redmine aankwamen als bewijs. Drie commits staan op
`7.0-stable-GEOxyz`.

**Reviewronde 2 (2026-09-06).** De vier bevindingen van ronde 1 staan alle vier
dicht, met een `Resolution:`-regel in
`docs/review/findings/2026-09-03-imap-oauth-claude-opus5.md`:

- **F01 (major, dossier)** — de claim "interpoleert token noch client secret in
  welke string dan ook" was te sterk: `oauth2_authorize` print het refresh token
  wel degelijk. De claim is bijgesteld en de uitzondering staat er nu bij, met
  het gevolg (scrollback wissen).
- **F02 (minor, code)** — het token wordt nu opgehaald **vóór** de
  IMAP-verbinding opengaat. Anders bleef een onge-authenticeerde verbinding tot
  twee minuten open te wachten op een traag tokenendpoint.
- **F03 (minor, code)** — een 200 met een niet-JSON body (een onderscheppende
  proxy) geeft nu dezelfde nette melding als elk ander faalpad in plaats van een
  kale `JSON::ParserError`.
- **F04 (minor, test)** — de stub in de happy-path-test gaf de blokwaarde van
  `Net::HTTP.start` niet terug, waardoor de test groen bleef op code die het
  HTTP-antwoord weggooide. Nu draait de echte `Net::HTTP.start`.

De patch is in dezelfde beweging op **huidige trunk r25037** herzet (g05), en
alle cijfers zijn daar opnieuw gemeten. De oude tip staat bewaard als
`archive/patch-imap-oauth-r24882-before-round2`, zodat `d63cb35a5` uit de
review oplosbaar blijft.

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

Alle cijfers hieronder zijn van **2026-09-06**, op trunk **r25037**
(`bee32a926`), na de vier reviewfixes. Elke volledige suite is **alleen**
gedraaid; drie tegelijk op vier cores laat Selenium-systeemtests willekeurig
omvallen (zie `docs/traps.md`).

- Volledige suite (`test:all`) met patch: 5904 runs, 30984 assertions,
  27 failures, 2 errors, 92 skips
- Schone trunk r25037 (eigen database): 5877 runs, 30889 assertions,
  27 failures, 2 errors, 92 skips — **dezelfde 29 faalnamen, `diff` leeg**;
  alle 29 zijn repository-/changeset-/`SysController`-tests die `svn`, `hg`,
  `bzr` of `cvs` nodig hebben, en die staan niet in dit image.
  5904 - 5877 = 27, precies het aantal nieuwe tests
- **De absolute totalen zijn tussen ronde 2 en ronde 3 gezakt, en dat is niet
  deze patch.** Ronde 2 mat 6000 en 5977 voor dezelfde twee kanten, ronde 3
  meet 5904 en 5877, in een verse container op dezelfde trunk-revisie. Beide
  kanten zakken ongeveer evenveel, allebei houden ze dezelfde 27 failures /
  2 errors / 92 skips en dezelfde 29 faalnamen, en het verschil patch-min-trunk
  is in elke ronde precies het aantal nieuwe tests (23 toen, 27 nu). **De
  oorzaak is de Git-testrepository, en dat is op 2026-09-06 nagemeten** — in de
  ronde-3-worktrees stond `tmp/test/git_repository` niet uitgepakt, en zonder
  dat bestaan de Git-tests niet eens: dezelfde drie bestanden geven `114 runs`
  mét de fixture en `8 runs` zonder, dus 106 tests verdwijnen geruisloos. Dat
  dekt vrijwel het hele gat (96 en 100); de laatste paar zijn niet verklaard.
  **Eerlijk erbij: dat betekent dat de ronde-3-suite de Git-adaptertests niet
  heeft gedraaid.** Voor deze patch verandert dat de conclusie niet — hij raakt
  geen repository-, changeset- of adaptercode — maar de dekking was kleiner dan
  het getal suggereert. Lees dus het verschil en de namendiff, niet het
  absolute getal; dat is alleen binnen één runpaar vergelijkbaar, en alleen als
  beide kanten dezelfde fixtures hebben
- Volledige suite op `7.0-stable-GEOxyz`, op de branchtip van 2026-09-06 met de
  ronde-3-fixes erop: 6014 runs, 31493 assertions,
  **0 failures, 0 errors**, 39 skips — helemaal groen, geen enkele faalnaam.
  Dat die branch nul faalt waar trunk er 29 heeft ligt **niet** aan de
  omgeving: geen van beide worktrees heeft SCM-fixtures en `svn`, `hg`, `bzr`
  en `cvs` ontbreken alle vier in dit image. Het is een verschil tussen de
  7.0-stable-code en de huidige trunk in wat een repositorytest doet als de
  SCM-binary er niet is: trunk laat hem falen, 7.0 slaat hem over. Nagemeten
  met hetzelfde bestand aan beide kanten —
  `test/functional/repositories_controller_test.rb` geeft op
  `7.0-stable-GEOxyz` `34 runs, 0 failures, 3 skips` en op trunk r25037
  `34 runs, 14 failures, 10 skips`. De twee nieuwe testbestanden apart: 27
  runs, 96 assertions, 0 failures
- De twee nieuwe testbestanden samen in één proces: 27 runs, 96 assertions,
  0 failures, 0 errors, aan beide kanten
- Rood bewezen voor de drie ronde-2-fixes, per hunk, door mutatie:
  het token weer ónder `Net::IMAP.new` zetten geeft
  `1 runs, 1 assertions, 1 failures` op
  `test_check_should_not_open_a_connection_when_the_token_cannot_be_obtained`;
  `json_body` terugdraaien geeft `1 failures` op
  `test_access_token_should_raise_when_a_successful_response_has_no_json_body`;
  en de mutatie uit bevinding F04 (`post_to_token_endpoint` gooit het antwoord
  weg) maakt `oauth2_client_test.rb` `18 runs, 5 failures, 3 errors` waar de
  oude stub hem groen liet
- Rood bewezen op de oude code (eerste ronde): 20 van de 21 nieuwe tests vallen om in een
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
- RuboCop op de vier gewijzigde bestanden: 0 (baseline 0). `lib/tasks/email.rake`
  wordt niet gelint (`lib/tasks/**/*` staat in Redmine's eigen `.rubocop.yml`
  onder Exclude), dus daar is menselijke review de enige controle
- `bin/rails zeitwerk:check`: "All is good!" — het nieuwe `lib/redmine`-bestand
  laadt ook onder eager loading, wat productie doet
- `tools/check-patch-clean.sh imap-oauth --submit`: PASS · 
  `tools/check-geoxyz-branch.sh`: PASS (current met `origin/7.0-stable`, geen
  AI-sporen, 1 lint-offence op 66 gewijzigde Ruby-bestanden die al op een eigen
  regel van upstream staat, baseline 1, locales binnen de vijf)
- Patch applyt op een verse `origin/master`-checkout r25037: ja
- Screenshots ronde 2: twee, gelezen: ja — `round2-issues-list.png` en
  `round2-issue-from-xoauth2-mail.png`, plus `shots/round2-terminal-transcript.txt`
  met de voor/na-paren van F02 en F03 tegen de echte harnas-servers: bij een
  onderscheppende proxy en bij een ingetrokken refresh token opende de oude code
  wél een IMAP-verbinding en de nieuwe geen enkele
- Screenshots eerste ronde: drie (één before), gelezen: ja. Plus
  `shots/terminal-transcript.txt`: de before-run op schone trunk, de vier
  geslaagde runs, de vijf faalpaden van het ophalen en de zes faalpaden van de
  toestemmingsstap
- De hele keten is in volgorde gedraaid, niet de drie stukken los:
  `oauth2_authorize` printte een URL, die URL is gevolgd zoals een browser hem
  volgt, het redirect-adres is teruggeplakt, de taak printte de
  `refresh_token:`-regel, die regel ging in het bestand, en `receive_imap`
  maakte daarmee issue #15 aan. Het log van de tokenendpoint laat beide grants
  in de juiste volgorde langskomen

**Reviewronde 3 (2026-09-06), blind.** Een verse sessie las de patch koud,
zonder de bevindingen van ronde 1 eerst te lezen, en vond acht dingen. Alle acht
staan dicht in
`docs/review/findings/2026-09-06-imap-oauth-claude-opus5-round3.md`:

- **F01 (minor, code)** — een querystring die de beheerder al in `authorize_url`
  had staan werd stil weggegooid, terwijl `token_url` de zijne wél behield. Een
  Azure AD B2C-endpoint draagt zo'n parameter (`?p=<policy>`). Nu samengevoegd,
  en de grant-parameters winnen nog steeds.
- **F02, F03, F05 (minor/nit, dossier)** — de verouderde K-06-regel is weg, de
  bewering "niets anders in Redmine leest van stdin" is omgedraaid naar het
  sterkere antwoord (`redmine:load_default_data` doet het zelf), en er staat nu
  bij waarom een access token wél via `ENV` mag en een refresh token niet.
- **F04 (nit, code)** — een 200 met een body die wél JSON is maar geen object
  (`[]`, `null`) gaf `TypeError`; nu dezelfde nette melding als elk ander
  faalpad.
- **F06 (nit, conventies)** — `write_timeout`, `::Net::HTTP` en `STDOUT.flush`,
  conform `app/models/webhook.rb` en `lib/tasks/load_default_data.rake`.
- **F07 (question)** — Jans keuze, optie B: zie hieronder.
- **F08 (minor, test-kwaliteit)** — **de belangrijkste, en hij kwam pas boven
  tijdens het fixen.** De drie timeout-assertions controleerden `Net::HTTP`'s
  eigen standaardwaarden: die staan alle drie al op 60, dus de test bleef groen
  met álle timeouts uit de productiecode gesloopt. Dit is INV-8 in het klein en
  het overleefde ronde 1 én de blinde leesbeurt van ronde 3. De gestubde
  verbinding wordt nu eerst op 1 gezet, zodat 60 alleen nog uit de code kan
  komen.

De patch is in dezelfde beweging opnieuw opgebouwd als één commit op trunk
r25037 (`10efe8761`), en de oude tip staat bewaard als
`archive/patch-imap-oauth-r25037-before-round3` zodat `fd712001c` uit de review
oplosbaar blijft.

## Wat Jan nog moet doen

Twee dingen, en het eerste is het echte werk.

**1. Hang `patches/imap-oauth/2026-09-06-r25037-feature.patch` als note aan je
eigen issue [#43023](https://www.redmine.org/issues/43023)** — geen nieuw
issue, dat issue staat op naam van kerncommitter Marius BĂLTEANU met doelversie
7.1.0. Zeg in die note dat dit een **vervanging** is van
`..._version3.patch`, niet een aanvulling, en waarom hij zoveel kleiner is:

- 618 regels in plaats van 1197, en **geen** nieuwe gem. `oauth2` en
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
- **Bied de splitsing aan, in één zin** (jouw keuze F07/optie B van 2026-09-06).
  Zeg dat de patch netjes in tweeën valt — het ophaalgedeelte (`oauth2_token=`,
  `oauth2_credentials=`, `Oauth2Client.access_token`) en de eenmalige
  toestemmingsstap (`oauth2_authorize`) — en dat je hem graag als twee
  indient als de committer liever eerst alleen het eerste neemt. **Hang wel
  één patchbestand aan**; het aanbod staat in de tekst. Reden: op #29664 vroeg
  Holger Just precies om zo'n splitsing, dus die vraag komt waarschijnlijk
  toch. De kant-en-klare formulering staat in `dossier.md` in de tabel met
  verwachte bezwaren, rij "This is two changes".

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

Er staat **geen keuze meer voor je open.** K-06 (de `client_credentials`-grant,
app-only) besliste je op 2026-09-03 met optie A: alleen de refresh-token-grant
gaat mee, en wie app-only wil mint het token zelf en geeft het met
`oauth2_token=`. F07 uit reviewronde 3 besliste je op 2026-09-06 met optie B:
de note biedt de splitsing aan, de bijlage blijft één bestand. Beide staan in
`docs/DECISIONS.md`; niet opnieuw afwegen.

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
Ronde 2 is voor deze slug klaar; ronde 3 (blinde herreview) is een aparte
sessie en leest deze regel liefst niet vooraf.
