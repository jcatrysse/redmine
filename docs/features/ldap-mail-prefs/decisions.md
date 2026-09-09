# ldap-mail-prefs — Class A-beslissingen

## Codex-ronde, 2026-09-09 — de onafhankelijke review

- **Beslist (autonoom, 2026-09-09):** `undo` vergelijkt vóór hij herstelt. Het
  journaal legt al vast *wat* de run gezet heeft (`values`) naast de vorige
  waarden per account; die eerste werd niet gebruikt. Nu wordt een account
  alleen teruggezet als het nog exact die gezette waarden heeft, via dezelfde
  `already_set?` die de forward-run gebruikt — dus met dezelfde
  `auto_watch_on`-sortering, geen tweede vergelijkingsregel.
- **Beslist (autonoom, 2026-09-09):** een journaal zonder `values` werpt
  `Error` in plaats van terug te vallen op onvoorwaardelijk herstellen. Onze
  eigen `write_journal` schrijft dat veld altijd, dus dit raakt alleen een
  handmatig bewerkt of afgekapt journaal — en daar is stil het onveilige doen
  precies de fout die de bevinding aanwijst.
- **Beslist (autonoom, 2026-09-09):** **geen** `force`-optie. De review noemt
  hem als mogelijkheid "only if operations genuinely needs one", en dat is nu
  niet zo; een schakelaar die het vangnet uitzet is pas een goed idee als er
  een echte aanleiding is.

## Ronde 3, 2026-09-09 — de drie bevindingen van de blinde herreview

- **Beslist (autonoom, 2026-09-09):** `apply` gaat door dezelfde `BOOLEANS`-
  tabel als `no_self_notified`, en een waarde die in geen van beide kolommen
  staat werpt `Error`. Was `options['apply'].present?`, en `"0".present?` is
  `true`, dus `apply=0` schreef. Er is geen keuze te maken: de tabel staat al
  in het bestand en dit is de destructieve optie.
- **Beslist (autonoom, 2026-09-09):** `apply` **weglaten** en `apply=` (leeg)
  blijven "alleen rapporteren", ze werpen dus niets. Alleen een niet-lege
  waarde die geen booleaan is (`apply=maybe`) is een fout. Anders zou de
  gedocumenteerde veilige aanroep — zonder `apply` — plots afbreken, en dat is
  een regressie in precies het pad dat het meest gebruikt wordt.
- **Beslist (autonoom, 2026-09-09):** het gevulde journaal wordt **binnen** de
  transactie geschreven, na de lus. Zo draait een journaal dat niet geschreven
  kan worden de accounts mee terug, in plaats van gewijzigde accounts achter te
  laten met een bestand dat zegt dat er niets is aangeraakt. De lege
  proefschrijfactie ervóór blijft staan — die moet juist falen vóór het eerste
  account verandert.
- **Beslist (autonoom, 2026-09-09):** het standaard journaalpad verhuist van
  `log/` naar `tmp/`. `.gitignore` dekt `/tmp/*` volledig maar van `log/`
  alleen `*.log*`, dus een journaal in een checkout stond als untracked
  bestand in `git status` — met alle logins erin — en `git add -A` had het
  gestaged. De **duurzaamheid** is daarmee niet opgelost (`tmp/` overleeft een
  deploy net zo min als `log/`) en is ook geen codeprobleem: de taakbeschrijving
  zegt nu dat het journaal het enige undo-bewijs is en vóór de volgende deploy
  ergens duurzaam gekopieerd moet worden.

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
