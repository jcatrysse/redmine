---
slug: ldap-mail-prefs
feature: "Rake: notificatievoorkeuren van LDAP-accounts zetten na een import"
commit_51: 9e2c38e2d
geoxyz: live
geoxyz_commit: 113f32117
upstream: nooit
patch:
issue: 
---

# ldap-mail-prefs — status

## Waar het staat

Ronde-2 fix is af. Alle elf reviewbevindingen van 2026-09-03 hebben een
`Resolution:`-regel; twee blockers en drie majors zijn opgelost, één nit is
vervallen omdat het onderdeel dat hij aanwees niet meer bestaat. De taak is
herbouwd op Jans gecorrigeerde doel (g01): **na een LDAP-import de
notificatie-instellingen van de LDAP-accounts op de gewenste waarde zetten**,
eenmalig, geen cron. Gaat nooit naar upstream, dus geen dossier en geen patch.

Op `7.0-stable-GEOxyz` staan er voor deze feature **twee** commits:
`add935736` (de oorspronkelijke taak, 2026-09-03) en `113f32117` (de
herbouw van vandaag). Dat is met opzet: `add935736` was al gepusht en
geschiedenis op die branch wordt niet herschreven, want dat maakt elke checkout
van GEOxyz ongeldig. Het registerveld wijst naar `113f32117`, de commit die
telt.

De oude taak `user:disable_mail_ldap_users` is weg. Wie hem gewend was, moet de
nieuwe naam gebruiken; er stond geen cron-regel op (dat is precies wat g01
vaststelde), dus er breekt niets.

## Wat het doet

`redmine:users:set_ldap_notification_defaults` zet voor elk account met een
authenticatiebron de notificatievoorkeuren die je op de opdrachtregel noemt.
Zonder `apply=1` verandert het niets en toont het alleen wat het zou doen; met
`apply=1` schrijft het in één transactie, en in beide gevallen legt het de
vorige waarden per account vast in een journaalbestand.
`redmine:users:undo_ldap_notification_defaults journal=<pad> apply=1` zet die
waarden terug.

```
bundle exec rake redmine:users:set_ldap_notification_defaults \
  mail_notification=none no_self_notified=1 auto_watch_on= RAILS_ENV=production
# lees de uitvoer, en pas dan:
bundle exec rake redmine:users:set_ldap_notification_defaults \
  mail_notification=none no_self_notified=1 auto_watch_on= apply=1 RAILS_ENV=production
```

Lokale accounts, de ingebouwde beheerder incluis, hebben geen authenticatiebron
en worden dus nooit geraakt.

## Bewijs

- **Volledige suite op `7.0-stable-GEOxyz`, systeemtests inbegrepen**
  (`tools/test-env.sh /home/user/wt/geoxyz bundle exec ruby bin/rails test:all`):
  **6069 runs, 32199 assertions, 0 failures, 0 errors, 39 skips**, exit 0.
  Gedraaid op de branch **na** de merge met `origin/7.0-stable`, dus op precies
  de boom die hierboven staat. De 39 skips zijn de SCM's die dit image niet
  heeft (svn, hg, bzr, cvs), de LDAP-tests en pandoc — die stonden er al.
- Nieuwe unittest los: 25 runs, 47 assertions, 0 failures, 0 errors, 0 skips
  (`test/unit/lib/redmine/ldap_notification_defaults_test.rb`).
- **Zes mutaties, één voor één ingebracht, om te controleren dat die tests
  onderscheidend zijn.** Geen enkele bleef groen:

  | Mutatie | Uitkomst |
  |---|---|
  | selectie verbreed naar `User.all` | 10 failures |
  | `already_set?` altijd `false` | 1 failure |
  | de proefdraai-guard weggehaald | 1 failure |
  | de apply-guard van `undo` weggehaald | 1 failure |
  | de transactie weggehaald | 1 failure (`Expected: "all", Actual: "none"` op het account dat vóór de fout geschreven was) |
  | de naam van het mislukte account weggehaald | 1 failure |

- RuboCop op de gewijzigde bestanden: **0 offences** op de twee bestanden die
  gelint worden (`lib/redmine/ldap_notification_defaults.rb` en de test).
  Baseline was ook 0: beide bestanden zijn nieuw.
  `lib/tasks/**` staat in de `Exclude` van Redmine's eigen `.rubocop.yml` en
  wordt dus niet geïnspecteerd — dat is precies waarom de logica uit het
  `.rake`-bestand is gehaald (F04).
- `tools/check-geoxyz-branch.sh`: **PASS** — actueel met `origin/7.0-stable`,
  21 eigen commits, geen AI-sporen, 0 lint-offences op 49 gewijzigde
  Ruby-bestanden, locales binnen en/nl/fr/de/es.
- **De branch is bijgewerkt met upstream `7.0-stable`** (32 commits achter,
  nu 0). Dat gaf één echt conflict, in `config/locales/fr.yml`: upstream heeft
  intussen de sleutels vertaald die op deze branch nog Engels stonden.
  Opgelost zoals CLAUDE.md het voorschrijft — upstream wint op de gedeelde
  sleutels, en de twee eigen GEOxyz-sleutels (`webhook_trackers_info`,
  `setting_my_page_max_issuequery_blocks`) blijven staan. `fr.yml` parset.
