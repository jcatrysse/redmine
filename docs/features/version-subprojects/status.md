---
slug: version-subprojects
feature: Doelversiefilter biedt ook de versies van de subprojecten in de query
commit_51: 89752a599
geoxyz: live
geoxyz_commit: 20ed9e2d1 + d157934c0
upstream: patch klaar
patch: patches/version-subprojects/2026-09-03-r24882-feature.patch
issue: "43534"
---

# version-subprojects — status

## Waar het staat

Af. Eén patchbestand tegen trunk r24882 (vijf bestanden, 175 regels), dezelfde
wijziging als `20ed9e2d1` + `d157934c0` op `7.0-stable-GEOxyz`, dossier
compleet, acht screenshots. Het issue bestaat en is van Jan zelf:
[#43534](https://www.redmine.org/issues/43534).

## Wat het doet

Een projectissuelijst toont standaard ook de issues van zijn subprojecten. Die
issues kunnen een doelversie hebben die van een subproject is en met niemand
gedeeld — de kolom "Doelversie" toont hem, maar het *filter* bood hem niet aan.
Nu wel, precies voor zover die subprojecten in de query zitten.

## Bewijs

- Volledige suite met patch: 5796 runs, 30701 assertions, 27 failures, 2 errors, 92 skips
- Schone trunk: 5790 runs, 30684 assertions, 27 failures, 2 errors, 92 skips —
  dezelfde 29 faalnamen, `diff` leeg
- Volledige suite op `7.0-stable-GEOxyz`: 5809 runs, 31001 assertions,
  0 failures, 0 errors, 39 skips
- RuboCop: 0 (baseline 0)
- Vier van de zes nieuwe tests rood bewezen op de oude code; twee zijn
  bewakers, en de belangrijkste daarvan is rood op het afgewezen alternatief
- `tools/check-patch-clean.sh`: PASS · `tools/check-geoxyz-branch.sh`: PASS
- Screenshots: acht, gelezen: ja

## Wat Jan nog moet doen

Hang `patches/version-subprojects/2026-09-03-r24882-feature.patch` als note aan
je eigen issue [#43534](https://www.redmine.org/issues/43534), en schrijf erbij
dat `43534-v2.patch` van **Go MAEDA** een regressie bevat: het vervangt
`project.shared_versions` in plaats van er een vereniging van te maken,
waardoor versies die van buiten de projectboom gedeeld zijn stil uit het filter
verdwijnen — met Redmine's eigen fixtures gaat project 1 van zes naar vier
waarden. Noem de test die het vastlegt
(`test_fixed_version_filter_should_include_versions_shared_from_outside_the_project_tree`).
De Engelse tekst staat in `dossier.md` vanaf "The problem"; de voor/na-paren in
`shots/`.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Een kerncommitter heeft hier zelf aan gewerkt.** Go MAEDA hing op
  2026-04-01 `43534-v2.patch` aan het issue ("Updated the patch for the current
  trunk"). Dat is het sterkste signaal dat upstream de feature wil — en geen
  bewijs dat de implementatie klopt.
- De wijziging staat in `Query#fixed_version_values`, niet als override op
  `IssueQuery`: die methode is sinds r16170 (#24787) generiek, dus
  `TimeEntryQuery` krijgt hem gratis mee. Diezelfde commit verklaart ook waarom
  er een AJAX-endpoint bestaat.
- De JavaScript zoekt het formulier via `$('#filters-table').closest('form')`.
  Twee formulier-id's bestaan: `#query_form` op lijstpagina's en `#query-form`
  op `queries/new`/`queries/edit`. Niet terugvallen op een lijst id's.
- Een expliciet subprojectfilter overstemt de instelling
  `display_subprojects_issues` — nagemeten voor `=`, `!` en `*`.

## Volgende stap voor een sessie

Af — niets te doen. Alleen Jans handeling hierboven.
