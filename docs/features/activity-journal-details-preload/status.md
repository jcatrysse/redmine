---
slug: activity-journal-details-preload
feature: De activiteitenpagina laadt de details van issue-wijzigingen in één query in plaats van één per wijziging
commit_51: -
geoxyz: live
geoxyz_commit: 83693089a
upstream: patch klaar
patch: patches/activity-journal-details-preload/2026-10-14-r25236-feature.patch
issue: "44252"
---

# activity-journal-details-preload — status

## Waar het staat

Af aan onze kant. Trunk lost het niet op, maar redmine.org heeft al issue
**#44252** (status New, target 7.1.0) met precies deze ene regel als patch,
zonder test. Daarom geen nieuw issue: onze patch is dezelfde regel plus een
test die het N+1 vastlegt, en de notitie voor #44252 staat klaar in het
dossier met PostgreSQL-metingen. Dezelfde commit staat op `7.0-stable-GEOxyz`.

## Wat het doet

`/activity` (globaal en per project, ook de Atom-feed) haalt de
`journal_details` van alle getoonde issue-wijzigingen in één query op, in plaats
van één query per wijziging. Wat er getoond wordt verandert niet.

## Bewijs

- Volledige suite met patch (`test:all`, systeemtests inbegrepen): 6219 runs, 32804 assertions, 28 failures, 2 errors, 87 skips
- Schone trunk r25236, de vijf bestanden met fouten (SCM-tests, geen `svn` in de container): 288 runs, 27 failures, 2 errors; faalnamen identiek aan de patchrun: ja (29 namen). De 28e failure is `IssuesSystemTest#test_update_issue_form_should_include_time_entry_form_only_for_users_with_permission`, in de login-helper (`expected "/my/page" to equal "/login"`); los opnieuw: 1 run, 0 failures, en heel `test/system/issues_test.rb`: 30 runs, 0 failures
- Volledige suite op `7.0-stable-GEOxyz` (`83693089a`, `test:all`): 6269 runs, 32960 assertions, 0 failures, 0 errors, 29 skips
- Nieuwe test rood op de oude code: ja, op r25236, op `7.0-stable-GEOxyz` en op echte trunk r25254 (`5 instead of 0 queries were executed`, vijf keer `SELECT "journal_details".*`)
- RuboCop op de gewijzigde bestanden: 0 (baseline 0), trunk en GEOxyz
- `tools/check-patch-clean.sh`: PASS (zonder `--submit`; mirror `origin/master` r25236 loopt 12 commits achter op echte trunk r25254, de patch applyt daar wel en is daar groen) · `tools/check-symmetry.sh`: zie dossier · `tools/check-geoxyz-branch.sh`: zie dossier
- Live (development mode, 1010 journal-events, mediaan van 5): `/activity` 5061 ms / 1033 DB-queries → 3172 ms / 34; GEOxyz 5073 ms → 3071 ms. Tekst van de pagina identiek (SHA-1)
- Screenshots: 24, gelezen: ja

## Wat Jan nog moet doen

Een notitie plaatsen op https://www.redmine.org/issues/44252 met de tekst onder
"Note for #44252" in `docs/features/activity-journal-details-preload/dossier.md`
en `patches/activity-journal-details-preload/2026-10-14-r25236-feature.patch`
als bijlage. Geen nieuw issue aanmaken.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- #44252 bestaat; een tweede issue zou als duplicaat gesloten worden. De code is letterlijk die van attachment 36470 daar.
- Florians variant (attachment 36501, `user: :email_address` bij Gravatar) is bewust niet meegenomen: ander N+1 (per auteur, alleen met Gravatar), eigen voorwaarde.
- `IssueStatus.find_by_id` in `Journal#new_status` blijft: de query cache beantwoordt die (geen round-trip).
- #44363 (r25118, preloads voor Attachment/Document/WikiContentVersion/TimeEntry) zit op trunk maar niet in 7.0-stable; hoort niet bij deze slug, gemeld aan de coördinator.
- Meten in de browser vraagt het strippen van `If-None-Match`: de controller geeft anders 304 en rendert niet, en dan zie je het N+1 niet.

## Volgende stap voor een sessie

Af — niets te doen tot er feedback op #44252 komt. Vlak voor Jan plaatst: patch tegen een gesyncte mirror opnieuw controleren met `tools/check-patch-clean.sh --submit`.
