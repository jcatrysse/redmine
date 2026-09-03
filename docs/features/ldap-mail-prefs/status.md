---
slug: ldap-mail-prefs
feature: "Rake: mailvoorkeuren dempen voor LDAP-only users"
commit_51: 9e2c38e2d
geoxyz: live
geoxyz_commit: add935736
upstream: nooit
patch:
issue: 
---

# ldap-mail-prefs — status

## Waar het staat

Af. Staat op `7.0-stable-GEOxyz` als één commit: één nieuw bestand,
`lib/tasks/disable_mail_ldap_users.rake`. Gaat nooit naar upstream, dus geen
dossier en geen patch.

## Wat het doet

`bundle exec ruby bin/rails user:disable_mail_ldap_users` loopt de leden van de
groep `ldap_sync_users` af. Zit een gebruiker **alleen** in die groep, dan is
het een account dat de LDAP-sync heeft aangemaakt en dat niemand gebruikt: de
taak zet zijn mailmelding op "alleen wat aan mij is toegewezen", zet
"stuur mij geen mail over mijn eigen wijzigingen" aan en zet alle
auto-watch-vinkjes uit. Zit hij ook in een andere groep, dan is het een echte
gebruiker en blijft hij ongemoeid; de taak print per gebruiker `UPDATE:` of
`SKIP:` met de reden.

## Bewijs

- Volledige suite: de taak heeft geen eigen test — `lib/tasks/**` wordt niet
  door de suite geraakt. De branchsuite staat groen, zie
  `docs/features/ar-sessions/status.md`.
- RuboCop: n.v.t. — `lib/tasks/**/*` staat in de `Exclude` van Redmine's eigen
  `.rubocop.yml`, dus dit bestand wordt nooit gelint. Daarom is het met de hand
  nagelopen op de verboden constructies: geen top-level `def`, geen top-level
  constante, geen `require_relative`.
- **Echt uitgevoerd tegen echte records**, in één transactie die daarna is
  teruggedraaid (`RAILS_ENV=test bin/rails runner`, drie gebruikers aangemaakt):

  | Gebruiker | Groepen | mail_notification | no_self_notified | auto_watch_on |
  |---|---|---|---|---|
  | `ldaponly` | alleen `ldap_sync_users` | `"only_assigned"` | `true` | `[]` |
  | `ldapboth` | `ldap_sync_users` + `other_group` | `"all"` (ongewijzigd) | `false` | alle drie (ongewijzigd) |
  | `nogroup` | geen | `"all"` (ongewijzigd) | `false` | alle drie (ongewijzigd) |

  Uitvoer: `UPDATE: ldaponly` en `SKIP: ldapboth is also in other_group`. Na de
  rollback stonden er weer alleen de drie principals die `db:migrate` zelf
  aanmaakt.
- Ontbrekende groep: `Group 'ldap_sync_users' not found.` op stderr en
  **exit 1** — gemeten.
- `bin/rails -T user` toont de taak met zijn `desc`.
- `tools/check-geoxyz-branch.sh`: PASS

## Wat Jan nog moet doen

niets

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Gaat **nooit** naar upstream: de groepsnaam `ldap_sync_users` is hardcoded en
  dat is precies goed voor een ops-taak van GEOxyz, en precies fout voor core.
- De taaknaam is bewust ongewijzigd gebleven ten opzichte van 5.1
  (`user:disable_mail_ldap_users`), zodat een bestaande cron-regel blijft
  werken.
- **`user.save(:validate => false)` staat er met opzet.** LDAP-beheerde accounts
  halen Redmine's eigen validaties niet altijd (bijvoorbeeld een ontbrekend
  mailadres) en de taak moet ze toch kunnen dempen. Haal het er niet uit.
- `user.pref.save` is een aparte `save`, want `has_one :preference` in
  `app/models/user.rb` staat **niet** op `:autosave => true`; een `user.save`
  alleen bewaart de voorkeuren dus niet.
- De rest van de afwegingen staat in `decisions.md`.

## Volgende stap voor een sessie

af — niets te doen.
