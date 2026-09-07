---
slug: webhook-tracker-filter
feature: Webhook beperken tot gekozen trackers
commit_51: 25220b45d (deel)
geoxyz: live
geoxyz_commit: f2242bd86 + 646008041 + 0fbad7c17 + 72a3a8e22
upstream: patch klaar
patch: patches/webhook-tracker-filter/2026-09-05-r25037-feature.patch
issue:
---

# webhook-tracker-filter — status

## Waar het staat

Af, op één ding na: Jan moet het issue op redmine.org aanmaken. Ronde 2 is
uitgevoerd op 2026-09-05: alle elf reviewbevindingen hebben een
`Resolution:`-regel, de patch is opnieuw tegen trunk r25037 gemaakt, de
bewijscijfers zijn allemaal opnieuw gedraaid tegen die basis, en de
G9-verificatie is in zijn geheel opnieuw gereden.

Er zijn vier codewijzigingen bij gekomen ten opzichte van ronde 1, alle vier
uit Jans keuzes:

- **g07** — `Tracker` krijgt `has_and_belongs_to_many :webhooks`, de spiegel van
  wat `Project` al heeft. Een verwijderde tracker laat geen rijen meer achter in
  `trackers_webhooks`.
- **K-11 optie C** — en een verwijderde tracker **deactiveert** de hooks waarvan
  hij de enige selectie was. Zonder dat zou zo'n hook een lege selectie
  overhouden, en leeg betekent alle trackers: het verwijderen van een tracker
  zou een hook dus stil verbreden in plaats van stilzetten. Nu gedraagt de
  trackerkant zich als de projectkant, waar een hook zonder projecten vanzelf
  niet meer vuurt.
- **g16d** — `Webhook#tracker_ids=` laat ids van niet-bestaande trackers vallen,
  zodat een met de hand geschreven POST geen 500 meer geeft.
- **F09** — de conditie in `hooks_for` staat over twee regels in plaats van één
  van 152 tekens.

## Wat het doet

Op een webhook kun je aanvinken voor welke trackers hij mag vuren. Issue-events
gaan dan alleen nog naar de endpoint voor die trackers; vink je niets aan, dan
vuurt de hook voor alle trackers, precies zoals nu.

