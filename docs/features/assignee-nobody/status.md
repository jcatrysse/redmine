---
slug: assignee-nobody
feature: Niet-toegewezen combineerbaar met gekozen gebruikers in het toewijzingsfilter
commit_51: 9b03b74b2
geoxyz: live
geoxyz_commit: 9d28be94d + d8e0db501
upstream: patch klaar
patch: patches/assignee-nobody/2026-09-05-r25037-feature.patch
issue: "5535"
---

# assignee-nobody — status

## Waar het staat

Ronde 2 is af. De review van 2026-09-03 gaf negen bevindingen, waarvan één
echte fout in de code: het gevouwen NULL-fragment kwam zonder haakjes terug,
en `UserQuery#sql_for_is_member_of_group_field` plakt dat fragment achter een
`AND` binnen een `EXISTS`. De `OR` ontsnapte daar, waardoor het gebruikersfilter
"lid van groep" met de waarde `none` erbij *alle* gebruikers teruggaf in plaats
van de leden van die groep. Dat is gerepareerd door het fragment zelfstandig te
maken (haakjes), niet door die ene aanroeper te repareren — `sql_for_field`
heeft 31 aanroepers. Alle negen bevindingen hebben een `Resolution:`-regel.

De patchbranch is opnieuw op trunk r25037 gezet (g05), de bewijscijfers zijn
opnieuw gedraaid en alle screenshots zijn opnieuw gemaakt, met twee nieuwe:
hetzelfde gebruikersfilter vóór en ná de fix.

## Wat het doet

Je kunt in het filter "Toegewezen aan" nu `<< niemand >>` samen met echte
gebruikers kiezen, dus "van Jan, of van niemand" in één filter. Dat kon niet.

## Bewijs

- Volledige suite met patch: `test:all` in `/home/user/wt/patch-assignee-nobody` → **5990 runs, 31732 assertions, 27 failures, 2 errors, 92 skips**
- Volledige suite op schone trunk r25037: **5977 runs, 31706 assertions, 28 failures, 2 errors, 92 skips**, faalnamen identiek: ja, op één na, en die
  ene staat op **trunk** en niet bij ons: trunk faalt daarnaast op
  `IssuesSystemTest#test_change_watch_or_unwatch_icon_from_sidebar`
  (`expected "/my/page" to equal "/login"`, een inlograce in een Selenium-test).
  De 29 faalnamen met de patch zijn dus een echte deelverzameling van trunks 30.
  Het verschil in runs is 13 — precies de dertien nieuwe tests
- Volledige suite op `7.0-stable-GEOxyz`: `test:all` → **6102 runs, 32270 assertions, 0 failures, 0 errors, 39 skips** — helemaal groen
- RuboCop op de vier gewijzigde bestanden: 0 (baseline 0, gemeten op
  `origin/master` r25037). Op de GEOxyz-branch 1 (baseline 1): één
  `Style/DirectiveScope` op `query.rb`, die letterlijk zo in `origin/7.0-stable`
  staat en die trunk zelf al opgeruimd heeft — niet van ons, dus niet gefixt
  (INV-1)
- Rood op de oude code: de elf `nobody`-tests in `query_test.rb` geven op schone
  trunk 2 failures en 7 errors (twee poorttests slagen daar, want zonder de
  patch is er niets te vouwen); de twee in `user_query_test.rb` geven 2 errors.
  Per mutatie: haakjes eruit → 2 failures; beide poorten eruit → 2 failures;
  de huidige-waarde-helft van `ev` eruit → 2 failures; de journaal-helft eruit
  → 3 errors
- `tools/check-patch-clean.sh`: `test:all` in `/home/user/wt/patch-assignee-nobody` → **5990 runs, 31732 assertions, 27 failures, 2 errors, 92 skips**CLEAN · `tools/check-geoxyz-branch.sh`: PASS
- Screenshots: 17 (8 voor, 8 na, 1 regressie), gelezen: ja

## Wat Jan nog moet doen

Hang `patches/assignee-nobody/2026-09-05-r25037-feature.patch` als note aan
[#5535](https://www.redmine.org/issues/5535), met de uitleg dat de afhandeling
generiek in `Query#sql_for_field` zit en dat **alle zeven operatoren** gedekt
zijn in plaats van alleen `=`. Dat is het inhoudelijke verschil met de
bestaande patches: vier van die operatoren gaven daar een HTTP 500 op
PostgreSQL en `cf` gaf stil nul resultaten.

Draai vlak daarvoor `tools/check-patch-clean.sh assignee-nobody --submit`; is
trunk intussen verder gelopen, dan ververst een sessie de patch eerst (g05).

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
- De vijf identieke `before-*.png` zijn Redmine's generieke 500-pagina en dat
  hoort zo; ze bewijzen dat die URL's klappen en verder niets. Het dossier zegt
  dat nu ook.

## Volgende stap voor een sessie

Af — niets te doen. Alleen Jans handeling hierboven.
