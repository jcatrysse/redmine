# ar-sessions — Class A-beslissingen

- **Beslist (autonoom, 2026-09-03):** het migratienummer blijft
  `20240929111106`, hetzelfde als op 5.1, ook al staat het vóór alle andere
  7.0-migraties. De productiedatabase van GEOxyz is op 5.1 gemigreerd, dus die
  regel staat al in `schema_migrations` en de migratie wordt bij de upgrade
  overgeslagen. Een nieuw, hoger nummer zou proberen een tabel te maken die er
  al is.
- **Beslist (autonoom, 2026-09-03):** `ActiveRecord::Migration[8.1]` in plaats
  van `[6.1]` uit 5.1 — gelijk aan de andere nieuwe migratie op deze branch
  (`20260903081500_create_trackers_webhooks.rb`).
- **Beslist (autonoom, 2026-09-03):** `return if table_exists?(:sessions)`
  blijft staan. `db/schema.rb` is gitignored, dus een database die uit een
  schemadump is opgezet kan de tabel hebben zonder de regel in
  `schema_migrations`.
- **Beslist (autonoom, 2026-09-03):** `:path` en `:same_site => :lax` blijven op
  `config.session_store` staan. De 5.1-commit liet ze beide vallen; dat is een
  echte regressie: `same_site` is CSRF-bescherming en `path` is nodig bij een
  installatie onder een sub-URI. Het zijn opties van de **cookie**, en de
  ActiveRecord-store zet nog steeds een cookie (met alleen het sessie-id erin),
  dus ze werken onveranderd — nagemeten in een echte browser:
  `sameSite=Lax path=/ httpOnly=true`, waarde 32 tekens.
- **Beslist (autonoom, 2026-09-03):** het uitgecommentarieerde
  `:cookie_store`-blok uit de 5.1-commit is niet meegekomen (INV-3). De
  wijziging is daardoor één regel in plaats van negen.
- **Beslist (autonoom, 2026-09-03, INV-6-verantwoording):**
  `gem 'activerecord-session_store', '~> 2.3.0'` staat in de **Gemfile**, niet in
  een `Gemfile.local`. `:active_record_store` zit niet in Rails core — Rails
  geeft er expliciet een foutmelding voor als de gem mist — en `Gemfile.local`
  is gitignored. Zonder de regel in de Gemfile boot deze branch dus niet uit een
  verse clone, wat op 5.1 ook zo was. De gem eist `activerecord >= 7.1` en
  `rack >= 2.0.8, < 4`; de branch pint Rails 8.1.3.1 en `rack >= 3.1.3`.