- **G9, in een echte browser tegen een draaiende Redmine** (dev-instance,
  `verify/ldap-mail-prefs.mjs`, gebruiker `dev` met authenticatiebron
  "GEOxyz LDAP", gebruiker `admin` lokaal als controle):

  | Wat | Screenshot | Wat je ziet |
  |---|---|---|
  | LDAP-account vóór de run | `before-ldap-account.png` | "For any event on all my projects", zelfmelding uit, alle drie de auto-watch vinkjes aan |
  | LDAP-account ná `apply=1` | `after-ldap-account.png` | "No events", zelfmelding aan, alle drie de vinkjes uit — zelfde pagina, zelfde account |
  | LDAP-account na de undo | `undone-ldap-account.png` | weer precies de beginstand — **byte-identiek** aan `before-ldap-account.png` (md5 `508f8391…`) |
  | Lokaal account vóór en ná | `before-local-account.png`, `after-local-account.png` | authenticatiemodus "Internal", instellingen onveranderd — de twee bestanden zijn **byte-identiek** (md5 `4376803b…`) |
  | Lokaal account na de undo | `undone-local-account.png` | zelfde inhoud; het bestand verschilt 26 bytes van de andere twee zonder zichtbaar verschil, dus hier claim ik gelijke inhoud en geen gelijke bytes |

- **De foutpaden zijn ook echt gedraaid**, tegen dezelfde instance, elk met
  exit 1:

  | Aanroep | Uitvoer |
  |---|---|
  | `mail_notification=silent` | `mail_notification must be one of all, selected, …, got "silent".` |
  | `auto_watch_on=everything` | `auto_watch_on takes issue_created, …, got everything.` |
  | `no_self_notified=maybe` | `no_self_notified must be one of 1, true, yes, 0, false, no, got "maybe".` |
  | geen enkel veld genoemd | `Give at least one of mail_notification, no_self_notified, auto_watch_on; nothing to set.` |
  | geen enkel account met authenticatiebron | `No account has an authentication source; nothing to do.` |
  | `undo` met een niet-bestaand journaal | `/tmp/nope.json does not exist.` |

- **Tweede run direct achter de eerste** (idempotentie, F06): `SKIP:   dev
  already set` / `SKIP:   tester already set`, en `0 of 2 accounts changed,
  2 already set` — geen enkele schrijfactie.

## Wat Jan nog moet doen

Twee dingen, allebei eenmalig, en de tweede is niet dringend.

1. **De taak draaien op productie na de volgende LDAP-import.** Eerst zonder
   `apply=1`, de uitvoer lezen, en pas daarna met `apply=1`. Welke waarden je
   meegeeft is jouw keuze; `mail_notification=none no_self_notified=1
   auto_watch_on=` is de volledige demping. Bewaar het journaalbestand dat de
   run noemt — dat is het enige waarmee de run terug te draaien is.
2. **De twee Redmine-instellingen eenmalig goed zetten** in Beheer →
   Instellingen → Gebruikers: "geen melding van eigen wijzigingen" en de
   standaard auto-watch-vinkjes (`default_users_no_self_notified`,
   `default_users_auto_watch_on`). Die gelden alleen bij het **aanmaken** van
   een gebruiker (`user_preference.rb`, binnen `if new_record?`), dus ze
   vervangen de taak niet — ze zorgen dat je hem na de volgende import niet
   opnieuw voor dezelfde reden hoeft te draaien. Voor `mail_notification`
   bestaat zo'n instelling niet; dat blijft werk voor de taak.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Gaat **nooit** naar upstream. De taak is nu wel generiek genoeg om te kunnen
  (geen hardcoded groepsnaam meer), maar "zet in bulk de voorkeuren van andermans
  accounts" is geen functie die Redmine core wil, en de reviewer kwam op
  hetzelfde uit. Niet opnieuw voorstellen.
- **De selectie is `auth_source_id IS NOT NULL` en filtert niet op status.**
  Geblokkeerde en nog niet geactiveerde LDAP-accounts krijgen de waarden dus
  ook. Dat is bij dit doel juist; bij het oude doel was het een fout. Zie
  `decisions.md`.
- **Een weggelaten veld wordt niet geschreven.** Dat is een keuze, geen
  vergetelheid: `mail_notification=none` alleen laat de andere twee met rust.
- **`user.save!(:validate => false)` staat er met opzet.** LDAP-beheerde
  accounts halen Redmine's eigen validaties niet altijd (bijvoorbeeld een
  ontbrekend mailadres) en de taak moet ze toch kunnen zetten. Haal het er niet
  uit.
- **`user.pref.save!` is een aparte `save`**, want `has_one :preference` in
  `app/models/user.rb` staat niet op `:autosave => true`.
- **Het journaal wordt twee keer geschreven**, leeg vóór de lus en gevuld erna.
  Dat is geen slordigheid: een journaalpad waar niet naartoe geschreven kan
  worden moet falen vóórdat het eerste account verandert, niet erna.
- **Een account zonder opgeslagen voorkeurenrij** krijgt bij het lezen de
  waarden die `UserPreference#initialize` uit de Redmine-instellingen afleidt.
  Het journaal legt dus de *effectieve* vorige waarden vast, en een undo maakt
  voor zo'n account een voorkeurenrij aan die er eerst niet was. Het gedrag is
  identiek; alleen de rij is nieuw.
- De rest van de afwegingen staat in `decisions.md`, inclusief wat van
  2026-09-03 vervallen is.

## Volgende stap voor een sessie

af — niets te doen. Jan heeft twee handelingen openstaan, zie hierboven.
