---
slug: upgrade-from-51-geoxyz
feature: Upgradepad van een 5.1-stable-GEOxyz-database naar 7.0 (webhooktabellen en hernoemde instellingen)
commit_51: -
geoxyz: live
geoxyz_commit: 8dc5e73a1
upstream: nooit
patch:
issue:
---

# upgrade-from-51-geoxyz — status

## Waar het staat

Af. Eén commit op `7.0-stable-GEOxyz` (`8dc5e73a1`) met drie migraties en één
testbestand. Gaat nooit naar upstream: het probleem bestaat alleen op een
database die op `5.1-stable-GEOxyz` gedraaid heeft. Aanleiding is de
upgrade-repetitie van de coördinator (2026-10-14: `5.1-stable-GEOxyz`
`bcf917c` met de 44 productieplugins, daarna `7.0-stable-GEOxyz` `ad17efd`),
die twee bevindingen opleverde: F1 en F6 hieronder.

## Wat het doet

**F1 — `rake db:migrate` stopte op `20251007073256 CreateWebhooks`** met
`PG::DuplicateTable: relation "webhooks" already exists`. De 5.1-commit
"Feature: webhook" (`25220b45d`) maakte `webhooks`, `projects_webhooks` en
`trackers_webhooks` al aan in eigen migraties `20231120120000`..`20231120120200`,
in een andere vorm (bigint-referenties, jointabellen zonder `id`, `active`
standaard true). Nu:

- `20251007073255 SetAsideGeoxyz51Webhooks` — staat `20231120120000` in
  `schema_migrations`, dan worden de drie tabellen hernoemd naar `geoxyz51_*`
  (elk alleen als hij bestaat) en de drie 5.1-rijen uit `schema_migrations`
  geschrapt.
- `20260903081501 RestoreGeoxyz51Webhooks` — bestaat `geoxyz51_webhooks`, dan
  worden de rijen met `INSERT … SELECT` gekopieerd (id, url, secret, events,
  user_id, active, timestamps; project_id/webhook_id; tracker_id/webhook_id),
  de sequence gezet (PostgreSQL) en de oude tabellen gedropt.
- Op een verse installatie en op een database zonder de 5.1-tabellen doen
  beide niets (getest, en gezien in `db:migrate` op een lege database, PG en
  MariaDB).

**Gevolg om te kennen:** er wordt gekopieerd **zonder validatie**. 7.0 lost de
host van een webhook-URL op bij het bewaren; een 5.1-webhook met een host die
niet resolvet wordt dus behouden en blijft vuren zoals voorheen (dan
mislukt de levering), maar kan in Beheer → Webhooks pas opnieuw bewaard
worden als de URL gecorrigeerd is.

**F6 — vier hernoemde instellingen.** `20261014120000 CopyGeoxyz51Settings`
kopieert, alleen als de 7.0-naam nog niet bestaat:

| 5.1 | 7.0 | Hoe |
|---|---|---|
| `display_under_single_revision` | `display_revision_branches` | letterlijk (`0`/`1`) |
| `display_under_associated_revisions` | `display_associated_revision_branches` | letterlijk (`0`/`1`) |
| `display_revision_branches_regex_enable` | `revision_branches_enable_regex` | `1` als er minstens één patroon meekomt |
| `display_revision_branches_enable_regex_delimiters` | `revision_branches_excluded` | omgezet, zie hieronder |

De betekenis verschilt, en daarom is het geen kopie: op 5.1 was de lijst
**één regexp per regel**, **zonder ankers**, **hoofdlettergevoelig**, en
werd hij **alleen** toegepast als de schakelaar aan stond. Op 7.0 is het een
**kommalijst**, elk patroon **verankerd** (`\A(?:…)\z`) en
**hoofdletterongevoelig**, en met de schakelaar uit een glob-lijst. Dus:

- schakelaar uit op 5.1 → niets gekopieerd (anders zou 7.0 de lijst als glob
  toepassen en branches verbergen die 5.1 toonde);
- schakelaar aan → elk patroon `p` wordt `.*(?-i:p).*`, wat per branchnaam
  dezelfde uitkomst geeft als op 5.1 (getest op zes namen);
- een patroon met een komma, of een ongeldige regexp, wordt overgeslagen met
  een regel in de uitvoer van `db:migrate`.

Kleine bijkomende verschillen, die bij de feature `revision-branches` horen en
al beslist zijn: de branchregel staat op 7.0 ook op de diffpagina, en de
issuetab vraagt geen `:browse_repository` meer (zie
`docs/features/revision-branches/status.md`).

**`search_token_limit`** bestaat op 7.0 niet meer. Op 5.1 gold het getal
(0 = onbeperkt) voor de globale zoekfunctie **én** de tekstfilters. Op 7.0
(feature `search-token-limit`) gebruiken tekstfilters altijd alle woorden en
houdt het zoekvak rechtsboven vast 5. Een productiewaarde anders dan 5 gaat
voor het zoekvak dus verloren; voor de filters wordt het juist ruimer. **Dat is
Jans keuze K-04 (2026-09-02, optie A)**, die dit gevolg letterlijk noemt — dus
niet opnieuw voorgelegd. Er is geen migratie voor; de migratie zegt het wel in
de uitvoer van `db:migrate` als de waarde niet 5 was
(`search_token_limit was 0: the global search now uses the first 5 tokens and
text filters use all of them`), zodat het bij de upgrade zichtbaar is.

