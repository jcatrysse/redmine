---
slug: ar-sessions
feature: Sessies in de database
commit_51: ea61e37e8 + c2fefd51c
geoxyz: live
geoxyz_commit: bc745ce73 + 22daa7c96
upstream: nooit
patch:
issue: 
---

# ar-sessions — status

## Waar het staat

Ronde 3 (blinde herreview, 2026-09-08) is gedaan en haar drie bevindingen zijn
op 2026-09-09 opgelost. De major was een echte en het is de belangrijkste van
deze hele ronde: **de sessiedata stond als Marshal in de database.** Elke
request deed dus `Marshal.load` over `sessions.data`, een kolom zonder
signature — bij de cookiestore die Redmine hiervoor had, was dat onmogelijk.
Nu is de serializer JSON. Daar zat één keuze aan vast, want elke bestaande
sessie wordt daarmee onleesbaar en iedereen wordt één keer uitgelogd: **Jan
koos op 2026-09-09 optie A** (K-17), wat is wat er staat. De uitlog is dus
geaccepteerd en hoeft niet opnieuw besproken te worden.

Ronde-2 fix is af. Alle twaalf reviewbevindingen van 2026-09-03 hebben een
`Resolution:`-regel: de blocker, de drie majors en de zes minors zijn opgelost,
de nit is gecorrigeerd en de vraag is beantwoord. Gaat nooit naar upstream, dus
geen dossier en geen patch.

Op `7.0-stable-GEOxyz` staan er voor deze feature drie commits: `95bbb9750`
(2026-09-03, de omschakeling zelf), `bc745ce73` (de ronde-2 fix) en
`22daa7c96` (de ronde-3 fixes, 2026-09-09). Het registerveld noemt de twee die
nog iets toevoegen. Geschiedenis wordt op deze branch niet
herschreven, want dat maakt elke checkout van GEOxyz ongeldig.

## Wat het doet

Redmine bewaarde de sessie in de cookie zelf. Nu staat hij in de tabel
`sessions` en houdt de cookie alleen nog een sessie-id vast. Dat haalt de
4 KB-grens weg en maakt een sessie serverseitig intrekbaar: een rij verwijderen
logt die gebruiker uit.

Nieuw in ronde 2: **`redmine:sessions:check`**, een deploystap die vaststelt dat
de tabel er is en de vorm heeft die de store nodig heeft, en die met exit 1
faalt als dat niet zo is. En de store weigert nu een sessie-id in leesbare vorm
(`secure_session_only`), zodat een oude rij geen werkend inlogkoekje meer is.

```
bundle exec rake db:migrate                          RAILS_ENV=production
bundle exec rake redmine:sessions:check              RAILS_ENV=production
# pas als die PASS geeft: verkeer naar de nieuwe code
```

## Bewijs

- **Volledige suite op `7.0-stable-GEOxyz`, systeemtests inbegrepen**
  (`tools/test-env.sh /home/user/wt/geoxyz bundle exec ruby bin/rails test:all`):
  **6084 runs, 32241 assertions, 0 failures, 0 errors, 39 skips**, exit 0.
  De run ervoor, op dezelfde boom zonder deze commit, gaf 6069 runs — het
  verschil is precies de vijftien nieuwe tests. De 39 skips zijn de SCM's die
  dit image niet heeft (svn, hg, bzr, cvs), de LDAP-tests en pandoc.
- De twee nieuwe testbestanden samen in één proces: 15 runs, 42 assertions,
  0 failures, 0 errors, 0 skips.
- **Mutaties, om te controleren dat die tests onderscheiden.** Geen enkele bleef
  groen:

  | Mutatie | Uitkomst |
  |---|---|
  | `config/application.rb` terug op `:cookie_store` | 2 failures + 2 errors in `session_store_test.rb` |
  | `:secure_session_only => true` weggehaald | 1 failure — het rijtje met leesbaar sessie-id geeft weer `200 OK` op `/my/account` |
  | de eis "uniek" van de index op `session_id` weggehaald | 1 failure |
  | de controle op de index op `updated_at` weggehaald | 1 failure |
  | de controle op een ontbrekende kolom weggehaald | 1 failure |
  | de controle `table_exists?` weggehaald | 2 failures |

- RuboCop op de gewijzigde bestanden: **0 offences op 5 bestanden** —
  `config/application.rb`, `db/migrate/20240929111106_add_sessions_table.rb`,
  `lib/redmine/session_store_check.rb`,
  `test/integration/session_store_test.rb` en
  `test/unit/lib/redmine/session_store_check_test.rb`. Baseline op de twee
  bestaande bestanden was ook 0; de drie andere zijn nieuw.
  `lib/tasks/session_store.rake` wordt niet geïnspecteerd, want `.rubocop.yml`
  sluit `lib/tasks/**` uit.
