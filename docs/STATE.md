# STATE — waar staan we

> Het geheugen tussen sessies. Aan het einde van **elke** sessie volledig
> bijgewerkt (overschreven, niet aangevuld). Schrijf het alsof de volgende
> sessie niets weet.

## Huidige positie

Vier features af. De vierde is **`version-subprojects`**, deze sessie gebouwd,
bewezen en klaar. Patch tegen trunk r24882
(`patches/version-subprojects/2026-09-03-r24882-feature.patch`, vijf bestanden,
175 regels), dezelfde wijziging als twee commits op `7.0-stable-GEOxyz`
(`20ed9e2d1` + `d157934c0`), dossier compleet, acht screenshots gemaakt en
gelezen. Er zijn geen open keuzes.

**Wat het doet:** een projectissuelijst toont standaard ook de issues van zijn
subprojecten. Die issues kunnen een doelversie hebben die van een subproject is
en met niemand gedeeld — de kolom "Doelversie" toont hem, maar het *filter*
"Doelversie" bood hem niet aan. Nu wel, precies voor zover die subprojecten in
de query zitten.

**De trunk-check was voor de derde sessie op rij beslissend, en deze keer op de
scherpst mogelijke manier.** Het issue bestaat al —
[#43534](https://www.redmine.org/issues/43534), door Jan aangemaakt op
2025-11-26 — en **Go MAEDA, een kerncommitter, heeft op 2026-04-01 zelf een
bijgewerkte patch bijgevoegd** (`43534-v2.patch`, "Updated the patch for the
current trunk"). Dat is de sterkste indicatie die je kunt krijgen dat upstream
de feature wil.

**En toch bevatten beide bestaande patches dezelfde regressie.** Ze *vervangen*
`project.shared_versions` door `Version.visible.where(project_statement)`. Dat
wint de subprojectversies en verliest elke versie die van búiten de bevraagde
boom naar het project gedeeld is: `sharing: 'system'`, en versies die van een
voorouder of over een boom heen gedeeld zijn. In Redmine's eigen fixtures zakt
het filter van project 1 daardoor van zes waarden naar vier — de systeembreed
gedeelde versie 7 ("OnlineStore - Systemwide visible version") en de gedeelde
versie 6 van het privé-subproject verdwijnen allebei, zonder waarschuwing. Deze
patch maakt er een **vereniging** van. De bijbehorende test
(`test_fixed_version_filter_should_include_versions_shared_from_outside_the_project_tree`)
is groen op kale trunk en op deze patch, en rood op `43534-v2.patch` met
`"7" not found in ["3", "4", "2", "1"]`. Dat is het inhoudelijke argument voor
de note aan Jan's issue.

**Drie kleinere verbeteringen op de bestaande patches.**

1. De wijziging staat in `Query#fixed_version_values`, niet als override op
   `IssueQuery` zoals de 5.1-commit deed. De methode is sinds r16170 (#24787,
   2017, "Don't preload all query filters") generiek, en dus krijgt het filter
   `issue.fixed_version_id` van `TimeEntryQuery` hem er gratis bij. Diezelfde
   commit is ook de reden dat er een AJAX-endpoint bestaat: sinds r16170 worden
   lambda-waardelijsten pas opgehaald als je het filter toevoegt.
2. `q.build_from_params(params)` staat **ná** de `raise Unauthorized`, niet
   ervoor. Het bouwen van de query evalueert `available_filters` en draait
   daarmee meerdere queries voor een verzoek dat geweigerd gaat worden.
3. De JavaScript zoekt het formulier via `$('#filters-table').closest('form')`.
   De 5.1-patch noemde vijf formulier-id's, `43534-v2.patch` noemt er één
   (`#query_form`); beide missen `#query-form` (met streepje) van
   `queries/new` en `queries/edit` — precies de pagina waar je een query mét
   subprojectfilter opslaat.

**Bewijs.** Trunk met patch 5796 runs / 30701 assertions / 27 failures /
2 errors, schone trunk 5790 / 30684 / 27 / 2 — de **29 faalnamen zijn letterlijk
identiek** (`diff` leeg), allemaal repository-, changeset- en
`SysController`-tests die `svn`, `hg`, `bzr` of `cvs` nodig hebben.
GEOxyz-branch **helemaal groen**: 5809 runs, 31001 assertions, 0 failures,
0 errors. RuboCop 0 aan beide kanten, baseline ook 0.
`tools/check-patch-clean.sh` PASS, `tools/check-geoxyz-branch.sh` PASS.

Vier van de zes nieuwe tests zijn rood bewezen op de oude code. De twee andere
zijn bewakers: ze zijn groen op trunk én op deze patch, en de belangrijkste
ervan is rood op het afgewezen alternatief — dat is precies wat een bewaker
hoort te doen, en het staat zo in het dossier.

**Na Jans vraag "werkt dit ook als subproject-issues standaard niet getoond
worden?" is één test aangescherpt.** Het antwoord is ja:
`Query#project_statement` kijkt eerst of er een `subproject_id`-filter staat en
valt pas dán terug op de instelling, dus een expliciet subprojectfilter
overstemt de instelling. Nagemeten in het model voor `=`, `!` en `*`, en in de
browser voor de AJAX-weg met de instelling op `0`.
`test_fixed_version_filter_should_respect_selected_subprojects` draaide op de
standaardinstelling, waar het subproject toch al in scope zat; hij draait nu met
`display_subprojects_issues => '0'` en bewijst daarmee dat het filter de lijst
*verbreedt* voorbij de instelling in plaats van alleen binnen die instelling te
versmallen. Rood op trunk met `"8" not found in ["3", "4", "6", "7", "2", "1"]`.
Beide volledige suites zijn daarna opnieuw gedraaid met dezelfde cijfers. Op de
patchbranch is die wijziging in de bestaande commit ge-amend (hij moet één
commit blijven voor `git format-patch`, force-push met `--force-with-lease`); op
`7.0-stable-GEOxyz` staat hij in een **tweede** commit, want daar wordt niet
gerebased.

**Geen nieuwe instelling, migratie, route, permissie, gem of string.** Dus geen
locale-patch en één patchbestand.

`tools/dev-seed.rb` zaait nu ook een tweede subproject, een project buiten de
boom met een systeembreed gedeelde versie, en een subproject-issue op de eigen
versie van dat subproject. Zonder het tweede subproject kun je niet tonen dat
één gekozen subproject de versie van het ándere uitsluit; zonder de gedeelde
versie van buiten kan een screenshot de regressie niet weerleggen.

## Volgende stap

**Jan, één ding:** hang
`patches/version-subprojects/2026-09-03-r24882-feature.patch` als note aan je
eigen issue [#43534](https://www.redmine.org/issues/43534), en schrijf erbij dat
`43534-v2.patch` van Go MAEDA een regressie bevat: het vervangt
`project.shared_versions` in plaats van er een vereniging van te maken, waardoor
versies die van buiten de projectboom gedeeld zijn stil uit het filter
verdwijnen — met Redmine's eigen fixtures gaat project 1 van zes naar vier
waarden. Noem de test die het vastlegt. De Engelse tekst staat kant-en-klaar in
`docs/features/version-subprojects.md`, alles vanaf "The problem"; de
voor/na-paren staan in `docs/features/version-subprojects/shots/`.

**Nog open van eerdere sessies, allemaal alleen jouw handeling:**

- `search-token-limit` — `patches/search-token-limit/2026-09-02-r24882-feature.patch`
  hangen aan [#43701](https://www.redmine.org/issues/43701), met de uitleg dat
  de instelling eruit is.
- `assignee-nobody` — `patches/assignee-nobody/2026-09-02-r24882-feature.patch`
  hangen aan [#5535](https://www.redmine.org/issues/5535), met de uitleg dat de
  afhandeling generiek in `sql_for_field` zit en dat alle zeven operatoren
  gedekt zijn in plaats van alleen `=`.
- `wiki-export-attachments` — het issue is nog niet aangemaakt. Follow-up van
  [#43978](https://www.redmine.org/issues/43978), twee patchbestanden.

**Volgende sessie:** `mypage-query-blocks`, de volgende regel in het register.
Wat er al van bekend is: de 5.1-commit `0214f3ecc` maakt het maximumaantal
issuequery-blokken op "Mijn pagina" configureerbaar. Doe eerst de trunk-check op
de *herkomst* van die limiet (`git log --oneline -S "<de code>" -- <bestand>`),
en zoek op redmine.org met **één** trefwoord — drie sessies op rij bleek er al
een issue te bestaan.

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
| `version-subprojects` | Doelversiefilter incl. subproject-versies | `89752a599` | live (`20ed9e2d1` + `d157934c0`) | patch klaar | `patches/version-subprojects/2026-09-03-r24882-feature.patch` | [#43534](https://www.redmine.org/issues/43534) (bestaat, Go MAEDA werkte de patch bij; onze versie repareert een regressie erin) |
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

Achttien regels. **Vier af**, zeven te gaan upstream, vijf nooit, twee
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
  fix van vier regels.
- **`wiki-export-txt`** — vervallen. GEOxyz gebruikt de TXT-export niet. Niet
  opnieuw afwegen.
- **`assignee-nobody`** — af. Generiek in `Query#sql_for_field`, alle zeven
  operatoren gedekt; vier ervan gaven een HTTP 500 met de bestaande patches en
  `cf` gaf stil nul resultaten.
- **`version-subprojects`** — af. De verwachting uit de doorlichting klopte
  precies: de override vervangt in plaats van te verenigen en verliest daarmee
  `sharing: 'system'`. Wat de doorlichting *niet* wist, is dat dezelfde fout in
  de patch zit die een kerncommitter in april zelf heeft bijgewerkt en aan het
  issue heeft gehangen — dus die fout is nu het inhoudelijke argument van onze
  note, niet alleen een interne verbetering.
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

- **Zoek op redmine.org vóór je begint, met één trefwoord.** Drie sessies op
  rij bestond er al een issue, en deze keer had een **kerncommitter er zelf al
  aan gewerkt**. Dat verandert de inzending van "nieuw issue" in "note met een
  betere patch, en zeg precies waarom". `titles_only=1` plus meerdere woorden
  is een AND over de titel en geeft nul resultaten.
- **Lees de patch die al aan het issue hangt, ook als een committer hem heeft
  bijgewerkt.** `43534-v2.patch` is van Go MAEDA en bevat een regressie die met
  Redmine's eigen fixtures aantoonbaar is. Een bijgewerkte patch van een
  committer is een sterk signaal dat de feature gewenst is, geen bewijs dat de
  implementatie klopt. Download hem (`/attachments/download/<id>/<naam>`), pas
  hem toe in een wegwerp-worktree en draai jouw tests ertegen.
- **Doe de trunk-check op de *herkomst* van een constante of methode, niet
  alleen op het bestaan van de feature.** `git log --oneline -S "<de code>" --
  <bestand>` wees hier r16170 aan, en die ene commit verklaarde zowel waarom de
  methode generiek hoort te zijn als waarom er überhaupt een AJAX-endpoint is.
- **De trunk-mirror loopt achter.** `origin/master` staat op r24882 van
  2026-08-03. Redmine's bron is SVN en deze fork synchroniseert niet vanzelf.
  Altijd verse fetch vóór een patch, en de revisie noemen in het issue.
- **De sessie-omgeving zet je op een verkeerde branch.** Elke sessie krijgt een
  eigen `claude/...`-branch. Meteen `git checkout geoxyz/framework` en
  `git merge --ff-only origin/geoxyz/framework`.
- **De worktrees zijn er niet meer bij een nieuwe sessie.** De container is
  leeg. Opnieuw aanmaken, en per worktree een `config/database.yml` schrijven
  **vóór** `bundle install` (de Gemfile leest dat bestand). Schrijf meteen ook
  een `development:`-sectie erin, anders start de dev-server later niet — 
  `dev-server.sh` schrijft het bestand alleen als het nog niet bestaat. Kost
  ~4 minuten per worktree; start ze parallel in de achtergrond.
- **Ook de remote branches zijn er niet.** `git ls-remote --heads origin` en dan
  gericht fetchen: `master`, `7.0-stable`, `7.0-stable-GEOxyz`,
  `5.1-stable-GEOxyz` (daar staan de 5.1-commits), `ansifi/learn-and-test-7.0`.
- **Drie testdatabases** (`redmine_test`, `redmine_test_geoxyz`,
  `redmine_test_base`) zodat de patch, de GEOxyz-branch en de schone
  trunk-referentie tegelijk kunnen draaien. Met 4 cores lopen twee suites
  comfortabel parallel, drie is krap. Eén volledige suite duurt ~9 minuten.
- **Wijzig de working tree niet terwijl de suite daar loopt.** Deze sessie is de
  patch-suite één keer herstart omdat RuboCop een naamgevingsoffence
  (`version_1` → `version1`, `Naming/VariableNumber`) in een testbestand
  aanwees nadat de run al begonnen was. Lint dus *vóór* je de suite start.
- **Er is één dev-database en één poort.** Voor/na-screenshots gaan dus na
  elkaar: eerst de dev-server op de schone-trunk-worktree (`base`) voor de
  `before-`shots, dan stoppen en opnieuw starten op de patch-worktree. Een
  dev-server op een worktree waar tegelijk een suite draait is prima — andere
  database.
- **Verander het verify-script niet meer nadat de before-shots gemaakt zijn.**
  Doe je het toch, draai dan beide kanten opnieuw, anders vergelijk je twee
  verschillende renderingen. Deze sessie gebeurde dat één keer.
- **Een `<select multiple>` opent op een vaste hoogte.** De opties eronder
  staan wél in de DOM en zijn dus assert-baar, maar staan **niet op de
  screenshot** — en G9 gaat over de afbeelding. Zet `el.size` op het aantal
  opties voordat je schiet.
- **Een filterwaarde die niet in de `<select>` staat, kan de browser niet
  selecteren.** In een before-screenshot valt de widget dan terug op de eerste
  optie terwijl de URL iets anders vroeg. Dat is echt bewijs, geen kapotte
  check — maar assert er niet op in `MODE=before`, en zeg het in het dossier.
- **De eerste `dev-seed.rb`-run na `load_default_data` kan op een nested-set
  fout stuiten** (`Project#shared_versions` leest `r.lft`, dat nog nil is voor
  een net aangemaakt subproject). De tweede run loopt schoon door; de seed is
  idempotent. Controleer dus na `dev-server.sh` dat de gezaaide rijen er echt
  zijn in plaats van op PASS te vertrouwen.
- **Het filterformulier van Redmine is JavaScript.** De filterrij is
  `div.filter#tr_<veld>` in `#filters-table`, aangemaakt door `addFilter()`, en
  de gekozen operator en de waarde staan alleen in de DOM-*properties*. In
  Playwright dus `inputValue()` op `#operators_<veld>` en `#values_<veld>`.
- **Twee formulier-id's, niet één.** Lijstpagina's gebruiken `#query_form`
  (underscore), `queries/new` en `queries/edit` gebruiken `#query-form`
  (streepje). `$('#filters-table').closest('form')` dekt allebei zonder een
  lijst bij te houden.
- **De volledige suite is niet optioneel.** Bij `assignee-nobody` vond alleen de
  volledige run de test die filterwaarden telt. Bij deze feature was de
  volledige run schoon, maar dat weet je pas achteraf.
- **Alleen git is beschikbaar als SCM.** `svn`, `hg`, `bzr` en `cvs` staan niet
  in het image, dus 29 repository-, changeset- en `SysController`-tests falen op
  trunk ongeacht je patch. Draai altijd een tweede volledige suite op een schone
  trunk-worktree (`redmine_test_base`) en `diff` de lijst met faalnamen. Op
  `7.0-stable` falen diezelfde bestanden niet — daar is de suite echt 0/0.
- **`test:all` is waardeloos zonder `tools/test-env.sh`** — ~260 fouten in de
  systeemtests die niets met je patch te maken hebben.
- **`lib/tasks/**/*` is uitgesloten in Redmine's `.rubocop.yml`.**
- **Redmine laadt hele suites in één proces.** Draai testbestanden dus altijd
  ook samen.
- **RuboCop leest de working tree, niet een ref.** Lint dus altijd binnen een
  worktree die op de juiste commit staat.
- **Een geaccepteerde trunk-patch komt niet in 7.0-stable.** Trunk staat nog op
  `7.0.0 devel`, dus deze patches landen in 7.1 of later. Elke GEOxyz-commit
  blijft nodig tot GEOxyz zelf naar die release gaat.
- **Attributie hoort alleen op deze branch**, en dat geldt ook voor de
  commit-**auteur**. Commits op `patch/<slug>` en `7.0-stable-GEOxyz` staan op
  naam van `Jan Catrysse <jan.catrysse@geoxyz.eu>`. Zie K-01 en
  `tools/check-patch-clean.sh`.
- **`git checkout -- <bestand>` haalt HEAD terug, niet trunk.** Zodra je op de
  patchbranch gecommit hebt, herstelt dat dus je eigen wijziging en lijkt een
  nieuwe test ten onrechte groen op "de oude code". Gebruik
  `git checkout origin/master -- <bestand>`. Kostte deze sessie één verkeerde
  rood-bewijs-run; het eerdere bewijs klopte wel, want dat liep vóór de commit.
- **PostgreSQL kan tussen commando's door omvallen** in deze container (een test
  faalde met "Connection refused" terwijl er niets aan de hand was).
  `service postgresql start` en opnieuw; het is geen probleem met je patch.
- **Lees je eigen diff adversarieel vóór de eerste push.** Een amend na een push
  vraagt een force-push, precies wat "nooit rebasen op deze branch" wil
  voorkomen. Zet een correctie liever in een tweede commit.
- **`origin/ansifi/learn-and-test-7.0`** is referentiemateriaal, geen basis.
