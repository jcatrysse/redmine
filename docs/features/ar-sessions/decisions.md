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

## Ronde 2, 2026-09-05 — na Jans keuze g02

- **Beslist (autonoom, 2026-09-05):** de deploycontrole is een **rake-taak**
  (`redmine:sessions:check`) en geen psql-regel in de runbook. Reden: hij moet
  de dingen weten die alleen de applicatie weet — welke sessionstore
  geconfigureerd staat en welke tabelnaam die store gebruikt — en hij moet in de
  deploy als eigen stap kunnen falen met exit 1. Een psql-regel kan het eerste
  niet en moet het tweede hardcoderen.
- **Beslist (autonoom, 2026-09-05):** de logica staat in
  `lib/redmine/session_store_check.rb`; `lib/tasks/session_store.rake` roept één
  methode aan. Zelfde reden als bij `ldap-mail-prefs`: `.rubocop.yml` sluit
  `lib/tasks/**` uit en de suite kan een rake-bestand niet laden.
- **Beslist (autonoom, 2026-09-05):** de controle kijkt naar de **kolommen** van
  een index, niet naar zijn naam. Een database die vanaf 5.1 is meegekomen kan
  anders heten geïndexeerde kolommen hebben; wat de store nodig heeft is een
  unieke index op `session_id` en een index op `updated_at`, niet twee bepaalde
  namen.
- **Beslist (autonoom, 2026-09-05):** de bewaartermijn is **7 dagen**, als
  `Redmine::SessionStoreCheck::TRIM_DAYS`. De gem-standaard van 30 dagen is voor
  Redmine te ruim, want er komt een rij bij per **paginaweergave** en niet per
  login: 100 anonieme GETs op `/login` gaven 100 rijen in vijf seconden
  (gemeten in de review). Zeven dagen begrenst de tabel op ongeveer een week
  paginaweergaves, en een gebruiker die binnen die week terugkomt merkt er
  niets van, want elke request zet `updated_at` opnieuw.
- **Beslist (autonoom, 2026-09-05):** `secure_session_only => true`. Dit is de
  enige regel die voorkomt dat een rij met een sessie-id in leesbare vorm — wat
  een database die van 5.1 komt kan bevatten — een werkend inlogkoekje is voor
  iedereen die de tabel of een back-up kan lezen. Kosten: zulke rijen worden
  geweigerd, dus die gebruikers loggen één keer opnieuw in. Dat is dezelfde
  eenmalige logout die de deploy sowieso al aankondigde.
- **Beslist (autonoom, 2026-09-05):** de **serializer blijft Marshal**.
  `:json` en `:hybrid` zijn hier niet gratis: `app/helpers/queries_helper.rb`
  bewaart `session[:issue_query]` als een hash met **symboolsleutels** en leest
  hem ook zo terug (`session[session_key][:filters]`). Een JSON-rondgang geeft
  stringsleutels terug, dus het onthouden filter op de issuelijst zou stilletjes
  stoppen met werken. Een aanval die databaseschrijfrechten vereist wegnemen
  door een functie te breken die elke gebruiker gebruikt, is de verkeerde ruil.
- **Beslist (autonoom, 2026-09-05):** de migratie weigert een rollback
  (`down` gooit `ActiveRecord::IrreversibleMigration`) in plaats van hem te
  laten slagen. De tabel droppen logt iedereen uit en vernietigt elke levende
  sessie; dat mag geen bijeffect van een routineuze `db:rollback` zijn.
- **Beslist (autonoom, 2026-09-05):** de controle op `secure_session_only`
  staat **niet** in de deploytaak. Het kan niet betrouwbaar: de store haalt de
  optie met `options.delete` uit `Rails.application.config.session_options`
  zodra de middleware-stack gebouwd wordt, dus na het opstarten is de sleutel
  weg en zou een controle erop altijd "uit" melden. Het gedrag is in plaats
  daarvan vastgelegd in
  `test/integration/session_store_test.rb`, wat sterker bewijs is dan een
  configuratielezing.
