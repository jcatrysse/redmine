---
slug: webhook-issue-closed
feature: Apart issue.closed-event op de webhook
commit_51: 25220b45d (deel)
geoxyz: live
geoxyz_commit: 827e9e7d5
upstream: patch klaar
patch: patches/webhook-issue-closed/2026-09-03-r24882-feature.patch
issue:
---

# webhook-issue-closed — status

## Waar het staat

Af, op één ding na: Jan moet het issue op redmine.org aanmaken. De patch is
gemaakt, bewezen en geëxporteerd (**één** bestand, geen aparte locales-patch —
zie hieronder), en dezelfde wijziging staat als commit `827e9e7d5` op
`7.0-stable-GEOxyz`. De volledige suite is aan drie kanten gedraaid (patch,
schone trunk, GEOxyz), RuboCop is nul, en de functie is in een echte browser
nagelopen met een echte HTTP-ontvanger die de uitgaande POSTs opving — voor en
na, met dezelfde zeven wijzigingen aan hetzelfde issue.

De patch is zes regels productiecode. Dat komt doordat trunk sinds
`acts_as_webhookable` (2026-02-22) al een generieke webhooklaag heeft: de
5.1-commit bouwde vier eigen `after_*_commit`-callbacks in `Issue`, en daarvan
is niets meer nodig.

## Wat het doet

Een webhook kan aanvinken dat hij alleen wil horen wanneer een issue
**gesloten** wordt, in plaats van op elke issuewijziging te abonneren en zelf
uit de journaalregels te moeten opmaken of dit de sluiting was. Het event vuurt
één keer per sluiting: niet opnieuw bij een tweede gesloten status, niet bij
heropenen, wél opnieuw als het issue daarna weer dichtgaat.

## Bewijs

- Volledige suite met patch: **5929 runs, 31487 assertions, 27 failures,
  2 errors, 92 skips**
- Volledige suite op schone trunk: **5920 runs, 31449 assertions, 28 failures,
  2 errors, 92 skips**. Faalnamen vergeleken, niet aantallen: de **29** namen
  van de patchrun zijn een strikte **deelverzameling** van de **30** van de
  schone run. Alle 29 zijn repository-/changeset-/`SysController`-tests die een
  SCM-binary nodig hebben die dit image niet heeft. De ene naam die de schone
  run extra had is
  `ListAutofillSystemTest#test_remove_list_marker_with_single_halfwidth_space_variants`
  (`expected "/my/page" to equal "/login"`) — een inlograce in de
  Selenium-harnas van een Markdown-test die niets met webhooks te maken heeft.
  De patch introduceert dus **geen enkele** fout.
- Volledige suite op de **werkelijke tip** van `7.0-stable-GEOxyz`
  (`827e9e7d5`, met de zeven eerdere features eronder): **PENDING**
- Webhooksuites apart (`webhook_test`, `webhook_payload_test`,
  `webhooks_controller_test` in één proces): **68 runs, 254 assertions,
  0 failures, 0 errors**, tegen **60 runs, 226 assertions, 0 failures** op
  schone trunk. Op `7.0-stable-GEOxyz`: **102 runs, 1076 assertions,
  0 failures** (met de i18n-test erbij).
- Locale-consistentietest van Redmine zelf
  (`test/unit/lib/redmine/i18n_test.rb`) samen met de webhooksuites: **96 runs,
  1057 assertions, 0 failures, 0 errors**.
- RuboCop op de gewijzigde bestanden: **0** (baseline op dezelfde bestanden op
  de merge-base: **0**). Ook 0 in de GEOxyz-worktree.
- Rood op oude code: **4 van de 8** nieuwe tests falen op een schone
  trunk-worktree (`ArgumentError: invalid event: issue.closed`,
  `Validation failed: Events is invalid`, en twee keer
  `expected exactly once, invoked never`). De andere **drie zijn bewakers** met
  een `.never`-verwachting (gesloten→gesloten, heropenen, en een gewone edit
  van een gesloten issue) en staan aan **beide** kanten groen; ze bewijzen niet
  het nieuwe gedrag maar beschermen tegen een toekomstige regressie. Zo staat
  het ook in het dossier.
