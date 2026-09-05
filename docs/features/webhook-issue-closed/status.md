---
slug: webhook-issue-closed
feature: Apart issue.closed-event op de webhook
commit_51: 25220b45d (deel)
geoxyz: live
geoxyz_commit: 7e92b5596
upstream: patch klaar
patch: patches/webhook-issue-closed/2026-09-05-r25037-feature.patch
issue:
---

# webhook-issue-closed — status

## Waar het staat

Af, op één ding na: Jan moet het issue op redmine.org aanmaken. De patch is
gemaakt, bewezen en geëxporteerd (**één** bestand, geen aparte locales-patch —
zie hieronder). De volledige suite is aan drie kanten gedraaid (patch, schone
trunk, GEOxyz), RuboCop is nul, en de functie is in een echte browser
nagelopen met een echte HTTP-ontvanger die de uitgaande POSTs opving — voor en
na, met dezelfde zeven wijzigingen aan hetzelfde issue.

**Ronde 2 is af (2026-09-05).** Alle tien bevindingen uit
`docs/review/findings/2026-09-03-webhook-issue-closed-claude-opus5.md` hebben
een `Resolution:`-regel. Drie ervan wijzigden code, zeven de begeleidende
tekst. De patch is opnieuw op **r25037** (`bee32a926`) gezet, 88 commits verder
dan de eerste versie, zonder conflict — en op `7.0-stable-GEOxyz` staat het
ontwerp nu in een tweede commit, `7e92b5596`, naast de oorspronkelijke
`827e9e7d5`. (Twee commits omdat de branch die GEOxyz draait nooit herschreven
wordt; het registerveld wijst naar de laatste.)

De belangrijkste codewijziging van ronde 2 is F05: `lib/redmine/acts/webhookable.rb`
staat weer exact op trunk. `closed` is een event dat alleen `Issue` kan
afvuren, dus de generieke laag leert de naam niet meer kennen —
`Issue::Webhookable` overschrijft `webhook_payload_timestamp`. **De patch raakt
daarmee geen enkel bestand onder `lib/redmine/`.**

Buiten de tests is de patch dertien toegevoegde en twee verwijderde regels over
drie bestanden, waarvan twee toevoegingen commentaar zijn. Dat het zo klein is,
komt doordat trunk sinds `acts_as_webhookable` (2026-02-22) al een generieke
webhooklaag heeft: de 5.1-commit bouwde vier eigen `after_*_commit`-callbacks
in `Issue`, en daarvan is niets meer nodig.

## Wat het doet

Een webhook kan aanvinken dat hij alleen wil horen wanneer een issue
**gesloten** wordt, in plaats van op elke issuewijziging te abonneren en zelf
uit de journaalregels te moeten opmaken of dit de sluiting was. Het event vuurt
één keer per sluiting: niet opnieuw bij een tweede gesloten status, niet bij
heropenen, wél opnieuw als het issue daarna weer dichtgaat.

## Bewijs

Alles opnieuw gemeten op **2026-09-05**, tegen trunk **r25037** (`bee32a926`).

- Volledige suite met patch: **5988 runs, 31747 assertions, 27 failures,
  2 errors, 92 skips**
- Volledige suite op schone trunk r25037: **5977 runs, 31708 assertions,
  27 failures, 2 errors, 92 skips**. De elf extra runs zijn de tien nieuwe
  tests plus de ene die trunks eigen geparametriseerde payloadlus voor het
  nieuwe event genereert.
- **Faalnamen vergeleken, niet aantallen — en de twee verzamelingen zijn nu
  identiek.** Beide runs falen op dezelfde **29** namen; `comm` van de twee
  gesorteerde lijsten is in beide richtingen leeg. Uitsplitsing:
  `RepositoriesControllerTest` (14), `Redmine::ApiTest::RepositoriesTest` (8),
  `SysControllerTest` (5), `UserTest#test_destroy_should_nullify_changesets` en
  één `Redmine::ApiTest::IssuesTest`. Alle 29 hebben een SCM-binary nodig die
  dit image niet heeft (`svn`, `hg`, `bzr`, `cvs` ontbreken; alleen `git` is er).
  De patch introduceert dus **geen enkele** fout. Anders dan bij de meting op
  r24882 hoeft er deze keer aan geen van beide kanten een flake weggeredeneerd
  te worden.
