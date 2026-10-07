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
