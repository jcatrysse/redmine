# Valkuilen — wat er hier al een keer misging

> Gedeeld tussen alle sessies, en de enige lijst die dat is. Append-only, en
> **altijd via `tools/append-note.sh docs/traps.md`** — die haalt eerst binnen
> wat een andere sessie toevoegde en zet jouw blok eronder, dus er is nooit iets
> te mergen.
>
> Eén regel per valkuil, met het incident erin. Een regel waarvan je het
> incident kan noemen wordt gevolgd; een algemene stijlregel niet.

## Werken met meerdere sessies tegelijk

- **Je lokale checkout is verouderd.** De omgeving mint per sessie een eigen
  branch, en de checkout van `geoxyz/framework` kan een oude commit zijn: één
  sessie stond op `cc3437527` terwijl de remote op `990496e1a` stond, en begon
  aan een feature die al af was. Dus altijd eerst
  `git fetch origin geoxyz/framework && git merge --ff-only origin/geoxyz/framework`.
- **Claim vóór je begint.** `tools/claim.sh <slug>`. Zonder claim doen twee
  sessies dezelfde feature en gooit één van de twee zijn werk weg.
- **Push met `tools/session-push.sh`,** niet met `git push`. Die haalt binnen,
  speelt jouw commits erbovenop en probeert het vier keer opnieuw. Een gewone
  push wordt geweigerd zodra een andere sessie eerder was.
- **Raak niets aan wat je niet bezit.** `tools/check-ownership.sh <slug>` zegt
  wat je bezit. `CLAUDE.md`, `docs/STATE.md`, `docs/runbook.md` en `tools/**`
  zijn van een sessie die Jan expliciet om een framework-wijziging vroeg.
- **`docs/REGISTER.md` is gegenereerd.** Bij een conflict merge je hem niet, je
  draait `tools/register.sh --write` opnieuw.
- **Het enige conflict dat blijft bestaan is een append aan het eind van
  hetzelfde bestand:** twee features die elk een sleutel onder aan
  `config/locales/{nl,fr,de,es}.yml` zetten, of twee blokken onder aan
  `docs/traps.md`. Oplossing is altijd **beide kanten houden** — er is niets te
  kiezen.

## Voordat je bouwt

- **Een slot moet uit verschillende bestandsnamen bestaan.** De eerste versie van
  `tools/claim.sh` zette een `claimed:`-regel in `status.md`. Twee sessies die
  dezelfde regel schrijven geven een **conflict op de replay**, geen winnaar —
  precies het tegenovergestelde van een slot. Nu is het één bestand per sessie
  (`docs/claims/<slug>--<sessie>`), dus verschillende paden, dus geen conflict,
  en beide kanten breken de knoop op dezelfde manier.
- **Een retry mag alleen zijn eigen commit terugdraaien.** `append-note.sh` deed
  eerst `git reset --hard origin/geoxyz/framework` in de retrylus; dat gooit ook
  de nog niet gepushte commits van je eigen sessie weg. `HEAD~1` is wat je wil.
- **Een push-race test je niet in één clone.** Twee commits achter elkaar in
  dezelfde clone staan al op elkaar, dus de push wordt niet geweigerd en je test
  niets. Twee losse clones op dezelfde commit, één pusht, de ander niet-fetchen
  en dan pushen: dat is de race.


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
## De omgeving opzetten

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
## Bewijzen (G3, G4, G8)

- **Wijzig de working tree niet terwijl de suite daar loopt.** Deze sessie is de
  vertaling van `nl.yml` aangepast nadat de suite al liep; dat kan de uitslag
  niet veranderen (locales worden bij het opstarten gelezen), maar het bewijs
  dekt dan niet meer de gecommitte boom, dus de volledige suite is nog een keer
  gedraaid. Lint en herformuleer dus *vóór* je de suite start.
- **Twee runs van dezelfde boom geven niet hetzelfde aantal assertions.** 31483
  en 31485 op dezelfde code; Redmine randomiseert de testvolgorde en sommige
  tests asserteren voorwaardelijk. Vergelijk dus **faalnamen**, niet aantallen.
## Live nalopen in een browser (G9)

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
## Committen en exporteren

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

## Repositories en SCM (uit revision-branches)

