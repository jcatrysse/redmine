---
slug: search-token-limit
feature: Tekstfilters negeren geen zoekwoorden meer na het vijfde
commit_51: 17528437d
geoxyz: live
geoxyz_commit: 1c85728aa + f260958c6
upstream: patch klaar
patch: patches/search-token-limit/2026-09-05-r25037-feature.patch
issue: "43701"
---

# search-token-limit — status

## Waar het staat

Af, en in ronde 2 herzien. Eén patchbestand tegen trunk r25037, dezelfde
wijziging op `7.0-stable-GEOxyz`, dossier compleet, alle negen reviewbevindingen
van 2026-09-03 afgehandeld. Het issue bestaat al:
[#43701](https://www.redmine.org/issues/43701). De patch die daar hangt is nog
niet vervangen door de onze.

## Wat het doet

Een tekstfilter op een issuelijst gooide alles na het vijfde woord stil weg,
door een hardcoded 5 in de zoekcode. Nu gebruikt een filter alle getypte
woorden — ook het filter "Any searchable text", dat via de zoekmachine loopt.
Het globale zoekvak rechtsboven houdt zijn grens van vijf, en de knop "Apply
issues filter" onder de zoekresultaten geeft precies die vijf woorden door,
zodat hij de lijst opent die bij het getal erboven hoort.

## Bewijs

- Volledige suite met patch: 5985 runs, 31725 assertions, 27 failures, 2 errors,
  92 skips
- Schone trunk r25037: 5977 runs, 31711 assertions, 27 failures, 2 errors,
  92 skips — dezelfde 29 faalnamen, `diff` leeg. Het verschil is precies de acht
  nieuwe tests (+8 runs, +14 assertions).
- Volledige suite op `7.0-stable-GEOxyz`: 6112 runs, 32304 assertions,
  0 failures, 0 errors, 39 skips
- RuboCop: 0 op de 8 gewijzigde Ruby-bestanden (baseline 0); op GEOxyz 0 op 7
  (baseline 0)
- Mutatie: de acht nieuwe tests op de oude code → 8 runs, 6 failures, 1 error;
  de achtste is de bewaker die vóór en na groen hoort te zijn
- Mutatie op schone trunk: de limiet er helemaal uit en zeven testbestanden
  draaien → 656 runs, 0 failures. Geen enkele bestaande test legt de vijf vast.
- `tools/check-patch-clean.sh --submit`: PASS · `tools/check-geoxyz-branch.sh`: PASS
- Screenshots: 16 in `shots/`, gelezen: ja, inclusief het regressiepaar bij de
  knop "Apply issues filter"
- Prestatiemeting (PostgreSQL 16.13, 50 000 issues): `*~` gaat van 0,184 s bij
  vijf woorden naar 10,930 s bij duizend; `~` blijft vlak (0,053 s → 0,123 s)

## Wat Jan nog moet doen

Hang `patches/search-token-limit/2026-09-05-r25037-feature.patch` als note aan
[#43701](https://www.redmine.org/issues/43701), met de uitleg dat de
instelling eruit is: dit is een bugfix geworden in plaats van een
functieverzoek, en het globale zoekvak houdt bewust zijn grens van vijf
woorden (jouw keuze K-04, optie A). Vermeld de oude bijlage als achterhaald.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- De trunk-check was hier beslissend op de *herkomst* van de constante, niet op
  het bestaan van de feature: r21238 was een refactor die het blok woordelijk
  verplaatste. Dat maakte er een fix van in plaats van een instelling.
- Geen instelling. Niet opnieuw wegen (K-04 is beslist).
- Het filter "Any searchable text" wordt wél gerepareerd (Jans keuze g08). De
  grens blijft de standaard van `Fetcher`; de aanroeper beslist. Niet opnieuw
  wegen.
- De knop "Apply issues filter" geeft de tokens van de zoekmachine door, niet de
  hele vraag. Alternatieven (de knop laten zoals hij was, of het filter weer
  afkappen) zijn afgewogen in `decisions.md`; het eerste laat een kapotte link
  staan, het tweede is de bug zelf.

## Volgende stap voor een sessie

Af — niets te doen. Alleen Jans handeling hierboven. Ronde 3 (blinde
herreview) kan hierop.
