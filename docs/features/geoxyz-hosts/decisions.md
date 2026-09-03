# geoxyz-hosts — Class A-beslissingen

- **Beslist (autonoom, 2026-09-03):** de regexpvorm `/.*\.geoxyz\.eu/` blijft, niet
  Rails' stringvorm `".geoxyz.eu"`. Rails ankert een regexp zelf
  (`ActionDispatch::HostAuthorization::Permissions#sanitize_regexp` maakt er
  `/\A<regexp>(?::\d+)?\z/` van), dus het is géén substringmatch en
  `geoxyz.eu.attacker.com` wordt geweigerd — nagemeten. De stringvorm zou wél
  het apexdomein toelaten en tegelijk maar één subdomeinniveau
  (`SUBDOMAIN_REGEX` is `(?:[a-z0-9-]+\.)`), dus `a.b.geoxyz.eu` zou wegvallen.
  Dat is een gedragsverandering ten opzichte van wat GEOxyz op 5.1 draait.
- **Beslist (autonoom, 2026-09-03):** het commentaar `# Allow requests to
  *.geoxyz.eu` uit de 5.1-commit is niet meegekomen — het herhaalt de regel
  eronder (INV-3).
- **Beslist (autonoom, 2026-09-03):** de regel staat vóór het bestaande
  `config.after_initialize`-blok (Bullet) in plaats van onderaan het bestand,
  want onderaan staat sinds 7.0 dat blok.