- Webhooksuites apart (`webhook_test`, `webhook_payload_test`,
  `webhooks_controller_test` in één proces): **71 runs, 262 assertions,
  0 failures, 0 errors, 0 skips**. Op `7.0-stable-GEOxyz`, dezelfde drie plus
  Redmine's eigen locale-consistentietest: **110 runs, 1104 assertions,
  0 failures, 0 errors**.
- RuboCop op de gewijzigde Ruby-bestanden: **0** (vier bestanden; `en.yml` is
  geen Ruby). Baseline op dezelfde vier op de merge-base, gemeten in een
  worktree met dezelfde `Gemfile.lock` zodat dezelfde cops draaien: **0**. In
  de GEOxyz-worktree, vijf bestanden: **0**.
- **Rood op oude code:** de twee testbestanden op een schone trunk-worktree
  (r25037) — **62 runs, 218 assertions, 2 failures, 3 errors**, dus **5 van de
  10** nieuwe tests falen daar. Drie keer `ArgumentError: invalid event:
  issue.closed` of `Validation failed: Events is invalid`, twee keer
  `expected exactly once, invoked never`.
- **De andere vijf zijn bewakers, en die staan óók niet stil.** Het zijn de
  `.never`-verwachtingen (aangemaakt met open status, gesloten→andere gesloten
  status, heropenen, veld gewijzigd terwijl gesloten, notitie terwijl
  gesloten). Ze zijn groen op oude code omdat het event daar niet bestaat.
  Wat bewijst dat ze dragen is een mutatie: haal `if saved_change_to_closed_on?`
  weg en draai `webhook_test` → **36 runs, 127 assertions, 5 failures**, alle
  vijf. Vijf tests bewijzen dus het nieuwe gedrag, vijf beschermen het.
- **De metingen waar de dossierclaims op steunen** (probe die
  `sql.active_record` telt en de types van de `WebhookJob`s in de wachtrij
  leest): queries op `webhooks` rond één `Issue#save`, nul hooks in de tabel —
  aan `sluitend 2 / niet-sluitend 1`, uit `0 / 0`; twee saves van hetzelfde
  issue in één transactie → alleen `issue.updated`; kopie met "status
  behouden" → `issue.closed` + `issue.created`; sluiten met één duplicaat →
  twee keer beide; direct gesloten aangemaakt → `issue.closed` staat vóór
  `issue.created` in de wachtrij.
- Volledige suite op de tip van `7.0-stable-GEOxyz` (`7e92b5596`, met de
  eerdere features eronder): **6121 runs, 32338 assertions, 0 failures,
  0 errors, 39 skips** — in één run, zonder gelijktijdige andere suite, dus
  geen flake om weg te redeneren.
- `tools/check-patch-clean.sh webhook-issue-closed --submit`: **PASS** — het
  patchbestand applyt op een verse r25037-checkout en is dezelfde wijziging als
  de branch. `tools/check-geoxyz-branch.sh`: **PASS** (lint 1 offence op 66
  bestanden, en die stond al op een regel van upstream — baseline 1, de branch
  voegt er nul toe).
- Screenshots: **10**, gelezen: **ja** — de twee uitsnedes van het
  vinkjesblok geteld (drie tegen vier) en het nieuwe label op zijn plek
  gelezen, en beide leveringstabellen regel voor regel tegen het journaal in de
  bijbehorende `issue-history`-shot gelegd. Daardoor zijn de vier
  "geen levering"-gevallen conclusies en geen afwezigheden. De twee
  leveringstabellen zijn echte POSTs van de draaiende applicatie, opgevangen
  door een echte HTTP-server: **zes** leveringen voor, **twee** na.

## Wat Jan nog moet doen

