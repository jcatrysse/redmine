# revision-branches — Class A-beslissingen

Beslist zonder Jan: best practice, een bestaande Redmine-conventie, of het
framework beslist het al. Class B staat in `docs/DECISIONS.md`.

- **2026-09-03** — Inzenden op **#5386**, niet als nieuw issue. Dat issue is het
  hoofdissue voor dit onderwerp (2010, 42 notes, category SCM), Jan staat er
  zelf in als note #42, en de vier bezwaren die dit ontwerp moet weerleggen
  staan er woordelijk in (notes 4, 17, 18 en 20 van Toshi MARUYAMA). Een nieuw
  issue zou die discussie weggooien.
- **2026-09-03** — Adaptermethode heet `branches_containing(identifier)`, niet
  `branch_contains` (de 5.1-naam) en niet `get_branches` (de naam uit #7829).
  Sluit aan bij `branches` en `tags` in dezelfde adapter, en `get_`-prefixen
  komen in de huidige codebase niet voor.
- **2026-09-03** — De adapter leest **geen** `Setting`. Het filteren zit in
  `Changeset`, want een SCM-adapter die instellingen leest is een laagfout; de
  5.1-versie deed dat wel.
- **2026-09-03** — `Changeset#branches` als publieke modelmethode, met het
  filteren in de private `excluded_branch_patterns`. Dat is precies de vorm van
  Patch #7829 (2011) en van `MailHandler#accept_attachment?`, dus een reviewer
  herkent het.
- **2026-09-03** — Filteren gebeurt met dezelfde glob-of-regex-schakelaar als
  `mail_handler_excluded_filenames` / `mail_handler_enable_regex_excluded_filenames`,
  inclusief `\A…\z`-ankering, `IGNORECASE` en `*` → `.*`. Geen eigen syntaxis
  verzinnen als core er al één heeft.
- **2026-09-03** — Een ongeldige reguliere expressie wordt gelogd en
  overgeslagen; de overige patronen blijven werken. Core doet dat in
  `MailHandler` niet, maar daar is de context een achtergrondtaak en hier een
  paginaweergave: een typefout van een beheerder mag de revisiepagina niet met
  een 500 opblazen.
- **2026-09-03** — Instellingen op de tab **Repositories**, niet op *Issue
  tracking* waar de 5.1-versie ze zette. Het is repositorygedrag en het staat
  naast `autofetch_changesets` en `repository_log_display_limit`.
- **2026-09-03** — Sleutel `label_branch_plural`, niet `label_branches`.
  Redmine's meervoudsconventie is `label_x_plural` (`label_revision_plural`,
  `label_repository_plural`).
- **2026-09-03** — Geen nieuwe sleutel voor de voorbeeldhint: `text_regexp_info`
  bestaat al in alle vijf de bestanden en wordt in
  `custom_fields/formats/_regexp.html.erb` al voor exact dit doel gebruikt.
  `label_example` ervóór zetten leverde "Example: eg. ^[A-Z0-9]+$" op — pas
  gezien op de screenshot, daarna weggehaald.
- **2026-09-03** — **Geen** groepering van branchnamen achter een
  `[prefix...]`-link, zoals de 5.1-versie deed. Twee redenen, en de tweede is
  beslissend: de heuristiek bakt een GEOxyz-branchconventie in core, én de
  klikhandler zat in `public/javascripts/repository_navigation.js`, dat alleen
  door `app/views/repositories/_navigation.html.erb` wordt ingeladen — en die
  partial staat niet op de revisiepagina en niet op de issuepagina. De link
  deed dus op beide plekken niets. Weglaten is een reparatie, geen inperking.
  De keuze om hem eventueel terug te willen ligt bij Jan (K-07 in
  `docs/DECISIONS.md`).
- **2026-09-03** — Geen extra permissiecheck op de branchregel, op geen van de
  twee weergaven. De branchlinks gaan naar `repositories#show`, en die actie
  staat in `lib/redmine/preparation.rb` onder **zowel** `:view_changesets` als
  `:browse_repository`; `Changeset.visible` filtert al op `:view_changesets`.
  Een eigen `:browse_repository`-check zou strenger zijn dan core is over
  dezelfde gegevens (de branch-dropdown op `repositories#show` toont álle
  branchnamen aan `:view_changesets`), en zou de twee weergaven onderling
  inconsistent maken. De eerste versie had die check wél op de issuetab; hij is
  er weer uit.
- **2026-09-03** — Linkdoel is `repositories#show` met `:rev => branch`, in
  precies de vorm van `app/views/repositories/_breadcrumbs.html.erb`
  (`:path => nil, :rev => …`). Getest dat een branchnaam met een `/` erin geen
  `UrlGenerationError` geeft: de routeconstraint `/[a-z0-9.\-_]+/` matcht niet,
  dus valt hij door naar `?rev=feature%2F1234`.
- **2026-09-03** — `safe_join` in plaats van `.join(', ').html_safe`, en geen
  `force_encoding("UTF-8")` in de view: het omzetten hoort in de adapter met
  `scm_iconv`, zoals `branches` en `tags` het al doen (#21141).
- **2026-09-03** — `branches_containing` geeft `[]` bij een mislukt commando,
  niet `nil` zoals `branches` en `tags` doen. Een lege lijst is het eerlijke
  antwoord voor de weergave en het houdt een nil-guard uit de view.
- **2026-09-03** — Het G9-opzetscript staat in
  `docs/features/revision-branches/seed.rb` en niet in `tools/`, want `tools/**`
  is eigendom van een framework-sessie.
- **2026-09-03** — Geen wijziging aan `robots.txt`, ondanks note 20 ("if issue
  page will call git command, robot should exclude issue page, too"). De
  revisiepagina staat er al in via `Disallow: /projects/<p>/repository`
  (prefixmatch, dus ook de revisie-URL's), en de issuepagina roept git niet aan
  voor een crawler: het tabblad staat in `IssuesHelper#issue_history_tabs` als
  `:remote => true` zonder `:partial`, dus `common/_tabs.html.erb` rendert een
  lege container en `getRemoteTab` haalt de inhoud pas via XHR op.
