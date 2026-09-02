# STATE — waar staan we

> Het geheugen tussen sessies. Aan het einde van **elke** sessie volledig
> bijgewerkt (overschreven, niet aangevuld). Schrijf het alsof de volgende
> sessie niets weet.

## Huidige positie

Drie features af. De derde is **`assignee-nobody`**, deze sessie gebouwd,
bewezen en klaar. Patch tegen trunk r24882
(`patches/assignee-nobody/2026-09-02-r24882-feature.patch`, één bestand,
252 regels), dezelfde wijziging als één commit op `7.0-stable-GEOxyz`
(`9d28be94d`), dossier compleet, veertien screenshots gemaakt en gelezen.
**K-05 is beslist** (2026-09-02, optie A): `<< niemand >>` komt alleen in de
lijst van het toewijzingsfilter. Dat is wat er al gebouwd is, dus er is geen
code veranderd. Er zijn geen open keuzes meer.

**Wat het doet:** in het filter "Toegewezen aan" kun je nu `<< niemand >>`
aanvinken náást echte gebruikers. "Toegewezen aan mij **of** nog aan niemand"
is daarmee één filter in plaats van twee aparte lijsten.

**Net als vorige sessie was de trunk-check beslissend.** Het issue bestaat al:
[Patch #5535](https://www.redmine.org/issues/5535), aangemaakt in **2010**,
status nog altijd New, met Feature #28924 eraan gekoppeld als duplicaat. Jan
heeft er op 2025-11-22 zelf de 5.1-patch aan gehangen. In zestien jaar staan er
maar twee inhoudelijke opmerkingen van een committer op, en allebei sturen het
ontwerp:

1. **Jean-Baptiste Barth (2010):** "I'd prefer a generic solution which would
   consist in having a `<< none >>` option in some fields: assigned to, target
   version, category, etc. But only when it makes sense." En: de patch van 2010
   raakte ook `author_id`, want die deelde toen de waardelijst — "not the
   correct behavior, since author cannot be none".
2. **Marius Bălteanu (2018):** "Which will be the difference between 'Assignee
   None' and 'Assignee Is \<nobody\>'?" — beantwoord in dezelfde draad door
   Radek Antoniuk: je wil "issues assigned to me + the queue".

Daarom zit de afhandeling **generiek** in `Query#sql_for_field`, niet in een
eigen `sql_for_assigned_to_id_field`: elke filter van type `list_optional` of
`list_optional_with_history` leest de waarde `'none'` nu als "deze kolom is
NULL". Alleen de *lijst* van de toewijzing is aangesloten — dat is K-05, en Jan
koos optie A. Doelversie en categorie werken dus al via een URL
(`?v[fixed_version_id][]=none`) maar krijgen geen eigen ingang in het
filterformulier; het dossier zegt de reviewer expliciet dat dat één regel per
lijst is en dat de keuze de zijne is. Barths eerste punt is vanzelf verdwenen:
trunk heeft al jaren een aparte `Query#author_values`.

**Het tweede probleem, dat pas zichtbaar wordt als de waarde bestaat.** Het
toewijzingsfilter biedt **zeven** operatoren aan (`=`, `!`, `ev`, `!ev`, `cf`,
`!*`, `*`), en de waardelijst is voor alle zeven dezelfde. De patches op #5535,
inclusief die van Jan, behandelen `'none'` alleen bij `=`. Bij vier van de
overige operatoren belandt de string in een vergelijking met de integerkolom
`issues.assigned_to_id` → `PG::InvalidTextRepresentation` → **HTTP 500**. Bij
`cf` geen fout maar een stil lege lijst, want `journal_details.old_value` is een
tekstkolom waar niets gelijk is aan `'none'`. Die stille variant is erger dan de
500. Alle zeven zijn nu gedekt; de before-screenshots tonen vijf keer een echte
500-pagina en één keer "No data to display".

**Bewijs.** Trunk met patch 5798 runs / 30700 assertions / 27 failures /
2 errors, schone trunk 5790 / 30686 / 27 / 2 — **de 29 faalnamen zijn letterlijk
identiek** (`diff` leeg), allemaal repository- of changeset-tests die `svn`,
`hg`, `bzr` of `cvs` nodig hebben. GEOxyz-branch **helemaal groen**: 5803 runs,
30987 assertions, 0 failures, 0 errors. RuboCop 0 aan beide kanten, baseline
ook 0. `tools/check-patch-clean.sh` PASS, `tools/check-geoxyz-branch.sh` PASS.

**Twee bestaande trunk-tests aangepast, geen enkele verzwakt.**
`test_assigned_to_values_should_be_sorted_by_status_and_name` telt met `[1..]`
de pseudo-waarden weg vóór de echte gebruikers; dat wordt `[2..]`.
`QueriesControllerTest#test_assignee_filter_should_return_active_and_locked_users_grouped_by_status`
telt de JSON-waarden: 6 → 7, met één `assert_include` erbij zodat de reden in de
test zelf staat. **Die tweede is alleen gevonden doordat G3 de volledige suite
eist** — de aangeraakte bestanden waren groen, en de eerste volledige run gaf
28 failures in plaats van 27. Dat is precies waar die gate voor is.

Geen nieuwe instelling, migratie, route, permissie of gem, en **geen enkele
nieuwe string**: `label_nobody` bestaat al in alle 63 locale-bestanden, en
`assigned_to_id => 'none'` is al wat Redmine zelf gebruikt in het
bulk-bewerkformulier en het contextmenu. Dus geen locale-patch en geen tweede
patchbestand.

`tools/dev-seed.rb` zaait nu ook een issue toegewezen aan `tester` en een issue
dat van niemand naar `dev` ging mét journal. Zonder de eerste heeft
"niemand of dev" niets om uit te sluiten; zonder de tweede hebben de
historie-operatoren geen journalregel om te vinden.

## Volgende stap

**Jan, één ding:** hang
`patches/assignee-nobody/2026-09-02-r24882-feature.patch` als note aan het
bestaande issue [#5535](https://www.redmine.org/issues/5535) en leg in één
alinea uit wat er anders is aan deze vorm: de afhandeling zit generiek in
`sql_for_field` (dat is wat Barth in noot 4 vroeg) en alle zeven operatoren zijn
gedekt in plaats van alleen `=`. Noem je eigen bijlage van november als
achterhaald. De Engelse tekst staat kant-en-klaar in
`docs/features/assignee-nobody.md`, alles vanaf "The problem"; de voor/na-paren
staan in `docs/features/assignee-nobody/shots/`.

**Nog open van eerdere sessies, allebei alleen jouw handeling:**

- `search-token-limit` — `patches/search-token-limit/2026-09-02-r24882-feature.patch`
  hangen aan [#43701](https://www.redmine.org/issues/43701), met de uitleg dat
  de instelling eruit is.
- `wiki-export-attachments` — het issue is nog niet aangemaakt. Follow-up van
  [#43978](https://www.redmine.org/issues/43978), twee patchbestanden.

**Er zijn geen open keuzes meer.** K-05 (krijgen "Doelversie" en "Categorie"
ook een `<< niemand >>`?) is beslist op optie A: nee, alleen de toewijzing.

**Volgende sessie:** `version-subprojects`, de volgende regel in het register.
Wat er al van bekend is staat onder "Wat er per feature al bekend is": de
5.1-override vervangt `project.shared_versions` door
`Version.visible.where(project_statement)` en verliest daarmee versies die van
elders gedeeld zijn (`sharing: 'system'`), gereproduceerd. Union in plaats van
vervanging.

## Feature-register

Twee kolommen, want elke feature heeft twee leveringen. **GEOxyz** = staat het
in productie op 7.0? **Upstream** = waar staat de patch?

- GEOxyz: `todo` · `live` (commit op de branch) · `n.v.t.`
- Upstream: `todo` · `ontworpen` · `patch klaar` · `ingediend` · `geaccepteerd` ·
  `afgewezen` · `nooit` (alleen-lokaal) · `vervallen`

| Slug | Feature | 5.1-commit | GEOxyz | Upstream | Patch | Issue |
|---|---|---|---|---|---|---|
| `wiki-export-attachments` | Wiki-ZIP genest naar de wikiboom + bijlagen als exportoptie | `3c3e9368e` (deel) | live (`28c618860`) | patch klaar | `patches/wiki-export-attachments/2026-09-01-r24882-{feature,locales}.patch` | — (follow-up van #43978) |
| `wiki-export-txt` | Hele wiki als één TXT-bestand | `3c3e9368e` (deel) | n.v.t. | vervallen | — | — |
| `search-token-limit` | Tekstfilters negeren geen zoekwoorden meer na het vijfde | `17528437d` | live (`1c85728aa`) | patch klaar | `patches/search-token-limit/2026-09-02-r24882-feature.patch` | [#43701](https://www.redmine.org/issues/43701) (bestaat, patch nog niet vervangen) |
| `assignee-nobody` | "Niet toegewezen" combineerbaar met gekozen gebruikers | `9b03b74b2` | live (`9d28be94d`) | patch klaar | `patches/assignee-nobody/2026-09-02-r24882-feature.patch` | [#5535](https://www.redmine.org/issues/5535) (bestaat sinds 2010, patch nog niet vervangen) |
| `version-subprojects` | Doelversiefilter incl. subproject-versies | `89752a599` | todo | todo | — | — |
| `mypage-query-blocks` | Configureerbaar max issuequery-blokken op Mijn pagina | `0214f3ecc` | todo | todo | — | — |
| `webhook-tracker-filter` | Webhook beperken tot gekozen trackers | `25220b45d` (deel) | todo | todo | — | — |
| `webhook-issue-closed` | Apart `issue.closed`-event | `25220b45d` (deel) | todo | todo | — | — |
| `members-pagination` | Paginatie op projectleden en groepsleden | `455f5753c` | todo | todo | — | #43355 (aanhaken) |
| `revision-branches` | Git-branches op revisie- én issuepagina | `cf826e3fd` | todo | todo | — | — |
| `imap-oauth` | IMAP inbound mail via OAuth 2.0 (Gmail / O365) | `bbf5c0eb3` | todo | todo | — | — |
| `geoxyz-hosts` | `*.geoxyz.eu` toestaan in development | `918f3466e` | todo | nooit | — | — |
| `gitignore-credentials` | `master.key` / `credentials.yml.enc` negeren | `8ec9951d3` | todo | nooit | — | — |
| `ldap-mail-prefs` | Rake: mailvoorkeuren dempen voor LDAP-only users | `9e2c38e2d` | todo | nooit | — | — |
| `ar-sessions` | Sessies in de database | `ea61e37e8` + `c2fefd51c` | todo | nooit | — | — |
| `database-yml-erb` | ERB in `database.yml` bij bundle install | `7ffcdcafc` | todo (laag) | nooit | — | — |
| `netimap-cve` | net-imap gem-bump | `92312960c` | n.v.t. | vervallen | — | — |
| `auto-watch-defaults` | Configureerbare auto-watch defaults | `b2adb8053` | n.v.t. | geaccepteerd | — | — |

Achttien regels. **Drie af**, acht te gaan upstream, vijf nooit, twee
vervallen, één al binnen.

## Wat er per feature al bekend is

Uit de doorlichting van PR #1. Dit zijn geen nieuwe bevindingen maar
vertrekpunten — bij elke feature hoort de trunk-check (G1) nog te gebeuren.

- **`wiki-export-attachments`** — af. De trunk-check bleek beslissend: trunk
  heeft sinds r24605 (#43978, april 2026) al een ZIP-export van de wiki, en de
  indiener daarvan schreef er expliciet bij dat hij bijlagen bewust wegliet
  omdat ze "additional design questions" opwerpen — archiefstructuur,
  naamconflicten, en verwijzingen naar bijlagen in de tekst. Het dossier
  beantwoordt die drie.
- **`search-token-limit`** — af. De trunk-check was hier opnieuw beslissend,
  maar op een andere manier: niet "bestaat het al?" maar "wanneer is die
  constante er gekomen en waarom?". Het antwoord (r21238, een refactor die het
  blok woordelijk verplaatste) veranderde de patch van een instelling in een
  fix van vier regels. **Dat is het patroon dat de volgende features moeten
  volgen: zoek de commit die de regel invoerde, niet alleen de regel.**
- **`wiki-export-txt`** — vervallen. GEOxyz gebruikt de TXT-export niet. Niet
  opnieuw afwegen.
- **`assignee-nobody`** — af. De verwachting uit de doorlichting klopte, met
  één correctie: `cf` geeft géén 500 maar stil nul resultaten, omdat
  `journal_details.old_value` een tekstkolom is. Vier van de zeven operatoren
  gaven wél een 500. De verwachte upstream-vorm (een eigen
  `sql_for_assigned_to_id_field` op `IssueQuery`) is bij het bouwen verworpen:
  die zou de journal-subquery van de historie-operatoren moeten dupliceren. Het
  is generiek in `Query#sql_for_field` geworden, wat niet groter is, geen kopie
  heeft en bovendien letterlijk beantwoordt wat de enige committer op #5535 in
  2010 vroeg.
- **`version-subprojects`** — de override vervangt `project.shared_versions`
  door `Version.visible.where(project_statement)` en verliest daarmee versies
  die van elders gedeeld zijn (`sharing: 'system'` is niet meer filterbaar,
  gereproduceerd). Union in plaats van vervanging.
- **`revision-branches`** — vier bezwaren, alle vier terecht: een
  git-subproces per pageview (Redmine cachet changesets juist om de SCM buiten
  het renderen te houden), alleen de Git-adapter van zes, vier nieuwe
  instellingen, en een groeperingsheuristiek die een GEOxyz-branchconventie in
  core bakt. **Jan kiest bewust om dit niet vooraf in te binden**: Git-only, het
  commando blijft, de vier instellingen blijven, en we wachten hun reactie af.
  De bezwaren horen dus wél in het dossier onder "verwachte bezwaren", met per
  bezwaar het antwoord en wat het alternatief zou kosten.
- **`imap-oauth`** — de bestaande 5.1-rake is 435 regels met tien methodes en
  een constante op `Object`, print het access token volledig bij
  `imap_debug=1`, en trekt `gmail_xoauth` binnen terwijl
  `Net::IMAP::XOauth2Authenticator` al in de gepinde `net-imap` zit
  (nagekeken: 0.6.6 heeft hem, en 5.1's 0.4.24 had hem al). Upstream-vorm is
  vermoedelijk geen nieuwe taakfamilie maar opties op de bestaande
  `receive_imap` plus configuratie in `configuration.yml`.
- **`members-pagination`** — leeft al upstream als #43355 (Takenori). De
  GEOxyz-toevoeging is de groepsleden-lijst en de gescheiden
  `members_page`/`users_page` parameters. Aanhaken op dat issue.

## Bekende valkuilen

- **Doe de trunk-check op de *herkomst* van een constante, niet alleen op het
  bestaan van de feature.** `search-token-limit` werd een vierregelige fix in
  plaats van een instelling omdat `git log -S` liet zien wanneer en waarom die
  `.first 5` daar terechtkwam. `git log --oneline -S "<de code>" -- <bestand>`
  is het commando, en daarna de commit zelf lezen.
- **Zoek ook op redmine.org vóór je begint.** Voor deze feature bestond al een
  issue van Jan zelf (#43701), met de 5.1-patch eraan. Dat verandert de
  inzending van "nieuw issue" in "note met een betere patch, en zeg waarom".
- **De trunk-mirror loopt achter.** `origin/master` staat op r24882 van
  2026-08-03. Redmine's bron is SVN en deze fork synchroniseert niet vanzelf.
  Altijd verse fetch vóór een patch, en de revisie noemen in het issue.
- **De sessie-omgeving zet je op een verkeerde branch.** Elke sessie krijgt een
  eigen `claude/...`-branch. Meteen `git checkout geoxyz/framework` en
  `git merge --ff-only origin/geoxyz/framework`. Deze sessie stond de vorige
  sessie zijn werk op de `claude/...`-branch en op `geoxyz/framework`, dus de
  lokale `geoxyz/framework` liep 14 commits achter — fast-forwarden loste dat op.
- **De worktrees zijn er niet meer bij een nieuwe sessie.** De container is
  leeg. Opnieuw aanmaken, en per worktree een `config/database.yml` schrijven
  **vóór** `bundle install` (de Gemfile leest dat bestand). Kost ~5 minuten per
  worktree; start ze parallel in de achtergrond.
- **Ook de remote branches zijn er niet.** `git ls-remote --heads origin` en dan
  gericht fetchen: `7.0-stable-GEOxyz`, `7.0-stable`, `5.1-stable-GEOxyz` (daar
  staan de 5.1-commits), `ansifi/learn-and-test-7.0`, `master`.
- **`dev-server.sh` schrijft `config/database.yml` alleen als het niet bestaat.**
  Heb je er al een met alleen een `test:`-sectie (voor de suite), dan mist de
  `development:`-sectie en start de dev-server niet. Zelf toevoegen.
- **Er is één dev-database en één poort.** Voor/na-screenshots gaan dus na
  elkaar: eerst de dev-server op een schone-trunk-worktree voor de
  `before-`shots, dan stoppen en opnieuw starten op de patch-worktree. Doe dat
  **niet** met `git stash` in een worktree waar op dat moment een suite loopt.
- **Bijlagen leven per worktree, de dev-database niet.** Opgelost in
  `dev-server.sh` (`/tmp/redmine-dev-files`), maar weet waarom: een bijlage die
  je uploadt terwijl worktree A draait, is onleesbaar vanuit worktree B, en
  `Attachment#readable?` laat hem dan stil vallen.
- **De volledige suite is niet optioneel, en dat is deze sessie bewezen.** De
  aangeraakte testbestanden waren groen; de volledige run vond
  `QueriesControllerTest#test_assignee_filter_should_return_active_and_locked_users_grouped_by_status`,
  dat het *aantal* waarden in de filter-JSON telt. Elke feature die een
  waardelijst uitbreidt raakt zulke tests, en ze staan nooit in het bestand dat
  je aan het bewerken bent.
- **Zoek een bestaand issue op redmine.org met één trefwoord, niet met een
  zin.** `titles_only=1` plus meerdere woorden is een AND over de titel en geeft
  nul resultaten; *unassigned filter* vond niets bruikbaars, *nobody filter*
  vond #5535 en #28924 meteen. Twee sessies op rij bleek er al een issue te
  bestaan, dus dit is de regel en niet de uitzondering.
- **Een filterwaarde die niet in de `<select>` staat, kan de browser niet
  selecteren.** In een before-screenshot valt de widget dan terug op de eerste
  optie (`<< me >>`) terwijl de URL iets anders vroeg. Dat is echt bewijs, geen
  kapotte check — maar assert er niet op in `MODE=before`, en zeg het in het
  dossier, anders leest de screenshot verkeerd.
- **`git worktree` + een draaiende suite + een dev-server op dezelfde worktree
  gaan prima samen** zolang ze verschillende databases hebben. Wat níét kan is
  de working tree wijzigen terwijl de suite loopt; om een test rood te bewijzen
  op de oude code, kopieer `app/models/query.rb` weg, `git checkout --` het
  bestand, draai, en zet het terug — met de volledige suite *niet* actief.
- **`test:all` is waardeloos zonder `tools/test-env.sh`** — ~260 fouten in de
  systeemtests die niets met je patch te maken hebben.
- **Alleen git is beschikbaar als SCM.** `svn`, `hg`, `bzr` en `cvs` staan niet
  in het image, dus 29 repository- en changeset-tests falen op trunk ongeacht je
  patch. Draai altijd een tweede volledige suite op een schone trunk-worktree
  (`redmine_test_base`) en `diff` de lijst met faalnamen; dat is het enige
  sluitende bewijs. Op `7.0-stable` falen diezelfde bestanden niet.
- **Drie testdatabases** (`redmine_test`, `redmine_test_geoxyz`,
  `redmine_test_base`) zodat de patch, de GEOxyz-branch en de schone
  trunk-referentie tegelijk kunnen draaien. Met 4 cores lopen twee suites
  comfortabel parallel, drie is krap.
- **Het filterformulier van Redmine is JavaScript.** De filterrij is
  `div.filter#tr_<veld>` in `#filters-table`, aangemaakt door `addFilter()`, en
  de gekozen operator en de waarde staan alleen in de DOM-*properties*, niet in
  de HTML. In Playwright dus `inputValue()` op `#operators_<veld>` en
  `#values_<veld>`, niet `getAttribute`. Een selector op `tr#tr_<veld>` vindt
  niets.
- **`lib/tasks/**/*` is uitgesloten in Redmine's `.rubocop.yml`.** Rake-code
  wordt dus niet gelint.
- **Redmine laadt hele suites in één proces.** Draai testbestanden dus altijd
  ook samen.
- **RuboCop leest de working tree, niet een ref.** Lint dus altijd binnen een
  worktree die op de juiste commit staat.
- **Een geaccepteerde trunk-patch komt niet in 7.0-stable.** Elke GEOxyz-commit
  blijft dus nodig tot GEOxyz zelf naar de release met die feature gaat.
- **Attributie hoort alleen op deze branch**, en dat geldt ook voor de
  commit-**auteur**. Zie K-01 en `tools/check-patch-clean.sh`.
- **Amend en push in de juiste volgorde op `7.0-stable-GEOxyz`.** Deze sessie is
  daar één keer een commit ge-amend *nadat* hij al gepusht was, wat een
  force-push nodig maakte — precies wat de regel "nooit rebasen op deze branch"
  wil voorkomen. Risico was nul (de tussenversie stond een paar minuten op de
  remote en niemand kan die gehaald hebben), maar doe het niet opnieuw: lees je
  eigen diff adversarieel **voor** de eerste push, of zet een correctie in een
  tweede commit.
- **`origin/ansifi/learn-and-test-7.0`** is referentiemateriaal, geen basis.
