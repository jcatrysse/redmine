# STATE — waar staan we

> Het geheugen tussen sessies. Aan het einde van **elke** sessie volledig
> bijgewerkt (overschreven, niet aangevuld). Schrijf het alsof de volgende
> sessie niets weet.

## Huidige positie

Het framework staat er, en er is nog **geen enkele Redmine-code aangeraakt**.
Wat eraan voorafging: een volledige doorlichting van PR #1 (Ansifs port van
`5.1-stable-GEOxyz` naar 7.0), inclusief het meten van beide branches. De
uitkomst bepaalt waarom dit framework zo is opgezet:

- Negen functionele bevindingen, **alle negen uit de originele 5.1-commits**,
  ongemerkt meegereisd in de port. De porter toetste "werkt het nog" in plaats
  van "is dit goed".
- Twee bestaande Redmine-tests staan rood op **beide** branches
  (`queries_controller_test.rb` assignee-count, `query_test.rb`
  `assigned_to_values[1..]`). Nooit opgemerkt omdat de volledige suite nooit
  gedraaid is.
- De port introduceerde 73 RuboCop-fouten op een bestandsset die er 0 had.
- Er is **nul CI gelopen** op die PR, terwijl de repo `linters.yml` en
  `tests.yml` heeft.

Vandaar INV-8 (bewezen groen) en G1 (trunk-check) als harde regels.

## Volgende stap

**Eerst**: `7.0-stable-GEOxyz` bijwerken met upstream `7.0-stable` — de branch
staat 5 commits achter en heeft nul eigen commits. `git merge`, nooit rebase.
`tools/check-geoxyz-branch.sh` meldt dit als eerste FAIL.

**Daarna**: analysefase, feature per feature, in de volgorde van het register.
Beginnen met `wiki-export` — de sterkste upstream-kandidaat, en de enige waar
de bestaande 7.0-implementatie al een aanknopingspunt biedt.

## Feature-register

Twee kolommen, want elke feature heeft twee leveringen. **GEOxyz** = staat het
in productie op 7.0? **Upstream** = waar staat de patch?

- GEOxyz: `todo` · `live` (commit op de branch) · `n.v.t.`
- Upstream: `todo` · `ontworpen` · `patch klaar` · `ingediend` · `geaccepteerd` ·
  `afgewezen` · `nooit` (alleen-lokaal) · `vervallen`

| Slug | Feature | 5.1-commit | GEOxyz | Upstream | Patch | Issue |
|---|---|---|---|---|---|---|
| `wiki-export` | Wiki TXT-export + ZIP met mappen en bijlagen | `3c3e9368e` | todo | todo | — | — |
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

Zeventien features. Upstream: tien kandidaten, vijf nooit, één vervallen, één
al binnen. GEOxyz: **vijftien nog te doen** — de branch heeft nu nul eigen
commits, dus geen enkele feature loopt op 7.0.

## Wat er per feature al bekend is

Uit de doorlichting van PR #1. Dit zijn geen nieuwe bevindingen maar
vertrekpunten — bij elke feature hoort de trunk-check (G1) nog te gebeuren.

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
- **`wiki-export`** — 7.0 heeft zelf al een vlakke ZIP-export op
  `wiki#export`; daarop voortbouwen, niet ernaast bouwen. De ZIP-opbouw hoort
  uit de controller naar `lib/redmine/export/`. `bulk_download_max_size` op de
  hele ZIP betekent dat een project met veel bijlagen de wiki niet meer kan
  exporteren — beslissen wat daar moet gebeuren.
- **`revision-branches`** — vier bezwaren, alle vier terecht: een
  git-subproces per pageview (Redmine cachet changesets juist om de SCM buiten
  het renderen te houden), alleen de Git-adapter van zes, vier nieuwe
  instellingen, en een groeperingsheuristiek die een GEOxyz-branchconventie in
  core bakt. **Jan kiest bewust om dit niet vooraf in te binden**: Git-only, het
  commando blijft, de vier instellingen blijven, en we wachten hun reactie af.
  De bezwaren horen dus wél in het dossier onder "verwachte bezwaren", met per
  bezwaar het antwoord en wat het alternatief zou kosten — dan kan het gesprek
  op redmine.org meteen inhoudelijk verder.
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

- **De trunk-mirror loopt achter.** `origin/master` stond op 2026-08-03 bij het
  opzetten van dit framework; vandaag is 2026-09-01. Redmine's bron is SVN.
  Altijd verse fetch vóór een patch, en de revisie noemen in het issue.
- **`lib/tasks/**/*` is uitgesloten in Redmine's `.rubocop.yml`.** Rake-code
  wordt dus niet gelint. Daar is menselijke review de enige controle.
- **Redmine laadt hele suites in één proces.** Een testbestand dat
  `minitest/autorun` gebruikt, een `.rake` `load`t, of een constante buiten de
  autoloader definieert, vervuilt zijn buren. In de bestaande port slagen vijf
  OAuth-testbestanden los en falen ze samen — draai testbestanden dus altijd
  ook samen.
- **SCM-tests skippen stil** als de git-testrepo niet uitgepakt is. Zie
  `docs/runbook.md`.
- **`config/database.yml` bestaat niet** in de repo en is gitignored; die moet
  je zelf aanmaken.
- **RuboCop leest de working tree, niet een ref.** Lint dus altijd binnen een
  worktree die op de juiste commit staat, anders rapporteert het schoon over
  bestanden die daar niet bestaan. `tools/check-geoxyz-branch.sh` deed dit eerst
  fout en meldde stil "0 offences"; gevonden door het te testen.
- **Een geaccepteerde trunk-patch komt niet in 7.0-stable.** Redmine backportt
  geen features naar een stable branch. Elke GEOxyz-commit blijft dus nodig tot
  GEOxyz zelf naar de release met die feature gaat.
- **`origin/ansifi/learn-and-test-7.0`** is referentiemateriaal, geen basis.
  Wat daar goed aan was: `.text.erb` i.p.v. `.txt.erb` voor de mime-mapping op
  Rails 8, `Group.named`, `identifier_param`, `safe_join`, `--no-color` op
  `git branch --contains`.
