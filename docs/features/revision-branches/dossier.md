# revision-branches — show which Git branches contain a revision

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** op de revisiepagina en bij "Geassociëerde
  revisies" van een issue komt er een regel "Branches" te staan met de
  Git-branches waar die commit in zit, elk als link naar de repository op die
  branch. Uit met de standaardinstelling; een beheerder zet het aan en kan
  branchnamen wegfilteren (bijvoorbeeld `dependabot/*`).
- **Waar het vandaan komt:** 5.1-commit `cf826e3fd` ("Feature: add branches to
  different views"). Volledig herschreven, niet geport: van die commit is de
  bedoeling overgenomen en verder niets. Wat er mee zou zijn meegereisd staat
  onder "Alternatives considered" en in `decisions.md`, waarvan de ergste een
  klikbare link is die nergens op reageerde omdat zijn JavaScript op die twee
  pagina's niet werd ingeladen.
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen
- **Kans dat Redmine dit aanneemt:** twijfelachtig, maar beter dan de vorige
  zeven pogingen. Het is 16 jaar gevraagd (#5386, 42 notes) en nooit afgewezen,
  alleen nooit opgepakt. Kerncommitter Toshi MARUYAMA schreef er vier concrete
  bezwaren bij (notes 4, 17, 18 en 20); die zijn hier woordelijk overgenomen en
  het ontwerp is er op gebouwd in plaats van eromheen. Twee ervan
  (branchgegevens verouderen na een force-push, en de kosten per revisie)
  verwerpen precies wat alle eerdere patches deden: opslaan in de database. Wij
  slaan niets op en zetten het standaard uit. Het vierde bezwaar — "als de
  issuepagina git gaat aanroepen, moeten robots ook van de issuepagina worden
  geweerd" — gaat grotendeels niet op: het tabblad "Geassociëerde revisies"
  wordt pas via JavaScript opgehaald én het eindpunt weigert alles wat geen XHR
  is met een 422. Wat overblijft is een crawler die JavaScript uitvoert; die
  wordt begrensd door de bovengrens die er sinds ronde 2 op zit.
- **Wat ronde 2 (2026-09-05) veranderde:** elf reviewbevindingen opgelost. De
  drie die ertoe doen: het instellingenformulier weigert nu een ongeldige
  reguliere expressie in plaats van hem stil op te slaan, de issuetab heeft een
  bovengrens gekregen (jouw keuze g12) zodat het aantal Git-processen begrensd
  is, en één zin in de issuetekst die aantoonbaar onwaar was ("de revisiepagina
  roept al drie Git-commando's aan") is vervangen door de gemeten cijfers.
- **Wat jij nog moet doen:** het issue op redmine.org bijwerken. Dit hoort
  **niet** als nieuw issue: **#5386** is de plek (Feature, New, category SCM,
  jij staat er zelf in als note #42 van 2024-08-07). Hang de twee patches
  eronder met de tekst vanaf "The problem". Zie ook één open keuze onderaan.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** eerst `2563fa6a5` = SVN r24882 (2026-08-03),
  bij het verversen van 2026-09-05 opnieuw op `bee32a926` = SVN **r25037**
  (2026-09-04). De bevindingen hieronder zijn op beide gecontroleerd en
  ongewijzigd.
- **Lost trunk dit al op?** Nee. `Redmine::Scm::Adapters::GitAdapter` heeft
  `branches` (alle branches met hun tip) en `tags`, maar niets dat vraagt
  *welke branches een gegeven commit bevatten*. `app/models/changeset.rb` heeft
  geen `branches`. `app/views/repositories/_changeset.html.erb` toont ID,
  parent en child, geen branches. `app/views/issues/tabs/_changesets.html.erb`
  toont revisie plus diff-link, geen branches.
- **Bestaand issue op redmine.org?** Ja, drie, en dat verandert het hele
  verhaal:
  - **#5386** Feature "Branch/Tags in Changeset Description" (2010, New,
    category SCM) — het hoofdissue, 42 notes, met álle relevante discussie. De
    laatste notes: #38 (Niklaus Giger, 2020-11-24) een patch met
    geminimaliseerde instellingen, #39 (2022-11-14) een patch voor 4.2, #40/#41
    (Marco Descher, 2024-08-06) werkt op 5.1 en de vraag of sponsoring helpt,
    #42 (Jan Catrysse, 2024-08-07) draait productief op 5.0.
  - **#7829** Patch "Show branches changsets belongs to on issue page" (2011,
    New) — `Changeset#branches` + `GitAdapter#get_branches(scmid)` met
    `git branch --no-color --contains`. Gerelateerd aan #5386. **Dezelfde
    architectuur als deze patch**, en dat is geen toeval: het is de vorm die
    hier past.
  - **#38278** Patch "Basename of repository and Branch/Tags in Changeset
    Description" (2023, New) — hetzelfde onderwerp, breder van opzet.
  Gezocht met `branches` en `branch contains` (titles_only).
- **Verandert iets in trunk het ontwerp?** Ja, twee dingen:
  1. `app/views/issues/tabs/_changesets.html.erb` is sinds 5.1 opnieuw
     geïndenteerd. De helft van de 5.1-diff in dat bestand was
     herformattering; die is nu overbodig, wat de diff kleiner maakt (INV-1).
  2. r24882 kent `scm_<type>_path_regexp` in `configuration.yml` als harde
     voorwaarde om een adapter te mogen gebruiken (#43209). Dat raakt het
     ontwerp niet, maar wel het opzetten van een testomgeving.

---

# The problem

Redmine tells you everything about a revision except the one thing a reviewer
or release manager asks first: **is this commit on the branch I care about?**
The revision page shows the commit id, its parents and its children; the
"Associated revisions" tab of an issue shows the revision and a link to its
diff. Neither says which branches the commit is reachable from, so the question
"has this fix landed on the release branch?" cannot be answered in Redmine at
all. People answer it by leaving Redmine — `git branch --contains` on a
checkout, or a second tool (note 6 on #5386: "without this patch my team still
need to run gitweb").

This has been requested since 2010. Feature #5386 has 42 notes and ten related
issues, Patch #7829 proposes the same thing from the other end, and Patch
#38278 asks again in 2023. Nobody has ever argued the information is not
useful. What blocked it were four specific, correct objections from Toshi
MARUYAMA, all about *how* the earlier patches got the data. They are the
specification for this patch, so they are quoted rather than paraphrased:

- **Note 4 (2011-10-13):** "Git branch is not stable. Git branch is the pointer
  to the specific revision. So, Git branch cannot be stored in database.
  Mercurial *named branch* is stable."
- **Note 17 (2013-03-07):** "In following case, git branch becomes
  **incorrect**. delete branch (`git branch -D branch`,
  `git push somewhere :branch`) force push (`git push -f somewhere branch`)"
- **Note 18 (2013-03-07):** "[The patch] calls 'git branch --contains hash' per
  associated revisions. In the issue which has many associated revisions (e.g.
  #61), It becomes terrible performance regression."
- **Note 20 (2013-03-07):** "Repository page calls three git commands... So,
  robot excludes repository page... Current issue page does not call git
  command. If issue page will call git command, robot should exclude issue
  page, too."

Notes 4 and 17 say the same thing from two sides, and together they rule out
the approach every patch on the issue took until 2014: storing branch
membership in the database and refreshing it on rescan. Note 18 rules out doing
the work unconditionally. Note 20 adds a condition on the issue page
specifically. The design below is built to satisfy all four.

# Why this belongs in core

The information is derived from the SCM adapter, and the adapter is the part a
plugin cannot reach cleanly. A plugin has to reopen
`Redmine::Scm::Adapters::GitAdapter` to add a command, reopen `Changeset` to
expose it, and patch two core partials that have no view hook at the place the
row belongs — `_changeset.html.erb` has no hook at all, and
`view_issues_history_changeset_bottom` fires *after* the changeset block, so a
plugin cannot put the branches next to the revision link where they read as
part of it.

The honest counter-argument: the plugin exists. `redmine_revision_branches` was
written in 2015 (note 36 on #5386) and ported to master in 2020 by a volunteer
who offered to keep maintaining it (note 37). It works by doing exactly those
three monkey-patches. That something this small needs three of them, and that
it has been carried outside core for a decade while the issue stayed open, is
the case for core rather than against it.

# Proposed change

Three layers, each with one job.

1. `GitAdapter#branches_containing(identifier)` runs
   `git branch --no-color --contains <identifier>` and returns the branch names
   as UTF-8, sorted. It knows nothing about settings — an SCM adapter should
   not read `Setting`.
2. `Changeset#branches` asks the adapter (when it responds to
   `branches_containing`, so every other SCM keeps working and Mercurial can be
   added later without touching anything else) and drops the names an
   administrator excluded.
3. The two views render the list when their setting is on, using
   `RepositoriesHelper#link_to_revision_branches`. The issue tab asks
   `RepositoriesHelper#display_changeset_branches?` first, which drops the whole
   display when the issue carries more associated revisions than
   `Setting.repository_log_display_limit` (default 100) — one command per
   revision, so that is the bound on the fork count note 18 predicted.

Nothing is stored, so there is no cached copy to disagree with the repository
after a branch is deleted or force-pushed (notes 4 and 17). Nothing runs unless
an administrator turns it on, and the two pages are separate settings, so the
cost note 18 describes is opt-in per page (note 18's own example, an issue with
many associated revisions, is exactly what the second setting governs).

Note 20's condition is met without any change to `robots.txt`. The reason is
worth spelling out, including the one case it does not fully cover:

- The **revision page** is already excluded. `app/views/welcome/robots.text.erb`
  emits `Disallow: /projects/<project>/repository` for every project, and
  `Disallow` is a prefix, so `/projects/<p>/repository/<id>/revisions/<rev>` is
  covered.
- The **issue page** does not render this server-side, and the endpoint that
  does render it refuses anything but an XHR. The associated revisions tab is
  declared in `IssuesHelper#issue_history_tabs` with `:remote => true` and no
  `:partial`, so `common/_tabs.html.erb` renders an empty container and
  `getRemoteTab` fetches the content. `GET /issues/123` therefore does not call
  `issues#issue_tab`, does not render `issues/tabs/_changesets`, and runs no
  command. And `IssuesController#issue_tab` opens with
  `return render_error :status => 422 unless request.xhr?`, so a crawler that
  discovers `/issues/123/tab/changesets` by any other route gets a 422 rather
  than a page.

  Being precise about what is left: when `?tab=changesets` is the selected tab,
  `common/_tabs.html.erb` emits an inline `javascript_tag` that calls
  `getRemoteTab` **on load**, and `/issues/:id` is not in `robots.txt`. A
  crawler that executes JavaScript and follows the tab link therefore does fire
  the XHR. That is the residual case, and what bounds it is the cap described
  above: the tab runs no command at all above `repository_log_display_limit`
  revisions, which is the same bound note 18's own example (#61, many
  associated revisions) runs into. If that is not enough for a reviewer,
  `Disallow: /issues/*/tab/` in `robots.text.erb` closes it in one line and
  affects a route no human navigates to directly — it is not in this patch
  because deindexing anything is the reviewer's call, not the author's.

| File | Change |
|---|---|
| `lib/redmine/scm/adapters/git_adapter.rb` | `branches_containing(identifier)`: 19 lines, patterned on the existing `branches` and `tags` |
| `app/models/changeset.rb` | `branches`, plus the private `excluded_branch_patterns` |
| `app/models/setting.rb` | one row in the `validate_all_from_params` table, so a malformed regular expression is rejected at the form exactly as the mail-handler pair's is |
| `app/helpers/repositories_helper.rb` | `link_to_revision_branches(changeset)` — `safe_join` of links to the repository at that branch — and `display_changeset_branches?(changesets)`, the cap |
| `app/views/repositories/_changeset.html.erb` | one `<li>` in `ul.revision-info`, between parent and child. This partial is rendered by **both** `repositories/revision.html.erb` and `repositories/diff.html.erb`, so the row appears wherever a single revision is described; the setting's label says both pages |
| `app/views/issues/tabs/_changesets.html.erb` | one `<em>` after the diff link, and the cap read once before the loop |
| `app/views/settings/_repositories.html.erb` | the four settings, in the existing settings box, with a glob example and a "Git only" hint |
| `config/settings.yml` | the four settings, next to the other repository settings |
| `config/locales/en.yml` | six keys |

**New setting / migration / gem / route / permission:** four settings, no
migration, no gem, no route, no permission. Justification per setting (INV-6):

| Setting | Default | Why it cannot be dropped |
|---|---|---|
| `display_revision_branches` | `0` | The command must be opt-in, or every existing installation pays note 18's cost without asking. Off by default is what makes the patch safe to merge. |
| `display_associated_revision_branches` | `0` | Separate from the first because the cost is different in kind: the issue tab renders N changesets, so N commands. An administrator who wants the cheap half must be able to take only the cheap half. |
| `revision_branches_excluded` | `''` | A repository with `dependabot/*` branches produces a list nobody reads. Empty means exclude nothing, so this is inert until used. |
| `revision_branches_enable_regex` | `0` | Direct precedent in core: `mail_handler_excluded_filenames` is paired with `mail_handler_enable_regex_excluded_filenames` in exactly this way, with the same glob-or-regex switch and the same shared label. `Changeset#excluded_branch_patterns` is `MailHandler#accept_attachment?` with the settings renamed — with **one deliberate difference**, below. |

**Where this deliberately differs from `MailHandler`, and why.** The exclusion
patterns are anchored as `\A(?:<pattern>)\z`, with the group.
`app/models/mail_handler.rb:365` writes the same expression **without** it, as
`%r{\A#{pattern}\z}i`, and that is a bug: alternation binds more loosely than
concatenation, so `feature|hotfix` there means "starts with feature **or** ends
with hotfix" and quietly matches `feature-123` and `my-hotfix`. The new code
groups the pattern so both anchors apply to all of it, which is what an
administrator typing an exact-match list expects, and
`test_changeset_branches_should_anchor_a_regular_expression_containing_alternation`
pins it. `MailHandler` is **not** changed here — that is a separate defect in a
file this feature has no business touching — but it is worth a separate issue,
and this paragraph exists so a reviewer sees the difference was a choice rather
than an oversight.

They go on the **Repositories** tab, with the other SCM settings.
`autofetch_changesets` and `repository_log_display_limit` are its neighbours;
the feature is repository behaviour, and its first setting only does anything
when the SCM is Git.

**Translations** (INV-5 — every row names the existing key it was patterned on):

| Key | en | nl | fr | de | es | Patterned on |
|---|---|---|---|---|---|---|
| `label_branch_plural` | Branches | Branches | Branches | Zweige | Ramas | `label_branch` in the same file (Branch / Branch / Branche / Zweig / Rama) — grammatical plural of it, and `label_x_plural` is Redmine's plural convention (`label_revision_plural`) |
| `setting_display_revision_branches` | Display branches on the revision and diff pages | Branches weergeven op de revisie- en diffpagina | Afficher les branches sur les pages de révision et de diff | Zweige auf der Revisions- und der Vergleichsseite anzeigen | Mostrar ramas en las páginas de revisión y de diferencias | `setting_display_subprojects_issues` for the verb and word order (weergeven / Afficher / anzeigen / Mostrar), `label_revision` for the noun (Revisie / révision / Revision / revisión), `label_diff` for the second page (diff / diff / Vergleich / diferencias) |
| `setting_display_associated_revision_branches` | Display branches in associated revisions | Branches weergeven bij geassociëerde revisies | Afficher les branches dans les révisions associées | Zweige bei zugehörigen Revisionen anzeigen | Mostrar ramas en las revisiones asociadas | `label_associated_revisions` verbatim for the term (Geassociëerde revisies / Révisions associées / Zugehörige Revisionen / Revisiones asociadas), same verb source as above |
| `setting_revision_branches_excluded` | Exclude branches by name | Branches uitsluiten op basis van naam | Exclure les branches par leur nom | Zweige nach Namen ausschließen | Excluir ramas por nombre | `setting_mail_handler_excluded_filenames` ("Exclude attachments by name") — same sentence with the object swapped |
| `setting_revision_branches_enable_regex` | Enable regular expressions | Reguliere expressies gebruiken | Utiliser les expressions régulières | Reguläre Ausdrücke verwenden | Habilitar expresiones regulares | `setting_mail_handler_enable_regex` for de/es/fr; for **nl** that key is still untranslated English in core, so the Dutch is derived from `field_regexp` ("Reguliere expressie", nl.yml:275) plus the "… gebruiken" form of `setting_default_issue_start_date_to_creation_date` |
| `text_revision_branches_git_only` | Branch information is only available for Git repositories. | Branchinformatie is alleen beschikbaar voor Git-repositories. | Les informations de branche ne sont disponibles que pour les dépôts Git. | Zweig-Informationen sind nur für Git-Repositories verfügbar. | La información de ramas solo está disponible para repositorios Git. | `label_repository_plural` in the same file for the noun (Repositories / Dépôts / Repositories / Repositorios) and `label_branch` for the branch term; the sentence form (a full sentence ending in a full stop under `em.info`) is `text_scm_config`'s, its neighbour on the same settings tab |

No new key for the example hint: it now shows two glob examples the way
`app/views/settings/_mail_handler.html.erb` does for
`mail_handler_excluded_filenames` — `l(:label_example)` plus a literal — because
the field is glob syntax until `revision_branches_enable_regex` is ticked, and
`text_regexp_info` ("eg. `^[A-Z0-9]+$`") is only correct in the mode that is not
the default.

**Backward compatibility:** both displays default to `0`, so an installation
that upgrades sees no change and runs no extra command — the
`before-revision-default.png` / `revision-default.png` pair is the same page.
An empty `revision_branches_excluded` excludes nothing. No schema change, so
downgrading is only a code revert. Non-Git repositories are unaffected:
`Changeset#branches` returns `[]` unless the adapter responds to
`branches_containing`.

# What this does not fix

**A branch whose name is not UTF-8 is shown, but its link leads to "not
found".** `branches_containing` converts each name from the repository's path
encoding to UTF-8 for display, exactly as the existing `branches` and `tags` do.
The link then carries the converted name as `:rev`, and on the way back in
`valid_name?` runs `git show-ref -- <name>`, which looks the ref up by its raw
bytes. The name that is safe to display is not the name that can be looked up.
Measured on Redmine's own Git fixture, which has two latin-1 branch names:

    latin-1-branch-Ü-01      valid_name?=false   -> show_error_not_found
    latin-1-branch-Ü-02      valid_name?=false   -> show_error_not_found
    latin-1-path-encoding    valid_name?=true
    master                   valid_name?=true

**This is not new and this patch does not cause it.** The branch dropdown in
`app/views/repositories/_navigation.html.erb` is built from
`@repository.branches`, runs the identical `scm_iconv`, and fails in the same
place on trunk today. Fixing it means deciding how a displayed ref name maps
back to its bytes, which is core's question and much larger than this feature.
What the patch does do is take a link that was broken in one dropdown and put it
on the revision page, the diff page and the issue tab, so it is worth naming
rather than leaving for a reviewer to trip over. The patch's own encoding tests
cover the conversion but deliberately not the round trip, since the round trip
is the pre-existing part.

# Alternatives considered

**Cache branch membership in the database, refreshed on rescan.** This is what
every patch on #5386 before 2014 did, and it is what notes 4 and 17 reject: a
Git branch is a pointer, so a deleted or force-pushed branch leaves Redmine
showing a branch the repository no longer has, with no event to correct it. Running the command on demand is slower and
always right. Note 16 (Colin Mollenhour, 2013-03-06) reports rescan times
growing with the number of issues, which is the same problem from the other
side.

**One command for the whole page instead of one per revision.** Note 29
(Anthony Mallet, 2014-02-25) proposes `git log --format=%h%d`, which decorates
commits with the refs pointing *at* them — that is not the same question.
Answering "which branches contain this commit" for N commits in one pass means
`git branch --contains` per commit anyway, or walking the graph in Ruby. So the
issue tab is bounded rather than batched: above `repository_log_display_limit`
revisions it shows no branches at all, which reuses the setting an
administrator already tunes for "how many revisions a repository view shows"
instead of adding a fifth.

**Say plainly what that reuse costs, because it is not only a saving.** The
default is 100, so an issue with a hundred associated revisions fires a hundred
`git branch --contains` on one XHR — bounded, but not small, and each one walks
the commit graph. `repository_log_display_limit` is read in exactly one other
place, `RepositoriesController#show`, where it caps the repository log. So an
administrator who wants branches only on small issues has one lever, and pulling
it to ten also truncates every repository log page in the installation to ten
revisions. The two cannot be tuned apart. That is the deliberate trade against a
fifth setting (INV-6), and a reviewer who would rather have the fifth setting
should say so — it is four lines and one locale key, and the answer is theirs to
give rather than ours to assume.

**Group branch names by a common prefix,** which the GEOxyz 5.1 code did with
`name.downcase.gsub(/^\d+/, '#####').split(/[\-._]/).first`, collapsing a group
behind a `[prefix...]` link. Dropped, for two reasons. It hard-codes one team's
branch naming convention into core, and — decisively — **it never worked.** The
click handler lives in `public/javascripts/repository_navigation.js`, which is
included only by `app/views/repositories/_navigation.html.erb`. That partial is
rendered by `show.html.erb` and by neither `revision.html.erb` nor the issue
page, so on both views the patch put a link in the DOM that did nothing when
clicked. `revision_branches_excluded` covers the real need (a long list of
uninteresting branches) with a setting instead of a heuristic.

**Support every SCM.** Only Git can answer this cheaply. Note 11 (Colin
Mollenhour, 2012-01-31) explains why Subversion cannot: branches are a
directory convention, not a graph property. Mercurial is the one that could,
and note 4 says so from the reviewer's side — "Mercurial *named branch* is
stable" — with note 30 asking for it; `Changeset#branches` is written so that
adding `branches_containing` to `MercurialAdapter` is the whole change, and
because hg named branches are stable that implementation could legitimately be
cached where this one must not be.

**Do it in a plugin.** See "Why this belongs in core": the plugin exists, needs
three monkey-patches, and has been carried by volunteers since 2015.

# Tests

| Test | What it proves |
|---|---|
| `GitAdapterTest#test_branches_containing` | the command's output is parsed into names: 3 branches for `fba357b`, 1 for `2a68215`, and the `* ` current-branch marker is stripped |
| `GitAdapterTest#test_branches_containing_should_convert_branch_names_to_utf8` | `scm_iconv` is applied, so the fixture's two Latin-1 branch names come back as UTF-8 — the bug of #21141, which the 5.1 code worked around with `force_encoding("UTF-8")` in a view |
| `GitAdapterTest#test_branches_containing_with_unknown_or_blank_revision_should_return_empty_array` | an unknown sha, `''` and `nil` all give `[]` rather than raising or running `git branch --contains` with no argument (which would answer for HEAD) |
| `GitAdapterTest#test_branches_containing_should_skip_names_that_cannot_be_converted` | with `path_encoding` `ISO-2022-JP`, the fixture's two Latin-1 branch names cannot be converted and are dropped; the other five come back. On the unguarded version `scm_iconv`'s `nil` reaches `Array#sort!` and the method raises `ArgumentError: comparison of NilClass with String failed` into the view, which is the only path in it that does not return `[]` |
| `RepositoryGitTest#test_changeset_branches` | `Changeset#branches` against a real repository |
| `RepositoryGitTest#test_changeset_branches_without_scmid_should_be_empty` | no command is attempted without an scmid |
| `RepositoryGitTest#test_changeset_branches_should_exclude_names_matching_a_pattern` | `master` excludes only `master`, `master*` also excludes `master-20120212` — the glob form, and that the exclusion is anchored |
| `RepositoryGitTest#test_changeset_branches_should_anchor_a_regular_expression_containing_alternation` | `master\|test` excludes `master` and nothing else — not `master-20120212`, which an ungrouped `\A...\z` would have swallowed. This is the case that separates this code from `MailHandler`'s, and it is red without the group: `["master-20120212", "test_branch"]` becomes `["test_branch"]` |
| `RepositoryGitTest#test_changeset_branches_should_exclude_names_matching_a_regular_expression` | `.*-\d+` excludes `master-20120212` with the regex setting on, and excludes nothing with it off — so the switch is what decides, not the pattern |
| `RepositoryGitTest#test_changeset_branches_should_ignore_an_invalid_regular_expression` | `[, master` drops the invalid pattern, keeps applying `master`, and does not raise on the page |
| `ChangesetTest#test_branches_should_be_empty_for_a_scm_without_branch_support` | Subversion is unaffected |
| `RepositoriesGitControllerTest#test_revision_should_show_the_branches_containing_the_revision` | the revision page renders the row and links each branch to the repository at that branch |
| `RepositoriesGitControllerTest#test_revision_should_not_show_branches_by_default` | **green on trunk too** — the default is unchanged |
| `IssuesControllerTest#test_show_changesets_tab_should_display_the_branches_of_each_revision` | the associated revisions tab renders the branches, and a branch name with a `/` in it generates a URL (`?rev=feature%2F1234`) instead of raising `UrlGenerationError` |
| `IssuesControllerTest#test_show_changesets_tab_should_not_display_branches_by_default` | **green on trunk too** — the default is unchanged |
| `IssuesControllerTest#test_show_changesets_tab_should_not_display_branches_without_view_changesets_permission` | the display inherits `Changeset.visible`: the same request shows `Branches: main` with the permission and no branch row anywhere on the page without it. The second assertion looks for the row on the whole response rather than inside the changeset block, so rendering branches outside the visible scope would fail it |
| `IssuesControllerTest#test_show_changesets_tab_should_not_display_branches_above_the_revision_display_limit` | with `repository_log_display_limit` at 1 and two associated revisions, both changesets still render and neither carries branches — the cap drops the display rather than half of it |
| `RepositoriesGitControllerTest#test_diff_should_show_the_branches_containing_the_revision` | the row also appears on the diff page, which renders the same `repositories/_changeset` partial — the second of the two places the setting governs |
| `SettingsControllerTest#test_post_revision_branches_excluded_should_not_save_an_invalid_regular_expression` | posting `Abc[` with the regex switch on comes back 200 with "is not a valid regular expression" and stores nothing, the same as the mail-handler pair |

**Evidence (INV-8 — figures, not claims).** All of it re-run on 2026-09-05
against trunk **r25037** (`bee32a926`), Ruby 3.3.6 / Rails 8.1.3 /
PostgreSQL 16, RuboCop 1.90.0.

- **full** suite, patch: `tools/test-env.sh /home/user/wt/patch-revision-branches bundle exec ruby bin/rails test:all`
  → `5995 runs, 31785 assertions, 27 failures, 2 errors, 92 skips`
- **full** suite, pristine trunk r25037 for comparison (`redmine_test_base`)
  → `5977 runs, 31715 assertions, 27 failures, 2 errors, 92 skips`
- the two failure lists are **identical**: 29 names on each side, with no name
  in one and not the other (`comm -13` and `comm -23` both empty). The 18-run
  difference is exactly the tests this patch adds.
- the 29 failures on trunk are all Subversion-dependent and unrelated:
  `RepositoriesControllerTest` (14), `Redmine::ApiTest::RepositoriesTest` (8),
  `SysControllerTest` (5), `UserTest#test_destroy_should_nullify_changesets`,
  `Redmine::ApiTest::IssuesTest#test_GET_/issues/:id.xml_should_not_disclose_associated_changesets_from_projects_the_user_has_no_access_to`.
  `svn` is not installed in this image. The patch's failure list is compared by
  **name**, not by count — two runs of the same tree give different assertion
  totals because Redmine randomises test order.
- touched suites in one process (`git_adapter_test`, `repository_git_test`,
  `changeset_test`, `repositories_git_controller_test`,
  `issues_controller_test`, `settings_controller_test`)
  → `672 runs, 4275 assertions, 0 failures, 0 errors, 16 skips`
- RuboCop on the 10 changed Ruby files: **0** offences
  (baseline, same files at `origin/master` r25037 with the same `Gemfile.lock`:
  **0**)
- each new test verified red on the old code, by reverting only the production
  code and keeping the test:
  - `branches_containing` × 3 and `Changeset#branches` × 3 →
    `NoMethodError: undefined method 'branches_containing' for an instance of Redmine::Scm::Adapters::GitAdapter`
    and `NoMethodError: undefined method 'branches' for an instance of Changeset`
  - the settings-form test, with only the `validate_all_from_params` row
    removed → `Expected response to be a <2XX: success>, but was a <302: Found>`
    and the value stored
  - the cap test, with only the limit arithmetic replaced by `true` →
    `Expected exactly 0 elements matching "em", found 2`
  - the conversion test, with only the `if name` guard removed →
    `ArgumentError: comparison of NilClass with String failed` from `sort!`
  - the four view tests, with the branch block deleted from the two partials →
    all four red, including
    `test_show_changesets_tab_should_not_display_branches_without_view_changesets_permission`,
    which is the point of its rewrite
  - the tests that use `with_settings` on a tree with no settings at all →
    `RuntimeError: There's no setting named …`. That is honest red but it is the
    setting missing, not the behaviour. The two **guard** tests exist for
    exactly this: `test_revision_should_not_show_branches_by_default` and
    `test_show_changesets_tab_should_not_display_branches_by_default` pass on
    trunk *and* on the patch, and they are what pins the unchanged default.
- **Cost, measured**, by instrumenting `AbstractAdapter#shellout` and driving
  real requests against the patch on r25037. Issue 1 given all 29 changesets of
  the Git fixture repository; three runs, uncached and not warmed up, so the
  millisecond figures are a range and the subprocess counts are exact and
  identical across all three:

  | Page | setting off | setting on |
  |---|---|---|
  | issue tab, 29 associated revisions | 0 subprocesses, 189–194 ms | 29 subprocesses, 460–589 ms |
  | issue tab, same, above the cap | — | **0 subprocesses, 140–165 ms** |
  | revision page | 0 subprocesses, 143–150 ms | 1 (`branch`), 109–217 ms |
  | diff page | 1 (`show`), 109–163 ms | 2 (`show`, `branch`), 114–121 ms |
  | repository browse page (untouched) | 5 (`branch`, `show-ref`, `ls-tree`, `log`, `tag`) | — |

  That last row is what note 20's "three git commands" refers to. The revision
  page runs none today and one with the setting on.
- patch applies to pristine `origin/master` r25037: **yes** — each of the two
  files applies on its own, and the two together reproduce the branch tree
  exactly (`tools/check-patch-clean.sh` checks that as its fifth check)
- `tools/check-patch-clean.sh revision-branches --submit`: **PASS** — only
  Redmine paths (19 files), locales within en/nl/fr/de/es, no AI trace in the
  header or the message, applies to a pristine r25037 checkout, and branch and
  patch file are the same change

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb` plus `docs/features/revision-branches/seed.rb`, which adds
a Git repository with five branches — `main`, `release/7.0`,
`12345-add-revision-branches`, `dependabot/bundler/rails-8.1.4`,
`wip/experiment` — and links **two** of its commits to issue 1. The
`dependabot/…` branch is there so that excluding it is visible rather than
theoretical, and the second associated revision is there so the cap is visible
rather than described. Screenshots in
`docs/features/revision-branches/shots/`.

Every case below was asserted, not only photographed: the verification reads
the branch names out of the DOM and compares them to a literal expected list,
on both instances. All 10 before-cases and all 14 after-cases pass.

| Function | Screenshot | What it shows |
|---|---|---|
| The four settings | `before-settings-repositories.png` | Repositories tab on trunk: `Apply text formatting to commit messages` is the last setting in the box |
| | `settings-repositories.png` | the same tab, at the defaults: both checkboxes off, the exclusion box empty, its `Enable regular expressions` switch, the hint `Multiple values allowed (comma separated). Example: dependabot/*, wip-*` and the line `Branch information is only available for Git repositories.` |
| Branches on the revision page | `before-revision-branches.png` | trunk: ID, Parent, Child |
| | `revision-branches.png` | a `Branches` row between Parent and Child, five branch names, each a link |
| The same row on the diff page | `before-diff-branches.png` | trunk: ID, Parent, Child, then the diff |
| | `diff-branches.png` | the `Branches` row above the diff — `repositories/_changeset` is shared by both views, which is why the setting's label names both pages |
| Branches in associated revisions | `before-issue-branches.png` | trunk: `Revision a80b7eca (diff)` and `Revision 7b8c278c (diff)` |
| | `issue-branches.png` | both rows now read `… (diff) Branches: 12345-add-revision-branches, dependabot/bundler/rails-8.1.4, main, release/7.0, wip/experiment` |
| A branch name is a working link | `revision-branch-link-followed.png` | clicking `release/7.0` lands on `demo @ release/7.0` with the branch selector set to it — the link is followed, not just rendered |
| Exclusion by name pattern | `before-revision-excluded-glob.png` | trunk: no row at all |
| | `revision-excluded-glob.png` | `dependabot/*, wip/*` excluded, the other three still listed |
| Exclusion by regular expression | `revision-excluded-regex.png` | `.*/.*` leaves only the two names without a slash |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| both settings off (the default) | `revision-default.png`, `issue-default.png` | identical to trunk, no command run | identical to `before-revision-default.png` / `before-issue-default.png` |
| more revisions than the cap | `issue-above-limit.png` | with `repository_log_display_limit` at 1 and two associated revisions, both revisions still render and neither carries branches; the revision page is unaffected | exactly that — and the revision page in the same state still lists all five |
| invalid regular expression at the form | `settings-invalid-regex.png` | rejected, nothing stored | `Exclude branches by name is not a valid regular expression (premature end of char-class: /[/)`, the value echoed back in the field, the settings unchanged — the same behaviour as the mail-handler field |
| invalid regular expression already in the settings table | `revision-invalid-regex.png` | page renders, `[` ignored, `main` still excluded | exactly that — four branches, `main` gone, no 500. Written with `Setting[:revision_branches_excluded] =`, which runs no form validation, because that is the only way such a value can now exist |
| permission absent | `issue-no-permission.png` | no Associated revisions tab at all, so no branches, whatever the setting says | exactly that (user `norepo`, role `Issue reader` with `view_issues` only). `Changeset.visible` filters on `:view_changesets`, and the branch display inherits that gate rather than adding one of its own |
| SCM that cannot answer | — | no row | covered by `ChangesetTest#test_branches_should_be_empty_for_a_scm_without_branch_support`; the dev image has no Subversion binary to show it in a browser |

Screenshots read, not just generated: yes. What that caught, and what it
confirmed:

- **Round 1 (2026-09-03).** The settings hint rendered as
  `Multiple values allowed (comma separated). Example: eg. ^[A-Z0-9]+$` —
  `text_regexp_info` already starts with "eg.", so `label_example` in front of
  it was redundant. Only visible by looking.
- **Round 2 (2026-09-05).** The remaining half of that, which the first reading
  missed: `^[A-Z0-9]+$` is a regular expression, and the field takes globs
  until the switch below it is ticked. The hint now shows glob examples, the
  way `_mail_handler.html.erb` does for the field this one is modelled on.
- Every branch name is a working link, not just an `<a>` in the DOM. The
  verification clicks `release/7.0` and asserts the page that comes back is the
  repository browser at that branch. This is the check the 5.1 grouping link
  would have failed, and it is why the screenshot of the destination is in the
  table above.
- The `Branches` row sits between `Parent` and `Child`, which is where a reader
  looks for it, and the issue-tab line stays subordinate to the revision link.

# Anticipated objections

| Objection | Answer |
|---|---|
| A Git subprocess per page view. Redmine caches changesets in the database precisely to keep the SCM out of rendering. | Correct, and it is note 18. Four things bound it. Both displays are off by default, so no existing installation pays anything. The issue tab is capped: above `repository_log_display_limit` associated revisions (default 100) it runs no command and shows no branches, so N is bounded by a number the administrator already sets. The revision page renders one extra command and is already excluded from crawlers by the `Disallow: /projects/<project>/repository` prefix `robots.text.erb` emits — note 20's "repository page calls three git commands" is about the repository *browse* page, which this patch does not touch; the revision page itself makes no SCM call today. And the alternative — a cached copy — is what notes 4 and 17 reject as unfixably wrong after a delete or a force-push. Measured on a 29-commit fixture repository: an issue tab with 29 associated revisions goes from 466 ms and 0 subprocesses to 1007 ms and 29, which is what the cap exists to bound. |
| Note 20 says that if the issue page starts calling Git, robots must be excluded from it too. | It does not start calling Git on `GET /issues/123`: the associated revisions tab is `:remote => true` with no `:partial`, so that request renders an empty container and runs no command. The endpoint that does render it, `issues#issue_tab`, answers `422` to anything that is not an XHR, so it cannot be crawled by URL either. What remains is a crawler that executes JavaScript and follows the `?tab=changesets` link: the inline `javascript_tag` in `common/_tabs.html.erb` fires `getRemoteTab` on load, and `/issues/:id` is not in `robots.txt`. That case is real, and it is bounded by the same cap as every other caller — no command above `repository_log_display_limit` revisions, and nothing at all while the setting is off. If a reviewer would rather close it outright, one line in `robots.text.erb` (`Disallow: /issues/*/tab/`) covers a route no human navigates to directly and does not deindex issue pages. The revision page, which does render server-side, is already covered by the `Disallow: /projects/<project>/repository` prefix. |
| Git only, of six adapters. | Only Git can answer it. Subversion branches are a directory convention, not a graph property (note 11). `Changeset#branches` guards with `respond_to?(:branches_containing)`, so the other five are untouched and Mercurial named branches (note 30) need only the adapter method. The settings tab says so in words (`text_revision_branches_git_only`, an `em.info` under the block) rather than hiding the settings on a non-Git installation: with Git in `enabled_scm` but this project's repository on Subversion the settings are still meaningful, so gating on `enabled_scm` would be wrong in the mixed case that is the common one. |
| Four new settings for one display feature. | Two are the on/off switches, and they must be separate because their costs differ in kind. The other two are one exclusion list plus its glob-or-regex switch, which is the shape core already uses for `mail_handler_excluded_filenames`; `Changeset#excluded_branch_patterns` is deliberately `MailHandler#accept_attachment?` with the names changed, down to the `\A…\z` anchoring and the `*` → `.*` translation. If three is the limit, drop `revision_branches_enable_regex` and treat every pattern as a regular expression — one line. |
| The name `branches` on `Changeset` will collide. | It does not: `Changeset` has no `branches` today, and `Repository#branches` (a different thing — all branches with their tips) stays as it is. `Changeset#branches` is the name Patch #7829 chose in 2011. |
| An administrator's bad regular expression will break the revision page. | It is rejected before it is stored, by the same mechanism as the pair this is modelled on: `revision_branches_excluded` is a row in `Setting.validate_all_from_params`, so the settings form comes back with "is not a valid regular expression" and saves nothing — exactly what `mail_handler_excluded_filenames` does. `Changeset#excluded_branch_patterns` still rescues `RegexpError` and drops that one pattern, as a guard against a value written straight into the `settings` table; both halves are tested, and the render is photographed (`revision-invalid-regex.png`). |
| Branch names come from outside Redmine, so this is an injection surface. | `link_to_revision_branches` uses `safe_join` over `link_to`, so every name is escaped by Rails; nothing calls `html_safe` on SCM output. The adapter passes the identifier to `git_cmd`, which shell-quotes each argument, and a bad identifier makes git exit non-zero and yields `[]`. |
| Shouldn't this need `:browse_repository`? | No, and requiring it would be stricter than Redmine is about the same data. The branch links target `repositories#show`, which `lib/redmine/preparation.rb` grants under **both** `:view_changesets` and `:browse_repository`, and the branch selector on that page already lists every branch name to a `:view_changesets` user. `Changeset.visible` filters on `:view_changesets`, so both views are gated by that already, and adding a second check to only one of them would make them inconsistent. |
| Why not one setting that takes `off` / `revision` / `both`? | It would be one key instead of two, but it makes the common case (revision page only, issue tab off) a three-way choice instead of two checkboxes, and it has no precedent in Redmine's settings. Worth changing if a committer prefers it; it is a rename plus one condition. |

**Reported, not fixed** (INV-1 — noticed while working here, left alone):

- `config/locales/fr.yml` has `setting_mail_handler_enable_regex: "Utiliser les
  expressions regulières"` — *régulières* is missing its accent. The new key
  spells it correctly, so the two strings differ by one character.
- `config/locales/nl.yml` has `setting_mail_handler_enable_regex: Enable
  regular expressions`, still untranslated.
- `app/views/repositories/_changeset.html.erb` builds the parent and child
  lists with `.collect{…}.join(", ").html_safe`, where `safe_join` is what the
  rest of the codebase now uses. Pre-existing, and not this feature's to
  change.

---

## Submission

- **Issue:** **#5386** — https://www.redmine.org/issues/5386 (Feature, New,
  category SCM). Not a new issue: this is a 16-year-old request with the
  reviewer's objections already written down, and Jan is already note #42.
  Patch #7829 and Patch #38278 are the same subject and are already related.
- **Patches attached:** `patches/revision-branches/2026-09-05-r25037-feature.patch`
  (code + `en.yml`) and `-locales.patch` (`nl`, `fr`, `de`, `es`)
- **Made against:** `origin/master` r25037 (`bee32a926`, 2026-09-04)
- **Status:** klaar om in te dienen — nog niet ingediend
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commits op `7.0-stable-GEOxyz`:** `115230bc2` (de feature) en `8c1fa23fb`
  (ronde 2: de formuliervalidatie, de bovengrens, de hints en de labels)
- **Suites daar groen:** ja — volledige suite met systeemtests op 2026-09-05:
  `6119 runs, 32341 assertions, 0 failures, 0 errors, 39 skips`. Dat is echt
  0/0: op `7.0-stable` bestaan de SCM-afhankelijke tests die op trunk falen
  niet in dezelfde vorm. De aangeraakte suites in één proces:
  `675 runs, 4331 assertions, 0 failures, 0 errors, 1 skip`. RuboCop op
  dezelfde tien bestanden: 0, baseline op `origin/7.0-stable` ook 0.
- **`nl.yml` toegevoegd:** ja, samen met `fr`, `de` en `es` — identiek aan de
  patch (INV-10)
- **`tools/check-geoxyz-branch.sh`:** PASS
- **Wanneer kan deze commit vervallen?** Trunk staat op `7.0.0 devel`, dus een
  geaccepteerde patch landt in 7.1 of later en nooit in 7.0-stable. De
  GEOxyz-commit blijft dus nodig tot GEOxyz zelf naar die release gaat.
