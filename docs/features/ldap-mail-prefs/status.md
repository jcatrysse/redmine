---
slug: ldap-mail-prefs
feature: "Rake: notificatievoorkeuren van LDAP-accounts zetten na een import"
commit_51: 9e2c38e2d
geoxyz: live
geoxyz_commit: bc7314a62 + 5b4943570 + f00b41afd + ae2417a6e
upstream: nooit
patch:
issue: 
---

# ldap-mail-prefs — status

## Waar het staat

Ronde 3 (blinde herreview, 2026-09-08) is gedaan en haar drie bevindingen zijn
op 2026-09-09 opgelost, één major en twee kleinere. De major was een echte:
**`apply=0` schreef.** De veiligheidsklep van deze taak is "schrijf niets tenzij
ik het zeg", en die stond op `options['apply'].present?` — en `"0".present?` is
`true`, dus `apply=0`, `apply=false` en `apply=no` schreven alle drie. Dat is nu
dicht, aan de `run`- én de `undo`-kant, en er zijn zeven tests die het rood
maken op de oude code. Zie "Bewijs — ronde 3".

Ronde-2 fix is af. Alle elf reviewbevindingen van 2026-09-03 hebben een
`Resolution:`-regel; twee blockers en drie majors zijn opgelost, één nit is
vervallen omdat het onderdeel dat hij aanwees niet meer bestaat. De taak is
herbouwd op Jans gecorrigeerde doel (g01): **na een LDAP-import de
notificatie-instellingen van de LDAP-accounts op de gewenste waarde zetten**,
eenmalig, geen cron. Gaat nooit naar upstream, dus geen dossier en geen patch.

Op `7.0-stable-GEOxyz` staan er voor deze feature **drie** commits:
`add935736` (de oorspronkelijke taak, 2026-09-03), `bc7314a62` (de herbouw na
ronde 2) en `5b4943570` (de drie ronde-3-fixes, 2026-09-09). Dat is met opzet:
elke vorige was al gepusht en geschiedenis op die branch wordt niet
herschreven, want dat maakt elke checkout van GEOxyz ongeldig. Het registerveld
noemt de twee die nog iets toevoegen, `bc7314a62 + 5b4943570`.

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
waarden terug — maar **alleen voor accounts die nog steeds hebben wat de run
schreef**. Wie daarna zelf iets anders koos, houdt zijn keuze; die accounts
worden overgeslagen en geteld.

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

## Bewijs — ronde 3 (2026-09-09)

**Wat er veranderd is, in drie stukken:**

1. **F01 (major) — `apply` gaat door `BOOLEANS`.** Dezelfde frozen tabel die
   `no_self_notified` al gebruikt: `1/true/yes` schrijft, `0/false/no`
   rapporteert, en iets anders (`apply=maybe`) breekt af met een melding in
   plaats van te schrijven. `apply` weglaten of `apply=` leeglaten blijft
   "alleen rapporteren", dus de gedocumenteerde veilige aanroep verandert niet.
2. **F02 (minor) — het gevulde journaal wordt binnen de transactie geschreven.**
   Stond erbuiten, dus tussen de commit en die schrijfactie was er een venster
   waarin de accounts gewijzigd waren en het bestand op schijf nog `"users": []`
   zei — precies het bestand waarmee je terugdraait.
3. **F03 (nit) — het journaal gaat naar `tmp/` in plaats van `log/`.**

**Cijfers:**

- **Zeven nieuwe tests, alle zeven eerst rood gedraaid op de oude code**, in één
  run: `35 runs, 63 assertions, 7 failures, 0 errors`. Met de fix erin:
  **`35 runs, 72 assertions, 0 failures, 0 errors, 0 skips`**. De verdeling van
  die zeven: vijf op F01 (`apply=0/false/no` mag niet schrijven, in `run` en in
  `undo`; `apply=maybe` moet werpen, in `run` en in `undo`), één op F02
  (journaal onschrijfbaar → geen enkel account gewijzigd), één op F03 (het
  standaardpad staat in `tmp/`).
- RuboCop 1.88.2: **0 offences** op de twee bestanden die Redmine's eigen
  `.rubocop.yml` inspecteert (baseline: 0). Het `.rake`-bestand staat in de
  `Exclude`; forceer je het er toch door, dan zijn het **5 offences vóór en 5
  ná** — allemaal de `<<-DESC`-heredoc die er al stond, dus niet van deze
  wijziging (INV-1).

**G9, echt gedraaid tegen een draaiende Redmine** (dev-instance op de fix,
gebruikers `dev` en `tester` met authenticatiebron "GEOxyz LDAP", `admin`
lokaal als controle). De vier schermafbeeldingen zijn één keten, en de md5's
zijn het bewijs:

