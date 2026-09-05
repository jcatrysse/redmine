# ldap-mail-prefs — Class A-beslissingen

## Ronde 2, 2026-09-05 — na Jans keuzes g01, g01a t/m g01d

De taak is herbouwd op Jans gecorrigeerde doel: **na een LDAP-import de
notificatie-instellingen van de LDAP-accounts op de gewenste waarde zetten**,
eenmalig, geen cron. De beslissingen van 2026-09-03 hieronder zijn deels
vervallen; dat staat er per regel bij.

- **Beslist (autonoom, 2026-09-05):** de taak heet nu
  `redmine:users:set_ldap_notification_defaults`, met
  `redmine:users:undo_ldap_notification_defaults` ernaast. De naamkeuze van
  2026-09-03 (`user:disable_mail_ldap_users`, ongewijzigd gehouden zodat een
  bestaande cron-regel bleef werken) is **vervallen**: g01 stelt vast dat er
  geen cron is en ook nooit was, dus de enige reden om buiten Redmine's eigen
  `redmine:`-namespace te blijven is weg. De reviewer merkte dat ook op.
- **Beslist (autonoom, 2026-09-05):** de logica staat in
  `lib/redmine/ldap_notification_defaults.rb`, het `.rake`-bestand roept per
  taak één methode aan. Dat is Redmine's eigen vorm (`User.prune`,
  `Token.destroy_expired`, `Redmine::Ciphering.encrypt_all`) en het is het enige
  dat F04 oplost: `.rubocop.yml` sluit `lib/tasks/**` uit maar `lib/redmine/**`
  niet, en de suite kan een klasse laden maar geen rake-bestand.
- **Beslist (autonoom, 2026-09-05):** **alleen de velden die je noemt worden
  geschreven.** Een weggelaten veld houdt zijn huidige waarde in plaats van
  stilzwijgend teruggezet te worden. Dat maakt het gereedschap bruikbaar voor
  "zet alleen `mail_notification`" zonder dat je de andere twee moet kennen, en
  het is de veiligste lezing van "alle drie de waarden als parameter" (g01a).
  Niets noemen is een fout, geen no-op.
- **Beslist (autonoom, 2026-09-05):** parameters via `ENV`, zoals `email.rake`
  en `locales.rake` het doen. Rake's eigen `task[:args]`-vorm komt in Redmine
  nergens voor.
- **Beslist (autonoom, 2026-09-05):** het journaal is JSON en wordt **ook bij
  een proefdraai** geschreven. Bij een proefdraai is het precies het overzicht
  dat je wil kunnen nalezen voordat je `apply=1` zet, en het kost niets.
- **Beslist (autonoom, 2026-09-05):** er komt een echte `undo`-taak, geen
  handleiding-met-een-runner-regel. g01c vraagt dat een run terug te draaien is;
  een journaal dat je zelf moet ontleden maakt dat theoretisch, en F01 ging er
  juist over dat een onomkeerbare schrijfactie zich voordeed als een veilige.
- **Beslist (autonoom, 2026-09-05):** een toegepaste run zit in één
  `ActiveRecord::Base.transaction`; een proefdraai niet, want die schrijft niets.
- **Beslist (autonoom, 2026-09-05):** de selectie filtert **niet** op status.
  Geblokkeerde en nog niet geactiveerde LDAP-accounts krijgen dus ook de nieuwe
  waarden. Dat is bij het gecorrigeerde doel juist: het gaat om "welke waarde
  hoort bij een LDAP-account", niet om "wie is er actief". Bij het oude doel
  (robotaccounts dempen) was het een fout, en dat was F02's tweede helft.
- **Beslist (autonoom, 2026-09-05):** geen enkel account met een
  authenticatiebron wordt overgeslagen, ook `admin` niet als die ooit aan LDAP
  gekoppeld wordt. Een uitzondering die alleen in code staat is precies het
  soort verborgen regel dat F02 aanwees; wie een account wil sparen, haalt zijn
  authenticatiebron weg.
- **Beslist (autonoom, 2026-09-05):** `user.save!(:validate => false)` en
  `user.pref.save!` — de bang-vorm, zodat een mislukte schrijfactie de
  transactie terugdraait in plaats van stil `false` terug te geven. De
  `:validate => false` zelf blijft, om de reden van 2026-09-03 hieronder.

## Ronde 1, 2026-09-03 — nog geldig

- **Beslist (autonoom, 2026-09-03):** `user.save(:validate => false)` blijft.
  LDAP-beheerde accounts halen Redmine's eigen validaties niet altijd, en de
  taak moet ze toch kunnen zetten. (Nu in de bang-vorm, zie hierboven.)
- **Beslist (autonoom, 2026-09-03):** `user.pref.save` is een aparte `save`,
  want `has_one :preference` staat niet op `:autosave => true`.
- **Beslist (autonoom, 2026-09-03):** `auto_watch_on = []` in plaats van `['']`.
  `['']` is een artefact van het formulier; `[]` is wat de getter van het model
  zelf teruggeeft.
- **Beslist (autonoom, 2026-09-03):** Redmine's GPL-header staat boven elk
  bestand, zoals bij elke buur.
- **Beslist (autonoom, 2026-09-03):** geen Nederlandse commentaarregels (INV-3).

## Ronde 1, 2026-09-03 — vervallen

- ~~de taaknaam blijft `user:disable_mail_ldap_users`~~ — zie hierboven.
- ~~`group.users` in plaats van een join op `groups`~~ — er is geen groep meer
  in het spel; de selectie gaat over `auth_source_id`.
- ~~`preload(:groups)` tegen N+1 op de groepscontrole~~ — die controle bestaat
  niet meer. Wat ervoor in de plaats komt is `preload(:preference)`, om
  dezelfde reden: de voorkeuren worden per account gelezen.
- ~~`abort` als de groep niet bestaat~~ — vervangen door `abort` als geen enkel
  account een authenticatiebron heeft.
