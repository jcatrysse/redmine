# STATE — waar staan we

> Het geheugen tussen sessies. Aan het einde van **elke** sessie volledig
> bijgewerkt (overschreven, niet aangevuld). Schrijf het alsof de volgende
> sessie niets weet.

## Huidige positie

Twee features af. De tweede is **`search-token-limit`**, deze sessie gebouwd,
bewezen en klaar. Patch tegen trunk r24882, dezelfde wijziging als één commit
op `7.0-stable-GEOxyz` (`1c85728aa`), dossier compleet, tien screenshots
gemaakt en gelezen. Er hangt één keuze voor Jan aan (K-04).

**Het belangrijkste van deze sessie is de trunk-check, niet de code.** Het issue
bestaat al: [#43701](https://www.redmine.org/issues/43701), door Jan aangemaakt
op 2026-01-21, met de 5.1-patch eraan, en in zeven maanden geen enkele reactie.
Die patch voegt een instelling `search_token_limit` toe (51,6 kB, 48
locale-bestanden) om een limiet te overrulen.

Wat de git-geschiedenis van trunk laat zien: die limiet van vijf tokens is
nooit voor filters bedacht. Tot r21238 (2021-10-05, #35148) stond het
tokeniseren inline in `Redmine::Search::Fetcher#initialize` en eindigde het op
`@tokens.slice! 5..-1` — een grens van de **zoekmachine**, die per token een
LIKE over elke soort en elk project legt. Die commit verplaatste het blok
woordelijk naar een nieuwe klasse `Tokenizer` zodat tekstfilters en de
issue-autocomplete het tokeniseren konden hergebruiken, en de limiet ging mee.
Sindsdien gooien vijf filteroperatoren (`~`, `!~`, `*~`, `^`, `$`) stil alles
weg wat een gebruiker na het vijfde woord typt.

Dus geen instelling. De patch zet de vijf terug bij de enige caller die hem
nodig heeft:

    -        @tokens = Tokenizer.new(@question).tokens
    +        # no more than 5 tokens to search for
    +        @tokens = Tokenizer.new(@question).tokens.first(5)

    -        # no more than 5 tokens to search for
    -        tokens.uniq.select{|w| ... }.first 5
    +        tokens.uniq.select{|w| ... }

Vier regels in één bestand. `app/models/query.rb` en `app/models/issue.rb`
worden niet aangeraakt: die roepen `Tokenizer.new(value).tokens` al aan en
krijgen nu alles terug. Geen instelling, geen migratie, geen route, geen
permissie, en **geen enkele nieuwe string** — dus ook geen locale-patch en geen
tweede patchbestand. Het exportbestand is 114 regels tegen 51,6 kB.

Geen enkele bestaande test in trunk legde die vijf vast, dus er breekt niets —
het tegenovergestelde van `wiki-export-attachments`, dat twee trunk-tests
veranderde.

Bewijs: trunk met patch 5924 runs / 31456 assertions / 27 failures / 2 errors,
schone trunk 5920 / 31452 / 27 / 2 — **test voor test dezelfde 29 namen**, alle
29 repository- of changeset-tests die `svn`, `hg`, `bzr` of `cvs` nodig hebben
(niet in het image). De patch voegt precies 4 runs en 4 assertions toe.
GEOxyz-branch **helemaal groen**: 5925 runs, 31738 assertions, 0 failures,
0 errors. RuboCop 0, baseline 0, aan beide kanten.

De trunk-suite is daarna nog één keer gedraaid op exact de geëxporteerde commit
(twee testmethodes verplaatst, verder identiek) en gaf toen 3 errors in plaats
van 2. De derde is `OauthProviderSystemTest`, een Selenium-race in Chrome
(*"Node with given id does not belong to the document"*) terwijl twee volledige
suites samen op vier cores liepen. Los gedraaid op dezelfde commit: 1 run,
13 assertions, 0 failures. Staat zo in het dossier — niet weggemoffeld, en ook
niet "flaky" genoemd zonder het na te lopen.

G9 heeft de fout zichtbaar gemaakt in een echte browser, en dat is het
overtuigendste stuk van het dossier: `before-filter-contains.png` toont het
filter "Subject contains: pump alignment survey report northern zzz" met
daaronder één resultaat, issue #7 "Pump alignment survey report northern wind
farm" — een issue dat `zzz` niet bevat. Na de patch: "No data to display". De
twee zoekpagina-screenshots markeren de gebruikte tokens en daar zijn er
precies vijf gemarkeerd, voor én na: dat is het bewijs dat de grens van de
zoekmachine blijft staan.

`tools/dev-seed.rb` zaait nu ook één issue met een onderwerp van zeven woorden.
Zonder dat kon G9 de fout niet laten zien: geen bestaand gezaaid onderwerp is
lang genoeg om een filter meer dan vijf bruikbare tokens te geven.

## Volgende stap

**Jan, twee dingen:**

1. Hang `patches/search-token-limit/2026-09-02-r24882-feature.patch` als note
   aan het bestaande issue [#43701](https://www.redmine.org/issues/43701) en
   leg in één alinea uit waarom de vorm veranderd is: geen instelling meer, het
   is de limiet terugzetten waar hij hoort. De Engelse tekst staat kant-en-klaar
   in `docs/features/search-token-limit.md`, alles vanaf "The problem". De
   voor/na-screenshots zitten in `docs/features/search-token-limit/shots/`.
   Vergeet niet de oude bijlage als achterhaald te benoemen.
2. Beantwoord **K-04** in `docs/DECISIONS.md`: heeft GEOxyz meer dan vijf
   zoekwoorden nodig in het globale zoekvak, of alleen in de filters? Wij
   bouwden "alleen in de filters". Niet blokkerend.

Ook nog open van de vorige sessie: het issue voor `wiki-export-attachments` is
nog niet aangemaakt. Dat is een follow-up van
[#43978](https://www.redmine.org/issues/43978) met twee patchbestanden.

**Volgende sessie:** `assignee-nobody`, de volgende regel in het register.
Daar is al iets van bekend, zie "Wat er per feature al bekend is": de
5.1-aanpak geeft een `500` op PostgreSQL bij de operatoren `!`, `ev`, `!ev` en
`cf`, en dat is reproduceerbaar. Reken erop dat dat een echte bug is die bij
deze feature hoort.

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
| `assignee-nobody` | "Niet toegewezen" combineerbaar met gekozen gebruikers | `9b03b74b2` | todo | todo | — | — |
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

Achttien regels. **Twee af**, negen te gaan upstream, vijf nooit, twee
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