- `tools/check-geoxyz-branch.sh`: **PASS** — actueel met `origin/7.0-stable`,
  22 eigen commits, geen AI-sporen in de commitberichten, 0 lint-offences op
  53 gewijzigde Ruby-bestanden, locales binnen en/nl/fr/de/es.
- **De blocker is eerst gereproduceerd en daarna gevangen**, op de
  ontwikkeldatabase van een draaiende instance:

  ```
  $ psql -c 'drop table sessions;'                      DROP TABLE
  $ psql -tAc "select count(*) from schema_migrations
               where version='20240929111106';"         1
  $ bin/rails db:migrate                                (geen uitvoer, exit 0)
  $ GET /login in Chromium                              HTTP 500
  $ bin/rails redmine:sessions:check
    FAIL  the table 'sessions' does not exist, so every request would be a 500 - /login included
                                                        exit 1
  ```

- **De rollback weigert nu**, met een rij in de tabel:

  ```
  $ bin/rails db:migrate:down VERSION=20240929111106
    == 20240929111106 AddSessionsTable: reverting
    ActiveRecord::IrreversibleMigration               exit 1
  $ tabel, beide indexen en de rij staan er nog
  $ select count(*) from schema_migrations where version='20240929111106'   1
  ```

  En het `up`-pad is opnieuw gedraaid op een lege database: tabel plus
  `index_sessions_on_session_id` en `index_sessions_on_updated_at`.

- **De opruimtaak doet wat de controle voorspelt** (gemeten, dezelfde instance):

  ```
    rows                               4
    rows the first trim would delete   3
  $ SESSION_DAYS_TRIM_THRESHOLD=7 bin/rails db:sessions:trim
    rows                               1
  ```

- **G9, in een echte browser tegen een draaiende Redmine**
  (`verify/ar-sessions.mjs`, drie stappen):

  | Wat | Screenshot | Wat je ziet |
  |---|---|---|
  | `/login` zonder de tabel | `before-login-500-without-the-sessions-table.png` | de 500-pagina met `PG::UndefinedTable: relation "sessions" does not exist` |
  | dezelfde URL mét de tabel | `after-login-with-the-sessions-table.png` | ingelogd op `/my/account` |
  | ingelogd, rij aanwezig | `revoked-before-deleting-the-row.png` | **byte-identiek** aan de vorige (md5 `bc8cff4a…`) |
  | dezelfde pagina na `delete from sessions` | `revoked-after-deleting-the-row.png` | het inlogformulier — de sessie is serverseitig ingetrokken |

  De oude screenshot `logged-in-with-a-database-session.png` is verwijderd: hij
  zou er met de cookiestore precies zo uitzien en kon dus niet falen (F10).

- **De cookie en de rij, als tekst** (dezelfde run):

  ```
  cookie   bytes=32  sameSite=Lax  path=/  httpOnly=true  value=ea5b2a82b7468ae6bb216e75c0b281c9
  database session_id=2::10bb2045b8684f6cbe3780b897c697cc0c46291be00a534aa572d0834fd6e518
  cookie value stored verbatim? no
  ```

## Bewijs — ronde 3 (2026-09-09)

**Wat er veranderd is, in drie stukken:**

1. **F01 (major) — de serializer is JSON in plaats van Marshal.** Eén regel in
   `config/application.rb` plus `Redmine::SessionDataSerializer`, een klasje van
   vijf regels dat de JSON-serializer van de gem overneemt met één verschil: een
   rij die niet te parsen is wordt een lege sessie in plaats van een
   uitzondering. Zonder dat verschil geeft elke bestaande Marshal-rij na de
   deploy een **500** — dat is niet gereconstrueerd maar gemeten, zie hieronder.
   `:hybrid` van de gem is geen alternatief: die valt terug op `Marshal.load`
   voor elke waarde die met `BAh` begint.
2. **F02 (minor) — de controle rapporteert de periode die `db:sessions:trim`
   echt gebruikt.** Stond op de eigen constante `TRIM_DAYS = 7`, terwijl de taak
   van de gem alleen naar `SESSION_DAYS_TRIM_THRESHOLD` (standaard 30) kijkt. De
   twee klopten met elkaar bij toeval. De constante heet nu
   `RECOMMENDED_TRIM_DAYS`, er is een `trim period`-regel bij, en wijkt de
   omgeving af van de aanbevolen 7 dan zegt de uitvoer dat.
