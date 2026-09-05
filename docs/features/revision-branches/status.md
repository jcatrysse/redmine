---
slug: revision-branches
feature: Git-branches op de revisie- en de issuepagina
commit_51: cf826e3fd
geoxyz: live
geoxyz_commit: 115230bc2 + 8c1fa23fb
upstream: patch klaar
patch: patches/revision-branches/2026-09-05-r25037-feature.patch
issue: 5386
---

# revision-branches — status

## Waar het staat

**Ronde 2 is af (2026-09-05).** Alle elf bevindingen van de review hebben een
`Resolution:`-regel en zijn opgelost — niets weggeredeneerd, één keuze (F11)
beantwoord door Jans g12. De patch is daarna opnieuw opgebouwd op verse trunk
**r25037** (`bee32a926`, g05) en de bewijscijfers zijn in dezelfde beweging
opnieuw gedraaid (g10).

Af en klaar om in te dienen. De patch is opnieuw ontworpen, niet geport: van de
5.1-commit `cf826e3fd` is de bedoeling overgenomen en verder niets. Hij ligt in
twee bestanden onder `patches/revision-branches/`, gemaakt tegen trunk r25037,
en dezelfde wijziging staat als de commits `115230bc2` + `8c1fa23fb` op
`7.0-stable-GEOxyz`. De volledige suite is aan beide kanten gedraaid, RuboCop
is schoon, en de functie is in een echte browser nagelopen.

De trunk-check leverde het belangrijkste van deze sessie op: dit hoort **niet**
als nieuw issue. **#5386** bestaat sinds 2010, heeft 42 notes, en Jan staat er
zelf in als note #42. Daar staan ook de vier bezwaren van kerncommitter Toshi
MARUYAMA die dit ontwerp moet weerleggen (notes 4, 17, 18 en 20). Ze staan
woordelijk in het dossier, met per bezwaar het antwoord. Note 20 is de
verrassing: die zegt dat als de issuepagina git gaat aanroepen, robots ook van
de issuepagina moeten worden geweerd. Het antwoord staat sinds ronde 2 op het
juiste slot: het tabblad "Geassociëerde revisies" is `:remote => true` zonder
partial, én `IssuesController#issue_tab` begint met
`render_error :status => 422 unless request.xhr?` — de URL is dus ook
rechtstreeks niet op te halen. Wat overblijft is een crawler die JavaScript
uitvoert; die wordt begrensd door de bovengrens op de tab. De revisiepagina
staat al in `robots.txt` (`Disallow: /projects/<p>/repository`).

## Wat het doet

Op de revisiepagina (en op de diffpagina, die dezelfde partial rendert) en bij
"Geassociëerde revisies" van een issue komt er een regel met de Git-branches
waarin die commit zit, elk als link naar de repository op die branch. Staat
standaard uit; een beheerder zet het per weergave aan en kan branchnamen
wegfilteren met een lijst namen of patronen. De issuetab draait het commando
niet meer boven `repository_log_display_limit` revisies (standaard 100): één
Git-proces per rij, dus dat aantal is nu begrensd door een getal dat de
beheerder toch al instelt.

## Bewijs

- Volledige suite met patch: `5934 runs, 31502 assertions, 27 failures, 2 errors, 92 skips`
- Volledige suite op schone trunk r24882: `5920 runs, 31455 assertions, 27 failures, 2 errors, 92 skips`, de 29 faalnamen zijn **byte-identiek** aan die van de patch-run (alle 29 SCM-afhankelijk, `svn`/`hg`/`bzr`/`cvs` staan niet in dit image)
- Volledige suite op `7.0-stable-GEOxyz`: `5977 runs, 31909 assertions, 0 failures, 0 errors, 39 skips` — echt 0/0, want de
  SCM-afhankelijke tests die op trunk falen bestaan daar niet in dezelfde vorm.
  Dit is de run **ná** de replay: tijdens deze sessie duwde een parallelle
  sessie twee commits (`f117ea32e` imap-oauth, `f2242bd86`
  webhook-tracker-filter) onder de mijne, dus is de suite daarna nog een keer
  volledig gedraaid, met hun migratie erbij. De run vóór de replay gaf
  `5959 runs, 31847 assertions, 0 failures, 0 errors, 39 skips`.
- RuboCop op de 8 gewijzigde Ruby-bestanden: 0 (baseline 0), en op de
  GEOxyz-branch ook 0 (baseline 0)
- `tools/check-patch-clean.sh`: PASS · `tools/check-geoxyz-branch.sh`: PASS
- Elk patchbestand applyt los op een schone `origin/master`, en samen geven ze
  exact de boom van `patch/revision-branches`: geverifieerd met `git am` in een
  wegwerp-worktree
- Screenshots: 10 (9 before, 10 after), gelezen: ja — en dat leverde één
  correctie op (zie hieronder)

## Wat Jan nog moet doen

Voeg een note toe aan **https://www.redmine.org/issues/5386** (Feature, New,
category SCM) — **geen nieuw issue**, dit is het hoofdissue voor dit onderwerp
sinds 2010 en je staat er zelf in als note #42 van 2024-08-07. Hang er twee
bestanden aan:

- `patches/revision-branches/2026-09-05-r25037-feature.patch` — de code plus
  `en.yml`
