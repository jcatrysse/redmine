---
slug: assignee-nobody
feature: Niet-toegewezen combineerbaar met gekozen gebruikers in het toewijzingsfilter
commit_51: 9b03b74b2
geoxyz: live
geoxyz_commit: 9d28be94d
upstream: patch klaar
patch: patches/assignee-nobody/2026-09-02-r24882-feature.patch
issue: "5535"
---

# assignee-nobody — status

## Waar het staat

Af. Eén patchbestand tegen trunk r24882, dezelfde wijziging als commit
`9d28be94d` op `7.0-stable-GEOxyz`, dossier compleet. Het issue bestaat sinds
2010: [#5535](https://www.redmine.org/issues/5535). De patch die daar hangt is
nog niet vervangen door de onze.

## Wat het doet

Je kunt in het filter "Toegewezen aan" nu `<< niemand >>` samen met echte
gebruikers kiezen, dus "van Jan, of van niemand" in één filter. Dat kon niet.

## Bewijs

- Volledige suite met patch: 5798 runs, 30700 assertions, 27 failures, 2 errors, 92 skips
- Schone trunk: 5790 runs, 30686 assertions, 27 failures, 2 errors, 92 skips —
  dezelfde 29 faalnamen, `diff` leeg
- Volledige suite op `7.0-stable-GEOxyz`: 5803 runs, 30987 assertions,
  0 failures, 0 errors, 39 skips
- RuboCop: 0 (baseline 0)
- Rood op de oude code: negen nieuwe tests → 9 runs, 3 failures, 6 errors
- `tools/check-patch-clean.sh`: PASS · `tools/check-geoxyz-branch.sh`: PASS
- Screenshots: zeven gevallen, gelezen: ja

## Wat Jan nog moet doen

Hang `patches/assignee-nobody/2026-09-02-r24882-feature.patch` als note aan
[#5535](https://www.redmine.org/issues/5535), met de uitleg dat de afhandeling
generiek in `Query#sql_for_field` zit en dat **alle zeven operatoren** gedekt
zijn in plaats van alleen `=`. Dat is het inhoudelijke verschil met de
bestaande patches: vier van die operatoren gaven daar een HTTP 500 op
PostgreSQL en `cf` gaf stil nul resultaten.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- De 5.1-aanpak zette een pseudo-waarde in de generieke
  `Query#assigned_to_values` en behandelde die in een `elsif` in
  `Query#statement`, alleen voor operator `=`. Bij `!`, `ev`, `!ev` en `cf`
  belandde de string `'none'` in een vergelijking met een integerkolom → 500.
- `<< niemand >>` komt **alleen** in het toewijzingsfilter, niet in
  "Doelversie" en "Categorie" (Jans keuze K-05, optie A). Het mechanisme is
  generiek, dus die twee zijn één regel per stuk als hij later toch wil — maar
  niet in deze patch.

## Volgende stap voor een sessie

Af — niets te doen. Alleen Jans handeling hierboven.
