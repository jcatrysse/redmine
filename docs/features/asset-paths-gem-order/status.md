---
slug: asset-paths-gem-order
feature: gems in vendor/bundle achter de assetpaden van core (Chart.js van RedmineUP brak core-grafieken)
commit_51: -
geoxyz: live
geoxyz_commit: 6abebe886 + 1bf0ef69b + 1d8c2a3a7
upstream: patch klaar
patch: patches/asset-paths-gem-order/2026-10-12-r25136-feature.patch
issue:
---

# asset-paths-gem-order — status

## Waar het staat

Af, op het issue na. Jan herzag op 2026-10-12 zijn keuze van 2026-10-07: **keuze
B, de code-fix terug op GEOxyz én als patch voor redmine.org**
(`docs/DECISIONS.md`, "asset-paths-gem-order herzien"). De patch staat op
`patch/asset-paths-gem-order` (`bd0ce4c5b`, van `origin/master` r25136) en
letterlijk dezelfde commit staat op `7.0-stable-GEOxyz` (`1d8c2a3a7`, een
cherry-pick bovenop de revert `1bf0ef69b`). Alle gates gedraaid, cijfers
hieronder. Wat `check-patch-clean.sh --submit` nog tegenhoudt is alleen de
mirror: `origin/master` loopt 51 commits achter echte trunk (K-19/K-20). Met de
hand nagegaan dat de patch op echte trunk r25227 applyt.

**Het ontwerp verschilt van `6abebe886`:** dezelfde sortering, maar in
`Redmine::AssetLoadPath#initialize` in plaats van een `after_initialize` in
`config/application.rb`, en een tweede test die ook in CI rood is zonder fix.
Waarom: `decisions.md` en het dossier, "Alternatives considered".

## Wat het doet

Met de gems in `vendor/bundle` binnen de Redmine-map (Bundler's
deployment-modus) wint een gem-asset van een core-asset met dezelfde naam;
redmineup's Chart.js 3 (`chart.min.js`) brak zo elke core-grafiek ("Chart is not
a constructor"). Redmine's eigen laadpad zet de paden van gems nu weer achter
die van Redmine.

## Bewijs

- Volledige suite met patch (`tools/test-env.sh … test:all`, r25136): `6102 runs, 32297 assertions, 28 failures, 2 errors, 82 skips`. Van de 30: 29 de bekende omgevingsfouten van de runbook (14 `RepositoriesControllerTest`, 8 `ApiTest::RepositoriesTest`, 5 `SysControllerTest`, 1 `UserTest`, 1 `ApiTest::IssuesTest`: `svn`/`hg`/`bzr`/`cvs` ontbreken hier); de dertigste, `ListAutofillSystemTest#test_textile_nested_list_autofill` ("expected /my/page to equal /login" in `log_user`, terwijl twee suites tegelijk liepen), is groen bij herhaling: `list_autofill_test.rb` → `15 runs, 55 assertions, 0 failures, 0 errors`
- Volledige suite op schone trunk r25136 (zelfde container, `test:all`): `6100 runs, 32266 assertions, 28 failures, 2 errors, 82 skips`, faalnamen identiek: **ja, op de inlogflake na** — dezelfde 29 omgevingsfouten (`diff` leeg), en elk van beide runs één andere systeemtest met "expected /my/page to equal /login" (trunk: `IssuesSystemTest#test_bulk_edit`, patch: `ListAutofillSystemTest#test_textile_nested_list_autofill`; bekend uit `traps.md`). Beide groen op de patch bij herhaling (`test_bulk_edit`: `1 runs, 32 assertions, 0 failures`). Verschil 2 runs = precies de 2 nieuwe tests
- Volledige suite op `7.0-stable-GEOxyz` (`1bf0ef69b` + deze commit): `6194 runs, 32667 assertions, 0 failures, 0 errors, 28 skips` — helemaal groen
- Aangeraakte suite: `5 runs, 8 assertions, 0 failures, 0 errors, 0 skips` (trunk
  en GEOxyz); zonder de wijziging in `lib/redmine/asset_path.rb`:
  `5 runs, 7 assertions, 1 failures, 1 errors` — beide nieuwe tests rood
- RuboCop 1.91.0 op de twee Ruby-bestanden, `--cache false`: 0 (baseline 0 op
  `origin/master`); Rails-cops live bewezen met `Rails/Output`
