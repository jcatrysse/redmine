---
slug: asset-paths-gem-order
feature: gems in vendor/bundle achter de assetpaden van core (Chart.js van RedmineUP brak core-grafieken)
commit_51: -
geoxyz: live
geoxyz_commit: 6abebe886
upstream: nooit
patch:
issue:
---

# asset-paths-gem-order — status

## Waar het staat

Af aan GEOxyz-kant. Eén commit op `7.0-stable-GEOxyz` (`6abebe886`), de
gereviewde versie van `fix/asset-paths-gems-under-rails-root` (redmine_tags-sessie,
`3d0c1b2`) met één herschreven test en zonder AI-trailers. Geen upstream-patch:
Jans keuze core-q2 (2026-10-07) was optie A, niet B. Het onderzoek naar een
oplossing aan de RedmineUP-kant staat in het dossier: technisch kan het
(`config.assets.excluded_paths` in `config/additional_environment.rb`, getest),
maar het leeft dan in een gitignored bestand per server en dekt alleen redmineup.

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
- Screenshots: 3, gelezen: ja (met stand-in-gem, niet met de echte RedmineUP-plugin)

## Wat Jan nog moet doen

Na de deploy van `7.0-stable-GEOxyz` in productie `RAILS_ENV=production bundle exec rake assets:precompile`
draaien (anders blijft de oude `public/assets/chart.min-*.js` van redmineup
staan), en één keer een core-grafiek openen (Issues → Rapporten → Tracker) met
de RedmineUP-plugins erbij: grafieken zichtbaar, geen "Chart is not a constructor"
in de console. De branch `fix/asset-paths-gems-under-rails-root` is daarna overbodig
en mag weg.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Optie A, geen upstream-patch: Jans keuze core-q2, 2026-10-07.
- Oplossen in de gem zelf kan niet: er is geen nieuwere redmineup dan 1.1.13,
  en een bestand in de geïnstalleerde gem aanpassen overleeft `bundle install` niet.
- `excluded_paths` in `config/additional_environment.rb` werkt, maar is bewust
  niet gekozen (decisions.md); het blijft het gedocumenteerde terugvalpad.
- De echte RedmineUP-plugin starten in een sessie wordt door de veiligheidscheck
  van de omgeving geweigerd; G9 gebruikt daarom de stand-in-gem `asset_shadow_probe`
  (bron in het dossier beschreven).
- De tweede test is alleen rood zonder fix als de suite draait met de bundle in
  `vendor/bundle`; in de standaard-container staan de gems erbuiten.

## Volgende stap voor een sessie

af — niets te doen, tenzij Jans productiecontrole iets anders toont.
