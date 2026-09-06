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
- **Beslist (autonoom, 2026-09-06):** de regexp krijgt de `i`-vlag én een
  prefix van echte DNS-labels:
  `/[a-z0-9-]+(?:\.[a-z0-9-]+)*\.geoxyz\.eu/i`. De vlag hoort op het patroon
  zelf, want `sanitize_regexp` voegt er geen toe (reviewbevinding F01); de
  strengere prefix sluit reviewbevinding F02 mee af omdat de regel toch al
  aangeraakt werd. Wat het patroon toelaat is precies wat Rails' eigen
  geblokkeerde-hostpagina als eis noemt: "valid hostnames (containing only
  numbers, letters, dashes and dots)". Nagemeten via
  `ActionDispatch::HostAuthorization::Permissions#allows?` én tegen een
  draaiende server: `a.b.geoxyz.eu` en `a.b.c.geoxyz.eu` blijven werken, het
  apexdomein blijft geweigerd, en geen enkele host die eerder geweigerd werd
  wordt nu toegelaten.
- **Beslist (autonoom, 2026-09-06):** de regel blijft in
  `config/environments/development.rb` staan (reviewbevinding F03, bewust niet
  opgelost). `config/additional_environment.rb` wordt in **elke** omgeving
  geladen, dus daar aanhangen zet `HostAuthorization` in productie aan met
  alleen `*.geoxyz.eu` toegestaan — dat vraagt een expliciete
  `Rails.env.development?`-bewaking én haalt de instelling uit versiebeheer.
  `RAILS_DEVELOPMENT_HOSTS` loopt door `sanitize_string` en levert maar één
  subdomeinniveau. Een mergeconflict in dit bestand wordt dus opgelost door de
  regel te behouden, niet door de vraag te heropenen.