- Patchbestand appliceert los op een verse `origin/master`-checkout en
  reproduceert de branch exact (gecontroleerd in een wegwerp-worktree).
- `tools/check-patch-clean.sh`: **PASS** · `tools/check-geoxyz-branch.sh`:
  **PASS** (snelle checks; de suite is de andere helft en staat hierboven)
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
`patches/webhook-issue-closed/2026-09-03-r24882-feature.patch` aan. Dat is
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
per stuk de reden erbij. Dit is punt 2, los, tegen r24882. `webhook-tracker-filter`
was punt 1; dien ze los in, niet samen.

Drie dingen die het waard zijn om erbij te zetten omdat ze de patch verdedigen
vóórdat iemand ernaar vraagt:

- **Niets verandert voor een bestaande installatie.** De `events`-array van een
  bestaande hook bevat `issue.closed` niet, dus `hooks_for` geeft die hook
  nooit terug voor dit event. Er is een end-to-end test die een hook met
  **alleen** `issue.closed` sluit en precies één job verwacht, en een
  screenshot van echte leveringen die het in een draaiende Redmine laat zien.
- **De tabel met de acht overgangen** uit het dossier ("Which transitions fire,
  and which do not"). Twee rijen daarvan zijn wat een ontvanger die dit uit
  `issue.updated` reconstrueert als eerste fout doet: `Closed` → `Rejected` is
  geen tweede sluiting, en een gewone edit van een gesloten issue is er ook
  geen. Elke rij heeft een test.
- **Er zit geen instelling, migratie, gem, route of permissie in.** Zes regels
  productiecode, waarvan één een locale-string.

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
- **De callback staat met opzet niet in de `case` van
  `acts_as_webhookable`.** Die `case` mapt actienamen op Rails-lifecycle-
  callbacks en "closed" is er geen. De `case` heeft geen `else`, en trunks
  eigen test `should generate payload for custom event` leunt daarop. Zie
  `decisions.md`.
- **Alleen `en.yml`, en dat is een beredeneerde keuze, geen vergeten stap.**
  De drie zustersleutels (`webhook_event_created`, `_updated`, `_deleted`)
  staan in **elk** taalbestand en zijn in **allemaal** onvertaald Engels, ook
  in `de.yml`. Ze staan daar door `rake locales:update`, dat nieuwe `en`-
  sleutels letterlijk naar alle talen kopieert. En `config.i18n.fallbacks` staat
  aan, dus een taal zonder de sleutel rendert exact dezelfde Engelse string.
  Eén van de vier labels vertalen zou het vinkjesblok half Engels maken, want
  `_form.html.erb` vult `object_name` met een Engelse klassenaam. Volledige
  onderbouwing in `dossier.md`.
- **De drie codebestanden die deze patch raakt zijn byte-identiek tussen
  `origin/master` en `7.0-stable-GEOxyz`** (`issue.rb`,
  `concerns/issue/webhookable.rb`, `acts/webhookable.rb`). `en.yml` en
  `webhook_test.rb` verschillen wel, maar in andere regio's van het bestand, dus
  de cherry-pick landde schoon. De twee diffs zijn regel voor regel vergeleken
  (na het wegfilteren van `index`- en hunk-regels): **identiek**. Geen
  INV-10-afwijking.
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
2. **`webhook_event_created` / `_updated` / `_deleted` staan in álle
   taalbestanden onvertaald**, ook in `de.yml`. Al gemeld bij
   `webhook-tracker-filter`; deze patch voegt er een vierde onvertaalbare
   sleutel aan toe en dat is precies waarom K-09 openstaat.
3. **`object_name` wordt niet gelokaliseerd.** `_form.html.erb` geeft
   `:object_name => type.to_s.humanize` door — een Engelse klassenaam — terwijl
   de legenda erboven `l(:"label_#{type}_plural")` gebruikt. Al gemeld bij
   `webhook-tracker-filter`. Het is de reden dat vertalen van deze sleutel
   alleen samen met een fix hiervoor zin heeft.

## Volgende stap voor een sessie

Af — niets te doen. Wachten tot Jan het issue heeft aangemaakt; vul dan het
`issue:`-veld in de front matter en de "Submission"-sectie van `dossier.md` in.
