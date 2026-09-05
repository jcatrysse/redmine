---
slug: version-subprojects
feature: Doelversiefilter biedt ook de versies van de subprojecten in de query
commit_51: 89752a599
geoxyz: live
geoxyz_commit: 20ed9e2d1 + d157934c0 + e2f060570
upstream: patch klaar
patch: patches/version-subprojects/2026-09-05-r25037-feature.patch
issue: "43534"
---

# version-subprojects — status

## Waar het staat

Ronde 2 is af. De patch is op 2026-09-05 opnieuw opgebouwd op trunk r25037
(`bee32a926`), alle twaalf reviewbevindingen hebben een `Resolution:`-regel, en
de GEOxyz-branch draait dezelfde wijziging. Eén patchbestand, vijf bestanden,
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
- Screenshots: tien, vijf paren voor/na, gelezen: ja. De verificatie draait ook
  op de GEOxyz-branch en faalt aantoonbaar op het afgewezen ontwerp (ze
  controleert dat `authenticity_token` niet in de URL staat).

## Wat Jan nog moet doen

Hang `patches/version-subprojects/2026-09-05-r25037-feature.patch` als note aan
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
