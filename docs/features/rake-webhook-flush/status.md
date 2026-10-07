---
slug: rake-webhook-flush
feature: Webhooks gaan niet meer verloren in de rake-taken die mail ontvangen
commit_51: -
geoxyz: live
geoxyz_commit: e1e759c47
upstream: patch klaar
patch: patches/rake-webhook-flush/2026-10-07-r25136-feature.patch
issue:
---

# rake-webhook-flush — status

## Waar het staat

Af, in beide vormen, op 2026-10-07. Zonder aparte job-backend verloren
`rake redmine:email:read`, `receive_imap` en `receive_pop3` de webhooks van de
issues die ze uit mail aanmaakten, omdat het proces stopte voor de jobs liepen
(gemeten op trunk: 4 issues, 0 webhooks). Core had voor de mails in diezelfde
taken al `Mailer.with_synched_deliveries`; die zet nu ook `ActiveJob::Base` op
inline binnen het blok, zodat de webhooks in het rake-proces zelf vertrekken.
Patch klaar tegen r25136 en applyt ook op echte trunk r25215; dezelfde commit
staat als `e1e759c47` op `7.0-stable-GEOxyz`. Wacht op Jan: issue aanmaken en
keuze K-24.

## Wat het doet

Een beheerder die mail binnenhaalt via cron of een MTA-pipe, zonder Sidekiq of
iets dergelijks, krijgt de webhooks van die issues nu gewoon toegestuurd. Een
plugin-job die bij zo'n issue start, loopt nu ook, in plaats van stil te
verdwijnen.

## Bewijs

- Volledige suite met patch (`test:all`, incl. systeemtests): `6101 runs, 32301 assertions, 27 failures, 2 errors, 82 skips`
- Volledige suite op schone trunk r25136: `6100 runs, 32296 assertions, 27 failures, 2 errors, 82 skips`, faalnamen identiek: ja (29 namen, `diff` leeg; 14 `RepositoriesControllerTest`, 8 `ApiTest::RepositoriesTest`, 5 `SysControllerTest`, 1 `UserTest`, 1 `ApiTest::IssuesTest` — de bekende omgevingsfouten van de runbook)
- Volledige suite op `7.0-stable-GEOxyz` (parent `37d718169` + deze commit): `6189 runs, 32656 assertions, 0 failures, 0 errors, 28 skips`. Na de replay op `5c2dcdd7a` (drie commits van parallelle sessies eronder): mailer-, webhook-, mail_handler- en query-tests samen `549 runs, 2232 assertions, 0 failures, 0 errors`; de volledige run op `e1e759c47` zelf: `6194 runs, 32668 assertions, 0 failures, 0 errors, 28 skips`
- Nieuwe test rood op de oude code: ja, gezien (`assert_empty ... enqueued_jobs` faalt: de job bleef in de wachtrij), groen met de patch
- Testvervuiling: `mailer_test` + `webhook_test` + `mail_handler_test` in één proces, seeds 1–4: telkens `233 runs, 1335 assertions, 0 failures, 0 errors`
- RuboCop op de gewijzigde bestanden: 0 (baseline 0)
- `tools/check-patch-clean.sh`: PASS · `tools/check-symmetry.sh`: PASS · `tools/check-geoxyz-branch.sh`: alles ok voor deze feature (`e1e759c47` staat geregistreerd, lint 8 = baseline 8, current met `origin/7.0-stable`); de run faalt op 2026-10-07 alleen op drie commits van parallelle sessies (`5c2dcdd7a` assignee-nobody, `0f4317246` back-url-array, `6abebe886` asset-paths-gem-order) die hun `status.md` nog niet bijwerkten — niet van deze feature
- Screenshots: 13 (3 voor, 7 na incl. twee faalpaden, 3 op GEOxyz), gelezen: ja

## Wat Jan nog moet doen

Op redmine.org een issue aanmaken met de Engelse tekst van
`docs/features/rake-webhook-flush/dossier.md` vanaf "The problem", met
`patches/rake-webhook-flush/2026-10-07-r25136-feature.patch` erbij en
`before-receiver.png` / `after-receiver.png` als voor/na; daarna het nummer hier
invullen. En K-24 in `docs/DECISIONS.md` bevestigen (aanbeveling: A, zoals
gebouwd). Voor het indienen de mirror syncen (41 commits achter op 2026-10-07)
en `tools/check-patch-clean.sh rake-webhook-flush --submit` draaien.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Eén plek, in `Mailer.with_synched_deliveries`, geen sleep of wachtlus per
  taak.** Opdracht van Jan, en die helper is daar precies voor.
- **`ActiveJob::Base` wisselen, niet `WebhookJob`.** Gebouwd en gemeten:
  `WebhookJob` wisselen pint hem via `class_attribute` op de geërfde adapter en
  maakt de suite volgordeafhankelijk (8 failures). Zie `decisions.md`.
- **Onvoorwaardelijk inline**, conform #36393. De keerzijde voor installaties
  met een echte backend is K-24, niet hier opnieuw te wegen tot Jan kiest.
- **Geen job-backend voor heel Redmine of GEOxyz.** Jans beslissing bij
  issue_recurring: dat is een aparte keuze, deze feature maakt hem niet.
- **De wachtlussen in de crons van issue_recurring en redmine_ai_triage blijven.**
  Ook Jans beslissing. Voor de eigen rake-taken van die plugins helpt deze commit
  niet vanzelf (die draaien niet in het blok); een plugin kan zijn taak wel zelf
  in `Mailer.with_synched_deliveries` zetten.
- **#36395 (helper niet thread-safe)** geldt al voor de bestaande regel en is
  niet het onderwerp van deze patch. **#44465 (eigen queue voor webhooks)** staat
  er los van. **#44454** (leeg events-lijstje in development) kwam alleen in het
  G9-script naar boven.
- **Geen redmine.org-issue gevonden** (gezocht 2026-10-07 op `webhook`,
  `WebhookJob`, `webhook rake`, `webhook async`, `with_synched_deliveries`).
- **Kan vervallen** als GEOxyz naar de Redmine-release gaat die de patch bevat
  (op zijn vroegst 7.1).

## Volgende stap voor een sessie

Af — niets te doen tot Jan het issue heeft aangemaakt of K-24 omgooit.