| Stap | Screenshot | md5 | Wat het aantoont |
|---|---|---|---|
| beginstand | `before-apply-zero-ldap-account.png` | `ee23599d…` | "For any event on all my projects", zelfmelding uit, drie vinkjes aan |
| ná `apply=0` | `apply-zero-ldap-account.png` | `ee23599d…` | **byte-identiek** aan de beginstand — de run die vóór de fix alles schreef, schrijft nu niets |
| ná `apply=1` | `applied-ldap-account.png` | `a550441d…` | "No events", zelfmelding aan, drie vinkjes uit — **wél anders**, dus de vergelijking hierboven meet echt iets |
| ná `undo … apply=1` | `undone-after-fix-ldap-account.png` | `ee23599d…` | byte-identiek aan de beginstand |
| lokaal account, hele keten | `apply-zero-local-account.png` | `e97bef10…` | onveranderd, authenticatiemodus "Internal" |

En de opdrachtregel zelf, elk pad echt aangeroepen:

| Aanroep | Uitkomst |
|---|---|
| `apply=0` | `Reporting only. Add apply=1 to write.` + twee `WOULD UPDATE`-regels, exit 0, nul schrijfacties |
| `apply=false`, `apply=no` | idem — nul `UPDATE:`-regels |
| `apply=maybe` | `apply must be one of 1, true, yes, 0, false, no, got "maybe".`, **exit 1** |
| `apply=1` | twee `UPDATE:`-regels, `2 of 2 accounts changed` |
| `undo … apply=0` | `Reporting only.` + twee `WOULD RESTORE`-regels, en de accounts stonden erna nog steeds op `none` |
| `undo … apply=1` | twee `RESTORE:`-regels, beginstand terug |

**F03 met beide kanten aangetoond**, in dezelfde checkout:

```
$ git check-ignore -v tmp/ldap-notification-defaults-20260909-060909.json
.gitignore:36:/tmp/*    tmp/ldap-notification-defaults-20260909-060909.json
$ git check-ignore -v log/ldap-notification-defaults-20260909-060909.json
(niets — het bestand stond als `?? log/…json` in `git status`)
```

Dus het oude pad zette een bestand met alle logins erin als untracked in de
checkout, en `git add -A` had het gestaged. Het nieuwe pad niet.
**Wat `tmp/` níét oplost:** duurzaamheid. `tmp/` overleeft een deploy net zo min
als `log/`, en dat is geen codeprobleem — de taakbeschrijving zegt nu dat het
journaal het enige undo-bewijs is en vóór de volgende deploy ergens duurzaam
gekopieerd moet worden.

## Bewijs — Codex-ronde (2026-09-09)

**Wat er veranderd is:** `undo` vergelijkt nu vóór hij herstelt. Het journaal
legde altijd al vast *wat* de run schreef (`values`), naast de vorige waarden
per account, en die eerste werd niet gebruikt. Nu wordt een account alleen
teruggezet als het nog exact die geschreven waarden heeft, met dezelfde
`already_set?` die de forward-run gebruikt — dus één plek voor de
`auto_watch_on`-sortering en geen kans op drift tussen de twee richtingen. Een
conflict komt per regel als `SKIP:    <login> changed after the run, left alone
(now …)`, met een teller in de slotregel. Een journaal zonder `values` werpt
`Error` in plaats van stil onvoorwaardelijk te herstellen. Er is **geen**
force-optie.

**Cijfers:**

- **Vier nieuwe tests, alle vier rood op de oude undo**: de run zet `none`, de
  gebruiker kiest daarna `only_assigned`, en de undo moet dat account laten
  staan terwijl het tweede (onaangeraakt) wél teruggezet wordt; de slotregel
  moet `1 of 2 … 1 changed after the run` melden; een wijziging in slechts één
  van twee geschreven velden telt óók als gewijzigd; en een journaal zonder
  `values` moet werpen.
- Met de fix: **39 runs, 81 assertions, 0 failures, 0 errors, 0 skips**. De 35
  bestaande tests blijven groen, dus het gewone undo-pad is niet veranderd.
- RuboCop op de gewijzigde bestanden: **0**.
- Volledige suite op de branch: **6159 runs, 32502 assertions, 0 failures,
  0 errors, 39 skips**.

## Bewijs — Codex-ronde 2 (2026-09-09)

**Wat er veranderd is:** `undo` weigert nu het journaal van een **rapportagerun**.
De vergelijk-en-herstel uit de eerste ronde hierboven vertrouwde `values`, maar
keek niet of de run ook echt geschreven had. Een rapportagerun schrijft óók een
journaal — met `"applied": false` — en dan is "het account heeft nu precies de
voorgestelde waarden" geen bewijs dat de run ze gezet heeft: de gebruiker kan ze
zelf gekozen hebben. De undo herstelde dan de oude waarde over die keuze heen.
`undo` werpt daarom `Error` zodra `journal['applied']` niet exact `true` is, ook
zonder `apply=1`, want een "WOULD RESTORE"-rapport over zo'n journaal is op
zichzelf misleidend.