## Bewijs

- Volledige suite op `7.0-stable-GEOxyz` `8dc5e73a1`, systeemtests inbegrepen
  (`tools/test-env.sh /home/user/wt/geoxyz bundle exec ruby bin/rails test:all`,
  PostgreSQL 16, `tmp/test/git_repository` uitgepakt): **6268 runs, 32956
  assertions, 0 failures, 0 errors, 29 skips**, exit 0.

- Nieuwe tests `test/unit/geoxyz51_upgrade_test.rb`: **11 runs, 30
  assertions, 0 failures** op PostgreSQL 16 én op MariaDB 10.11.
- **Rood zonder de migraties** (de drie `up`-methodes leeggemaakt):
  `11 runs, 11 assertions, 4 failures, 3 errors`. De vier die groen blijven
  horen dat te doen: de reproductie van F1 zelf, de no-op op een verse
  database, "schakelaar uit kopieert niets" en "bestaande 7.0-instelling
  blijft".
- **Echte `bin/rails db:migrate`**, `rehearsal/rehearse.sh`: database tot
  `20250611092227`, 5.1-toestand erin met `rehearsal/seed51.rb` (1 webhook,
  2 projectlinks, 3 trackerlinks, de vier instellingen, `search_token_limit`
  0), dan migreren. Uitvoer in `rehearsal/output.txt`.
  - zonder de drie migraties: PostgreSQL `PG::DuplicateTable`, MariaDB
    `Table 'webhooks' already exists` — F1 gereproduceerd;
  - met: `webhooks=1 projects_webhooks=2 trackers_webhooks=3`, url, secret,
    events en active ongewijzigd, geen `geoxyz51_*`-tabellen of 5.1-versies
    over, volgende webhook-id 4, de instellingen zoals in de tabel hierboven —
    op beide databases identiek.
- RuboCop op de vier nieuwe bestanden: 0 (nieuwe bestanden, baseline 0).
- `tools/check-geoxyz-branch.sh`: **INCOMPLETE, niet PASS** — alle
  inhoudelijke regels `ok` (66 eigen commits, alle 62 vastgelegde
  `geoxyz_commit`-sha's op de branch, geen niet-vastgelegde commit, geen
  AI-identiteit, locales binnen de vijf), maar de lintregel staat op `????`.
  Dat ligt niet aan deze commit: dezelfde `????` stond er al vóór de push.
  De probe van de gate (`Project.find(params[:id])`) wordt door
  `Rails/StrongParametersExpect` van rubocop-rails 2.34.3 niet gemeld, terwijl
  de cop wél leeft: `params.require(:project).permit(:name)` in een
  controller geeft hem meteen. Staat in `docs/traps.md`; de gate zelf is
  framework-werk. Zelf gemeten met de lockfile aanwezig: 0 offences op de vier
  nieuwe bestanden.
- `tools/check-symmetry.sh`: n.v.t. — er is geen `patch/`-branch; dit is
  bewust een GEOxyz-only afwijking die upstream nooit nodig heeft.
- G9 (browser): n.v.t. — er is geen scherm; het bewijs is de migratie-uitvoer
  hierboven. Wat een beheerder na de upgrade ziet, is de bestaande
  instellingenpagina van `revision-branches` en Beheer → Webhooks.

## Wat Jan nog moet doen

niets — de coördinator draait de upgrade-repetitie opnieuw op de nieuwe kop
van `7.0-stable-GEOxyz`. Nuttig om bij de echte upgrade te bekijken: de
uitvoer van `db:migrate` op regels met `not copied` of
`search_token_limit was`.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Waarom hernoemen en niet een eigen schema:** MySQL kent geen schema naast
  de database; `rename_table` werkt op beide en neemt op PostgreSQL sequence,
  primaire sleutel en standaard-indexnamen mee (anders botst
  `index_projects_webhooks_on_project_id`). Zie `decisions.md`.
- **Waarom de branchpatronen omgezet worden en niet gekopieerd:** zie de tabel
  hierboven. Een letterlijke kopie verandert stil welke branches zichtbaar zijn.
- **`search_token_limit` is K-04**, niet heropenen.
- **De migraties blijven altijd staan**, ook als er geen 5.1-database meer is:
  ze zijn dan no-ops, maar `schema_migrations` verwacht ze.
- Alleen de webhooktabellen botsen: van de 5.1-GEOxyz-migraties die 7.0 niet
  heeft, zijn dit de enige drie (`comm` op beide `db/migrate`-lijsten).
  `20240929111106 AddSessionsTable` (feature `ar-sessions`) staat op beide en
  heeft al een `table_exists?`-bewaker.
- De test draait **niet-transactioneel** met een `teardown` die de 7.0-tabellen
  herbouwt via de 7.0-migraties zelf: MySQL commit DDL impliciet.

## Volgende stap voor een sessie

af — niets te doen, tenzij de nieuwe upgrade-repetitie iets vindt.