3. **F03 (nit) — geen code, wel opgeschreven** waarom `data` een `text` is en
   wat een MySQL-deployment zou moeten doen. Zie "wat er al bekend is".

**Waar de review naast zat, en dat is goed nieuws.** De bevinding beschrijft het
pad "beheerder → shell". Bij het naspelen bleek er nog een tweede slot te zitten
dat zij niet noemt: `ApplicationController#session_expired?` doet
`User.verify_session_token(session[:user_id], session[:tk])`, dus een
*verzonnen* sessie met alleen een `user_id` erin logt niemand in — dat is
uitgeprobeerd en het gaf een redirect naar `/login`. Dat verkleint het
inlog-scenario, maar **niet** het scenario dat de bevinding echt aanwijst: de
bytes worden gedeserialiseerd voordat er ook maar iets gecontroleerd wordt.

**Cijfers:**

- **Volledige suite op `7.0-stable-GEOxyz`, systeemtests inbegrepen**
  (`tools/test-env.sh /home/user/wt/geoxyz bundle exec ruby bin/rails test:all`):
  **6145 runs, 32428 assertions, 0 failures, 0 errors, 39 skips**, in 913 s.
  De run ervoor op dezelfde branch, met alleen de `ldap-mail-prefs`-fix erin,
  gaf **6138 runs** — het verschil is precies de zeven tests die hieronder
  staan. Nul failures en nul errors is hier het hele verhaal: er is geen
  basislijnvergelijking nodig om te zeggen dat de JSON-omschakeling niets
  gebroken heeft.
- **Vier nieuwe integratietests en drie nieuwe/gewijzigde unittests, eerst rood
  gedraaid.** Op de oude code: `session_store_test.rb` gaf `8 runs, 2 failures,
  1 error` — `test_session_data_should_not_be_marshalled` faalt met "session
  data is marshalled", `test_the_serializer_should_read_an_unparsable_row_as_an_empty_session`
  is een `NameError` (de klasse bestond niet), en
  `test_a_marshalled_session_row_should_log_the_user_out_rather_than_raise`
  faalt met **`200 OK`** — dat is precies het gat: de rij die ik zelf schreef,
  werd geaccepteerd. `session_store_check_test.rb` gaf `14 runs, 3 failures`.
  Met de fix: **8 runs, 51 assertions, 0 failures** en **14 runs, 25 assertions,
  0 failures**.
- **Eerlijk gelabeld:** twee van de nieuwe tests staan groen op *beide* kanten
  en zijn bewakers, geen bewijs —
  `test_a_query_should_survive_a_round_trip_through_the_stored_session` (die is
  er om te bewijzen dat JSON de queryopslag níét breekt) en
  `test_run_should_not_mention_the_period_when_it_is_the_recommended_one`.
- RuboCop 1.88.2 op de vijf gewijzigde bestanden: **0 offences**, baseline op de
  vier die al bestonden ook **0**.

**Het round-trip-risico is uitgezocht in plaats van beredeneerd.** De review
noemde `queries_helper.rb` als het gevaar: die zet een genest, symbol-keyed hash
in de sessie en leest hem met symbolen terug, en JSON kent geen symbolen. De
integratietest zet een filter met vier verschillende soorten waarden en haalt de
pagina daarna **zonder parameters** op, dus de query kan alleen uit de
sessierij komen. Elk van de vier heeft zijn eigen markering op de pagina:

| Sessiewaarde | Vorm | Markering die het bewijst |
|---|---|---|
| `filters` | hash van symbol-keyed hashes | `addFilter("assigned_to_id", "=", ["3"]);` in de uitvoer |
| `group_by` | string | `<option selected="selected" value="tracker">` |
| `column_names` | symbolen, strings na JSON | de koppen `# / Tracker / Subject / Assignee / Priority` |
| `sort` | array van arrays | `priority%3Adesc` in de sorteerlink van de kolom Tracker |

**G9, in een echte browser tegen een draaiende Redmine.** De twee eerste zijn
een paar: dezelfde bytes in dezelfde kolom, één keer op de branch zoals hij was
en één keer met de fix, met een herstart ertussen. Er is geen exploit gebouwd —
er staat een gemarshalde instantie van een klasse die de server níét definieert,
en alleen `Marshal.load` probeert die te bouwen:

