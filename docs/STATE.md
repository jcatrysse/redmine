# STATE — waar staan we

> Het geheugen tussen sessies. Aan het einde van **elke** sessie volledig
> bijgewerkt (overschreven, niet aangevuld). Schrijf het alsof de volgende
> sessie niets weet.

## Huidige positie

De eerste feature is af: **`wiki-export-attachments`**. Patch klaar tegen trunk
r24882, dezelfde wijziging staat als één commit op `7.0-stable-GEOxyz`, dossier
compleet, screenshots gemaakt en gelezen. Jan moet er nog een issue voor
aanmaken op redmine.org.

Bewijs: volledige suite op de GEOxyz-branch **helemaal groen** (5917 runs,
0 failures, 0 errors). Op trunk 27 failures + 2 errors, maar dat is exact
dezelfde set als op een schone trunk zonder patch — 29 repository-tests die
op deze machine falen omdat `svn`, `hg`, `bzr` en `cvs` niet geïnstalleerd
zijn. Op `7.0-stable` falen diezelfde bestanden niet; dat verschil is een
trunk-wijziging (`Setting.enabled_scm`), niet iets van ons. Staat in het
dossier onder "Found but not fixed".

Daarvoor is `7.0-stable-GEOxyz` bijgewerkt naar upstream `7.0-stable`
(`a7fe622f9` → `ffc731ed7`, fast-forward, geen conflicten). Die branch had nul
eigen commits en heeft er nu één.

Wat er onderweg aan het gereedschap is veranderd — allemaal omdat het echt
misging, niet op voorhand bedacht:

- `tools/dev-server.sh` wijst elke worktree naar één map voor bijlagen. Zonder
  dat verdwenen bijlagen stil zodra de dev-server van worktree wisselde, en
  leek de feature niet te werken terwijl de code klopte. **Dit is precies
  waarvoor G9 bestaat.**
- `tools/test-env.sh` is nieuw. `test:all` gaf ~260 fouten die niets met de
  patch te maken hadden: de systeemtests vinden geen `chrome` op `PATH` en de
  chromedriver in het image is vier majors te nieuw. Nu draaien ze echt.
- `tools/check-patch-clean.sh` controleert nu ook de **auteur** van de commits,
  niet alleen het bericht. `git format-patch` zet de auteur in de `From:`-regel
  van het bestand dat aan het issue hangt; "Claude <noreply@anthropic.com>"
  daar is net zo goed een AI-spoor (INV-4). Commits op `patch/<slug>` en
  `7.0-stable-GEOxyz` worden nu geschreven als Jan Catrysse.
- `tools/dev-seed.rb` zet nu ook wiki-bijlagen klaar, waaronder twee met
  dezelfde bestandsnaam op één pagina — dat is het botsingsgeval.
- Er zijn nu drie testdatabases (`redmine_test`, `redmine_test_geoxyz`,
  `redmine_test_base`), zodat de trunk-patch, de GEOxyz-branch en een schone
  trunk-referentie tegelijk kunnen draaien in plaats van na elkaar.

## Volgende stap

