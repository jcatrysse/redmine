---
slug: asset-paths-gem-order
feature: gems in vendor/bundle achter de assetpaden van core (Chart.js van RedmineUP brak core-grafieken)
commit_51: -
geoxyz: n.v.t.
geoxyz_commit: 6abebe886 + 1bf0ef69b
upstream: nooit
patch:
issue:
---

# asset-paths-gem-order — status

## Waar het staat

**Jan koos op 2026-10-07 (avond) de regel op de server, niet de code-fix**
(`docs/DECISIONS.md`, "Beslist (Jan) — K-24 en asset-paths-gem-order"). Dus:
`6abebe886` moet van `7.0-stable-GEOxyz` af met één revert-commit, en de
GEOxyz-kant wordt de regel `config.assets.excluded_paths` in
`config/additional_environment.rb` op de server.

**Die revert staat nog niet op de branch.** De sessie maakte hem
(`Revert "Assets: keep gems in vendor/bundle behind the application's asset
paths."`, als Jan, zonder trailers; de drie bestanden zijn daarna identiek aan
`origin/7.0-stable`), maar het pushen naar `7.0-stable-GEOxyz` werd door de
permissiecheck van de omgeving geweigerd, omdat de opdracht via een bericht van
een andere sessie kwam. Een lokale commit overleeft de container niet, dus het
commando staat hieronder bij Jan. Tot die revert er is, draait `7.0-stable-GEOxyz`
nog met de code-fix (`6abebe886`); de serverregel ernaast is onschadelijk.

De serverregel is bewezen in een echte Redmine (dev-modus) op de branch met de
revert, met een stand-in-gem die `redmineup` heet: zonder de regel "Chart is not
a constructor", met de regel Chart.js 4.5.1 en getekende grafieken. Het bewijs in
productiemodus (`RAILS_ENV=production`, precompile, server) werd door dezelfde
permissiecheck geweigerd als "Production Deploy" en is dus niet gedaan; de eerdere
precompile-meting gold de code-fix, niet de serverregel.

## Wat het doet

Met de gems in `vendor/bundle` binnen de Redmine-map wint een gem-asset van
een core-asset met dezelfde naam; redmineup's Chart.js 3 (`chart.min.js`) brak
zo elke core-grafiek ("Chart is not a constructor"). De commit zet na
Propshaft de paden van gems weer achter die van Redmine.

## Bewijs

- Volledige suite op `7.0-stable-GEOxyz` met de fix (oude basis `8067e231c`,
  bundle in `vendor/bundle`, `tools/test-env.sh ... test:all`):
  `6070 runs, 31745 assertions, 0 failures, 0 errors, 28 skips`
- Volledige suite op de gepushte kop `6abebe886` (na de 7.0-stable-merge van een
  andere sessie), zelfde opzet: `6076 runs, 31782 assertions, 0 failures, 0 errors, 28 skips`
- Aangeraakte suite: `5 runs, 9 assertions, 0 failures, 0 errors, 0 skips`;
  zonder de hook in `config/application.rb`: 1 failure (rood bewezen)
- RuboCop op de drie bestanden: 0 (baseline 0)
- `tools/check-patch-clean.sh`: n.v.t. (geen patch) · `tools/check-geoxyz-branch.sh`:
  **INCOMPLETE**, niet PASS: alle checks ok (geen AI-identiteit in 57 eigen commits,
  `6abebe886` geregistreerd, locales ok, merge actueel) behalve lint, omdat de
  probe van de gate zelf niet vuurt met rubocop-rails 2.34.3 (traps.md, 2026-10-07).
  Lint met de hand gemeten: 0 overtredingen op de drie bestanden, baseline 0,
  Rails-cops live bewezen met `params.require(...).permit(...)`
- `tools/check-symmetry.sh`: n.v.t. voor deze slug (geen patch-branch, GEOxyz-only);
  `--all`: 8 FAIL, alle van `assignee-nobody`/`version-subprojects` in `query.rb`
  (andere sessie, lopend werk), geen enkele in een bestand van deze feature
- `assets:precompile` productie: zonder fix wordt `chart.min.js` het gem-bestand,
  met fix Chart.js v4.5.1
- Screenshots: 5, gelezen: ja (met stand-in-gem, niet met de echte RedmineUP-plugin);
  de serverregel: `before-server-line-issue-report-chart.png` en `server-line-issue-report-chart.png`

## Wat Jan nog moet doen

1. ~~De revert op `7.0-stable-GEOxyz` zetten.~~ Gedaan op 2026-10-07 door de
   coördinerende sessie, op Jans uitdrukkelijke vraag: `1bf0ef69b` (revert van
   `6abebe886`, als Jan Catrysse, zonder trailers), gepusht met
   `tools/session-push.sh`; `geoxyz_commit` bijgewerkt (K-21) en het register
   opnieuw gegenereerd. GEOxyz draait deze feature dus niet als code: de
   serverregel hieronder is de oplossing.
2. Op de productieserver in `config/additional_environment.rb`:
   `if (spec = Gem.loaded_specs['redmineup'])` /
   `config.assets.excluded_paths += Dir[File.join(spec.full_gem_path, 'app/assets/*')]` /
   `end`; dan `RAILS_ENV=production bundle exec rake assets:precompile`, herstarten,
   en Issues → Rapporten → Tracker openen: grafieken zichtbaar, geen
   "Chart is not a constructor" in de console.
3. De branch `fix/asset-paths-gems-under-rails-root` op GitHub verwijderen
   (goedgekeurd; vanuit de sessies geweigerd).

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Optie A, geen upstream-patch: Jans keuze core-q2, 2026-10-07.
- Oplossen in de gem zelf kan niet: er is geen nieuwere redmineup dan 1.1.13,
  en een bestand in de geïnstalleerde gem aanpassen overleeft `bundle install` niet.
- Jan koos de serverregel (`excluded_paths` in `config/additional_environment.rb`)
  boven de code-fix, 2026-10-07 avond. Niet heropenen; de code-fix blijft in de
  git-historie (`6abebe886`) als iemand hem ooit terug wil.
- De echte RedmineUP-plugin starten in een sessie wordt door de veiligheidscheck
  van de omgeving geweigerd; G9 gebruikt daarom de stand-in-gem `asset_shadow_probe`
  (bron in het dossier beschreven).
- De tweede test is alleen rood zonder fix als de suite draait met de bundle in
  `vendor/bundle`; in de standaard-container staan de gems erbuiten.

## Volgende stap voor een sessie

Niets voor een sessie tot Jan stap 1 heeft gedaan; daarna alleen `geoxyz_commit` en het register bijwerken als hij dat niet zelf deed.
