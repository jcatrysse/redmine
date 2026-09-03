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