De belangrijkste uitkomst van de trunk-check blijft staan: **webhooks zitten
inmiddels in Redmine core** (#29664, 25 commits, sinds 2025-10-07). De
5.1-commit bouwde die hele functie zelf; daarvan blijft dus alleen het
trackerfilter over. Het feature-patchbestand is 8 bestanden, 144 toegevoegde en
4 verwijderde regels, tests inbegrepen; de vier vertalingen staan apart.

## Reviewronde 3 (2026-09-06), blind

Een verse sessie las de patchbestanden koud. **De wijziging zelf kwam er zonder
kleerscheuren doorheen** — geen enkele bevinding over de code, de migratie of de
vertalingen. De drie bevindingen gingen alle drie over de administratie eromheen,
en één ervan was een blocker. Ze staan dicht in
`docs/review/findings/2026-09-06-webhook-tracker-filter-claude-opus5-round3.md`.

- **F01 (blocker)** — de branch `patch/webhook-tracker-filter` stond nog op
  r24882 en miste `app/models/tracker.rb` volledig: geen K-11-deactivering en
  geen `Webhook#tracker_ids=`. De patchbestanden en `7.0-stable-GEOxyz` waren
  byte-identiek aan elkaar; alleen de branch week af. Het gevaar zat in onze
  eigen indieningsvolgorde: wie de patch vlak vóór indienen ververst (g05)
  begint bij de branch en levert dan stil de versie zónder K-11. De branch is
  opnieuw opgebouwd vanaf trunk r25037 als één commit `cb4972a5c`; de oude tip
  staat als `archive/patch-webhook-tracker-filter-r24882-before-round3`.
- **F02 (major, gereedschap)** — `tools/check-patch-clean.sh` zei PASS terwijl
  hij de vergelijking branch-tegen-patchbestand helemaal niet had kunnen
  uitvoeren: bij een mislukte apply viel hij terug op een notitie. Dat is de
  controle die in ronde 2 juist voor dit soort drift is aangescherpt. Nu faalt
  hij, met een melding die zegt wat er moet gebeuren. Jan gaf hier op
  2026-09-06 opdracht toe.
- **F03 (minor, dossier)** — het bewijsblok hieronder beweerde dat de
  patchbestanden de branch exact reproduceerden. Dat was niet zo; de regel is
  rechtgezet en zegt nu ook sinds wanneer hij wél klopt.

**Wat ronde 3 verder deed is bevestigen.** De suite is aan beide kanten opnieuw
gedraaid met dezelfde `Gemfile.lock`: `5989` runs met patch tegen `5977` op
schone trunk, verschil **12** — precies de twaalf nieuwe tests — en de faalnamen
zijn aan beide kanten identiek. De K-11-mutatie geeft woordelijk de foutmelding
die het dossier claimt. Vier eigen aanvalspogingen (migratievorm,
callbackvolgorde, INV-10 tegen GEOxyz, en of de suitefouten van de patch waren)
kwamen alle vier schoon terug.

## Bewijs

Alles hieronder is op 2026-09-05 gedraaid tegen trunk r25037 (`bee32a926`), met
`tools/test-env.sh … bundle exec ruby bin/rails test:all`, dus inclusief de
systeemtests.

- Volledige suite **met de patch**: **5989 runs, 31754 assertions, 27 failures, 2 errors, 92 skips**
- Volledige suite op **schone trunk** r25037: **5977 runs, 31708 assertions, 27 failures, 2 errors, 92 skips**
- **Ronde 3 heeft dit op 2026-09-06 overgedaan en de conclusie is dezelfde,
  maar de absolute getallen zijn dat niet — en dat is de omgeving, niet de
  patch.** Een verse `bundle install` haalt sinds die dag **json 3.0.0** binnen,
  en daarmee valt alles om wat door `ActiveSupport::JSON.decode` gaat: ruim
  honderd tests, **ook op onbewerkte trunk** (daar nagemeten, niet aangenomen).
  Met dezelfde `Gemfile.lock` aan beide kanten geeft ronde 3
  `5989 runs, 48 failures, 82 errors` met patch tegen
  `5977 runs, 48 failures, 82 errors` op schone trunk: **verschil 12 runs = de
  twaalf nieuwe tests**, en **130 faalnamen die aan beide kanten identiek zijn**,
  `comm` leeg in beide richtingen. `Gemfile.lock` staat in `.gitignore`, dus
  vergelijk nooit een cijfer uit de ene worktree met dat uit een andere zonder
  dezelfde lock — zie `docs/traps.md`.
- Faalnamen identiek aan beide kanten: **29 namen, byte-identieke lijst** — het zijn
  repository-, changeset- en `SysController`-tests die een SCM-binary nodig
  hebben die dit image niet heeft (alleen `git` staat erin); geen ervan wordt
  door deze patch geraakt.
- Volledige suite op **`7.0-stable-GEOxyz`** met de wijziging erop: **6108 runs, 32294 assertions, 0 failures, 0 errors, 39 skips**. 7.0-stable draagt de trunk-tests met die SCM-eis niet, dus daar is
  het echt schoon.
- Webhook- en trackersuites plus Redmine's eigen locale-consistentietest
  (`webhook_test`, `webhook_payload_test`, `webhooks_controller_test`,
  `tracker_test`, `i18n_test` in één proces): **117 runs, 1106 assertions,
  0 failures** op de patch, **126 runs, 1138 assertions, 0 failures** op GEOxyz.
- RuboCop op de zes gewijzigde/toegevoegde Ruby-bestanden: **0**. Baseline op
  dezelfde bestanden op de merge-base: **0**. Ook 0 in de GEOxyz-worktree.
- **Rood op oude code**, per nieuwe test gemeten door de fix weg te halen en
  opnieuw te draaien:
  - `test_should_drop_the_reference_to_a_tracker_that_is_destroyed` → zonder
    `has_and_belongs_to_many :webhooks` op `Tracker`: `Expected 1 to be nil`
  - `test_should_deactivate_a_hook_whose_only_tracker_is_destroyed` → zonder
    `before_destroy :deactivate_webhooks`: `Expected true to be nil or false`
  - `test_should_ignore_a_tracker_id_that_does_not_exist` → zonder de
    `tracker_ids=`-writer: `ActiveRecord::RecordNotFound: Couldn't find Tracker
    with 'id'=999999`
  - `test_edit_should_check_the_boxes_of_the_selected_trackers` → zonder de
    lege `hidden_field_tag` in het formulier: `Expected at least 1 element
    matching "input[type=hidden]…", found 0`. Dat is precies de mutatie die de
    reviewer deed en die vóór ronde 2 groen bleef.
  - de vijf tests uit ronde 1 zijn ongewijzigd; vier daarvan zijn rood op schone
    trunk, en `test_should_find_hook_for_issue_of_any_tracker_when_no_tracker_is_selected`
    is aan beide kanten groen en is de bewaker voor achterwaartse compatibiliteit.
  - `test_should_clear_the_trackers_of_a_webhook` is aan beide kanten groen: hij
    legt bestaand gedrag vast, net als de compatibiliteitstest.
- **N+1 opnieuw gemeten** (de cijfers uit ronde 1 waren niet zelfconsistent, zie
  bevinding F05). Getelde `sql.active_record`-notificaties rond een opgewarmde
  `hooks_for`, `SCHEMA`/`TRANSACTION` eruit gefilterd; de kolom "zonder" komt uit
  dezelfde boom met alleen de `preload`-regel weggehaald:

  | matchende hooks | met `preload(:trackers)` | zonder |
  |---|---|---|
  | 1 | 4 | 4 |
  | 5 | 4 | 8 |
  | 20 | 4 | 23 |
  | 20, elk met een tracker aangevinkt | 5 | 23 |
  | 20 op `news.created`, terwijl `issue.created` vuurt | 2 | 1 |

  Drie queries zijn de constante, de preload kost er precies één (twee als er
  iets te laden valt), en zonder preload is het er één per matchende hook. De
  laatste regel is het geval waarin de patch een query **kost**; die staat nu
  ook in de bezwarentabel van het dossier.
- Beide patchbestanden appliceren los op een verse
  `origin/master`-checkout van r25037. **De tweede helft van deze regel klopte
  niet en is op 2026-09-06 rechtgezet** (ronde-3-bevinding F01): er stond dat ze
  "de branch exact reproduceren", terwijl de branch toen nog op r24882 stond en
  `app/models/tracker.rb` — de hele K-11-deactivering — helemaal niet had. De
  branch is daarna opnieuw opgebouwd vanaf actuele trunk uit het ontwerp dat de
  patchbestanden dragen (`cb4972a5c`), en pas sinds dat moment is de zin waar.
  `tools/check-patch-clean.sh` bevestigt hem nu ook echt in plaats van de
  vergelijking over te slaan.
- `tools/check-patch-clean.sh webhook-tracker-filter --submit`: **PASS** ·
  `tools/check-geoxyz-branch.sh`: **PASS**
- Screenshots: **19**, gelezen: **ja**. De hele G9-run is op 2026-09-05 opnieuw
  gedaan tegen r25037, before én after, plus twee nieuwe voor/na-paren: de
  verzonnen tracker-id, en de verwijderde tracker (kolom Actief van `Yes` naar
  `No`).

## Wat Jan nog moet doen

Maak een **nieuw** issue op redmine.org aan als follow-up van
[#29664](https://www.redmine.org/issues/29664) — dus niet als note aan #29664
zelf, dat issue is gesloten met target version 7.0.0. Hang er
`patches/webhook-tracker-filter/2026-09-05-r25037-feature.patch` (code +
`en.yml`) en `-locales.patch` (`nl`, `fr`, `de`, `es`) aan. Draai vlak daarvoor
`tools/check-patch-clean.sh webhook-tracker-filter --submit`; is trunk intussen
verder gelopen, dan ververst een sessie de patch eerst (g05). De Engelse
issuetekst staat kant-en-klaar in `dossier.md` vanaf "The problem".

Zeg in de beschrijving expliciet dat dit **note 37 van Holger Just op #29664
beantwoordt**: hij vroeg om de monolithische 5.1-patch op te splitsen in losse
patches, elk met de reden erbij, en gerebaseerd op de huidige trunk. Dit is
punt 1 van je eigen note 36, los, tegen r25037, met de probleembeschrijving en
de afgewogen alternatieven erbij. Dat is het sterkste argument dat er is — een
committer heeft precies hierom gevraagd.

Drie dingen die het waard zijn om erbij te zetten omdat ze de patch verdedigen
vóórdat iemand ernaar vraagt:

- Leeg = alle trackers, dus geen enkele bestaande hook verandert van gedrag bij
  een upgrade. Er is een unittest die dat vastlegt en die **ongewijzigd groen
  staat op trunk**, plus een screenshot van een echte levering die het in een
  draaiende Redmine laat zien.
- De vertalingen zitten in een **apart** patchbestand. Zeg er expliciet bij dat
  een committer de feature-patch alleen kan aannemen en de vertalingen kan laten
  liggen als hij die liever van de taalteams krijgt — dan is er niets te
  herschrijven. Dat haalt het enige bezwaar weg dat de vier extra talen kunnen
  oproepen.
- De patch voegt `preload(:trackers)` toe zodat `hooks_for` niet één query per
  hook gaat doen. Noem #44386 erbij — daar haalde Marius Bălteanu een N+1 uit
  ditzelfde model, dus het is duidelijk dat het onderwerp leeft. r25011 zit in
  de basis van deze patch.

Er staat verder niets meer voor jou open: **K-11** is beslist — optie C, de
hook wordt gedeactiveerd als zijn laatste tracker verdwijnt.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **De hele webhookfunctie hoeft niet meer ingediend te worden.** Upstream heeft
  hem (#29664). Alleen het trackerfilter is nog nieuw. Ga dus niet op zoek naar
  de rest van `25220b45d` — het andere deel is de aparte feature
  `webhook-issue-closed`.
- **Leeg = alle trackers, en dat is geen keuze meer.** De 5.1-code eiste
  minstens één tracker zodra er een issue-event aanstond. Dat maakt elke
  bestaande hook ongeldig bij een upgrade en is upstream niet verdedigbaar. Zie
  `decisions.md`.
- **Een verwijderde tracker deactiveert de hooks waarvan hij de enige selectie
  was** (K-11 optie C, 2026-09-05). Niet opnieuw afwegen. Een hook met nog een
  andere tracker blijft gewoon actief, en een hook die nooit een tracker
  aanvinkte wordt niet aangeraakt. `update_column` en niet `update!`: de
  validaties van `Webhook` horen niet middenin een trackerverwijdering.
- **Het formulier biedt alle trackers** (`Tracker.sorted`), niet alleen die van
  de gekozen projecten, en ook niet `Tracker.visible(user)`. Zes bestaande
  Redmine-views doen het zo, `ProjectsController` geeft `Tracker.sorted.to_a`
  aan een scherm dat elke projectbeheerder bereikt, en het filter versmalt
  alleen — een tracker die je niet mag zien matcht simpelweg nooit. Staat nu ook
  als bezwaar-met-antwoord in het dossier (bevinding F08).
- **De webhooklijst krijgt met opzet geen Trackers-kolom.** Een lege cel leest
  daar als "geen trackers" terwijl hij "alle trackers" betekent, en #44337
  stelt voor die lijst helemaal te herbouwen. Als een reviewer erom vraagt is
  het twee regels.
- **Het Trackers-blok staat onvoorwaardelijk op het formulier**, ook op een hook
  zonder issue-events, waar het niets doet. Verbergen vraagt JavaScript;
  serverzijdig beslissen is verouderd tussen twee saves in. Afgewogen positie in
  de bezwarentabel (bevinding F07).
- **Een issue dat van tracker verandert, levert geen event meer op** voor een
  hook die op de oude tracker stond. Inherent aan een filter per object, het
  projectfilter doet hetzelfde, en repareren zou events sturen voor trackers die
  de beheerder juist uitsloot. Benoemd in het dossier, niet gerepareerd (Jans
  keuze g16f).
- **Alle vijf de talen krijgen de sleutel.** Jan koos op 2026-09-03 optie B van
  keuze **K-08**. Niet opnieuw afwegen. Elke term is herleid tot een bestaande
  sleutel in datzelfde locale-bestand; de tabel in `dossier.md` noemt per taal
  welke. Twee dingen om te weten: in het Spaans is een tracker een **tipo**,
  niet een "tracker", en in het Frans is sinds #44323 (`890812e49`) het hele
  webhookblok vertaald — de eerdere bewering dat `événements` in `fr.yml` niet
  herleid kon worden was onjuist en is ingetrokken (bevinding F03/F04).
- **Wijzig `create_hook` in de testbestanden niet.** Dat is geprobeerd: de
  helper een `trackers:`-argument geven liet 17 bestaande tests op trunk erroren
  en verstopte daarmee het rood-bewijs. De nieuwe tests zetten trackers met
  `hook.update!`.
- **De ontvanger in `verify/webhook-tracker-filter.mjs` bindt op `192.0.2.2`,
  niet op loopback.** `WebhookEndpointValidator` weigert loopback en link-local
  onvoorwaardelijk, dus een `127.0.0.1`-URL is nooit op te slaan als webhook.
- **De vijf codebestanden van de patch zijn niet meer byte-identiek tussen
  `origin/master` en `7.0-stable-GEOxyz`** — trunk heeft #44386 (r25011) en
  7.0-stable niet, maar dat raakt `setable_projects`, niet deze feature. De
  diff die deze feature toevoegt is aan beide kanten letterlijk dezelfde;
  gecontroleerd bestand voor bestand.

## Gevonden, bewust niet gerepareerd (INV-1)

Drie bestaande trunk-defecten die tijdens dit werk boven kwamen. Ze horen in
een eigen bugrapport, niet in deze patch; melden is genoeg.

1. **Een verzonnen id in `webhook[project_ids][]` geeft een 500.**
   `hook.project_ids = [999999]` gooit `ActiveRecord::RecordNotFound`, en
   `ApplicationController` heeft daar geen globale rescue voor. Opnieuw gemeten
   op 2026-09-05: nog steeds zo. `tracker_ids` erfde die eigenschap; sinds Jans
   keuze g16d is die kant wél dichtgezet, dus de twee velden verschillen nu
   totdat het trunk-defect gerepareerd is. Dat staat als zodanig in het dossier.
2. **`webhook_event_created` / `_updated` / `_deleted` staan in `de.yml` nog
   onvertaald** als `"%{object_name} created"`.
3. **`object_name` wordt niet gelokaliseerd.** `_form.html.erb` geeft
   `:object_name => type.to_s.humanize` door — een Engelse klassenaam. De
   legenda erboven gebruikt wél `l(:"label_#{type}_plural")`. Zichtbaar in
   `shots/webhook-form-de.png` (fieldset `Tickets`, vinkje `Issue created`) en
   in `shots/webhook-form-fr.png` (fieldset `Demandes`, vinkje
   `Création de issue`).

## Volgende stap voor een sessie

Af — niets te doen. Wachten tot Jan het issue heeft aangemaakt; vul dan het
`issue:`-veld in de front matter en de "Submission"-sectie van `dossier.md` in.
