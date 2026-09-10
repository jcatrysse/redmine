---
slug: version-subprojects
feature: Doelversiefilter biedt ook de versies van de subprojecten in de query
commit_51: 89752a599
geoxyz: live
geoxyz_commit: fd35bd2d1 + 157c171a5 + 74f343d3d + 73157aee5 + 43246a900
upstream: patch klaar
patch: patches/version-subprojects/2026-09-10-r25037-feature.patch
issue: "43534"
---

# version-subprojects — status

## Waar het staat

**Ronde 4 vond een echte regressie en hij is dezelfde dag gefixt (2026-09-10).**
`QueriesController#filter` gaf sinds deze feature de `f`-, `op`- en
`v`-parameters van het verzoek door aan `Query#build_from_params`, en
`Query#add_filters` itereert die veldenlijst. Een verzoek met `f` als losse
waarde in plaats van een lijst gaf daardoor `NoMethodError` en een HTTP 500,
waar kale trunk op datzelfde endpoint 200 antwoordde en de parameter negeerde.
Gemeten aan beide kanten op dezelfde machine, met hetzelfde `Gemfile.lock` en
dezelfde fixtures:

```
GET /projects/1/queries/filter?name=fixed_version_id&f=subproject_id&op[subproject_id]==
  kale trunk r25037   -> HTTP 200
  patch 6ad109efe     -> NoMethodError: undefined method `each' for an instance of String
```

**Waarom dit wél onze fout was en niet die van trunk.** De crash in
`Query#add_filters` bestaat op trunk ook, en ronde 3 had hem gevonden en onder
INV-1 bewust laten liggen: die regel zit in een kernmethode waar deze feature
niets mee te maken had. Dat klopte tot het moment dat deze feature de enige
aanroep toevoegde die er onbewerkte verzoekparameters in stopt. De reparatie
zit dus in **onze eigen regel** en niet in `add_filters`: de veldenlijst wordt
alleen gebruikt als het echt een lijst is. Trunks bredere probleem blijft
onaangeroerd en is nog steeds een los issue waard.

De patchbranch is één commit gebleven: `6ad109efe` is vervangen door
**`0f0bd0a53`** met de guard en één extra test erin, de oude tip staat bewaard
als `archive/patch-version-subprojects-before-round4`, en het patchbestand is
opnieuw geëxporteerd als `2026-09-10-r25037-feature.patch`. Op
`7.0-stable-GEOxyz` staat dezelfde wijziging als **`43246a900`** (INV-10).