**Jan:** maak het issue aan op redmine.org als follow-up van
[#43978](https://www.redmine.org/issues/43978) en hang er
`patches/wiki-export-attachments/2026-09-01-r24882-feature.patch` en
`-locales.patch` aan. De issuetekst staat kant-en-klaar in het dossier
(`docs/features/wiki-export-attachments.md`, alles onder "The problem"). Vul
daarna het issuenummer in het register en in het dossier in.

**Volgende sessie:** de volgende regel uit het register is
`search-token-limit`. `wiki-export-txt` (de andere helft van de oude
`wiki-export`-regel) kan ook, maar zie K-03 — die kandidaat is zwakker en Jan
mag zeggen of hij hem überhaupt wil indienen.

## Feature-register

Twee kolommen, want elke feature heeft twee leveringen. **GEOxyz** = staat het
in productie op 7.0? **Upstream** = waar staat de patch?

- GEOxyz: `todo` · `live` (commit op de branch) · `n.v.t.`
- Upstream: `todo` · `ontworpen` · `patch klaar` · `ingediend` · `geaccepteerd` ·
  `afgewezen` · `nooit` (alleen-lokaal) · `vervallen`

| Slug | Feature | 5.1-commit | GEOxyz | Upstream | Patch | Issue |
|---|---|---|---|---|---|---|
| `wiki-export-attachments` | Bijlagen mee in de wiki-ZIP-export | `3c3e9368e` (deel) | live | patch klaar | `patches/wiki-export-attachments/2026-09-01-r24882-{feature,locales}.patch` | — |
| `wiki-export-txt` | Hele wiki als één TXT-bestand | `3c3e9368e` (deel) | todo | todo | — | — |
| `search-token-limit` | Configureerbare max zoektokens i.p.v. hardcoded 5 | `17528437d` | todo | todo | — | — |
| `assignee-nobody` | "Niet toegewezen" combineerbaar met gekozen gebruikers | `9b03b74b2` | todo | todo | — | — |
| `version-subprojects` | Doelversiefilter incl. subproject-versies | `89752a599` | todo | todo | — | — |
| `mypage-query-blocks` | Configureerbaar max issuequery-blokken op Mijn pagina | `0214f3ecc` | todo | todo | — | — |
| `webhook-tracker-filter` | Webhook beperken tot gekozen trackers | `25220b45d` (deel) | todo | todo | — | — |
| `webhook-issue-closed` | Apart `issue.closed`-event | `25220b45d` (deel) | todo | todo | — | — |
| `members-pagination` | Paginatie op projectleden en groepsleden | `455f5753c` | todo | todo | — | — |
| `revision-branches` | Git-branches op revisie- én issuepagina | `cf826e3fd` | todo | todo | — | — |
| `imap-oauth` | IMAP inbound mail via OAuth 2.0 (Gmail / O365) | `bbf5c0eb3` | todo | todo | — | — |
| `geoxyz-hosts` | `*.geoxyz.eu` toestaan in development | `918f3466e` | todo | nooit | — | — |
| `gitignore-credentials` | `master.key` / `credentials.yml.enc` negeren | `8ec9951d3` | todo | nooit | — | — |
| `ldap-mail-prefs` | Rake: mailvoorkeuren dempen voor LDAP-only users | `9e2c38e2d` | todo | nooit | — | — |
| `ar-sessions` | Sessies in de database | `ea61e37e8` + `c2fefd51c` | todo | nooit | — | — |
| `database-yml-erb` | ERB in `database.yml` bij bundle install | `7ffcdcafc` | todo (laag) | nooit | — | — |
| `netimap-cve` | net-imap gem-bump | `92312960c` | n.v.t. | vervallen | — | — |
| `auto-watch-defaults` | Configureerbare auto-watch defaults | `b2adb8053` | n.v.t. | geaccepteerd | — | — |

Achttien regels (`wiki-export` is gesplitst in twee). Eén af, elf te gaan
upstream, vijf nooit, één vervallen, één al binnen.

## Wat er per feature al bekend is

Uit de doorlichting van PR #1. Dit zijn geen nieuwe bevindingen maar
vertrekpunten — bij elke feature hoort de trunk-check (G1) nog te gebeuren.

- **`wiki-export-attachments`** — af. De trunk-check bleek beslissend: trunk
  heeft sinds r24605 (#43978, april 2026) al een ZIP-export van de wiki, en de
  indiener daarvan schreef er expliciet bij dat hij bijlagen bewust wegliet
  omdat ze "additional design questions" opwerpen — archiefstructuur,
  naamconflicten, en verwijzingen naar bijlagen in de tekst. Het dossier
  beantwoordt die drie. Zonder die check hadden we de 5.1-vorm gebouwd (een
  eigen `export_attachments`-actie naast de bestaande export) en was de patch
  vrijwel zeker afgewezen.
- **`wiki-export-txt`** — nog te doen, zie K-03. Trunk heeft nu per pagina een
  `.txt` in de ZIP, dus de vraag "wat voegt één samengevoegd bestand toe" komt
  gegarandeerd.
- **`assignee-nobody`** — de 5.1-aanpak zet een pseudo-waarde in de generieke
  `Query#assigned_to_values` en behandelt die in een `elsif` in
  `Query#statement`, alleen voor operator `=`. Bij `!` en bij de
  history-operatoren (`ev`, `!ev`, `cf`, die al in 5.1 bestonden) belandt de
  string `'none'` in een vergelijking met een integerkolom → `500` op
  PostgreSQL. Reproduceerbaar. Upstream-vorm: een echte
  `sql_for_assigned_to_id_field` op `IssueQuery`, dekkend voor alle operatoren
  van `list_optional_with_history`. En de twee rode tests horen bij deze
  feature.
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

- **De trunk-mirror loopt achter.** `origin/master` staat op r24882 van
  2026-08-03; vandaag is 2026-09-01. Redmine's bron is SVN en deze fork
  synchroniseert niet vanzelf. Altijd verse fetch vóór een patch, en de
  revisie noemen in het issue.
- **De sessie-omgeving zet je op een verkeerde branch.** Elke sessie krijgt een
  eigen `claude/...`-branch die de framework-commits mist. Meteen
  `git checkout geoxyz/framework` en `git merge --ff-only origin/geoxyz/framework`.
- **Bijlagen leven per worktree, de dev-database niet.** Opgelost in
  `dev-server.sh` (`/tmp/redmine-dev-files`), maar weet waarom: een bijlage die
  je uploadt terwijl worktree A draait, is onleesbaar vanuit worktree B, en
  `Attachment#readable?` laat hem dan stil vallen. Zo lijkt een correcte
  feature stuk.
- **`test:all` is waardeloos zonder `tools/test-env.sh`** — ~260 fouten in de
  systeemtests die niets met je patch te maken hebben.
- **Alleen git is beschikbaar als SCM.** `svn`, `hg`, `bzr` en `cvs` staan niet
  in het image, dus die repository-suites skippen of falen ongeacht je patch.
  Vergelijk met een schone trunk-run voor je iets aan een patch toeschrijft.
- **`lib/tasks/**/*` is uitgesloten in Redmine's `.rubocop.yml`.** Rake-code
  wordt dus niet gelint. Daar is menselijke review de enige controle.
- **Redmine laadt hele suites in één proces.** Een testbestand dat
  `minitest/autorun` gebruikt, een `.rake` `load`t, of een constante buiten de
  autoloader definieert, vervuilt zijn buren. Draai testbestanden dus altijd
  ook samen.
- **`config/database.yml` bestaat niet** in de repo en is gitignored; die moet
  je zelf aanmaken, en wel vóór `bundle install`. Gebruik een tweede database
  (`redmine_test_geoxyz`) voor de GEOxyz-worktree, dan draaien beide suites
  tegelijk.
- **RuboCop leest de working tree, niet een ref.** Lint dus altijd binnen een
  worktree die op de juiste commit staat.
- **Een geaccepteerde trunk-patch komt niet in 7.0-stable.** Redmine backportt
  geen features naar een stable branch. Elke GEOxyz-commit blijft dus nodig tot
  GEOxyz zelf naar de release met die feature gaat.
- **Attributie hoort alleen op deze branch**, en dat geldt ook voor de
  commit-**auteur**, niet alleen de trailers. Zie K-01 en de wachter.
- **`origin/ansifi/learn-and-test-7.0`** is referentiemateriaal, geen basis.
