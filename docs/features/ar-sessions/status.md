---
slug: ar-sessions
feature: Sessies in de database
commit_51: ea61e37e8 + c2fefd51c
geoxyz: live
geoxyz_commit: 95bbb9750
upstream: nooit
patch:
issue: 
---

# ar-sessions — status

## Waar het staat

Af. Staat op `7.0-stable-GEOxyz` als één commit: de migratie die de tabel
`sessions` aanmaakt, één regel in `config/application.rb` en één gemregel in de
`Gemfile`. Gaat nooit naar upstream, dus geen dossier en geen patch. Dit is de
enige van de vier alleen-GEOxyz-items die echt gedrag verandert, dus hij is ook
in een draaiende Redmine met een echte browser nagelopen.

## Wat het doet

Redmine bewaarde de sessie tot nu toe in de cookie zelf. Nu staat hij in de
tabel `sessions` en houdt de cookie alleen nog het sessie-id vast. Dat haalt de
4 KB-grens van een cookie weg, en het maakt een sessie serverseitig
intrekbaar: een rij verwijderen logt die gebruiker uit.

## Bewijs

- **Volledige suite op de werkelijke tip na de push** (`add935736`, dus mijn
  vier commits bovenop wat twee parallelle sessies er ondertussen op zetten),
  `test:all`: **6009 runs, 32020 assertions, 0 failures, 0 errors, 39 skips**.
  Dit is de boom die GEOxyz draait, en dus het getal dat telt.
- Volledige suite op mijn eigen stapel (bovenop `646008041`), eerste run:
  5986 runs, 31936 assertions, **1 failure**, 0 errors, 39 skips. Tweede run van
  exact dezelfde boom: 5986 runs, 31936 assertions, **0 failures**. Die ene
  failure was `StickyIssueHeaderSystemTest` — zie hieronder, hij is niet van
  deze wijziging.
- Volledige suite op de schone branchtip **zonder** deze commits
  (`redmine_test_base`, commit `646008041`, geen `sessions`-tabel):
  5986 runs, 31937 assertions, 0 failures, 0 errors, 39 skips. Faalnamen
  identiek aan mijn stapel: ja (beide leeg).
- RuboCop op de gewijzigde bestanden: 0 offences op 4 bestanden
  (`Gemfile`, `config/application.rb`, `config/environments/development.rb`,
  `db/migrate/20240929111106_add_sessions_table.rb`); baseline op dezelfde
  bestanden vóór de wijziging ook 0.
- `tools/check-geoxyz-branch.sh`: PASS (0 offences op 33 gewijzigde
  Ruby-bestanden van de hele branch)
- Screenshots: 1, gelezen: ja —
  `shots/logged-in-with-a-database-session.png`
- **Echt nagelopen in een draaiende Redmine** (`tools/dev-server.sh`,
  `verify/ar-sessions.mjs`, Chromium):
  - inloggen als `admin` werkt, "Mijn pagina" rendert normaal
  - de cookie `_redmine_session` is nu **32 tekens** (een kaal sessie-id) in
    plaats van een ondertekende payload, en houdt
    `sameSite=Lax path=/ httpOnly=true`
  - de bijhorende rij staat in de tabel en bevat
    `{"user_id"=>3, "tk"=>"...", "sudo_timestamp"=>..., "_csrf_token"=>"..."}`,
    en `User.find(3).login` is `admin`
  - het `session_id` in de **database** is de gehashte vorm
    (`2::<sha256>`), niet de cookiewaarde: wie de tabel leest heeft daarmee nog
    geen bruikbare cookie
  - bij het inloggen verdwijnt de anonieme rij en komt er een nieuwe bij — de
    sessie wordt dus vernieuwd (bescherming tegen session fixation)
- **De guard in de migratie is echt getest:** de regel `20240929111106` uit
  `schema_migrations` verwijderd en `db:migrate` opnieuw gedraaid met de tabel
  er nog in. De migratie loopt door `table_exists?`, eindigt schoon, en de zes
  bestaande sessierijen bleven staan.

### De ene failure, en waarom hij niet van ons is

`StickyIssueHeaderSystemTest#test_sticky_issue_header_appears_on_scroll`
verwacht na `window.scrollTo(0, 1000)` een zichtbare `#sticky-issue-header`.
Dat is een JavaScript-scrolltest zonder login. Losse run van datzelfde bestand:
`3 runs, 8 assertions, 0 failures`. De derde test in datzelfde bestand **logt
wel in** en stond in de volledige run groen — dus de sessieopslag werkt daar
juist aantoonbaar. Daarna drie keer groen: losse run, tweede volledige run op
dezelfde commit, en de volledige run op de schone branchtip zonder deze
commits. Het is een scroll-en-render-timing in Chromium. Hij staat nu ook in
`docs/traps.md` zodat de volgende sessie hem herkent.

## Wat Jan nog moet doen

**Twee dingen bij de deploy, en het eerste is niet optioneel.**

1. `bundle install` moet gedraaid worden vóór de eerste start: er staat een
   nieuwe gem in de `Gemfile` (`activerecord-session_store`). Zonder die gem
   start Redmine niet — Rails geeft dan letterlijk de melding dat
   `ActiveRecord::SessionStore` uit Rails is gehaald en een gem is.
2. `bin/rails db:migrate` maakt de tabel aan. Op de bestaande database van
   GEOxyz doet die migratie **niets**, want hij heeft hetzelfde nummer als op
   5.1 en staat daar dus al in `schema_migrations`.

En twee dingen om te weten:

- **Iedereen is één keer uitgelogd** na de deploy. De oude cookies zijn
  payloads, geen sessie-ids, dus ze worden niet herkend. Eén keer opnieuw
  inloggen, daarna nooit meer.
- **Zet `db:sessions:trim` in de cron.** De tabel groeit anders eindeloos; de
  taak komt uit de gem en gooit standaard alles ouder dan 30 dagen weg
  (`SESSION_DAYS_TRIM_THRESHOLD=<dagen>` om dat te wijzigen). De index op
  `updated_at` in de migratie bestaat precies daarvoor — dat is de reden dat hij
  er staat, niet netheid.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Gaat **nooit** naar upstream: sessies in de database is een
  deployment-keuze, geen core-feature. Redmine kiest bewust de cookie-store.
- **Het migratienummer `20240929111106` is met opzet lager dan alle andere
  7.0-migraties.** Verhoog het niet: de productiedatabase is op 5.1 al met dat
  nummer gemigreerd, dus de migratie wordt bij de upgrade overgeslagen. Met een
  nieuw nummer zou hij proberen een bestaande tabel aan te maken.
- **`:path` en `:same_site => :lax` moeten blijven staan.** De 5.1-commit liet
  ze vallen; dat is een regressie (CSRF-bescherming, en een installatie onder
  een sub-URI). Ze horen bij de **cookie**, niet bij de store, dus ze werken
  ongewijzigd — nagemeten.
- De gem hoort in de `Gemfile`, niet in een `Gemfile.local`: dat laatste is
  gitignored, en dan boot de branch niet uit een verse clone. Zie
  `decisions.md` voor de INV-6-verantwoording.
- Redmine's eigen sessiecontrole (`config.redmine_verify_sessions` en
  `User.verify_session_token`) staat hier los van: die gebruikt de tabel
  `tokens`, niet de Rack-sessie, en verandert niet mee.

## Volgende stap voor een sessie

af — niets te doen.
