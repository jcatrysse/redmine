# STATE — waar staan we

> Het geheugen tussen sessies. Aan het einde van **elke** sessie volledig
> bijgewerkt (overschreven, niet aangevuld). Schrijf het alsof de volgende
> sessie niets weet.

## Huidige positie

Vijf features af. De vijfde is **`mypage-query-blocks`**, deze sessie gebouwd,
bewezen en klaar. Twee patchbestanden tegen trunk r24882
(`patches/mypage-query-blocks/2026-09-03-r24882-{feature,locales}.patch`),
dezelfde wijziging als commit `198cbfb63` op `7.0-stable-GEOxyz`, dossier
compleet, twaalf screenshots gemaakt en gelezen. Er zijn geen open keuzes.

**Wat het doet:** op "Mijn pagina" mag je maximaal drie blokken met een eigen
zoekopdracht zetten. Dat getal staat sinds 2017 hard in
`Redmine::MyPage::CORE_BLOCKS`. Het wordt een instelling in Beheer →
Configuratie → Algemeen, met **3 als standaard**, dus voor wie niets instelt
verandert er niets.

**De trunk-check was voor de vierde sessie op rij beslissend, en bepaalde deze
keer het hele ontwerp.** Het issue bestaat al:
[#27313](https://www.redmine.org/issues/27313), "More custom queries on My
page", status New, target "Candidate for next major release". De
issuebeschrijving vraagt letterlijk om een instelling. Maar:

- **Go MAEDA** (kerncommitter) stelde in note-8 voor `max_occurs` van 3 naar 5
  te zetten en wees het issue toe aan Jean-Philippe Lang.
- **Jean-Philippe Lang** haalde op 2018-12-08 de toewijzing weg, zette de target
  op "Candidate for next major release" en schreef precies één zin: *"We should
  probably load content asynchronously before raising the number of queries that
  can be displayed."*

Dat bezwaar geldt nog steeds: `app/views/my/page.html.erb` in r24882 rendert elk
blok nog synchroon via `MyHelper#render_blocks`, en er bestaat **geen** issue
voor asynchroon laden (gezocht op `asynchronously`). Dus: een patch die het
getal verhoogt loopt recht tegen de projectleider aan. Een patch met **default
3** niet — die verhoogt voor niemand iets en geeft alleen de beheerder de knop.
Dat is de hele inzet van de note die Jan gaat schrijven, en het is ook wat
note-5 op datzelfde issue vraagt: Olivier Houdas wilde juist *minder* dan drie
kunnen instellen nadat vijf blokken met een auto-refresh zijn server plat
legden.

**Wat er beter is dan de 5.1-commit.** `0214f3ecc` herschreef `MyPage.blocks`
zelf en zette de blokknaam `'issuequery'` midden in die generieke accessor —
en `blocks` wordt vanuit `block_options` één keer per blok aangeroepen, dus
twee hash-merges per iteratie. Nu mag `:max_occurs` een **instellingsnaam**
zijn, opgelost in één nieuwe `Redmine::MyPage.max_occurs`, en verhuist de
literal 3 naar `config/settings.yml`. Eén bron voor de standaard, `blocks`
blijft wat hij was, en een blok met een gewoon getal in `:max_occurs` werkt
onveranderd.

**Bewijs.** Trunk met patch **5926 runs / 31483 assertions / 27 failures /
2 errors / 92 skips**, schone trunk **5920 / 31455 / 27 / 2 / 92** — de **29
faalnamen zijn identiek** (`diff` leeg), allemaal repository-, changeset- en
`SysController`-tests die `svn`, `hg`, `bzr` of `cvs` nodig hebben.
GEOxyz-branch **helemaal groen: 5945 / 31800 / 0 failures / 0 errors / 39
skips**. RuboCop 0 op de gewijzigde bestanden, baseline ook 0.
`tools/check-patch-clean.sh` PASS, `tools/check-geoxyz-branch.sh` PASS. Beide
patchbestanden applyen los op een schone trunk en samen reproduceren ze de
branch exact (`diff` leeg).

**Rood op de oude code, eerlijk gezegd.** Vijf van de zes nieuwe tests zijn
`with_settings`-tests en die geven op kale trunk `RuntimeError: There's no
setting named my_page_max_issuequery_blocks` — dat is de eerlijke vorm van rood
voor een nieuwe instelling: de mogelijkheid bestaat daar niet. De zesde,
`test_page_should_disable_issuequery_option_at_the_default_maximum`, is een
**bewaker**: bewust groen aan beide kanten, want hij legt vast dat de standaard
3 blijft — en dat is precies wat deze patch belooft.

**Twee dingen gevonden door de screenshots te lezen in plaats van te
genereren.** Een `<select>` toont alleen zijn gekozen regel, dus de
optietoestanden stonden eerst helemaal niet op de afbeelding (`el.size` zetten,
trap stond al in dit bestand). En erger: op 1280px is het verschil tussen een
grijze en een zwarte `<option>` een paar pixels tekstkleur, en
`getComputedStyle` geeft voor een `disabled` optie exact dezelfde kleur
(`rgb(33, 37, 41)`) als voor een actieve — de DOM kan het dus niet aantonen en
de assertion alleen bewijst niets wat een reviewer kan zien. Daarom staat er nu
naast elke paginabrede afbeelding een **uitsnede van het element**
(`select-*.png`), waar grijs versus zwart onmiskenbaar is.

**Bevinding, bewust niet gerepareerd (INV-1).** `MyHelper#block_select_tag`
rendert een uitgeschakelde optie als `<option disabled>Issues</option>`: Rails
laat een `nil`-attribuut weg, dus de DOM-property `value` valt terug op de
tekst van de optie ("Issues"). Nagekeken dat dat niets kapotmaakt:
`UserPreference#add_block` doet `block.to_s.underscore` → `"issues"`, en dat
staat niet in `block_options(...).map(&:last)`, dus `POST /my/add_block` met
`block=Issues` wordt geweigerd. Bestaat al in trunk, hoort niet in deze patch.

## Volgende stap

**Jan, één ding:** hang
`patches/mypage-query-blocks/2026-09-03-r24882-feature.patch` en
`-locales.patch` als note aan het **bestaande** issue
[#27313](https://www.redmine.org/issues/27313) — dus geen nieuw issue — en zeg
in die note expliciet dat dit note-9 van Jean-Philippe Lang beantwoordt: de
standaard blijft 3, er wordt voor niemand iets verhoogd, en het voor/na-paar
`docs/features/mypage-query-blocks/shots/{before-,}select-at-default-maximum.png`
is dezelfde afbeelding. De Engelse tekst staat kant-en-klaar in
`docs/features/mypage-query-blocks.md`, alles vanaf "The problem".

**Nog open van eerdere sessies, allemaal alleen jouw handeling:**

- `search-token-limit` — `patches/search-token-limit/2026-09-02-r24882-feature.patch`
  hangen aan [#43701](https://www.redmine.org/issues/43701), met de uitleg dat
  de instelling eruit is.
- `assignee-nobody` — `patches/assignee-nobody/2026-09-02-r24882-feature.patch`
  hangen aan [#5535](https://www.redmine.org/issues/5535), met de uitleg dat de
  afhandeling generiek in `sql_for_field` zit en dat alle zeven operatoren
  gedekt zijn in plaats van alleen `=`.
- `version-subprojects` — `patches/version-subprojects/2026-09-03-r24882-feature.patch`
  hangen aan [#43534](https://www.redmine.org/issues/43534), met de uitleg dat
  `43534-v2.patch` van Go MAEDA een regressie bevat (vervangt
  `project.shared_versions` in plaats van er een vereniging van te maken).
- `wiki-export-attachments` — het issue is nog niet aangemaakt. Follow-up van
  [#43978](https://www.redmine.org/issues/43978), twee patchbestanden.

**Volgende sessie:** `webhook-tracker-filter`, de volgende regel in het
register. Wat er al van bekend is: de 5.1-commit `25220b45d` doet twee dingen en
is bewust in twee issues gesplitst; deze helft beperkt de webhook tot gekozen
trackers. Doe eerst de trunk-check op de **herkomst** van de webhook-code zelf
(zit die überhaupt in core, of is het een plugin op de GEOxyz-branch?) en zoek
op redmine.org met **één** trefwoord — vier sessies op rij bleek er al een issue
te bestaan, en één keer had een kerncommitter er zelf al aan gewerkt.

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
| `mypage-query-blocks` | Max. eigen zoekopdrachten op Mijn pagina instelbaar, default 3 | `0214f3ecc` | live (`198cbfb63`) | patch klaar | `patches/mypage-query-blocks/2026-09-03-r24882-{feature,locales}.patch` | [#27313](https://www.redmine.org/issues/27313) (bestaat sinds 2017, geparkeerd door JPL — onze note beantwoordt zijn bezwaar) |
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

Achttien regels. **Vijf af**, zes te gaan upstream, vijf nooit, twee vervallen,
één al binnen.

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
- **`version-subprojects`** — af. De override vervangt in plaats van te
  verenigen en verliest daarmee `sharing: 'system'`. Diezelfde fout zit in de
  patch die een kerncommitter in april zelf heeft bijgewerkt en aan het issue
  heeft gehangen — dus die fout is nu het inhoudelijke argument van onze note.
- **`mypage-query-blocks`** — af. De trunk-check besliste het ontwerp: het
  bestaande issue #27313 is door de projectleider geparkeerd met één bezwaar,
  dat over *verhogen* gaat. Een instelling met default 3 verhoogt niets. Niet
  opnieuw gaan afwegen of we de standaard toch naar 5 moeten zetten — dat is
  precies de patch die al is afgewezen.
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

- **Zoek op redmine.org vóór je begint, met één trefwoord.** Vier sessies op rij
  bestond er al een issue. Bij `version-subprojects` had een **kerncommitter er
  zelf al aan gewerkt**; bij `mypage-query-blocks` had de **projectleider het
  geparkeerd met één inhoudelijk bezwaar**, en dat bezwaar bepaalde het hele
  ontwerp. `titles_only=1` plus meerdere woorden is een AND over de titel en
  geeft nul resultaten.
- **Lees de laatste note van het issue woordelijk, en check hem twee keer.**
  Een parafrase van een samenvatting is niet goed genoeg als jouw hele patch een
  antwoord op die note is. Vraag WebFetch expliciet om de laatste note
  *verbatim* met auteur en datum; de eerste samenvatting noemde "2019", de
  verbatim-versie 2018-12-08.
- **Lees de patch die al aan het issue hangt, ook als een committer hem heeft
  bijgewerkt.** `43534-v2.patch` is van Go MAEDA en bevat een regressie die met
  Redmine's eigen fixtures aantoonbaar is. Download hem
  (`/attachments/download/<id>/<naam>`), pas hem toe in een wegwerp-worktree en
  draai jouw tests ertegen.
- **Doe de trunk-check op de *herkomst* van een constante of methode, niet
  alleen op het bestaan van de feature.** `git log --oneline -S "<de code>" --
  <bestand>` wees bij `mypage-query-blocks` precies één commit aan (r16413,
  #1565, 2017) en daarmee ook het issue dat eruit voortkwam.
- **De trunk-mirror loopt achter.** `origin/master` staat op r24882 van
  2026-08-03. Redmine's bron is SVN en deze fork synchroniseert niet vanzelf.
  Altijd verse fetch vóór een patch, en de revisie noemen in het issue.
- **De sessie-omgeving zet je op een verkeerde branch, en je lokale checkout is
  verouderd.** Elke sessie krijgt een eigen `claude/...`-branch, en de checkout
  van `geoxyz/framework` kan een oude commit zijn: deze sessie stond hij op
  `cc3437527` terwijl de remote op `990496e1a` stond, en het eerste wat er
  gebeurde was werk aan een feature die al af was. Dus **altijd eerst**
  `git fetch origin geoxyz/framework && git merge --ff-only origin/geoxyz/framework`
  en dan `docs/STATE.md` opnieuw lezen.
- **De worktrees zijn er niet meer bij een nieuwe sessie.** De container is
  leeg. Opnieuw aanmaken, en per worktree een `config/database.yml` schrijven
  **vóór** `bundle install` (de Gemfile leest dat bestand). Schrijf meteen ook
  een `development:`-sectie erin, anders start de dev-server later niet.
  Kost ~4 minuten per worktree; start ze parallel in de achtergrond.
- **Ook de remote branches zijn er niet.** `git ls-remote --heads origin` en dan
  gericht fetchen: `master`, `7.0-stable`, `7.0-stable-GEOxyz`,
  `5.1-stable-GEOxyz` (daar staan de 5.1-commits), `ansifi/learn-and-test-7.0`.
  De `patch/<slug>`-branches van eerdere sessies staan er ook.
- **Drie testdatabases** (`redmine_test`, `redmine_test_geoxyz`,
  `redmine_test_base`) zodat de patch, de GEOxyz-branch en de schone
  trunk-referentie tegelijk kunnen draaien. Met 4 cores lopen twee suites
  comfortabel parallel, drie is krap. Eén volledige suite duurt ~12 minuten.
- **Wijzig de working tree niet terwijl de suite daar loopt.** Deze sessie is de
  vertaling van `nl.yml` aangepast nadat de suite al liep; dat kan de uitslag
  niet veranderen (locales worden bij het opstarten gelezen), maar het bewijs
  dekt dan niet meer de gecommitte boom, dus de volledige suite is nog een keer
  gedraaid. Lint en herformuleer dus *vóór* je de suite start.
- **Twee runs van dezelfde boom geven niet hetzelfde aantal assertions.** 31483
  en 31485 op dezelfde code; Redmine randomiseert de testvolgorde en sommige
  tests asserteren voorwaardelijk. Vergelijk dus **faalnamen**, niet aantallen.
- **Er is één dev-database en één poort.** Voor/na-screenshots gaan dus na
  elkaar: eerst de dev-server op de schone-trunk-worktree (`base`) voor de
  `before-`shots, dan stoppen en opnieuw starten op de patch-worktree. Een
  dev-server op een worktree waar tegelijk een suite draait is prima — andere
  database.
- **Ruim je nieuwe instelling op uit `redmine_dev` vóór de before-run.** De
  dev-database is gedeeld tussen de worktrees, dus een rij in `settings` voor
  een instelling die de oude code niet kent blijft staan. `Setting#value` doet
  `available_settings[name]['serialized']` en zou daarop stuklopen als iets
  alle rijen leest. `DELETE FROM settings WHERE name='<jouw instelling>'`.
- **Verander het verify-script niet meer nadat de before-shots gemaakt zijn.**
  Doe je het toch, draai dan **beide** kanten opnieuw. Deze sessie gebeurde dat
  twee keer (eerst de uitsnedes toegevoegd, daarna `full: true`), en beide keren
  zijn beide modes opnieuw gedraaid.
- **Een `<select multiple>` of `size=1` opent op een vaste hoogte.** De opties
  eronder staan wél in de DOM en zijn dus assert-baar, maar staan **niet op de
  screenshot**. Zet `el.size` op het aantal opties voordat je schiet.
- **Een `disabled` `<option>` is op een paginabrede screenshot niet te
  onderscheiden, en `getComputedStyle` geeft dezelfde kleur** (`rgb(33, 37, 41)`)
  als voor een actieve optie. Chromium tekent hem wél grijs, maar dat zie je
  alleen op een uitsnede. Maak dus naast de paginabrede afbeelding een
  `locator.screenshot()` van het element zelf. Zelfde principe voor elk bewijs
  dat een paar pixels groot is.
- **`s.shot(name, caption, {full: true})`** voor een pagina die langer is dan
  900px — vier blokken op Mijn pagina passen niet in de viewport, en het vierde
  blok is het hele bewijs.
- **Het filterformulier van Redmine is JavaScript.** De filterrij is
  `div.filter#tr_<veld>` in `#filters-table`, aangemaakt door `addFilter()`, en
  de gekozen operator en de waarde staan alleen in de DOM-*properties*. In
  Playwright dus `inputValue()` op `#operators_<veld>` en `#values_<veld>`.
- **Twee formulier-id's, niet één.** Lijstpagina's gebruiken `#query_form`
  (underscore), `queries/new` en `queries/edit` gebruiken `#query-form`
  (streepje). `$('#filters-table').closest('form')` dekt allebei.
- **De volledige suite is niet optioneel.** Bij `assignee-nobody` vond alleen de
  volledige run de test die filterwaarden telt.
- **Een nieuwe instelling maakt nieuwe tests "rood" om de verkeerde reden.**
  `with_settings :jouw_instelling => x` geeft op oude code
  `RuntimeError: There's no setting named ...`. Dat is echt rood en het is
  eerlijk, maar zeg het zo in het dossier, en zet er één **bewaker** naast die
  aan beide kanten groen is en de onveranderde standaard vastlegt.
- **`Setting[...]` cachet op de sleutel zoals je hem doorgeeft.** `Setting.foo`
  is `self[:foo]` (symbool), en `with_settings` gebruikt ook symbolen. Geef dus
  een **symbool** door, anders lees je een aparte cache-ingang.
- **Een `format: int`-instelling valideert `only_integer`, maar niet het
  teken.** Leeg en `"abc"` worden geweigerd (de oude waarde blijft staan), maar
  `0` en `-2` worden opgeslagen. Klem dus zelf af als 0 iets stuk zou maken.
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
  worktree die op de juiste commit staat. En `--format offenses` kan "0 Total in
  0 files" zeggen waar `--format simple` "2 files inspected" zegt; vertrouw
  `simple`.
- **Een geaccepteerde trunk-patch komt niet in 7.0-stable.** Trunk staat nog op
  `7.0.0 devel`, dus deze patches landen in 7.1 of later. Elke GEOxyz-commit
  blijft nodig tot GEOxyz zelf naar die release gaat.
- **Attributie hoort alleen op deze branch**, en dat geldt ook voor de
  commit-**auteur**. Commits op `patch/<slug>` en `7.0-stable-GEOxyz` staan op
  naam van `Jan Catrysse <jan.catrysse@geoxyz.eu>` (`git -c user.name=... -c
  user.email=... commit`). Zie K-01 en `tools/check-patch-clean.sh`, die ook op
  `noreply@` in de auteur faalt.
- **`git checkout -- <bestand>` haalt HEAD terug, niet trunk.** Gebruik
  `git checkout origin/master -- <bestand>` voor de rood-bewijs-run, en zet de
  eigen versie eerst apart (`cp` naar de scratchpad) als je nog niet gecommit
  hebt.
- **PostgreSQL kan tussen commando's door omvallen** in deze container.
  `service postgresql start` en opnieuw; het is geen probleem met je patch.
- **De eerste `dev-seed.rb`-run na `load_default_data` kan op een nested-set
  fout stuiten** (`Project#shared_versions` leest `r.lft`, dat nog nil is voor
  een net aangemaakt subproject). De tweede run loopt schoon door; de seed is
  idempotent.
- **Lees je eigen diff adversarieel vóór de eerste push.** Een amend na een push
  vraagt een force-push, precies wat "nooit rebasen op deze branch" wil
  voorkomen. Zet een correctie liever in een tweede commit.
- **`origin/ansifi/learn-and-test-7.0`** is referentiemateriaal, geen basis.