- **Een `scm_*_path_regexp` onder `default:` in `config/configuration.yml`
  sloopt de testsuite.** Sinds r24882 (#43209) mag een adapter alleen gebruikt
  worden als die sleutel gezet is, en `dev-server.sh` zet hem niet. Zet je hem
  onder `default:` om de dev-server een Git-repository te laten maken, dan geldt
  hij ook in de testomgeving: `test/test_helper.rb` zet elke
  `scm_*_path_regexp` op `'.*'` met `||=`, dus jouw waarde wint en elke
  Git-repository in de suite wordt ongeldig. Kostte hier **46 extra fouten in
  `RepositoriesGitControllerTest`** die eruitzagen als de schuld van de patch
  (`UrlGenerationError … :repository_id=>nil`, want de `create` in `setup`
  faalde stil). Zet hem onder **`development:`**.
- **`Setting.enabled_scm` is `[]` in de dev-database.** `Repository` valideert
  zijn `type` tegen die lijst, dus een Git-repository aanmaken faalt met
  "Type is invalid" tot je `Setting.enabled_scm = Setting.enabled_scm | ['Git']`
  doet. Zelfde foutmelding als het path-regexp-probleem hierboven, andere
  oorzaak — check ze allebei.
- **`git branch --contains` levert een prefix van twee tekens per regel op**
  (`'  '`, `'* '` voor de huidige branch, `'+ '` voor een branch die in een
  andere worktree uitgechecked staat) en bij een losse HEAD een regel
  `* (HEAD detached at …)`. `line[2..]` plus een `start_with?('(')`-guard dekt
  alles; de 5.1-versie deed `gsub(/\* ?/, '')` en sloopte daarmee elke
  branchnaam met een sterretje erin.
- **Branchnamen moeten door `scm_iconv`.** De testfixture
  `git_repository.tar.gz` heeft twee Latin-1 branchnamen, precies om dit te
  betrappen (#21really 21141). De 5.1-versie loste het op met
  `force_encoding("UTF-8")` in de view; het hoort in de adapter, zoals
  `branches` en `tags` het al doen.
- **`link_to(:action => 'show', :rev => <branchnaam>)` kiest per branchnaam een
  andere route.** De route `revisions/:rev/show` heeft constraint
  `/[a-z0-9.\-_]+/`, dus `release/7.0` en `Feature-1` vallen door naar
  `?rev=release%2F7.0`. Beide werken, geen `UrlGenerationError` — maar test het,
  want het is niet vanzelfsprekend.
- **`public/javascripts/repository_navigation.js` wordt alleen ingeladen door
  `app/views/repositories/_navigation.html.erb`,** en die partial staat op
  `repositories/show`, **niet** op `repositories/revision` en niet op de
  issuepagina. De GEOxyz-5.1-code hing daar een klikhandler in voor een
  groepeer-link op precies die twee pagina's: die link deed dus nooit iets. Dit
  is de G9-fout in zijn oervorm — grep waar een JS-bestand ingeladen wordt
  vóórdat je erop bouwt.

## Uit `imap-oauth` (2026-09-03)

- **Pak de git-fixtures ook uit in de GEOxyz-worktree.** De runbook zegt het al
  voor de patch-worktree, en toch gebeurde het hier: zonder
  `tmp/test/git_repository` **slaan de repository-tests stil over** en gaf de
  suite op `7.0-stable-GEOxyz` `5727 runs, 0 failures` — na het uitpakken
  `5827 runs, 0 failures`. Honderd tests die groen léken en niet liepen. Doe het
  in élke worktree waar je een suite draait, meteen na `db:migrate`.
- **De adversariële herlezing van je diff hoort vóór de suite, niet erna.** De
  trap "wijzig de working tree niet terwijl de suite daar loopt" zegt "lint
  eerst"; lint is niet genoeg. Deze sessie vond bij het kritisch herlezen een
  echte verbetering (`JSON.parse(nil)` in een rescue-pad) terwijl de volledige
  suite al twintig minuten liep, en die suite moest dus helemaal opnieuw. Doe
  G5 op hetzelfde moment als G4: lint, herlees, commit, *dan* starten.
- **Een verificatieharnas dat te toegeeflijk is maakt je before-run ten
  onrechte groen.** De nep-IMAP-server accepteerde `LOGIN` klakkeloos, dus de
  "before"-run op schone trunk **slaagde** en maakte een issue aan — precies
  het tegendeel van wat bewezen moest worden. Een harnas moet de echte
  weigering nabootsen (Exchange Online antwoordt
  `NO [AUTHENTICATIONFAILED] basic authentication is disabled`), en het issue
  dat de te makkelijke run aanmaakte moest uit `redmine_dev` verwijderd worden
  voordat de before-screenshot klopte.
- **`net-imap` stuurt geen SASL initial response als de greeting geen `SASL-IR`
  adverteert.** Een nep-IMAP-server die alleen `AUTHENTICATE <mech> <base64>`
  op één regel begrijpt krijgt dan `AUTHENTICATE XOAUTH2` zonder meer, en
  weigert een geldige credential. Hij moet ook de `+ `-continuation kunnen: `+ `
  sturen en de base64 op de volgende regel lezen.
- **`pkill -f <script>` doodt ook je eigen shell**, niet alleen `rails server`.
  De runbook waarschuwt hiervoor voor `rails server`; het geldt voor élk
  patroon, ook `pkill -f imap_server.rb`. Dat kostte hier één commando
  (exit 144) en de herstart die erin stond liep niet meer. Kill op pid uit
  `ps -eo pid,cmd`.
- **`bin/rails zeitwerk:check` is de goedkoopste gate voor een nieuw bestand
  onder `lib/redmine/`.** Hij eager-loadt de hele applicatie zoals productie
  dat doet, dus hij vindt een verkeerd genoemde constante die de testsuite mist
  (de suite laadt lazy). Kost tien seconden.