**Cijfers:**

- **Het verlies is nagemeten, niet beredeneerd.** Een wegwerp-probe deed de
  reeks uit de bevinding: rapportagerun met `mail_notification=none`, daarna
  jsmith zelf op `none`, daarna `undo … apply=1` met dat journaal. jsmith kwam
  terug op `all` — de eigen keuze weg. Dat is de bevinding, letterlijk.
- **De nieuwe test is rood zonder de guard**: `Error expected but nothing was
  raised`. Met de guard: **40 runs, 84 assertions, 0 failures, 0 errors,
  0 skips**.
- Geen journaal dat bestaat wordt hierdoor geweigerd: `'applied' => apply?`
  staat in de journaalschrijver sinds de eerste commit van het bestand
  (`bc7314a62`), dus er is geen ouder formaat om mild voor te zijn.
- RuboCop op de gewijzigde bestanden: **0**, baseline 0.

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

- **`undo` is een vergelijk-en-herstel, geen blinde herstel** (Codex F01,
  2026-09-09). Hij zet een account alleen terug als het nog steeds de waarden
  heeft die *die run* geschreven heeft; koos een gebruiker of beheerder daarna
  zelf iets anders, dan wordt dat account overgeslagen met
  `SKIP:    <login> changed after the run, left alone` en een teller in de
  slotregel. Niet "vereenvoudigen" naar onvoorwaardelijk herstellen: het
  journaal bevat de gezette waarden precies zodat dit te zien is, en een undo
  van een oud journaal zou anders stil een latere keuze wissen.
- **Het journaal van een rapportagerun kan niet ongedaan gemaakt worden**
  (Codex ronde 2, F01, 2026-09-09). `"applied": false` betekent dat de run niets
  geschreven heeft, dus is er niets van hem terug te nemen; dat het account nú
  de voorgestelde waarden heeft, zegt alleen dat iemand ze zelf gekozen heeft.
  Niet "milder maken" zodat zo'n journaal wél te rapporteren valt: het verlies
  is nagemeten en het is echt.
- **Een journaal zonder `values` wordt geweigerd.** Zonder dat veld kan een
  undo een gewijzigd account niet van een onaangeraakt account onderscheiden,
  en dan is stil het onveilige doen precies de fout die hierboven staat. Er is
  **geen** force-optie; die komt er alleen als de praktijk erom vraagt.

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
  worden moet falen vóórdat het eerste account verandert, niet erna. **Sinds
  ronde 3 staat die tweede schrijfactie binnen de transactie** (F02), zodat een
  journaal dat niet weggeschreven kan worden de accounts meeneemt in de
  rollback. De omgekeerde restfout blijft mogelijk en is met opzet de
  goedaardige kant: als de commit zelf faalt ná die schrijfactie, ligt er een
  journaal dat wijzigingen beschrijft die niet gebeurd zijn — een undo daarop
  zet dezelfde waarden terug die er al staan en meldt "already set".
- **`apply` is een booleaan uit `BOOLEANS`, niet `present?`** (ronde 3, F01).
  Niet terugdraaien naar `present?` of naar `== '1'`: het eerste maakte
  `apply=0` destructief, het tweede zou `apply=true` stil laten rapporteren.
  Weglaten en `apply=` leeg blijven "rapporteren"; alleen een niet-lege
  niet-booleaan werpt.
- **Het standaard journaalpad is `tmp/`, niet `log/`** (ronde 3, F03). Reden:
  `.gitignore` dekt `/tmp/*` volledig en van `log/` alleen `*.log*`. Niet
  terugzetten. Duurzaamheid is een deploy-afspraak, geen codekeuze — dat staat
  in de taakbeschrijving.
- **Een account zonder opgeslagen voorkeurenrij** krijgt bij het lezen de
  waarden die `UserPreference#initialize` uit de Redmine-instellingen afleidt.
  Het journaal legt dus de *effectieve* vorige waarden vast, en een undo maakt
  voor zo'n account een voorkeurenrij aan die er eerst niet was. Het gedrag is
  identiek; alleen de rij is nieuw.
- De rest van de afwegingen staat in `decisions.md`, inclusief wat van
  2026-09-03 vervallen is.

## Volgende stap voor een sessie

af — niets te doen. Ronde 3 is gedaan en alle drie haar bevindingen zijn
gesloten. Jan heeft twee handelingen openstaan, zie hierboven.