- `tools/check-patch-clean.sh`: PASS · `--submit`: FAIL, alleen omdat de mirror 51 commits achterloopt (K-20) ·
  `tools/check-geoxyz-branch.sh`: PASS (lint 8 = baseline 8, Rails-cops live; 62 eigen commits, alle geregistreerd) · `tools/check-symmetry.sh`: PASS
- Patch applyt op `origin/master` r25136: ja; op echte trunk r25227 (`git apply
  --check`, `patch -p1 --dry-run`): ja
- `assets:precompile` met de bundle in `vendor/bundle` en een gem met
  `chart.min.js`: zonder patch is `chart.min-a89b27c8.js` het gem-bestand, met
  patch `chart.min-cae696ba.js` = Chart.js v4.5.1
- Standaardlayout (bundle buiten `Rails.root`): laadpad 13 paden, volgorde
  identiek aan die van Propshaft — de patch verandert daar niets
- Screenshots: 5 (trunk before/after/nogem, GEOxyz before/after), gelezen: ja;
  met de stand-in-gem `asset_shadow_probe`, niet met de echte RedmineUP-plugin

## Wat Jan nog moet doen

1. **De mirror syncen** (51 commits achter, `docs/runbook.md`), dan
   `tools/check-patch-clean.sh asset-paths-gem-order --submit` en de cijfers
   opnieuw laten draaien (g05).
2. **Een Defect aanmaken op redmine.org** met de Engelse tekst uit het dossier
   (vanaf "The problem") en `patches/asset-paths-gem-order/2026-10-12-r25136-feature.patch`
   erbij; relateren aan #44294 (zelfde symptoom). Het issuenummer daarna in
   `issue:` hierboven.
3. **Productie:** `7.0-stable-GEOxyz` deployen, `RAILS_ENV=production bundle exec rake
   assets:precompile`, herstarten, en Issues → Rapporten → Tracker openen met de
   RedmineUP-plugins erbij: grafieken zichtbaar, geen "Chart is not a
   constructor" in de console. Heeft een RedmineUP-plugin zelf grafieken, open
   er dan ook één: die horen ongewijzigd te werken (ze laden
   `plugin_assets/redmineup/chart.min.js`, niet het pad van de patch). Stond de serverregel `config.assets.excluded_paths`
   al in `config/additional_environment.rb`, dan mag die weg; laten staan kan
   ook, hij is naast de fix onschadelijk.
4. De branch `fix/asset-paths-gems-under-rails-root` op GitHub verwijderen
   (goedgekeurd op 2026-10-07; vanuit de sessies geweigerd). Staat er nog.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Jans keuze B (2026-10-12):** upstream-patch én code-fix op GEOxyz. De eerdere
  keuzes "optie A, geen upstream-patch" (core-q2, 2026-10-07) en "de serverregel"
  (2026-10-07 avond) zijn daarmee vervallen; niet heropenen.
- De sortering hoort in `Redmine::AssetLoadPath#initialize`, niet in een
  `after_initialize` (Class A, 2026-10-12, `decisions.md`). Het oude ontwerp
  staat in `6abebe886` en in het dossier als verworpen alternatief.
- Oplossen in de gem zelf kan niet: er is geen nieuwere redmineup dan 1.1.13, en
  een bestand in de geïnstalleerde gem aanpassen overleeft `bundle install` niet.
- `config.assets.excluded_paths` werkt (getest 2026-10-07, screenshots in de
  historie op `7d8b8e67c`), maar per gem en per server; niet meer de oplossing.
- Propshaft `main` heeft dezelfde heuristiek (`start_with?(Rails.root.to_s)`);
  er is geen Propshaft-versie die dit oplost.
- De echte RedmineUP-plugin starten in een sessie wordt door de veiligheidscheck
  van de omgeving geweigerd; G9 gebruikt de stand-in-gem `asset_shadow_probe`
  (dossier, "Live verification").
- Met de bundle buiten `Rails.root` (deze container, CI, de officiële
  Docker-image) zie je de fout niet; `bundle config set --local path
  vendor/bundle` om hem te zien. De nieuwe tests hangen daar niet van af.

## Volgende stap voor een sessie

Af — niets te doen tot Jan het issue aanmaakt; daarna `issue:` invullen en de
feedback verwerken.
