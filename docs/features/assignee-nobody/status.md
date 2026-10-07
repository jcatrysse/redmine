---
slug: assignee-nobody
feature: Niet-toegewezen combineerbaar met gekozen gebruikers in het toewijzingsfilter
commit_51: 9b03b74b2
geoxyz: live
geoxyz_commit: 349fe1860 + 9ad87a11b + 5c2dcdd7a
upstream: patch klaar
patch: patches/assignee-nobody/2026-10-07-r25136-feature.patch
issue: "5535"
---

# assignee-nobody — status

## Waar het staat

Ronde 2026-10-07 is af (Jans keuze core-q1, optie A). De patch crashte met
`NoMethodError: undefined method 'include?' for nil` als een aanroeper
`sql_for_field` een filter zonder waarde gaf: de nieuwe `none`-poort las
`value` voordat de operator bekend was, terwijl trunk `nil` voor `*`, `!*`
en de andere waardeloze operatoren gewoon aanvaardt. Core zelf doet dat nooit
(`Query#statement` slaat een lege waarde over), `redmine_contacts_helpdesk`
wel: 9 testfouten en HTTP 500 in de helpdeskrapporten op `7.0-stable-GEOxyz`.
Gerepareerd met `Array(value)` in de poort, plus één test die `sql_for_field`
met `nil` aanroept en trunks SQL terugverwacht. Op beide kanten: de patch is in
zijn ene commit bijgewerkt en meteen herzet op trunk r25136; GEOxyz kreeg een
eigen commit `5c2dcdd7a`.

Daarvoor: ronde 2 loste de enige echte codefout van de review op (het gevouwen
NULL-fragment is zelfstandig, met haakjes), ronde 3, 4 en Codex vonden niets
meer in de code.

## Wat het doet

Je kunt in het filter "Toegewezen aan" nu `<< niemand >>` samen met echte
gebruikers kiezen, dus "van Jan, of van niemand" in één filter. Dat kon niet.

## Bewijs

- Volledige suite met patch (r25136): `test:all` in `/home/user/wt/patch-assignee-nobody` → **6114 runs, 32319 assertions, 27 failures, 2 errors, 82 skips**
- Volledige suite op schone trunk r25136: **6100 runs, 32296 assertions, 27 failures, 2 errors, 82 skips**, faalnamen identiek: **ja**, alle 29 (repository- en changesettests die `svn`/`hg`/`bzr`/`cvs` nodig hebben; die ontbreken in deze container). Verschil 14 runs = precies de 14 nieuwe tests
- Volledige suite op `7.0-stable-GEOxyz` (fix + upstream-merge, vóór de replay op twee commits van een andere sessie): `test:all` → **6189 runs, 32654 assertions, 0 failures, 0 errors, 28 skips** — helemaal groen. Op de uiteindelijke tip `5c2dcdd7a` nog eens `query_test`, `user_query_test`, `queries_controller_test` en `issues_controller_test` in één proces: **886 runs, 4371 assertions, 0 failures, 0 errors**
- RuboCop op de vier gewijzigde bestanden: 0 (baseline 0 op `origin/master` r25136). `check-geoxyz-branch.sh`: 8 offences op 67 bestanden, alle 8 al op upstreams eigen regels (baseline 8)
- Rood op de oude code: `test_sql_for_field_should_accept_nil_value_for_operators_without_values` geeft op de vorige patch (`d0243086d`, herzet op r25136) en op `7.0-stable-GEOxyz` vóór `5c2dcdd7a` precies de gemelde fout, `NoMethodError: undefined method 'include?' for nil`, en is groen op schone trunk r25136 — hij pint trunks contract vast. De eerdere mutatiecijfers (haakjes, poorten, de twee helften van `ev`) staan in het dossier en zijn door deze wijziging niet geraakt
- `tools/check-patch-clean.sh`: **PASS** · `tools/check-geoxyz-branch.sh`: **PASS** (op `origin/7.0-stable-GEOxyz` na de push, met de RuboCop-wrapper uit `docs/traps.md`) · `tools/check-symmetry.sh`: **PASS**
- Mirror: `origin/master` r25136 loopt **41 commits** achter op echte trunk r25215; geen raakt de vier bestanden, en het patchbestand applyt ook op r25215 (`git apply --check`). `--submit` faalt dus tot Jan synct (K-19)
- Screenshots: 17 (8 voor, 8 na op r25136, 1 regressie van 2026-09-05) plus `nil-value-runner.txt`, gelezen: ja

## Wat Jan nog moet doen

1. Sync de mirror (`docs/runbook.md`, K-19): `origin/master` staat 41 commits
   achter op trunk.
2. Draai `tools/check-patch-clean.sh assignee-nobody --submit`.
3. Hang `patches/assignee-nobody/2026-10-07-r25136-feature.patch` als note aan
   [#5535](https://www.redmine.org/issues/5535), met de uitleg dat de
   afhandeling generiek in `Query#sql_for_field` zit en dat **alle zeven
   operatoren** gedekt zijn in plaats van alleen `=`. Vier van die operatoren
   gaven bij de bestaande patches een HTTP 500 op PostgreSQL en `cf` gaf stil
   nul resultaten.
4. Op productie: de helpdeskrapporten en de 9 tests van
   `redmine_contacts_helpdesk` opnieuw bekijken na het uitrollen van
   `5c2dcdd7a`. Die plugin zit niet in deze repo, dus dat is hier niet
   gedraaid.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- De 5.1-aanpak zette een pseudo-waarde in de generieke
  `Query#assigned_to_values` en behandelde die in een `elsif` in
  `Query#statement`, alleen voor operator `=`. Bij `!`, `ev`, `!ev` en `cf`
  belandde de string `'none'` in een vergelijking met een integerkolom → 500.
- `<< niemand >>` komt **alleen** in het toewijzingsfilter, niet in
  "Doelversie" en "Categorie" (Jans keuze K-05, optie A). Het mechanisme is
  generiek, dus die twee zijn één regel per stuk als hij later toch wil — maar
  niet in deze patch. Ronde 2 heeft daar één test bij gezet
  (`test_filter_fixed_version_nobody_or_version`) omdat het gedeelde codepad
  anders door één veld bewezen werd; dat is geen UI-wijziging.
- Het fragment dat `sql_for_field` teruggeeft is **zelfstandig**. Dat was een
  ongeschreven afspraak van Redmine zelf en staat nu als één regel boven de
  methode. Repareer een toekomstige variant hiervan nooit bij de aanroeper.
- `sql_for_field` moet `value = nil` blijven aanvaarden, zoals trunk: plugins
  roepen hem zo aan. De poort leest daarom `Array(value)`; geen vroege
  `return`, want die zou de operatortakken overslaan die trunk met `nil` gewoon
  afhandelt. De test roept de methode direct aan omdat geen kernpad `nil`
  doorgeeft.
- Een plugin-filter van type `list_optional` met de letterlijke waarde `none`
  verandert van betekenis; dat staat in het dossier als bewuste reservering
  (ronde 4, F01), niet als codewijziging.
- De vijf identieke `before-*.png` zijn Redmine's generieke 500-pagina en dat
  hoort zo; ze bewijzen dat die URL's klappen en verder niets. Het dossier zegt
  dat ook.
- De oude patchtip `d0243086d`, waar de bevindingen van ronde 3, 4 en Codex naar
  verwijzen, blijft oplosbaar als branch
  `archive/patch-assignee-nobody-r25037-before-nil-fix`.

## Volgende stap voor een sessie

Af — niets te doen. Alleen Jans handelingen hierboven.
