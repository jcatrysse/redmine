# version-subprojects — the target version filter offers the versions the issue list can actually show

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** een projectissuelijst toont standaard ook de
  issues van zijn subprojecten, maar het filter "Doelversie" bood alleen de
  versies van het project zelf aan. Je zag dus een doelversie in de kolom staan
  waar je niet op kon filteren. Nu staan de versies van de subprojecten in het
  lijstje, precies voor zover die subprojecten in de query zitten.
- **Waar het vandaan komt:** 5.1-commit `89752a599`, geen port-commit
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen — letterlijk dezelfde diff aan beide
  kanten
- **Kans dat Redmine dit aanneemt:** goed — het issue bestaat al
  ([#43534](https://www.redmine.org/issues/43534)) en **Go MAEDA, een
  kerncommitter, heeft de patch op 2026-04-01 zelf al bijgewerkt naar trunk**.
  Dat is de sterkste indicatie die je kunt krijgen dat een feature gewenst is.
- **Wat jij nog moet doen:** een note met deze patch aan #43534 hangen. Jouw
  keuze g16g: de note **begint** met de regressie in `43534-v2.patch`, zakelijk,
  en noemt daarna wat er van Go MAEDA's werk behouden is (drie van zijn tests).
  De kant-en-klare Engelse tekst staat hieronder vanaf "The problem"; het getal
  dat erin hoort is **zes naar vijf als beheerder**, niet zes naar vier.

**Het belangrijkste van deze sessie in één alinea.** Zowel jouw patch van
november als de bijgewerkte versie van Go MAEDA *vervangen*
`project.shared_versions` door `Version.visible.where(project_statement)`. Dat
wint de subprojectversies, maar het verliest elke versie die van búiten de
projectboom naar dit project gedeeld is — precies waar Redmine's
"sharing"-instelling voor bestaat. In Redmine's eigen testfixtures zakt het
filter van project 1 daardoor als **beheerder** van zes naar **vijf** waarden:
versie 7, "OnlineStore - Systemwide visible version", verdwijnt. Dat is het
getal dat voor iedere lezer klopt. (Wie project 5 níet mag zien, telt vier in
plaats van vijf, maar dat komt door `Version.visible` en niet door de sharing —
die versie was voor hem ook op kale trunk al onzichtbaar in de *lijst*, alleen
niet in het *filter*. Zie de objectie over zichtbaarheid verderop; dat is een
apart, al bestaand verschijnsel.) Deze patch maakt er een *vereniging* van in
plaats van een vervanging, en voegt de test toe die dat vastlegt. Die test is
groen op kale trunk en op deze patch, en rood op `43534-v2.patch`.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `bee32a926` = r25037 van 2026-09-03; de patch is
  op 2026-09-05 op precies die revisie herbouwd (g05). De eerste versie stond op
  `2563fa6a5` = r24882 van 2026-08-03.
- **Lost trunk dit al op?** Nee. `Query#fixed_version_values`
  (`app/models/query.rb:660`) is op trunk nog steeds
  `project.shared_versions.to_a`, en `QueriesController#filter`
  (`app/controllers/queries_controller.rb:93`) bouwt nog steeds een lege query
  met alleen het project erin.
- **Bestaand issue op redmine.org?**
  [#43534 "target version filter including subprojects"](https://www.redmine.org/issues/43534),
  Patch, status New, categorie "Issues filter", aangemaakt door Jan Catrysse op
  2025-11-26. Bijlagen: de oorspronkelijke 5.1-patch, en `43534-v2.patch` van
  **Go MAEDA** (2026-04-01, "Updated the patch for the current trunk").
  [#30924](https://www.redmine.org/issues/30924) gaat over het filter
  "Doelversie's status" bij gedeelde versies en is gesloten; het raakt deze code
  niet. Gezocht op: *subproject version filter*, *target version subproject*.
- **Verandert iets in trunk het ontwerp?** Ja, drie dingen.
  1. `fixed_version_values` staat sinds r16170 (#24787, 2017, "Don't preload all
     query filters") op `Query`, niet op `IssueQuery`. De 5.1-patch zette er een
     override overheen op `IssueQuery`; op trunk hoort de wijziging in de
     generieke methode, en dan werkt hij meteen ook voor het filter
     `issue.fixed_version_id` van `TimeEntryQuery`.
  2. Diezelfde commit is de reden dat er überhaupt een AJAX-endpoint is: sinds
     r16170 worden filterwaarden die een lambda zijn pas opgehaald als je het
     filter toevoegt. Daarom volstaat de modelwijziging alleen niet.
  3. De JavaScript is verhuisd van `public/javascripts/application.js` naar
     `app/assets/javascripts/application-legacy.js`, en élk filterformulier in
     trunk heet nu `#query_form` of `#query-form`. De lijst van vijf
     formulier-id's uit de 5.1-patch is achterhaald.

---

# The problem

Redmine's default setting `display_subprojects_issues` makes a project's issue
list include the issues of its subprojects. Those issues can have a target
version that belongs to the subproject, and a version's default sharing is
`none`, so most of them are not shared with the parent. The issue list happily
shows such a version in its "Target version" column — and the "Target version"
filter does not offer it.

The reason is that `Query#fixed_version_values` answers a different question
than the one the filter asks. It returns `project.shared_versions`: the versions
this project can *assign* to its own issues. What the filter needs is the
versions the query can *return*, which follows `Query#project_statement` — the
project plus whichever subprojects the setting, or an explicit "Subproject"
filter, has brought into scope.

There is a second half. Since r16170 (#24787) a filter whose values are a lambda
is "remote": the values are not rendered with the page but fetched from
`GET /queries/filter` when the filter is added. That action builds a bare query
carrying only the project, so it cannot know which subprojects the query is
currently scoped to. Choose "Subproject is X", then add "Target version", and
the list you get back is computed as if no subproject filter existed.

# Why this belongs in core

`Query#fixed_version_values` is a core method feeding a core filter that is
rendered by a core partial and refreshed by a core controller action and the
JavaScript Redmine ships. A plugin would have to monkey-patch the model method,
re-open the controller action and replace a function in
`application-legacy.js` — three patches to private core behaviour to fix one
list. And the defect is not a preference: the filter offers a set of values that
does not match the set of values the same page displays.

# Proposed change

The value list becomes the versions the project can assign **plus** the visible
versions belonging to the projects the query covers, the filter endpoint builds
the query from the filter parameters in the request instead of only from the
project, and the browser sends it those filter parameters.

| File | Change |
|---|---|
| `app/models/query.rb` | `fixed_version_values` unions `project.shared_versions` with `Version.visible.where(project_statement)` |
| `app/controllers/queries_controller.rb` | `filter` calls `build_from_params` with the filter parameters, after the permission check |
| `app/assets/javascripts/application-legacy.js` | `addFilter` sends the current filter parameters along with the field name |
| `test/unit/query_test.rb` | seven tests on the value list |
| `test/functional/queries_controller_test.rb` | two tests on the endpoint |

Four details are deliberate:

- **Union, not replacement.** `Version.visible.where(project_statement)` alone
  loses every version shared into this project from outside the queried tree.
  See "Alternatives considered".
- **`build_from_params` after `raise Unauthorized`, not before.** Building the
  query evaluates `available_filters`, which runs several queries. There is no
  reason to do that for a request that is about to be rejected.
- **`params.slice(:f, :op, :v)`, not the whole request.** The values of a filter
  can only depend on the other filters, so only the filter parameters are
  passed. Handing the whole hash over would make the action's own `name`
  parameter double as a filter — `ProjectQuery` has a filter called `name` — and
  would let `c` and `t` reach setters that expect arrays.
- **`$('#filters-table').closest('form')`, not a list of form ids.** The filters
  partial always renders `#filters-table` inside whichever form the page uses,
  so one selector covers the issue list, the gantt, the calendar, the spent-time
  list, the project and user lists, and the query editor — including
  `#query-form` on `queries/new` and `queries/edit`, which an id list based on
  `#query_form` silently misses. Only the `f[]`, `op[...]` and `v[...]` fields
  of that form are serialised: `queries/new` and `queries/edit` are POST forms,
  and their `authenticity_token` has no business in a URL.

**What the list is, exactly.** "The versions the project can assign, plus the
visible versions belonging to the projects the query covers." That is not quite
the same as "every version an issue in the list could be sitting on". One case
stays outside it: a version owned by a project M with `sharing: 'descendants'`,
where M lies strictly between the queried project P and a subproject S that an
explicit subproject filter has put in scope while leaving M out. Such a version
is assignable to S's issues, but it is neither in `P.shared_versions`
(`descendants` sharing only reaches P from an ancestor) nor owned by a project
in `project_statement`. In Redmine's fixtures: project 1 → project 5 →
project 6, a `descendants` version in project 5, filter "Subproject is
project 6" → `projects.id IN (1,6)` and the version is not offered. Closing that
would mean asking "which versions can *any* project in the query assign", which
is a different and much wider predicate than either patch on this issue
proposes. It is named here rather than fixed.

**New setting / migration / gem / route / permission:** none.

**Translations:** none — the patch adds no user-visible string. No locale file
is touched, so there is one patch file rather than two.

**Backward compatibility:** the value list only grows, and only with versions
the user may already see (`Version.visible`) that belong to projects the query
already covers. Saved queries are untouched: nothing about the stored filter
changes, and a stored value that is no longer valid was already handled the same
way. `TimeEntryQuery`'s `issue.fixed_version_id` filter picks up the same
improvement because it calls the same method, and
`QueryTest#test_time_entry_query_fixed_version_filter_should_include_subproject_versions`
asserts it.

# Alternatives considered

**Replace `project.shared_versions` with `Version.visible.where(project_statement)`.**
This is what the patch currently attached to #43534 does, in both its versions,
and it is the reason for the extra test in this one. It gains the subproject
versions and loses everything shared into the project from elsewhere: a version
with `sharing: 'system'`, a version shared down a tree from an ancestor, a
version shared up from a descendant that the query does not cover. Redmine's own
fixtures show it. As an administrator the filter for `Project.find(1)` goes from
`["3", "4", "6", "7", "2", "1"]` to `["3", "4", "6", "2", "1"]`: version 7,
"OnlineStore - Systemwide visible version", shared system-wide from a project
outside the tree, silently stops being filterable. That is the loss caused by
the sharing semantics, and it holds for every user. As an anonymous user the
same comparison reads `["3", "4", "6", "7", "2", "1"]` → `["3", "4", "2", "1"]`,
because version 6 is additionally removed by `Version.visible` — a different
phenomenon, discussed under the visibility objection below. The union keeps
version 7 and costs three extra SQL statements.

**Override `fixed_version_values` on `IssueQuery`.** That was the 5.1 shape, and
it made sense when the method was not yet generic. Since r16170 it is on
`Query`, and an override would duplicate it and leave `TimeEntryQuery`'s
`issue.fixed_version_id` filter with the old list.

**Send only the subproject filter to `/queries/filter`.** Smaller request, but it
hard-codes into the JavaScript which filter influences which value list. Sending
all of the filter rows — and only those — costs nothing extra and keeps the
JavaScript ignorant of the dependency: `build_from_params` is what every other
controller uses to turn filter params into a query, so the next filter whose
values depend on the query needs no JavaScript change at all.

**Send the whole form.** That was the first shape of this patch, and it is
wrong on two counts. On `queries/new` and `queries/edit` the filters partial
renders inside a POST form, so `serializeArray()` puts `authenticity_token` —
which `config.filter_parameters` does not cover — into the query string of a
GET, where `production.log` and every reverse proxy in front of Redmine record
it. Measured on a live instance, adding the Target version filter on
`queries/new` produced a 665-character request carrying the token,
`query[name]`, `query[description]`, `query[visibility]`, `query[role_ids][]`,
`query[sort_criteria][…]` and `default_columns`; sending the filter rows only
makes the same request 134 characters. It also hands the action parameters it
has no use for, which is how the action's own `name` argument ends up doubling
as a `ProjectQuery` filter.

**Add a setting to turn this on.** The current behaviour is not a behaviour
anyone chose; it is a list that does not match its own page. A setting would
make a defect configurable.

**Recompute the values when the subproject filter changes.** `addFilter` caches
the fetched list in `filterOptions['values']` and never refetches it, so a
subproject filter changed *after* the target version filter was added still
shows the older list until the page is reloaded. That is pre-existing behaviour
of every remote filter and this patch does not change it; fixing it means
invalidating the cache on filter changes, which is a separate change to a shared
code path.

# Tests

Three of these tests come from `43534-v2.patch` and are kept under their own
names, marked **(v2)** below. Two of the three are unchanged; the third is
tightened, as noted.

| Test | What it proves |
|---|---|
| `QueryTest#test_fixed_version_filter_should_include_versions_shared_from_outside_the_project_tree` | the system-shared version 7 is still offered — the regression guard against the replacement approach |
| `QueryTest#test_fixed_version_filter_should_include_subproject_versions_when_displaying_subproject_issues` **(v2)** | an unshared subproject version is offered when subproject issues are displayed |
| `QueryTest#test_fixed_version_filter_should_not_include_subproject_versions_when_not_displaying_subproject_issues` | and is not offered when they are not |
| `QueryTest#test_fixed_version_filter_should_respect_selected_subprojects` **(v2, tightened)** | with subproject issues **hidden**, one selected subproject still brings its own version in, and not the sibling's — the filter widens the list past the setting, it does not only narrow within it. v2 runs this on the default setting, where the subproject is in scope anyway |
| `QueryTest#test_fixed_version_filter_should_include_all_subproject_versions_when_filtering_any_subproject` **(v2)** | the `*` operator on the subproject filter overrides the setting |
| `QueryTest#test_fixed_version_filter_should_return_the_issues_of_an_offered_subproject_version` | the loop is closed: a newly offered version, used as a filter value, actually returns the subproject issue that sits on it |
| `QueryTest#test_time_entry_query_fixed_version_filter_should_include_subproject_versions` | `TimeEntryQuery`'s `issue.fixed_version_id` filter gets the same list, which the patch claims and nothing pinned before |
| `QueriesControllerTest#test_filter_should_take_the_current_filters_into_account` | `GET /queries/filter` answers for the query in the request, not for a bare project |
| `QueriesControllerTest#test_filter_should_ignore_request_params_that_are_not_filters` | `c` and `t` in the request no longer reach the query, so a scalar `c=subject` still returns JSON instead of raising |

**Evidence (INV-8 — figures, not claims):**

Measured on 2026-09-05 against `origin/master` `bee32a926` = r25037, with
RuboCop 1.90.0, PostgreSQL 16, Ruby 3.3.6.

- **full** suite with the patch, system tests included
  (`tools/test-env.sh <worktree> bundle exec ruby bin/rails test:all`) →
  `5986 runs, 31733 assertions, 27 failures, 2 errors, 92 skips`
- **full** suite, same command, on a pristine trunk worktree at the same
  revision → `5977 runs, 31710 assertions, 27 failures, 2 errors, 92 skips`
- the 29 failing names are **identical** on both sides (`comm` of the two sorted
  lists is empty in both directions); all 29 are repository, changeset and
  `SysController` tests that need `svn`, `hg`, `bzr` or `cvs`, none of which
  exist in this image
- an earlier run of the patched suite had one extra failure,
  `StickyIssueHeaderSystemTest#test_sticky_issue_header_appears_on_scroll`. It
  is a flake, not this patch's: it passes three times out of three run on its
  own, it does not appear in the run above, and the only thing the patch changes
  in JavaScript is `addFilter`, which an issue page never calls.
- RuboCop on the four changed Ruby files: **0** offences, baseline **0** on the
  same files at `origin/master` r25037. (Measure it in a worktree that has a
  `Gemfile.lock`: without one RuboCop cannot resolve the Rails version and
  silently switches `Rails/*` cops off.)
- each new test verified red on the old code, in the same worktree:
  - six fail against unpatched `query.rb` and `queries_controller.rb` —
    `..._include_subproject_versions_when_displaying_subproject_issues`,
    `..._respect_selected_subprojects`,
    `..._include_all_subproject_versions_when_filtering_any_subproject`,
    `..._return_the_issues_of_an_offered_subproject_version`,
    `test_time_entry_query_fixed_version_filter_should_include_subproject_versions`
    and `QueriesControllerTest#test_filter_should_take_the_current_filters_into_account`,
    each naming the version id missing from the list
  - `..._include_versions_shared_from_outside_the_project_tree` is green on
    trunk by design and fails on the rejected replacement implementation with
    `"7" not found in ["3", "4", "2", "1"]`
  - `..._not_include_subproject_versions_when_not_displaying_subproject_issues`
    is a guard, green on trunk by design
  - `test_filter_should_ignore_request_params_that_are_not_filters` is green on
    trunk (which reads neither `c` nor `t` in this action) and errors on the
    first shape of this patch, which passed the whole `params` hash:
    `NoMethodError: private method 'select' called for an instance of String`
- SQL statements for one `fixed_version_values` on a query with a project,
  counted with an `sql.active_record` subscriber: **5 with the patch, 2 on
  trunk** with the settings cache warm; **6 against 2** on the first call in a
  process
- patch applies to pristine `origin/master` r25037: **yes**
- `tools/check-patch-clean.sh version-subprojects`: **PASS** (5 files, no
  framework path, no locale, no AI trace, applies to r25037, branch and file
  agree)

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`. Screenshots in `docs/features/version-subprojects/shots/`.
The seeded tree is `geoxyz-verify` with two subprojects, each with its own
unshared version, plus an unrelated project `geoxyz-verify-other` whose version
is shared system-wide, and one issue in the first subproject sitting on that
subproject's version.

| Function | Screenshot | What it shows |
|---|---|---|
| Target version list in the parent project | `before-dropdown-project.png` | only the project's own version and the system-shared one |
| | `dropdown-project.png` | both subproject versions added, the system-shared one still there |
| Target version added after filtering on one subproject (the AJAX path) | `before-dropdown-one-subproject.png` | issue #10 is in the list with target version "GEOxyz sub - geoxyz-verify-sub-1.0", and that value is not in the filter above it |
| | `dropdown-one-subproject.png` | that version is now offered, and the other subproject's is not |
| Filtering on a subproject version | `before-filter-subproject-version.png` | the URL asks for it and the query is right, but the widget cannot hold a value it has no option for and falls back to the first entry |
| | `filter-subproject-version.png` | one issue, and the widget shows the version that was asked for |
| The same filter in the query editor (`queries/new`), whose form is a POST form | `before-query-editor-filter.png` | no subproject version offered |
| | `query-editor-filter.png` | both offered, and the request behind it is 134 characters: `?project_id=1&type=IssueQuery&f[]=status_id&op[status_id]=o&f[]=&name=fixed_version_id` — the filter rows and nothing else. The verification fails if `authenticity_token`, `query[…]` or `default_columns` appears in that URL |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| Subprojects excluded (`Subproject` operator `none`) | `before-dropdown-main-project-only.png`, `dropdown-main-project-only.png` | no subproject version offered, before or after | identical lists on both sides: the project's own version and the system-shared one |
| A version shared from outside the tree | every shot above | present before and after | present in all ten |
| The other subproject's version, with one subproject selected | `dropdown-one-subproject.png` | absent | absent |

Screenshots read, not just generated: yes. All ten were opened and checked for
the option list actually being *visible* in the image, not merely present in the
DOM — the listbox opens at a fixed height and the fourth entry was scrolled out
of the first run, which is why `verify/version-subprojects.mjs` grows the select
before it shoots. `before-dropdown-one-subproject.png` is the single most
useful image: the issue row and the filter that cannot reach it are in the same
screenshot.

# Anticipated objections

| Objection | Answer |
|---|---|
| The GET request grows | Only the `f[]`, `op[...]` and `v[...]` fields are sent, so the request carries the filter rows and nothing else — the same fields the page already submits by GET when you press Apply. |
| An extra query per call to `fixed_version_values` | Three, measured, and only when the query has a project: `fixed_version_values` runs 5 SQL statements against trunk's 2 (`projects` for `project.descendants` in `project_statement`, the new `versions` SELECT, and its `preload(:project)`). On the very first call in a process it is 6 against 2, because `display_subprojects_issues` has to be read; after that the setting comes from the in-process cache. The list was already a round trip away — this is the AJAX call's own body. |
| Does this leak version names from projects the user cannot see? | Yes, and it already did — this patch does not change it in either direction. `Project#shared_versions` has no permission scoping at all; it is a pure sharing query, so on trunk the target version filter of a public project already lists versions belonging to private projects. Anonymously, trunk and this patch return byte-identical JSON for `/queries/filter?project_id=1&name=fixed_version_id`, including "Private child of eCookbook - …" and "OnlineStore - …". The half this patch adds is the *scoped* one (`Version.visible`), so the union can only ever add values the user may already see. The replacement in `43534-v2.patch` does tighten this, as a side effect of dropping `shared_versions` — but tightening what is filterable is a behaviour change that deserves its own issue, and it should then apply to both halves rather than fall out of an unrelated patch. |
| Why not simply scope to the project tree, as the attached patch does? | Because that drops versions shared in from outside it. See "Alternatives considered" and the test that fails on that implementation. |
| Does the value list now cover every version an issue in the list can sit on? | Not quite, and the gap is named under "Proposed change": a `descendants`-shared version owned by a project between the queried project and a subproject that an explicit subproject filter brought into scope. Closing it needs a wider predicate than either patch on this issue proposes. |
| `build_from_params` on a public endpoint | It builds a `Query` in memory from `params.slice(:f, :op, :v)` — the filter parameters only — exactly as `IssuesController#retrieve_query` does with the same three, and it now runs *after* the `view_permission` check rather than before it. Unavailable filters are ignored by `add_filters`. Because nothing else is passed, `c` and `t` no longer reach the array setters that would raise on a scalar, and the action's own `name` argument cannot become a filter value. |
| The cached value list goes stale if the subproject filter is changed afterwards | True, and pre-existing for every remote filter; this patch does not touch that cache. Named under "Alternatives considered" so it is not mistaken for a regression. |
| Why does the "Subproject" filter influence another filter's values at all? | Because `project_statement` is what decides which issues the list contains, and a filter whose values do not match its own list is the defect being fixed. |
| Does it still work with `display_subprojects_issues` off? | Yes. `project_statement` consults an explicit `subproject_id` filter first and only falls back to the setting when there is none, so the filter widens the version list past the setting. Asserted by `..._should_respect_selected_subprojects` (`=`) and `..._when_filtering_any_subproject` (`*`), both with the setting off, and by `..._not_include_subproject_versions_when_not_displaying...` for the case with the setting off and no subproject filter, where nothing from a subproject may appear. |

---

## Submission

- **Issue:** [#43534](https://www.redmine.org/issues/43534) — bestaat al, status
  New, met `43534-v2.patch` van Go MAEDA eraan
- **Patches attached:** `patches/version-subprojects/2026-09-05-r25037-feature.patch`
  (code, geen locales — er is geen nieuwe string)
- **Made against:** `origin/master` r25037 = `bee32a926` (2026-09-03)
- **Status:** klaar om als note aan #43534 te hangen
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commits op `7.0-stable-GEOxyz`:** `20ed9e2d1` + `d157934c0` (de aangescherpte
  test) + `e2f060570` (ronde 2: alleen de filterparameters, plus de drie extra
  tests) — samen **letterlijk dezelfde wijziging** als de patch; de trunk-diff
  gaat er ongewijzigd op, 7.0-stable en trunk zijn identiek in deze drie
  bestanden
- **Suites daar groen:** `test:all` → `6115 runs, 32313 assertions, 0 failures,
  0 errors, 39 skips` — helemaal groen, in tegenstelling tot trunk, waar 29
  repository- en changeset-tests falen omdat `svn`, `hg`, `bzr` en `cvs` niet in
  het image zitten
- **RuboCop daar:** `tools/check-geoxyz-branch.sh` meet 1 offence op 67
  gewijzigde Ruby-bestanden, allemaal op regels die `origin/7.0-stable` zelf al
  had (baseline 1). Deze feature voegt er nul toe. In een worktree mét
  `Gemfile.lock` komen er twee `Rails/StrongParametersExpect`-meldingen bij op
  `queries_controller.rb:96` en `:127` — beide op regels die deze feature niet
  aanraakt, en beide onzichtbaar zonder `Gemfile.lock`, wat het verschil met de
  meting van het gereedschap verklaart.
- **`nl.yml` toegevoegd:** n.v.t. — geen nieuwe string
- **Live nagelopen op deze branch:** ja, dezelfde `verify/version-subprojects.mjs`
  in `MODE=after` tegen een dev-server op de GEOxyz-worktree
- **`tools/check-geoxyz-branch.sh`:** PASS
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus: pas als GEOxyz naar de release gaat
  die deze wijziging bevat.