Ronde 2 is af. De patch is op 2026-09-05 opnieuw opgebouwd op trunk r25037
(`bee32a926`), alle reviewbevindingen hebben een `Resolution:`-regel, en de
GEOxyz-branch draait dezelfde wijziging — sinds `73157aee5` ook de vernauwing
uit de Codex-ronde, wat er tussen 2026-09-09 en die commit niet zo was; zie
"Bewijs — Codex-ronde 2" hieronder. `tools/check-symmetry.sh
version-subprojects` bewijst het nu per regel. Eén patchbestand, vijf bestanden,
124 regels. Het issue bestaat en is van Jan zelf:
[#43534](https://www.redmine.org/issues/43534).

## Wat het doet

Een projectissuelijst toont standaard ook de issues van zijn subprojecten. Die
issues kunnen een doelversie hebben die van een subproject is en met niemand
gedeeld — de kolom "Doelversie" toont hem, maar het *filter* bood hem niet aan.
Nu wel, precies voor zover die subprojecten in de query zitten.

## Wat er in ronde 2 veranderd is

Drie dingen aan de code, de rest aan de tekst.

1. **Het endpoint krijgt alleen nog de filterparameters.**
   `q.build_from_params(params)` werd `q.build_from_params(params.slice(:f, :op,
   :v))`. Dat lost drie bevindingen tegelijk op: het eigen `name`-argument van
   de actie kan geen `ProjectQuery`-filter meer worden (F06), `c=foo` als scalar
   geeft geen 500 meer (F09), en er komt niets in de query op wat er niet hoort.
2. **De JavaScript stuurt alleen de filterrijen.** Het hele formulier
   serialiseren zette op `queries/new` en `queries/edit` het
   `authenticity_token` van de sessie in een GET-URL, waar `production.log` en
   elke reverse proxy het opschrijven (F05). Gemeten op een draaiende instantie:
   665 tekens mét token, 134 tekens zonder.
3. **Drie tests erbij.** Eén die de lus sluit (een nieuw aangeboden versie geeft
   ook echt het subprojectissue terug, F08), één op `TimeEntryQuery` (de claim
   in het dossier had geen test, F08), en één die vastlegt dat `c` en `t` het
   endpoint niet meer bereiken (F09).

Aan de tekst: het regressiegetal is gecorrigeerd naar zes → **vijf** als
beheerder (F01, keuze g16g), de zichtbaarheidsvraag wordt eerlijk beantwoord in
plaats van met "nee" (F02), de restcase met `descendants`-sharing wordt benoemd
in plaats van weggelaten (F03), het kostenplaatje staat op de gemeten drie
statements in plaats van "één" (F04), de drie tests van Go MAEDA zijn als zodanig
gemarkeerd (F07), en de commitboodschap is één regel geworden zoals elke commit
op trunk (F11).

## Reviewronde 3 (2026-09-06), blind

Een verse sessie las de patch koud, zonder de bevindingen van ronde 1 te lezen.
**Eén bevinding, geen code-wijziging nodig**; ze staat dicht in
`docs/review/findings/2026-09-06-version-subprojects-claude-opus5-round3.md`.

- **F01 (minor, dossier)** — de bezwarentabel beweerde dat de `slice(:f, :op,
  :v)` voorkomt dat een losse waarde in plaats van een lijst een fout geeft. Dat
  klopt voor `c` en `t`, maar niet voor `f` zelf: `f=subproject_id` met een
  bijpassende `op` geeft `NoMethodError` en dus een 500. **Niet nieuw** — exact
  dezelfde aanvraag op `/issues?set_filter=1` geeft op onbewerkte trunk dezelfde
  fout, want daar loopt hetzelfde `Query#add_filters`. De tekst zegt nu precies
  waar de grens ligt: de slice haalt crashruimte weg die *nieuw* voor dit
  eindpunt zou zijn geweest, en verandert niets aan hoe `f` en `op` zich
  gedragen.

Wat die ronde verder deed is vooral **bevestigen**. Zes aanvalspogingen op de
patch: vijf kwamen schoon terug (geen SQL-injectie via de nieuw bereikbare
parameters, geen lek van versies uit een privé-subproject, rechtencontrole op de
goede plek, geen verbreding naar andere filters, geen verborgen N+1), en de
zesde stond al in het dossier. De twee getallen waar een committer als eerste
aan trekt zijn onafhankelijk nagemeten en kloppen: de volledige suite komt op
`5986 runs, 31733 assertions, 27 failures, 2 errors, 92 skips` — vijf cijfers
gelijk aan wat het dossier claimt — en per test klopt welke er rood staan op
onbewerkte trunk: dezelfde zes rood, dezelfde drie met opzet groen.

## Bewijs — ronde-4-fix (2026-09-10)

Gemeten op `0f0bd0a53`, trunk r25037 = `bee32a926`, RuboCop 1.90.0,
PostgreSQL 16, Ruby 3.3.6, beide kanten met een identiek `Gemfile.lock`.

- **Rood bewezen op de oude code, per mutatie:** met de guard weggehaald geeft
  `test_filter_should_ignore_a_filter_field_list_that_is_not_a_list`
  `1 runs, 0 assertions, 0 failures, 1 errors`; met de guard erin
  `1 runs, 2 assertions, 0 failures, 0 errors`. De test asserteert bewust
  alleen de statuscode en het mediatype en niet de JSON-inhoud, want
  `ActiveSupport::JSON.decode` valt in dit image om op de json-3.0.2-gem en
  dan is een echte crash niet te onderscheiden van de omgeving.
- Aangeraakte suites in één proces: **360 runs, 1138 assertions, 0 failures,
  15 errors** — één run meer dan vóór de fix, en alle vijftien errors zijn
  `ArgumentError: wrong number of arguments (given 2, expected 1)` uit
  `ActiveSupport::JSON.decode`; hetzelfde bestand heeft er elf op **kale**
  trunk r25037 in dit image.
- RuboCop op de twee gewijzigde bestanden: **0**.
- Op `7.0-stable-GEOxyz` (`43246a900`): dezelfde test groen
  (`1 runs, 2 assertions, 0 failures`), en RuboCop **2 offences op 2
  bestanden, baseline ook 2** — beide `Rails/StrongParametersExpect` op regels
  van upstream, niet van ons.
- `tools/check-patch-clean.sh version-subprojects --submit`: **PASS** tegen
  echte trunk r25065, inclusief de vergelijking tussen branch en patchbestand.
- `tools/check-symmetry.sh version-subprojects`: **PASS**.
- **Volledige suite op de patch (`0f0bd0a53`): 5989 runs, 31382 assertions,
  48 failures, 86 errors, 92 skips**, tegen **kale trunk r25037: 5977 runs,
  31346 assertions, 49 failures, 83 errors, 92 skips** — beide vandaag, beide
  met de Git-fixture uitgepakt en een identiek `Gemfile.lock`. Verschil in
  runs: **12**, precies de 12 tests die de patch toevoegt (5 + 7).
- **De absolute cijfers zijn hier 48/86 en niet 27/2, en dat is de json-gem.**
  r25037 ligt vóór trunks pin `9a74cdf20` (#44428), dus een verse `bundle
  install` trekt json 3.0.2 binnen en die breekt `ActiveSupport::JSON.decode`.
  Het treft beide kanten. Van de vier namen die alleen aan de patchkant falen
  zijn het **alle vier** eigen nieuwe endpointtests die JSON decoderen
  (`..._take_the_current_filters_into_account`,
  `..._not_offer_versions_of_a_project_outside_the_tree`,
  `..._still_offer_versions_of_an_archived_subproject_never`,
  `..._ignore_request_params_that_are_not_filters`); de twee namen die alleen
  op trunk falen zijn Selenium-systeemtests. **De nieuwe ronde-4-test staat er
  niet bij**, precies omdat die geen JSON decodeert. Op een machine met json
  2.x geeft dezelfde patch 27/2, zoals de meting van 2026-09-05 hieronder.
- **Volledige suite op `7.0-stable-GEOxyz` (`43246a900`): 6165 runs, 32522
  assertions, 0 failures, 0 errors, 39 skips** — helemaal groen, en precies
  één run meer dan de 6164 die dezelfde branchtip vandaag vóór deze commit gaf.
  Die ene run is de nieuwe test.
- `tools/check-geoxyz-branch.sh`: **PASS** nadat `43246a900` aan het
  `geoxyz_commit`-veld hierboven is toegevoegd; de gate weigerde eerst, precies
  waar K-21 hem voor gebouwd heeft.
- **Volledige suite op `7.0-stable-GEOxyz` ná de hele fixronde**, op tip
  `fd2365dc3` en gedraaid via `tools/test-env.sh` zodat de systeemtests echt
  starten: **6169 runs, 32534 assertions, 0 failures, 0 errors, 39 skips**. Dat
  is vier runs en twaalf assertions meer dan de 6165/32522 van vóór de
  fixronde — precies de vier tests die er vandaag bij kwamen (twee wiki-export,
  één imap, één webhook). `tools/check-geoxyz-branch.sh`: **PASS**, met de
  echte lintgetallen 8 op de tak en 8 op `origin/7.0-stable`.

## Bewijs

Gemeten 2026-09-05, trunk r25037 = `bee32a926`, RuboCop 1.90.0, PostgreSQL 16,
Ruby 3.3.6.

- Volledige suite mét systeemtests op de patch: 5986 runs, 31733 assertions,
  27 failures, 2 errors, 92 skips
- Schone trunk, zelfde commando: 5977 runs, 31710 assertions, 27 failures,
  2 errors, 92 skips — **dezelfde 29 namen**, `comm` leeg in beide richtingen
- Volledige suite op `7.0-stable-GEOxyz`: 6115 runs, 32313 assertions,
  0 failures, 0 errors, 39 skips
- RuboCop op de vier gewijzigde Ruby-bestanden: 0, baseline 0
- Van de negen nieuwe tests zijn er zeven rood bewezen op de oude code (zes op
  kale trunk, één op de eerste vorm van deze patch); de twee overige zijn
  bewakers, en de belangrijkste daarvan is rood op het afgewezen alternatief
- SQL: 5 statements tegen trunk's 2 voor één `fixed_version_values` (6 tegen 2
  bij de eerste aanroep in een proces)
- `tools/check-patch-clean.sh version-subprojects`: PASS ·
  `tools/check-geoxyz-branch.sh`: PASS
- **Ronde 3 heeft de twee belangrijkste cijfers onafhankelijk overgedaan** in
  een eigen worktree en ze kwamen exact uit: de volledige suite op de patch geeft
  dezelfde vijf getallen, en per test klopt welke er rood staan op onbewerkte
  code (zes rood, drie met opzet groen, precies de drie die het dossier bij naam
  als bewaker noemt). Ook het verlies van het afgewezen alternatief is
  nagemeten: zes items worden er vijf, en wat verdwijnt is
  `OnlineStore - Systemwide visible version`
- Screenshots: tien, vijf paren voor/na, gelezen: ja. De verificatie draait ook
  op de GEOxyz-branch en faalt aantoonbaar op het afgewezen ontwerp (ze
  controleert dat `authenticity_token` niet in de URL staat).

## Bewijs — Codex-ronde (2026-09-09)

**Wat de onafhankelijke review vond, en het is echt.** Het filter komt bij
`QueriesController#filter` rechtstreeks uit het verzoek, en `project_statement`
bouwt zijn `=`-tak als `[project.id] + values_for('subproject_id').map(&:to_i)`
zónder die ingestuurde ids te snijden met de subprojecten die hij één regel
eerder heeft uitgerekend. Een handgemaakt verzoek met het id van een
**ongerelateerd** project levert dus de versies van dat project. Geen datalek —
`Version.visible` blijft gelden — maar wel een fout antwoord.

**Waar de fix zit, en dat is de inhoudelijke keuze.** `project_statement` is
**onaangeraakte upstream-code**: onze diff op `query.rb` is alleen de drie
regels in `fixed_version_values`. Die methode wijzigen zou élke issuequery met
een subprojectfilter raken, en dat is een aparte wijziging met eigen tests en
eigen risico — INV-1 zegt dat de losheid van een upstream-regel van upstream is
en benoemd hoort te worden, niet meegenomen in een patch die er niet over gaat.
Dus is de **onze** aanroep vernauwd: `fixed_version_values` beperkt nu tot
`project.self_and_descendants` zonder gearchiveerde projecten, *naast*
`project_statement`. Daarmee is dit eindpunt correct los van wat
`project_statement` accepteert. `self_and_descendants` wordt in core al zo
gebruikt, en het is een subselect, geen tweede databaseronde.

**Wat er gemeld en niet gerepareerd is:** de losheid in `project_statement`
zelf. Die staat nu als objectie in het dossier, zo geformuleerd dat een
committer kan beslissen of hij dezelfde vernauwing daar ook wil — waar hij dan
ook de issuequery raakt, en dat is hun keuze.

**Cijfers:**

- **De test is rood zonder de fix**: een niet-gedeelde versie op project 2, en
  project 1's filtereindpunt opgevraagd met `v[subproject_id][]=2`, geeft die
  versie terug op de onaangepaste branch.
- Een tweede test eist dat de versie van een **gearchiveerd** subproject nooit
  aangeboden wordt. Die staat groen op **beide** kanten — `project_statement`
  sluit gearchiveerde projecten al uit — dus dat is een bewaker die bestaand
  gedrag vastlegt, geen bewijs.
- De 17 filtertests samen: **0 failures**. RuboCop op de vier gewijzigde
  bestanden: **0**.
- **Volledige suite met de patch**: **5988 runs, 31739 assertions, 27 failures,
  2 errors, 92 skips**. De 29 faalnamen zijn **exact dezelfde verzameling** als
  op de schone trunk-basislijn die vandaag gemeten is (`diff` leeg): de
  repository- en `sys`-tests van een image zonder `svn`, `hg`, `bzr` en `cvs`.
- `tools/check-patch-clean.sh version-subprojects --submit`: **PASS**, applyt op
  de huidige trunk r25063.

## Bewijs — Codex-ronde 2 (2026-09-09)

**De review had gelijk en de fout was van mij.** De vernauwing hierboven stond
alleen op `patch/version-subprojects`. Op `7.0-stable-GEOxyz` stond nog de
oude vereniging, terwijl dit bestand beweerde dat beide kanten dezelfde
wijziging droegen. Dat is INV-10, en het is de erge soort: niet een afwijking
die iemand afgewogen heeft, maar een claim die niet klopte. In dezelfde ronde
heb ik de `state`-fix van `imap-oauth` wél naar GEOxyz gebracht; deze vergat ik,
en het generieke `check-geoxyz-branch.sh` meldde PASS omdat het de branch keurt
en niet de gelijkheid per feature.

**Wat er nu staat:** GEOxyz-commit `73157aee5` met dezelfde drie regels en
dezelfde twee regressietests. Regel voor regel nagekeken: het enige wat in
`query.rb` en `queries_controller_test.rb` nog tussen de twee worktrees
verschilt, hoort bij `assignee-nobody`.

**En het is nu mechanisch te controleren.** `tools/check-symmetry.sh <slug>`
vergelijkt elke inhoudelijke regel van `patch/<slug>` met hetzelfde bestand op
`7.0-stable-GEOxyz`. Tegen de tip van vóór de fix (`f00b41afd`) meldt hij
**20 afwijkingen** voor deze slug; tegen de nieuwe tip `ok`. `--all` meldt PASS
voor alle negen patches.

**Cijfers:**

- **De test is opnieuw rood bewezen, nu op GEOxyz zelf**: zonder de fix zit
  `["OnlineStore - Unrelated project version", "9", "open"]` in de JSON van
  project 1's filtereindpunt. Met de fix niet.
- De archief-test staat op GEOxyz net als op trunk groen aan **beide** kanten,
  dus die is daar ook een bewaker en geen bewijs. Dat staat nu zo in het
  dossier in plaats van dat het geïmpliceerd wordt.
- `queries_controller_test.rb` op GEOxyz: **68 runs, 318 assertions,
  0 failures, 0 errors, 0 skips**.
- RuboCop op de vier gewijzigde bestanden op GEOxyz: **1**, baseline **1** —
  de bestaande `Style/DirectiveScope` op regel 1546, die van `assignee-nobody`
  is en van 7.0-stable's oudere RuboCop-vorm.
- **Volledige suite op de gemergde GEOxyz-tree** (`32659b6f7`, dus mét de vijf
  upstream-commits van `origin/7.0-stable` erin): **6164 runs, 32519 assertions,
  0 failures, 0 errors, 39 skips** in 857 s. Dat is met opzet na de merge
  gemeten en niet ervoor: het bewijs hoort bij de tree die gedeployt wordt.
- `tools/check-symmetry.sh version-subprojects`: **ok** ·
  `tools/check-geoxyz-branch.sh`: **PASS**, 0 commits achter ·
  `tools/check-patch-clean.sh version-subprojects`: **PASS**

## Wat Jan nog moet doen

Hang `patches/version-subprojects/2026-09-10-r25037-feature.patch` als note aan
je eigen issue [#43534](https://www.redmine.org/issues/43534). Volgens jouw
keuze **g16g** begint die note direct met de regressie: `43534-v2.patch` van
**Go MAEDA** vervangt `project.shared_versions` in plaats van er een vereniging
van te maken, waardoor versies die van buiten de projectboom gedeeld zijn stil
uit het filter verdwijnen. Het getal dat erbij hoort is **zes naar vijf** met
Redmine's eigen fixtures, gemeten als beheerder — versie 7 ("OnlineStore -
Systemwide visible version") verdwijnt. Noem de test die het vastlegt
(`test_fixed_version_filter_should_include_versions_shared_from_outside_the_project_tree`).

Neem er twee dingen bij op, allebei omdat Go MAEDA ze anders zelf vindt:

- drie van de negen tests zijn van hem en zijn onder hun eigen naam behouden
  (één ervan aangescherpt zodat hij met `display_subprojects_issues` uit draait);
- het filter heeft altijd al versienamen getoond van projecten die je niet mag
  zien, want `Project#shared_versions` kent geen rechtencontrole. Deze patch
  verandert dat niet; zijn vervanging verandert het als bijwerking. Dat is zijn
  sterkste tegenargument, dus het hoort in de note en niet in zijn antwoord.

**En één los issue, als je zin hebt** — het hoort niet bij deze patch en het
blokkeert niets. `Query#add_filters` crasht op een `f`-parameter die geen lijst
is: `/issues?set_filter=1&f=subproject_id&op[subproject_id]==` geeft op
onbewerkte trunk `NoMethodError: undefined method 'each' for an instance of
String`, en dus een 500. De reparatie is één regel (accepteer alleen een Array),
maar die regel zit in een kernmethode waar deze feature verder niets mee te
maken heeft, dus hij is er bewust uit gehouden (INV-1). Gevonden in ronde 3.

De Engelse tekst staat in `dossier.md` vanaf "The problem"; de voor/na-paren in
`shots/`.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Een kerncommitter heeft hier zelf aan gewerkt.** Go MAEDA hing op
  2026-04-01 `43534-v2.patch` aan het issue ("Updated the patch for the current
  trunk"). Dat is het sterkste signaal dat upstream de feature wil — en geen
  bewijs dat de implementatie klopt.
- De wijziging staat in `Query#fixed_version_values`, niet als override op
  `IssueQuery`: die methode is sinds r16170 (#24787) generiek, dus
  `TimeEntryQuery` krijgt hem gratis mee — en heeft er sinds ronde 2 ook een
  test voor.
- De JavaScript zoekt het formulier via `$('#filters-table').closest('form')`.
  Twee formulier-id's bestaan: `#query_form` op lijstpagina's en `#query-form`
  op `queries/new`/`queries/edit`. Niet terugvallen op een lijst id's.
- **Wél het formulier zoeken, niet het formulier versturen.** Alleen de velden
  `f[]`, `op[...]` en `v[...]` gaan mee. Dat is in ronde 2 vastgelegd en heeft
  een reden die je niet in een suite ziet: `queries/new` is een POST-formulier.
- Een expliciet subprojectfilter overstemt de instelling
  `display_subprojects_issues` — nagemeten voor `=`, `!` en `*`.
- **De restcase met `descendants`-sharing is bewust niet gedicht** (F03). Jan
  koos dat op 2026-09-05 (K-12, optie A); hij staat benoemd in het dossier onder
  "Proposed change" en in de objectietabel. Niet heropenen.

## Volgende stap voor een sessie

Af — niets te doen, behalve Jans handeling hierboven. Er staat geen keuze meer
open: K-12 is op 2026-09-05 beslist (optie A, benoemen).