Maak een **nieuw** issue op redmine.org aan als follow-up van
[#29664](https://www.redmine.org/issues/29664) — dus niet als note aan #29664
zelf, dat issue is gesloten met target version 7.0.0. Hang er
`patches/webhook-issue-closed/2026-09-05-r25037-feature.patch` aan. Dat is
**één** bestand: er is geen aparte locales-patch, en de reden daarvoor staat
hieronder en in het dossier onder "Locales — why `en.yml` only". De Engelse
issuetekst staat kant-en-klaar in `dossier.md` vanaf "The problem".

Het sterkste argument staat in het issue zelf en het is jouw eigen tekst. Zeg
in de beschrijving expliciet dat dit **punt 2 van je note 36 op #29664** is.
Die note luidt verbatim: *"I revised this patch to include: 1. An option to
select trackers. 2. An option to only trigger on issue close. 3.
Documentation. 4. A full list of webhooks for admin users. 5. More languages.
6. Amended testing."* En **note 37 van Holger Just** vroeg precies om dit: die
monolithische patch opsplitsen in losse stukken, tegen de huidige trunk, met
per stuk de reden erbij. Dit is punt 2, los, tegen r25037. `webhook-tracker-filter`
was punt 1; dien ze los in, niet samen.

Drie dingen die het waard zijn om erbij te zetten omdat ze de patch verdedigen
vóórdat iemand ernaar vraagt:

- **Niets verandert voor een bestaande installatie.** De `events`-array van een
  bestaande hook bevat `issue.closed` niet, dus `hooks_for` geeft die hook
  nooit terug voor dit event. Er is een end-to-end test die een hook met
  **alleen** `issue.closed` sluit en precies één job verwacht, en een
  screenshot van echte leveringen die het in een draaiende Redmine laat zien.
- **De tabel met de overgangen** uit het dossier ("Which transitions fire, and
  which do not"). Twee rijen daarvan zijn wat een ontvanger die dit uit
  `issue.updated` reconstrueert als eerste fout doet: `Closed` → `Rejected` is
  geen tweede sluiting, en een gewone edit van een gesloten issue is er ook
  geen. **Zeven** van de acht rijen hebben een eigen test; de achtste
  ("verwijderd") niet, en waarom staat erbij — een `after_save_commit` kan door
  een destroy niet bereikt worden. Er staan sinds ronde 2 twee rijen bij die
  geërfd gedrag beschrijven: een kopie met "status behouden", en de cascade via
  `close_duplicates` die één statuswijziging in N+1 events omzet.
- **Er zit geen instelling, migratie, gem, route of permissie in.** Buiten de
  tests dertien toegevoegde en twee verwijderde regels over drie bestanden,
  waarvan één toevoeging een locale-string is en twee commentaar. En: **geen
  enkel bestand onder `lib/redmine/`**.

Er staat één keuze voor je open: **K-09** in `docs/DECISIONS.md`, over de
vertalingen. Er is geen haast — het blokkeert het indienen niet, we bouwden
verder met `en.yml` alleen.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **De hele webhookfunctie hoeft niet meer ingediend te worden.** Upstream
  heeft hem (#29664, 25 commits, sinds 2025-10-07). Van 5.1-commit `25220b45d`
  blijven precies twee dingen over: het trackerfilter
  (`webhook-tracker-filter`, af) en dit event. Verder niets — niet de gem, niet
  de controller, niet de validator, niet de payloadklasse.
- **Er is geen bestaand issue op redmine.org voor dit event.** Gezocht op
  `webhook` (22 issues) en `webhook event` (10 issues). Niet opnieuw zoeken;
  wél kijken of Jan er inmiddels een heeft aangemaakt.
- **De trigger leest `closed_on`, en dat is geen slimmigheid.** `closed_on`
  wordt in core op precies één plek geschreven (`update_closed_on`,
  `if closing?`) en staat in geen enkele `safe_attributes`-lijst. "Deze save
  schreef `closed_on`" ís dus "deze save sloot het issue". De statusgebaseerde
  variant van 5.1 staat in `dossier.md` onder "Alternatives considered" met wat
  hij kost. Niet opnieuw afwegen.
- **`after_save_commit`, dus ook een issue dat direct gesloten wordt
  aangemaakt.** Dat is Redmine's eigen definitie: `Issue#closing?` geeft voor
  een nieuw record `closed?` terug. Er is een test voor.
- **Een beheerder die een bestaande status op "gesloten" zet veroorzaakt geen
  leveringsstorm.** `IssueStatus#handle_is_closed_change` vult `closed_on` bij
  met twee `Issue.where(...).update_all(...)`-statements, en `update_all` draait
  geen callbacks — dus vuurt noch `issue.closed` noch het bestaande
  `issue.updated`. Nagekeken in `app/models/issue_status.rb`; het staat als
  verwacht bezwaar in het dossier.
- **`lib/redmine/acts/webhookable.rb` blijft ongemoeid, en dat is sinds ronde 2
  een harde eigenschap van de patch.** De callback staat met opzet niet in de
  `case` die actienamen op Rails-lifecycle-callbacks mapt — "closed" is er geen,
  de `case` heeft geen `else`, en trunks eigen test `should generate payload for
  custom event` leunt daarop. Sinds ronde 2 geldt hetzelfde voor de
  tijdstempelmapping: die staat als override in `Issue::Webhookable` in plaats
  van als `when 'updated', 'closed'` in de generieke `case` (F05). Niet
  terugdraaien om twee regels te besparen — het is precies het argument dat het
  dossier voert. Zie `decisions.md`, "Ronde 2".
- **Alleen `en.yml`, en dat is een beredeneerde keuze, geen vergeten stap.**
  De drie zustersleutels (`webhook_event_created`, `_updated`, `_deleted`)
  staan in alle 49 niet-Engelse taalbestanden. **Geteld op r25037** (het cijfer
  verliep één keer, dus het draagt nu zijn revisie mee): in **42** daarvan is de
  waarde nog de letterlijke Engelse string. Ze staan daar door
  `rake locales:update`, dat elke ontbrekende `en`-sleutel toevoegt **met de
  Engelse waarde**. **Zeven** talen hebben die groep inmiddels wél vertaald
  (`bg`, `cs`, `fr`, `gl`, `hu`, `ja`, `zh-TW`). `fr` is er tussen r24882 en
  r25037 bij gekomen; `nl`, `de` en `es` niet. En `config.i18n.fallbacks` staat
  aan, dus een taal zonder de sleutel rendert exact dezelfde Engelse string.
  Eén van de vier labels vertalen zou het vinkjesblok half Engels maken, want
  `_form.html.erb` vult `object_name` met een Engelse klassenaam.
  **Voor Jan bij K-09:** een Franse beheerder ziet sinds r25037 drie vertaalde
  labels plus een Engels "Issue closed" — precies de half-Engelse uitkomst
  waartegen dit argument pleit, nu bereikt langs de andere kant. Volledige
  onderbouwing in `dossier.md`.
- **De drie codebestanden die deze feature raakt zijn byte-identiek tussen de
  patch-worktree en de GEOxyz-worktree** (`issue.rb`,
  `concerns/issue/webhookable.rb`, `acts/webhookable.rb`) — opnieuw
  gecontroleerd na de ronde-2 wijziging, met `diff` op de bestanden zelf.
  `en.yml` en `webhook_test.rb` verschillen wel, maar alleen doordat de
  GEOxyz-tak ook andere features draagt; de hunks van deze feature zijn regel
  voor regel dezelfde. Geen INV-10-afwijking.
- **Op `7.0-stable-GEOxyz` staat deze feature in twee commits**, `827e9e7d5`
  (de feature) en `7e92b5596` (het ronde-2 ontwerp). Dat is met opzet: de
  branch die GEOxyz draait wordt nooit herschreven, want een force push maakt
  elke checkout daar ongeldig. Zelfde afweging als bij `ldap-mail-prefs`.
- **De end-to-end test leest niet de eerste `WebhookJob` in de wachtrij.**
  Sinds ronde 2 (F07) onthoudt hij `enqueued_jobs.size` vóór het blok. Dat
  terugdraaien laat de test bij een regressie omvallen op een payload van de
  *create* in plaats van op de aflevering van de sluiting. Rij 1 van de
  overgangstabel ("aangemaakt met een open status") hing aan precies dat
  toeval en heeft er daarom een eigen bewaker bij gekregen.
- **Wijzig `create_hook` in de testbestanden niet.** Dezelfde valkuil als bij
  `webhook-tracker-filter`: de helper uitbreiden laat 17 bestaande tests op
  trunk erroren en verstopt het rood-bewijs. De nieuwe tests gebruiken hun
  eigen helper `generate_closed_issue`.
- **De ontvanger in `verify/webhook-issue-closed.mjs` bindt op `192.0.2.2`,
  niet op loopback**, en op poort **9098** (9099 is die van
  `webhook-tracker-filter`, zodat de twee scripts naast elkaar kunnen lopen).
  `WebhookEndpointValidator` weigert loopback en link-local onvoorwaardelijk.

## Gevonden, bewust niet gerepareerd (INV-1)

1. **In development mist het webhookformulier hele modelblokken.**
   `WebhookPayload.events` is een class-level registry die `acts_as_webhookable`
   bij het laden van de modelklasse vult, en `config.eager_load = false` in
   development. Zolang Zeitwerk `WikiPage` nog niet geladen heeft, staat er dus
   géén "Wiki pages"-fieldset op `/webhooks/new` — zichtbaar in
   `shots/before-webhook-form.png`, waar vier van de vijf blokken staan. In
   productie is `eager_load = true` en is het er wel. Reproduceerbaar op schone
   trunk, niets met deze patch te maken, en een eigen bugrapport waard.
2. **`webhook_event_created` / `_updated` / `_deleted` staan in 43 van de 49
   niet-Engelse taalbestanden onvertaald**, `nl`, `fr`, `de` en `es`
   inbegrepen; zes talen (`bg`, `cs`, `gl`, `hu`, `ja`, `zh-TW`) hebben de groep
   wél gedaan. Al gemeld bij `webhook-tracker-filter`; deze patch voegt er een
   vierde Engelse sleutel aan toe en dat is precies waarom K-09 openstaat.
3. **De trunk-test `should generate payload for custom event` laat `News`
   dubbel vuren voor de rest van het proces.** Hij roept
   `News.acts_as_webhookable %w(created updated deleted commented)` aan, en dat
   registreert de drie bestaande `after_*_commit`-callbacks een **tweede** keer
   naast de eerste. Elke News-create in datzelfde testproces triggert daarna
   twee keer `news.created`. Vandaag valt het niet op omdat geen enkele test
   News-webhookleveringen telt (nagekeken: `webhook_test.rb` raakt News niet
   aan, en `news_test.rb` / `news_controller_test.rb` noemen `Webhook`
   nergens). Wie die test ooit wél schrijft, verliest er een middag aan.
   Bestaand trunk-gedrag, niets met deze patch te maken.
4. **`object_name` wordt niet gelokaliseerd.** `_form.html.erb` geeft
   `:object_name => type.to_s.humanize` door — een Engelse klassenaam — terwijl
   de legenda erboven `l(:"label_#{type}_plural")` gebruikt. Al gemeld bij
   `webhook-tracker-filter`. Het is de reden dat vertalen van deze sleutel
   alleen samen met een fix hiervoor zin heeft.

## Volgende stap voor een sessie

Af — ronde 2 incluis, niets te doen. Wachten tot Jan het issue heeft
aangemaakt; vul dan het `issue:`-veld in de front matter en de
"Submission"-sectie van `dossier.md` in. Vlak vóór het indienen nog één keer
`tools/check-patch-clean.sh webhook-issue-closed --submit` draaien (g05): als
trunk intussen verder is gelopen, is dat de plek waar dat blijkt, en dan worden
de bewijscijfers in dezelfde beweging opnieuw gedraaid.
