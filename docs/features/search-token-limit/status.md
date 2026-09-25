---
slug: search-token-limit
feature: Tekstfilters negeren geen zoekwoorden meer na het vijfde
commit_51: 17528437d
geoxyz: live
geoxyz_commit: 6695461bd + 1cd7091fd
upstream: patch klaar
patch: patches/search-token-limit/2026-09-05-r25037-feature.patch
issue: "43701"
---

# search-token-limit — status

## Go MAEDA reageerde, en er ligt een tegenvoorstel (2026-09-25)

**Op [#43701](https://www.redmine.org/issues/43701) heeft Go MAEDA geantwoord.**
Hij is het eens dat stil zoekwoorden weglaten een probleem is, maar wil de
limiet houden "to prevent costly database queries", en heeft
[#44464](https://www.redmine.org/issues/44464) ingediend: limiet blijft 5, maar
er verschijnt een waarschuwing die zegt welke termen gebruikt zijn. Die staat al
op *Candidate for next major release*.

**Hij reageert op de patch van januari, niet op de onze.** De enige bijlage op
#43701 is Jans 5.1-patch van 2026-01-21, die de limiet instelbaar maakte met
0 = onbeperkt — ook voor de globale zoekfunctie. Onze herontworpen patch (limiet
blijft 5 in de `Fetcher`, alleen de tekstfilters worden onbeperkt) is daar nooit
geplaatst.

**Zijn patch conflicteert met de onze.** Nagegaan op trunk `e3962939c`: zijn
patch applyt schoon, de onze ook, maar de onze applyt **niet** meer bovenop de
zijne — `lib/redmine/search.rb` en `test/unit/lib/redmine/search_test.rb` botsen
allebei. Landt #44464 eerst, dan moet onze patch herwerkt worden.

**En er is nu een meting, want geen van beide kanten had er een.** Zie
`bench/README.md` in deze map, met de scripts erbij. Kort: de globale
zoekfunctie wordt van 1 naar 50 tokens niet meetbaar duurder (729-850 ms op
50 000 issues), een filter met *selectieve* termen wordt goedkoper naarmate er
termen bij komen (443 ms bij één, 208 ms bij twintig), en er is één echt
slecht geval — `contains` met termen die in élke rij staan, 375 ms bij één term
en 6 808 ms bij twintig. Dat laatste geeft Go MAEDA voor een deel gelijk, en dat
hoort in de note te staan.

## Waar het staat

Ronde 3 (blinde herreview, 2026-09-08) is gedaan: **nul bevindingen over de
code**, en één vraag die van Jan was. **Jan koos op 2026-09-09 optie A** (K-18):
inzenden zoals hij is, met de meettabel in de note en het argument dat een grens
op gebruikersinvoer in `Query#validate_query_filters` hoort en dus een eigen
issue is. Er is dus niets aan de code veranderd en alle bewijscijfers hieronder
gelden onverkort. Gaat een committer er toch op staan, dan is het antwoord optie
B (de controle in de validatie) en niet C — zie K-18.

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

- **Waar een grens op filtertokens hoort is beargumenteerd, niet vergeten**
  (ronde 3, Q01 → K-18). In `Query#validate_query_filters`, waar hij élke
  operator en élk filter dekt en de vraag **weigert** in plaats van hem stil af
  te kappen. Niet oplossen door de grens terug in de tokenizer te zetten, en ook
  niet door alleen de `OR`-tak van `tokenized_like_conditions` te begrenzen:
  beide kappen stil af, en dat is precies het defect dat deze patch repareert.
  De keuze of de grens *in deze patch* mee moet, is K-18 en is beslist: nee,
  optie A, inzenden zoals hij is.

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

Af — niets te doen aan de code, en K-18 is beslist (optie A). Wat openstaat is
Jans handeling hierboven. Deze patch applyt nog schoon op de **echte** trunk
`8de368193` (2026-09-09), niet alleen op de mirror — zie K-19.