| Wat | Screenshot | Wat je ziet |
|---|---|---|
| vóór de fix, gemanipuleerde rij | `before-marshal-load-runs-on-the-column.png` | **HTTP 500**, "Internal error". Het log zegt `ArgumentError (undefined class/module Redmine::OnlyMarshalWouldBuildThis)` — die fout komt alleen uit `Marshal.load`, dus de kolom is gedeserialiseerd |
| ná de fix, dezelfde rij | `after-marshal-load-is-gone.png` | **HTTP 200** op `/login`, een schone uitlog; niets probeert de bytes te lezen |
| ingelogd, sessie als JSON | `json-signed-in.png` | gewoon `/my/account`, niets aan te zien — en dat is het punt |
| filter gezet | `json-filter-applied.png` | Status open, Assignee any, gegroepeerd op Tracker |
| filter zonder parameters | `json-filter-from-session.png` | dezelfde pagina op de URL **zonder parameters**: filters, kolommen én de groepering komen terug uit de JSON-rij |
| Marshal-rij, uitlog i.p.v. 500 | `marshal-row-logs-out.png` | de rij overschreven met een Marshal-payload van een klasse die er wél is: redirect naar `/login` |

Het script is `verify/ar-sessions.mjs`, `STEP=serializer` met
`SHOT_PREFIX=before|after`.

**En één natuurlijk voor/na dat niemand hoefde te construeren:** in de
dev-database staan de rijen van vóór en van ná de omschakeling naast elkaar,
omdat de vorige G9-sessie op de oude code liep:

```
id=10 updated=06:09:57  first12="BAh7CUkiDHVz"   marshalled=true
id=11 updated=06:38:08  first12="{\"value\":{\"_"  marshalled=false
id=14 updated=06:38:22  first12="{\"value\":{\"u"  marshalled=false
```

## Wat Jan nog moet doen

**K-17 is beslist (optie A), dus er staat geen keuze meer open.** Eén ding om
te weten bij de deploy: **iedereen is daarna één keer uitgelogd**, omdat de
bestaande sessierijen als Marshal opgeslagen zijn en JSON die niet leest. Er is
niets aan te doen en het gebeurt precies één keer.

**Drie stappen bij de deploy, in deze volgorde, en daarna één cronregel.**

1. `bundle install` vóór de eerste start. Er staat een gem in de `Gemfile`
   (`activerecord-session_store`) en zonder die gem start Redmine niet. Wat
   Rails 8.1 dan zegt is niet de oude, expliciete melding maar
   `Unable to resolve session store :active_record_store` — het noemt de gem
   dus **niet**.
2. `bundle exec rake db:migrate RAILS_ENV=production`.
3. `bundle exec rake redmine:sessions:check RAILS_ENV=production`, **als eigen
   stap, vóór er verkeer op de nieuwe code komt.** Stap 2 kan deze controle
   niet zijn: op de database die het uitmaakt staat `20240929111106` al in
   `schema_migrations`, dus de migratie wordt overgeslagen zonder één regel
   uitvoer — en als de tabel er dan niet is, is elke pagina een 500, `/login`
   incluis. De controle faalt in dat geval met exit 1 en zegt waarom.

   Diezelfde controle drukt bij succes af wat je moet weten:

   ```
     database adapter                   PostgreSQL
     session size limit                 none (text)
     rows                               0
     trim period                        7 days
     rows the first trim would delete   0
     rows written by an older store     0
   ```

4. **De cronregel, dagelijks**, met de gekozen bewaartermijn van 7 dagen:

   ```
   0 4 * * *  cd /pad/naar/redmine && RAILS_ENV=production SESSION_DAYS_TRIM_THRESHOLD=7 bundle exec rake db:sessions:trim
   ```

   Is `rows the first trim would delete` bij stap 3 groot (honderdduizenden),
   doe de eerste opruiming dan in porties in plaats van in één transactie:

   ```sql
   DELETE FROM sessions WHERE id IN (
     SELECT id FROM sessions WHERE updated_at < now() - interval '7 days' LIMIT 50000);
   ```

   en herhaal tot er niets meer weggaat.

**En twee dingen om te weten.**

- **Wie er uitgelogd wordt, hangt af van wat er nu op productie staat**, en
  stap 3 vertelt het je. Zegt de controle `rows: 0` of bestaat de tabel niet,
  dan kwam de installatie van de cookiestore en logt **iedereen** één keer
  opnieuw in. Staan er rijen, dan draaide 5.1 al op de databasestore; dan
  blijven de sessies met een `<n>::`-id gewoon geldig en loggen alleen de
  gebruikers achter de rijen onder `rows written by an older store` opnieuw in
  — die worden sinds deze commit geweigerd. In het statusbestand stonden hier
  eerder twee zinnen die elkaar tegenspraken; dit is er één, en hij wordt door
  een commando beantwoord in plaats van beredeneerd.
