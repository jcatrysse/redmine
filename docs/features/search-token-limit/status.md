---
slug: search-token-limit
feature: Tekstfilters negeren geen zoekwoorden meer na het vijfde
commit_51: 17528437d
geoxyz: live
geoxyz_commit: 1c85728aa
upstream: patch klaar
patch: patches/search-token-limit/2026-09-02-r24882-feature.patch
issue: "43701"
---

# search-token-limit — status

## Waar het staat

Af. Eén patchbestand tegen trunk r24882, dezelfde wijziging als commit
`1c85728aa` op `7.0-stable-GEOxyz`, dossier compleet. Het issue bestaat al:
[#43701](https://www.redmine.org/issues/43701). De patch die daar hangt is nog
niet vervangen door de onze.

## Wat het doet

Een tekstfilter op een issuelijst gooide alles na het vijfde woord stil weg,
door een hardcoded 5 in de zoekcode. Nu gebruikt een filter alle getypte
woorden. Het globale zoekvak rechtsboven houdt zijn grens van vijf.

## Bewijs

- Volledige suite met patch: 5924 runs, 31456 assertions, 27 failures, 2 errors, 92 skips
- Schone trunk r24882: 5920 runs, 31452 assertions, 27 failures, 2 errors,
  92 skips — dezelfde 29 faalnamen, `diff` leeg
- Volledige suite op `7.0-stable-GEOxyz`: 5925 runs, 31738 assertions,
  0 failures, 0 errors, 39 skips
- RuboCop: 0 (baseline 0)
- `tools/check-patch-clean.sh`: PASS · `tools/check-geoxyz-branch.sh`: PASS
- Screenshots: in `shots/`, gelezen: ja
- Bekende ruis in de bevestigingsrun: één `OauthProviderSystemTest`-error, een
  Chrome-driverrace terwijl twee volledige suites vier cores deelden. Niet van
  deze patch; staat zo in het dossier.

## Wat Jan nog moet doen

Hang `patches/search-token-limit/2026-09-02-r24882-feature.patch` als note aan
[#43701](https://www.redmine.org/issues/43701), met de uitleg dat de
instelling eruit is: dit is een bugfix van vier regels geworden in plaats van
een functieverzoek, en het globale zoekvak houdt bewust zijn grens van vijf
woorden (jouw keuze K-04, optie A).

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- De trunk-check was hier beslissend op de *herkomst* van de constante, niet op
  het bestaan van de feature: r21238 was een refactor die het blok woordelijk
  verplaatste. Dat maakte er een fix van in plaats van een instelling.
- Geen instelling. Niet opnieuw wegen (K-04 is beslist).

## Volgende stap voor een sessie

Af — niets te doen. Alleen Jans handeling hierboven.
