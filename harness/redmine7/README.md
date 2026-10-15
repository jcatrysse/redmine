# Redmine 7 harness: all GEOxyz plugins together

**Voor Jan.** Dit is het testharnas van de coördinator van de Redmine 7-migratie (14 en 15 oktober
2026), hier bewaard op jouw vraag zodat het later opnieuw kan draaien. Het test drie dingen die geen
enkele pluginsessie op zichzelf kan testen: alle 44 GEOxyz-plugins samen op 7.0-stable-GEOxyz, de
upgrade van een 5.1-database met plugindata naar 7.0, en de snelheid van de belangrijkste pagina's
met alle plugins tegenover core alleen. Er staat geen Jira-data en geen geheim in; de wachtwoorden
zijn die van de lokale testdatabases.

## Layout

| Path | What |
|---|---|
| `kit/` | Combined run: checkout of core and the 44 plugins (`01`), databases (`02`), every plugin's minitest and rspec in one installation (`03`, `05`, `06`), smoke over every plugin route (`04`), container restart recovery (`resume.sh`) |
| `upgrade/` | Upgrade rehearsal: 5.1-stable-GEOxyz with the production plugin set and seeded data, upgraded in place to 7.0-stable-GEOxyz with the redmine70-migration heads; schema, data, workflow and page comparisons |
| `perf44/` | Performance: seeded volume (20,000 issues, 1,000 users), production mode, all plugins vs core only, interleaved, median of 5; leave-one-out attribution |
| `heads-2026-10-15.tsv` | Repo, plugin id and head of each plugin in the last full run |
| `findings-2026-10-14.md` | The running log of every run and finding of those two days |

## Assumptions baked into the scripts

- A Linux container with PostgreSQL 16 on 127.0.0.1 (user and password `redmine`), Ruby 3.3 for
  Redmine 7 and Ruby 3.2 (`/opt/rbenv`) for Redmine 5.1, run as root.
- Hard-coded paths: `/home/user/r70h` (the 7.0 checkouts `redmine`, `redmine_b`, `redmine_c`, the
  plugin sources in `src/`, logs, results) and, for `upgrade/` and `perf44/`, a scratch directory
  set in their `env.sh`. Adjust those before running elsewhere.
- Access to the jcatrysse repositories (several are private).

## Running

Combined suites, in the second checkout `redmine_b` with its own test database:

    kit/01_checkout.sh                       # core + 44 plugins on redmine70-migration
    kit/02_db.sh                             # databases, migrations, default data
    kit/05_attrib.sh <label> "" "<plugin ids>"            # run suites with all plugins installed
    kit/05_attrib.sh <label> "<plugins to leave out>" "<ids>"   # attribution: leave plugins out
    kit/06_sync_changed.sh <label>           # bring moved plugins to their head and run their suites

Results land in `attrib-<label>.tsv`, logs in `logs/`. The test databases are copied from a template
(`r70h_test_tpl`) per suite; after a plugin adds a migration, migrate the template and re-dump
`db/schema.rb` (see `findings-2026-10-14.md`, "H7"). `kit/resume.sh` restarts PostgreSQL, the smoke
server and the test LDAP for redmine_ldap_sync after a container restart. Browser specs need a
chromedriver that matches Chrome; `05_attrib.sh` drops `/opt/node22/bin` from PATH for that reason.

Upgrade rehearsal: `upgrade/00_all.sh` (from scratch), or `29_data51.sh`, `33_before51.sh`,
`40_copy70.sh` and `00_run2.sh` to rerun on new heads.

Performance: `perf44/setup_db.sh`, then `measure.rb` through `start_server.sh` for core and all
plugins, `loo.sh` for leave-one-out, `compare_ba.rb` for a before/after table; `cleanup.sh` undoes it.

## State on 2026-10-15

7.0-stable-GEOxyz 71b9479 with Rails 8.1.4; 42 of 44 plugin suites fully green with all plugins
installed (redmine_editauthor waits for its view_issue_description test grant, one
redmine_issue_templates drag-and-drop browser spec is timing-sensitive). The upgrade rehearsal runs
without manual workarounds, 0 server errors on 900 crawled pages. Details per plugin in the findings
log and in each plugin's `docs/REDMINE7-MIGRATION.md`.