- **Rijen van een oudere store zijn dood gewicht.** Ze kunnen niemand meer
  inloggen, maar ze staan er wel. `bundle exec rake db:sessions:clear` maakt de
  tabel leeg (iedereen eruit), `db:sessions:upgrade` herschrijft ze naar de
  veilige vorm (niemand eruit). Kies zelf.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **De kolom `data` is `text` en dat is met opzet** (ronde 3, F03). Op
  PostgreSQL — wat GEOxyz draait — is `text` onbegrensd, dus er is niets te
  begrenzen. Op MySQL levert dezelfde migratie een `TEXT` van 65 535 bytes op
  en dan wil je `t.text :data, limit: 16.megabytes` (dat is `mediumtext`, en
  het is wat de gem zelf voorstelt). Er is bewust geen code voor: zolang GEOxyz
  op PostgreSQL zit, zou het een tak zijn die nooit gedraaid wordt.
  `redmine:sessions:check` drukt de grens af, dus je ziet vóór het verkeer op
  welke van de twee je zit.
- **De serializer is JSON, niet Marshal, en `:hybrid` is geen alternatief**
  (ronde 3, F01). `:hybrid` valt terug op `Marshal.load` voor elke waarde die
  met `BAh` begint, dus daarmee blijft het gat open. Niet opnieuw wegen.
- **`Redmine::SessionDataSerializer` bestaat om één reden**: een rij die niet
  te parsen is wordt een lege sessie in plaats van een uitzondering, zodat de
  bestaande Marshal-rijen na de deploy een uitlog zijn en geen 500. Weghalen
  betekent dat `db:sessions:clear` bij de deploy verplicht wordt in plaats van
  netjes.

- Gaat **nooit** naar upstream: sessies in de database is een
  deployment-keuze, geen core-feature. Redmine kiest bewust de cookiestore.
- **Het migratienummer `20240929111106` is met opzet lager dan alle andere
  7.0-migraties.** Verhoog het niet: de productiedatabase is op 5.1 al met dat
  nummer gemigreerd, dus de migratie wordt bij de upgrade overgeslagen. Met een
  nieuw nummer zou hij proberen een bestaande tabel aan te maken. Precies dát
  is de reden dat `redmine:sessions:check` bestaat.
- **De migratie is niet omkeerbaar, met opzet.** `down` gooit
  `ActiveRecord::IrreversibleMigration`. De tabel droppen logt iedereen uit en
  vernietigt elke levende sessie; dat mag geen bijeffect van een routineuze
  `db:rollback` zijn. Maak hem niet "netjes" omkeerbaar.
- **`:path` en `:same_site => :lax` moeten blijven staan.** De 5.1-commit liet
  ze vallen; dat is een regressie (CSRF-bescherming, en een installatie onder
  een sub-URI). Ze horen bij de **cookie**, niet bij de store.
- **`:secure_session_only => true` moet blijven staan.** Zonder die optie
  accepteert de store de kale cookiewaarde als `session_id`, en dan is elke rij
  die een oudere gemversie schreef een werkend inlogkoekje voor iedereen die de
  tabel of een back-up kan lezen. De integratietest pint dit vast; als je de
  optie weghaalt wordt hij rood.
- **Controleer `secure_session_only` niet in de deploytaak.** De store haalt de
  optie met `options.delete` uit `Rails.application.config.session_options`
  zodra de middleware-stack gebouwd wordt, dus na het opstarten is de sleutel
  weg en zou zo'n controle altijd "uit" melden. Dat is één keer geprobeerd en
  teruggedraaid.
- **De serializer blijft Marshal.** `:json`/`:hybrid` zou
  `session[:issue_query]` breken, want `queries_helper.rb` bewaart en leest die
  hash met symboolsleutels en een JSON-rondgang geeft strings terug. Zie
  `decisions.md`.
- **De index op `updated_at` staat er voor `db:sessions:trim`**, niet voor de
  netheid. PostgreSQL's planner kiest hem ook echt voor de DELETE.
- Redmine's eigen sessiecontrole (`config.redmine_verify_sessions` en
  `User.verify_session_token`) staat hier los van: die gebruikt de tabel
  `tokens`, niet de Rack-sessie.

## Volgende stap voor een sessie

af — niets te doen. Ronde 3 is gedaan, alle drie haar bevindingen zijn gesloten
en K-17 is beslist (optie A). Jan heeft alleen de vier deploystappen hierboven
nog openstaan.