- `patches/revision-branches/2026-09-05-r25037-locales.patch` — alleen `nl`,
  `fr`, `de` en `es`

De notetekst staat in `docs/features/revision-branches/dossier.md` vanaf
"# The problem"; die is in het Engels en kan zo gekopieerd worden. Vermeld dat
het tegen trunk r25037 is gemaakt. Drie dingen zijn het waard om in de note
expliciet te noemen, want ze zijn het verschil met de zeven eerdere patches op
dat issue: er wordt **niets** in de database bewaard (dat is het antwoord op
note 17), de weergave staat **standaard uit**, en het aantal Git-processen op
de issuetab is **begrensd** door `repository_log_display_limit` (dat samen is
het antwoord op note 18).

Daarnaast staat er één keuze voor je open, zie `docs/DECISIONS.md` — die
blokkeert het indienen niet.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **De vier bezwaren die in de oude status stonden zijn alle vier beantwoord,
  niet weggeredeneerd.** Ze staan met antwoord in het dossier onder
  "Anticipated objections", naast de vier notes van Toshi MARUYAMA (dat zijn
  twee verschillende lijstjes die elkaar deels overlappen). Jans beslissing van
  2026-09-01 (Git-only houden, het commando eronder houden, de vier
  instellingen houden, en de reactie van het core-team afwachten) is gevolgd en
  blijkt door de issuegeschiedenis **gesteund**: notes 4 en 17 verwerpen juist
  een database-cache. Dus niet opnieuw wegen of we een cache moeten bouwen of
  moeten splitsen. **Let op één correctie uit ronde 2 (F03):** note 20's "drie
  git-commando's" gaat over de *repository-bladerpagina*, niet over de
  revisiepagina. Die laatste roept op trunk **nul** SCM-commando's aan en
  krijgt er met deze patch precies één bij. Gebruik die zin dus niet meer als
  verdediging — hij is aantoonbaar onwaar en staat niet meer in het dossier.
- **De vier instellingen hebben nu een verdediging per stuk,** en het paar
  `revision_branches_excluded` + `revision_branches_enable_regex` heeft direct
  precedent in core (`mail_handler_excluded_filenames` +
  `mail_handler_enable_regex_excluded_filenames`). Zakt het tot drie in de
  review, dan is de kleinste toegift het weghalen van
  `revision_branches_enable_regex` en elk patroon als reguliere expressie
  behandelen — één regel.
- **De groepering van branchnamen achter een `[prefix...]`-link is eruit, en
  dat is een reparatie.** Niet alleen omdat de heuristiek een
  GEOxyz-branchconventie in core bakt, maar vooral omdat de klikhandler in
  `public/javascripts/repository_navigation.js` zat: dat bestand wordt alleen
  ingeladen door `app/views/repositories/_navigation.html.erb`, en die partial
  staat op `repositories/show` en dus **niet** op de revisiepagina en **niet**
  op de issuepagina. De link deed op beide plekken niets. Wil Jan de groepering
  terug, dan is dat een aparte keuze (K-07 in `docs/DECISIONS.md`) en een
  eigen ontwerp.
- **Geen extra permissiecheck.** De branchlinks gaan naar `repositories#show`,
  en die actie staat in `lib/redmine/preparation.rb` onder zowel
  `:view_changesets` als `:browse_repository`; `Changeset.visible` filtert al op
  `:view_changesets`. Een eigen `:browse_repository`-check zou strenger zijn dan
  core over dezelfde gegevens (de branch-dropdown op `repositories#show` toont
  álle branchnamen aan `:view_changesets`) en zou de twee weergaven onderling
  inconsistent maken. De eerste versie had die check wél; hij is er bewust weer
  uit.
- **Twee valkuilen uit deze sessie staan in `docs/traps.md`,** en de eerste
  kost een uur als je hem niet kent: een `scm_git_path_regexp` onder `default:`
  in `config/configuration.yml` (nodig om de dev-server een Git-repository te
  laten maken) geldt óók in de testomgeving en maakt daar elke Git-repository
  ongeldig — 46 fouten in `RepositoriesGitControllerTest` die eruitzien als de
  schuld van de patch. Zet hem onder `development:`.
- **Het G9-opzetscript is `docs/features/revision-branches/seed.rb`.** Dat
  bouwt een Git-repository met vijf branches (waaronder
  `dependabot/bundler/rails-8.1.4`, zodat het wegfilteren zichtbaar is in
  plaats van theoretisch), hangt hem aan het project `geoxyz-verify` en linkt
  een commit aan issue 1. Idempotent. Zonder dit script is er niets te zien in
  de browser, want `tools/dev-seed.rb` maakt geen repository aan.
- **Wat het lezen van de screenshots opleverde:** de hintregel onder het
  uitsluitingsveld stond er als "Multiple values allowed (comma separated).
  Example: eg. ^[A-Z0-9]+$" — `text_regexp_info` begint zelf al met "eg.", dus
  `label_example` ervóór was dubbel. Alleen te zien door te kijken. Weggehaald.

## Volgende stap voor een sessie

Af — niets te doen, behalve de feedback verwerken zodra Jan de note op #5386
heeft geplaatst en het core-team reageert.
