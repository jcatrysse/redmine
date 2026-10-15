---
slug: asset-paths-gem-order
feature: gems in vendor/bundle achter de assetpaden van core (Chart.js van RedmineUP brak core-grafieken)
commit_51: -
geoxyz: live
geoxyz_commit: 6abebe886 + 1bf0ef69b + 1d8c2a3a7
upstream: patch klaar
patch: patches/asset-paths-gem-order/2026-10-15-r25254-feature.patch
issue:
---

# asset-paths-gem-order — status

## Waar het staat

Klaar om in te dienen; alleen het issue ontbreekt. Jan herzag op 2026-10-12 zijn
keuze van 2026-10-07: **keuze B, de code-fix terug op GEOxyz én als patch voor
redmine.org** (`docs/DECISIONS.md`, "asset-paths-gem-order herzien").

**Ververst op 2026-10-15 (g05)**, nadat Jan de mirror gesynchroniseerd had:
`origin/master` = echte trunk r25254 (`d1f69043e`, 0 commits verschil). De
patch staat op `patch/asset-paths-gem-order` (`cd89c516a`, op r25254; de oude
tip `bd0ce4c5b` op r25136 staat als
`archive/patch-asset-paths-gem-order-r25136-before-refresh`). Het patchbestand
is inhoudelijk ongewijzigd, alleen de `From`-sha verschilt.
`check-patch-clean.sh --submit`: **PASS**. Letterlijk dezelfde commit staat op
`7.0-stable-GEOxyz` (`1d8c2a3a7`, een cherry-pick bovenop de revert
`1bf0ef69b`); daar is bij deze refresh ook `origin/7.0-stable` ingemerged
(`b4f255f0a`, #44231 en #44579). Alle cijfers hieronder zijn op 2026-10-15
opnieuw gedraaid, de drie suites na elkaar.

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

Gemeten op 2026-10-15, trunk r25254, `7.0-stable-GEOxyz` `b4f255f0a`. Elke
worktree met `tmp/test/git_repository` uitgepakt, de drie volledige suites
serieel (patch, trunk, GEOxyz; elk ~17 minuten).

- Volledige suite met patch (`tools/test-env.sh … test:all`, r25254): `6244 runs, 32921 assertions, 28 failures, 2 errors, 87 skips`. Van de 30: 29 de bekende omgevingsfouten van de runbook (14 `RepositoriesControllerTest`, 8 `ApiTest::RepositoriesTest`, 5 `SysControllerTest`, 1 `UserTest`, 1 `ApiTest::IssuesTest`: `svn`/`hg`/`bzr`/`cvs` ontbreken hier); de dertigste, `IssuesSystemTest#test_update_issue_form_should_include_add_notes_form_only_for_users_with_permission`, is de inlogflake ("expected /my/page to equal /login" in `log_user`), groen bij herhaling
- Volledige suite op schone trunk r25254 (zelfde container, `test:all`): `6242 runs, 32914 assertions, 28 failures, 2 errors, 87 skips`. Faalnamen identiek: **ja, op de inlogflake na** — dezelfde 29 omgevingsfouten (`diff` leeg), en elk van beide runs één andere systeemtest met "expected /my/page to equal /login" (trunk: `IssuesSystemTest#test_update_journal_notes_with_preview`). De flake zat er dus ook nu de suites serieel liepen. Beide tests samen, op patch én trunk: `2 runs, 13 assertions, 0 failures, 0 errors`; het hele `test/system/issues_test.rb` op beide: `30 runs, 265 assertions, 0 failures, 0 errors`
- Verschil patch − trunk: 2 runs = precies de 2 nieuwe tests; 7 assertions = 2 (de nieuwe tests) + 9 (`test_update_journal_notes_with_preview`, op de patch volledig gedraaid) − 4 (`test_update_issue_form_should_include_add_notes_form_only_for_users_with_permission`, op trunk volledig gedraaid), elk los gemeten
- Volledige suite op `7.0-stable-GEOxyz` (`b4f255f0a`, met deze commit en de upstream-merge): `6270 runs, 32965 assertions, 0 failures, 0 errors, 29 skips` — helemaal groen
- Aangeraakte suite: `5 runs, 8 assertions, 0 failures, 0 errors, 0 skips` (trunk
  r25254 en GEOxyz); zonder de wijziging in `lib/redmine/asset_path.rb`:
  `5 runs, 7 assertions, 1 failures, 1 errors` — beide nieuwe tests rood
  (`NoMethodError` op `application_paths_first`, en "expected
  `vendor/javascript/chart.min.js`, actual … `shadow-1.0/…/chart.min.js`")
- RuboCop 1.91.0 (rubocop-rails 2.38.0, rubocop-performance 1.27.0) op de twee
  Ruby-bestanden, `--cache false`: 0 (baseline 0 op `origin/master` r25254);
  Rails-cops live bewezen met `Rails/Output` op een probe-bestand
- `tools/check-patch-clean.sh --submit`: **PASS** ("origin/master is current with
  https://github.com/redmine/redmine.git", applyt op r25254, patchbestand = branch,
  geen AI-identiteit) · `tools/check-geoxyz-branch.sh`: PASS (current met
  `origin/7.0-stable`, lint 8 = baseline 8, Rails-cops live; 69 eigen commits, alle
  geregistreerd) · `tools/check-symmetry.sh`: PASS
- Patch applyt op trunk r25254 (= `origin/master`): ja
- Upgradepad via #44240 (r25240, trunk-only): `rails runner` met de testfixture als
  gem-map binnen `Rails.root`. Manifest geschreven door trunk zonder patch:
  `chart.min.js` → `chart.min-0edf0213.js` (de gem), `needs_precompile?` `false`;
  mét patch tegen datzelfde manifest: `chart.min.js` → `vendor/javascript`,
  `chart.min-cae696ba.js`, `needs_precompile?` **`true`**; na herschrijven
  `false`. De automatische precompilatie bij het opstarten pakt de fix op trunk dus
  zelf op, één keer. Op `7.0-stable-GEOxyz` staat #44240 niet (daar nog de
  mtime-vergelijking), dus daar blijft de handmatige precompile nodig (stap 2
  hieronder)
- `assets:precompile` met de bundle in `vendor/bundle` en een gem met
  `chart.min.js` (r25136, 2026-10-12, niet opnieuw gedraaid): zonder patch is
  `chart.min-a89b27c8.js` het gem-bestand, met patch `chart.min-cae696ba.js` =
  Chart.js v4.5.1
- Standaardlayout (bundle buiten `Rails.root`), r25254: laadpad 13 paden,
  volgorde na `application_paths_first` identiek aan die van Propshaft — de patch
  verandert daar niets
- Screenshots: 5 (trunk before/after/nogem, GEOxyz before/after), gelezen: ja;
  genomen op r25136 (2026-10-12), niet opnieuw op r25254; met de stand-in-gem
  `asset_shadow_probe`, niet met de echte RedmineUP-plugin

## Wat Jan nog moet doen

1. **Een Defect aanmaken op redmine.org** met de Engelse tekst uit het dossier
   (vanaf "The problem") en `patches/asset-paths-gem-order/2026-10-15-r25254-feature.patch`
   erbij; relateren aan #44294 (zelfde symptoom). Het issuenummer daarna in
   `issue:` hierboven.
2. **Productie:** `7.0-stable-GEOxyz` deployen, `RAILS_ENV=production bundle exec rake
   assets:precompile`, herstarten, en Issues → Rapporten → Tracker openen met de
   RedmineUP-plugins erbij: grafieken zichtbaar, geen "Chart is not a
   constructor" in de console. Heeft een RedmineUP-plugin zelf grafieken, open
   er dan ook één: die horen ongewijzigd te werken (ze laden
   `plugin_assets/redmineup/chart.min.js`, niet het pad van de patch). Stond de serverregel `config.assets.excluded_paths`
   al in `config/additional_environment.rb`, dan mag die weg; laten staan kan
   ook, hij is naast de fix onschadelijk.
3. De branch `fix/asset-paths-gems-under-rails-root` op GitHub verwijderen
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
- **g05 is gedaan (2026-10-15, r25254).** Niet opnieuw verversen tenzij trunk
  verschoven is vóór het indienen: dan eerst de mirror syncen, en
  `tools/check-patch-clean.sh asset-paths-gem-order --submit` zegt of het nodig is.
  Dat #44240 de automatische precompilatie het werk laat doen, is gemeten en geen
  reden om het ontwerp te wijzigen.

## Volgende stap voor een sessie

Af — niets te doen tot Jan het issue aanmaakt; daarna `issue:` invullen en de
feedback verwerken.
