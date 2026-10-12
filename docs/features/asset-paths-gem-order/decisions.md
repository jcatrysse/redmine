# asset-paths-gem-order — beslissingen

- **2026-10-07, Class B (gelogd, Jan kan terugdraaien):** core-fix (optie A) in plaats van
  `config.assets.excluded_paths` voor redmineup in `config/additional_environment.rb`.
  Beide getest en werkend; de excluded_paths-variant leeft in een per server
  gitignored bestand buiten elke gate en dekt alleen redmineup. Zie dossier,
  "Onderzoek: oplossen aan de RedmineUP-kant".
- **2026-10-07, Class A:** `test_application_asset_paths_come_before_gem_asset_paths`
  herschreven: rekende de gem-classificatie zelf na (verboden constructie
  "test die de code herimplementeert"); roept nu `application_paths_first` aan
  en controleert een letterlijk pad.
- **2026-10-07, Class A:** de commit van `fix/asset-paths-gems-under-rails-root`
  niet overgenomen zoals hij was: hij droeg `Co-Authored-By` en `Claude-Session`
  (INV-4). Opnieuw gecommit met Jans identiteit en zonder trailers.
- **2026-10-07, Class A:** G9 met een zelfgeschreven stand-in-gem
  (`asset_shadow_probe`) omdat de omgeving weigerde Redmine met de echte
  RedmineUP-plugin te starten. De echte controle staat bij Jan in status.md.
- **2026-10-07, Class A:** `7.0-stable-GEOxyz` loopt 8 commits achter op
  `origin/7.0-stable`; niet meegemerged in deze feature (CLAUDE.md wil dat als
  aparte stap, en via `session-push.sh` zou een replay de merge vlakleggen).
- **2026-10-07 avond, Jan:** de serverregel, niet de code-fix (`docs/DECISIONS.md`).
  Hiermee vervalt de Class B-keuze hierboven.
- **2026-10-07 avond, Class A:** de stand-in-gem voor het bewijs van de serverregel
  heet `redmineup`, zodat het snippet letterlijk zoals in productie getest is.
- **2026-10-12, Jan:** keuze B herzien: ook een upstream-patch, en de code-fix terug op
  `7.0-stable-GEOxyz` in de vorm die upstream ingediend wordt (`docs/DECISIONS.md`,
  "asset-paths-gem-order herzien"). Hiermee vervallen de regels "optie A, geen
  upstream-patch" en "de serverregel" hierboven.
- **2026-10-12, Class A:** de sortering verhuist van een `after_initialize` in
  `config/application.rb` naar `Redmine::AssetLoadPath#initialize` (als
  `AssetLoadPath.application_paths_first`). Eén bestand code in plaats van twee, geen
  afhankelijkheid van de volgorde van Propshafts en Redmines eigen `after_initialize`
  (die in `30-redmine.rb` bouwt in productie het laadpad al op), en het is de klasse
  waarmee Redmine Propshafts laadpad al overneemt. Het oude ontwerp staat in het
  dossier onder "Alternatives considered".
- **2026-10-12, Class A:** de integratietest draait niet meer op de echte configuratie
  maar bouwt een `Redmine::AssetLoadPath` met een fixture-gem binnen `Rails.root` en
  een stub van `Bundler.bundle_path`. De oude test was alleen rood met de bundle in
  `vendor/bundle` en dus groen in CI, met en zonder fix.
- **2026-10-12, Class A:** tests in de `test "..." do`-vorm van het bestand zelf,
  niet `def test_...` zoals in `6abebe886`.
- **2026-10-12, Class A:** op `7.0-stable-GEOxyz` een nieuwe commit (cherry-pick van
  de patch-commit), geen revert van `1bf0ef69b`: het ontwerp is veranderd, en
  gepubliceerde historie herschrijven mag niet. `geoxyz_commit` noemt alle drie.
- **2026-10-12, Class A:** de twee serverregel-screenshots uit `shots/` gehaald; die
  aanpak is vervallen. Ze staan in de historie (`7d8b8e67c`).
