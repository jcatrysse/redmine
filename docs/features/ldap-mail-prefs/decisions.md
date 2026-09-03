# ldap-mail-prefs — Class A-beslissingen

- **Beslist (autonoom, 2026-09-03):** de taaknaam blijft
  `user:disable_mail_ldap_users`, precies zoals op 5.1. Redmine zet zijn eigen
  taken onder `redmine:`, dus een eigen `user:`-namespace botst met niets, en een
  andere naam zou elke bestaande cron-regel van Jan breken.
- **Beslist (autonoom, 2026-09-03):** `group.users` in plaats van
  `User.joins(:groups).where(groups: {id: sync_group.id})`. `Group` erft van
  `Principal` en staat dus in de tabel **`users`**, niet in een tabel `groups`;
  een `where(groups: ...)` leunt op hoe Rails de self-join aliast. De associatie
  `Group#users` bestaat al en omzeilt die vraag volledig.
- **Beslist (autonoom, 2026-09-03):** `preload(:groups)` erbij, zodat de
  controle "zit deze gebruiker ook in andere groepen" niet één query per
  gebruiker kost.
- **Beslist (autonoom, 2026-09-03):** `abort` in plaats van `puts` + `next` als
  de groep niet bestaat. De 5.1-versie eindigde dan met exit 0, dus een cron-run
  meldde niets terwijl er niets gebeurd was. Nu exit 1 met de melding op stderr
  — nagemeten.
- **Beslist (autonoom, 2026-09-03):** `user.pref.auto_watch_on = []` in plaats
  van `user.pref[:auto_watch_on] = ['']`. `['']` is een artefact van het
  formulier (een leeg vinkjesveld post een lege string). `auto_watch_on?`
  vergelijkt met de strings in `AUTO_WATCH_ON_OPTIONS`, dus beide gedragen zich
  hetzelfde; `[]` is wat de getter van het model zelf teruggeeft.
- **Beslist (autonoom, 2026-09-03):** `user.save(:validate => false)` blijft.
  LDAP-beheerde accounts halen Redmine's eigen validaties niet altijd, en de
  taak moet ze toch kunnen dempen.
- **Beslist (autonoom, 2026-09-03):** Redmine's GPL-header staat boven het
  bestand. Elk ander bestand in `lib/tasks/` heeft hem; de 5.1-versie niet.
- **Beslist (autonoom, 2026-09-03):** de twee Nederlandse commentaarregels uit
  de 5.1-versie zijn weg (INV-3).
