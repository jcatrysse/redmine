---
slug: webhook-tracker-filter
feature: Webhook beperken tot gekozen trackers
commit_51: 25220b45d (deel)
geoxyz: live
geoxyz_commit: 135f15620
upstream: patch klaar
patch: patches/webhook-tracker-filter/2026-09-03-r24882-feature.patch
issue:
---

# webhook-tracker-filter — status

## Waar het staat

Af, op één ding na: Jan moet het issue op redmine.org aanmaken. De patch is
gemaakt, bewezen en geëxporteerd (twee bestanden), en dezelfde wijziging staat
als commit `135f15620` op `7.0-stable-GEOxyz`. De volledige suite is aan drie
kanten gedraaid (patch, schone trunk, GEOxyz), RuboCop is nul, en de functie is
in een echte browser nagelopen met een echte HTTP-ontvanger die de uitgaande
POSTs opving — voor en na.

De belangrijkste uitkomst van de trunk-check: **webhooks zitten inmiddels in
Redmine core** (#29664, 25 commits, sinds 2025-10-07). De 5.1-commit bouwde die
hele functie zelf; daarvan blijft dus alleen het trackerfilter over. Dat maakt
deze patch klein: 8 bestanden, 73 toegevoegde regels inclusief tests.

## Wat het doet

Op een webhook kun je aanvinken voor welke trackers hij mag vuren. Issue-events
gaan dan alleen nog naar de endpoint voor die trackers; vink je niets aan, dan
vuurt de hook voor alle trackers, precies zoals nu.

## Bewijs

- Volledige suite met patch: **5926 runs, 31473 assertions, 27 failures,
  2 errors, 92 skips**
- Volledige suite op schone trunk: **5920 runs, 31455 assertions, 27 failures,
  2 errors, 92 skips**. Faalnamen identiek: **ja** — 29 namen, byte-identieke
  lijst, allemaal repository-/changeset-/`SysController`-tests die een
  SCM-binary nodig hebben die dit image niet heeft.
- Volledige suite op `7.0-stable-GEOxyz`: **5951 runs, 31818 assertions,
  0 failures, 0 errors, 39 skips** — daar is het echt 0/0.
- Webhooksuites apart (`webhook_test`, `webhook_payload_test`,
  `webhooks_controller_test` in één proces): 66 runs, 246 assertions, 0 failures.
- RuboCop op de gewijzigde bestanden: **0** (baseline op dezelfde bestanden op
  de merge-base: **0**). Ook 0 in de GEOxyz-worktree.
- Rood op oude code: 5 van de 6 nieuwe tests falen op een schone
  trunk-worktree; de zesde
  (`test_should_find_hook_for_issue_of_any_tracker_when_no_tracker_is_selected`)
  is groen aan **beide** kanten en is de bewaker voor achterwaartse
  compatibiliteit.
- N+1 gemeten: met `preload(:trackers)` blijft `hooks_for` op 5 queries bij
  zowel 5 als 20 hooks; zonder de preload gaat het naar 8 en 23.
- `tools/check-patch-clean.sh`: **PASS** · `tools/check-geoxyz-branch.sh`:
  **PASS** (snelle checks; de suite is de andere helft en staat hierboven)
- Beide patchbestanden appliceren los op een verse `origin/master`-checkout, en
  samen reproduceren ze de branch exact (gecontroleerd in een wegwerp-worktree).
- Screenshots: **6**, gelezen: **ja** (zie de tabel in `dossier.md`; de twee
  leveringstabellen zijn echte POSTs van de draaiende applicatie, opgevangen
  door een echte HTTP-server, niet een bewering erover).

## Wat Jan nog moet doen

Maak een **nieuw** issue op redmine.org aan als follow-up van
[#29664](https://www.redmine.org/issues/29664) — dus niet als note aan #29664
zelf, dat issue is gesloten met target version 7.0.0. Hang er
`patches/webhook-tracker-filter/2026-09-03-r24882-feature.patch` en
`-locales.patch` aan. De Engelse issuetekst staat kant-en-klaar in
`dossier.md` vanaf "The problem".

Zeg in de beschrijving expliciet dat dit **note 37 van Holger Just op #29664
beantwoordt**: hij vroeg om de monolithische 5.1-patch op te splitsen in losse
patches, elk met de reden erbij, en gerebaseerd op de huidige trunk. Dit is
punt 1 van je eigen note 36, los, tegen r24882, met de probleembeschrijving en
de afgewogen alternatieven erbij. Dat is het sterkste argument dat er is — een
committer heeft precies hierom gevraagd.

Twee dingen die het waard zijn om erbij te zetten omdat ze de patch verdedigen
vóórdat iemand ernaar vraagt:

- Leeg = alle trackers, dus geen enkele bestaande hook verandert van gedrag bij
  een upgrade. Er is een unittest die dat vastlegt en die **ongewijzigd groen
  staat op trunk**, plus een screenshot van een echte levering die het in een
  draaiende Redmine laat zien.
- De patch voegt `preload(:trackers)` toe zodat `hooks_for` niet één query per
  hook gaat doen. Noem #44386 erbij — daar haalde Marius Bălteanu een week
  eerder een N+1 uit ditzelfde model, dus het is duidelijk dat het onderwerp
  leeft.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **De hele webhookfunctie hoeft niet meer ingediend te worden.** Upstream heeft
  hem (#29664). Alleen het trackerfilter is nog nieuw. Ga dus niet op zoek naar
  de rest van `25220b45d` — het andere deel is de aparte feature
  `webhook-issue-closed`.
- **Leeg = alle trackers, en dat is geen keuze meer.** De 5.1-code eiste
  minstens één tracker zodra er een issue-event aanstond. Dat maakt elke
  bestaande hook ongeldig bij een upgrade en is upstream niet verdedigbaar. Zie
  `decisions.md`.
- **Het formulier biedt alle trackers** (`Tracker.sorted`), niet alleen die van
  de gekozen projecten. Zes bestaande Redmine-views doen het zo; de
  projectgebonden variant vraagt JavaScript en riskeert precies de N+1 die
  #44386 net oploste.
- **De webhooklijst krijgt met opzet geen Trackers-kolom.** Een lege cel leest
  daar als "geen trackers" terwijl hij "alle trackers" betekent, en #44337
  stelt voor die lijst helemaal te herbouwen. Als een reviewer erom vraagt is
  het twee regels.
- **`nl`, `fr` en `es` krijgen de nieuwe sleutel niet** — de twee buurhints op
  datzelfde formulier staan daar zelf nog onvertaald in het Engels, en
  `config.i18n.fallbacks` is `true`. Dit is open keuze **K-06** in
  `docs/DECISIONS.md`; we bouwden verder met optie A (alleen `en` en `de`).
- **De vijf codebestanden die deze patch raakt zijn byte-identiek tussen
  `origin/master` en `7.0-stable-GEOxyz`.** Daarom is de GEOxyz-commit
  letterlijk dezelfde diff en is er geen INV-10-afwijking.
- **Wijzig `create_hook` in de testbestanden niet.** Dat is geprobeerd: de
  helper een `trackers:`-argument geven liet 17 bestaande tests op trunk erroren
  en verstopte daarmee het rood-bewijs. De nieuwe tests zetten trackers met
  `hook.update!`.
- **De ontvanger in `verify/webhook-tracker-filter.mjs` bindt op `192.0.2.2`,
  niet op loopback.** `WebhookEndpointValidator` weigert loopback en link-local
  onvoorwaardelijk, dus een `127.0.0.1`-URL is nooit op te slaan als webhook.
  Er is ook geen `http_proxy` gezet in deze container, dus plain HTTP gaat
  direct.

## Gevonden, bewust niet gerepareerd (INV-1)

Drie bestaande trunk-defecten die tijdens dit werk boven kwamen. Ze horen in
een eigen bugrapport, niet in deze patch; melden is genoeg.

1. **Een verzonnen id in `webhook[project_ids][]` geeft een 500.**
   `hook.project_ids = [999999]` gooit `ActiveRecord::RecordNotFound`, en
   `ApplicationController` heeft daar geen globale rescue voor. Reproduceerbaar
   op schone trunk. `tracker_ids` erft die eigenschap, want de patch spiegelt
   het projectenpatroon precies; het asymmetrisch dichtzetten zou slechter zijn.
2. **`webhook_event_created` / `_updated` / `_deleted` staan in `de.yml` nog
   onvertaald** als `"%{object_name} created"`.
3. **`object_name` wordt niet gelokaliseerd.** `_form.html.erb` geeft
   `:object_name => type.to_s.humanize` door — een Engelse klassenaam. De
   legenda erboven gebruikt wél `l(:"label_#{type}_plural")`. Zichtbaar in
   `shots/webhook-form-de.png`: de fieldset heet `Tickets` en het vinkje erin
   `Issue created`.

## Volgende stap voor een sessie

Af — niets te doen. Wachten tot Jan het issue heeft aangemaakt; vul dan het
`issue:`-veld in de front matter en de "Submission"-sectie van `dossier.md` in.
