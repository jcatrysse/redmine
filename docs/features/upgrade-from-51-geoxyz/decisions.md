# upgrade-from-51-geoxyz — Class A-beslissingen

- **Beslist (autonoom, 2026-10-14):** de 5.1-tabellen worden **hernoemd**
  (`geoxyz51_*`), niet naar een apart schema verplaatst. Een schema bestaat op
  MySQL niet als apart begrip; `rename_table` werkt op beide en hernoemt op
  PostgreSQL ook de sequence, de primaire sleutel en de indexen met
  standaardnaam mee, zodat 20251007073256 zijn eigen
  `index_projects_webhooks_on_project_id` kan maken.
- **Beslist (autonoom, 2026-10-14):** de opzij-migratie heeft versie
  `20251007073255`, direct vóór `CreateWebhooks`; de kopieer-migratie
  `20260903081501`, direct ná `CreateTrackersWebhooks`. Zo zit er geen andere
  migratie tussen die de nieuwe tabellen al zou kunnen gebruiken.
- **Beslist (autonoom, 2026-10-14):** de voorwaarde is de rij
  `20231120120000` in `schema_migrations` (zoals gevraagd), en per tabel
  `table_exists?`. Een 5.1-database die alleen de eerste twee 5.1-migraties
  draaide, werkt dus ook (getest).
- **Beslist (autonoom, 2026-10-14):** kopiëren met `INSERT … SELECT` in SQL,
  niet via het model: geen validatie (de 7.0-URL-validator lost de host op) en
  geen callbacks. De ids blijven gelijk; op PostgreSQL wordt de sequence
  daarna gezet met `reset_pk_sequence!`, zoals `lib/tasks/migrate_from_trac.rake`
  dat doet. MySQL zet `AUTO_INCREMENT` zelf voorbij de hoogste id (getest:
  volgende id 4 na id 3, op beide).
- **Beslist (autonoom, 2026-10-14):** `down` is in alle drie een no-op, zoals
  `20260320090000`. Er is niets terug te zetten dat nog bestaat.
- **Herzien (2026-10-15):** de oude instellingsrijen worden ná de kopie
  geschrapt (`20261015000000`). De beslissing van 2026-10-14 om ze te laten
  staan was fout: `Setting#value` geeft op een niet-gedeclareerde naam een
  `NoMethodError`, gevonden in de tweede upgrade-repetitie. Een aparte migratie,
  zodat een database die `20261014120000` al draaide ook opgeruimd wordt.
- **Beslist (autonoom, 2026-10-14):** een instelling die onder haar 7.0-naam al
  bestaat wordt niet overschreven; voor het paar
  `revision_branches_excluded` + `revision_branches_enable_regex` geldt dat
  voor het paar samen, zodat er nooit een lijst van het ene soort met de
  schakelaar van het andere soort ontstaat.
- **Beslist (autonoom, 2026-10-14):** 5.1 paste de branchlijst **alleen** toe
  als `display_revision_branches_regex_enable` aan stond. Stond hij uit, dan
  wordt de lijst niet meegenomen — anders zou 7.0 hem als glob gaan toepassen
  en branches verbergen die 5.1 toonde.
- **Beslist (autonoom, 2026-10-14):** elk 5.1-patroon `p` wordt
  `.*(?-i:p).*`. 7.0 zet er `\A(?:…)\z` omheen en matcht hoofdletterongevoelig;
  5.1 matchte zonder ankers en hoofdlettergevoelig. Zo blijft de uitkomst per
  branchnaam gelijk (getest op zes namen, inclusief `^`-anker en hoofdletters).
- **Beslist (autonoom, 2026-10-14):** een 5.1-patroon met een komma (7.0 splitst
  de lijst op komma's) of een ongeldig patroon wordt niet meegenomen, met een
  regel in de uitvoer van `db:migrate`. Op 5.1 gaf een ongeldig patroon een
  `RegexpError` bij elke branchweergave; een komma-patroon is in 7.0 niet uit
  te drukken zonder de betekenis van een quantifier `{m,n}` te veranderen.
- **Beslist (autonoom, 2026-10-14):** voor `search_token_limit` geen migratie,
  wel een regel in de uitvoer van `db:migrate` als de waarde niet 5 was. De
  gedragsverandering is K-04 (Jan, 2026-09-02, optie A), die precies dit gevolg
  al noemt; niet opnieuw voorgelegd.
- **Beslist (autonoom, 2026-10-14):** de test draait niet-transactioneel en zet
  in `teardown` de drie 7.0-tabellen opnieuw op met de 7.0-migraties zelf.
  MySQL commit `CREATE`/`DROP TABLE` impliciet, dus een transactionele test zou
  daar de testdatabase achterlaten zonder 7.0-tabellen.
