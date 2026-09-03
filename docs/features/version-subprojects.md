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
- **Wat jij nog moet doen:** een note met deze patch aan #43534 hangen, en
  daarin uitleggen dat `43534-v2.patch` een regressie bevat (zie hieronder).

**Het belangrijkste van deze sessie in één alinea.** Zowel jouw patch van
november als de bijgewerkte versie van Go MAEDA *vervangen*
`project.shared_versions` door `Version.visible.where(project_statement)`. Dat
wint de subprojectversies, maar het verliest elke versie die van búiten de
projectboom naar dit project gedeeld is — precies waar Redmine's
"sharing"-instelling voor bestaat. In Redmine's eigen testfixtures zakt het
filter van project 1 daardoor van zes naar vier waarden: de systeembreed
gedeelde versie van OnlineStore en de gedeelde versie van het privé-subproject
verdwijnen allebei, zonder waarschuwing. Deze patch maakt er een *vereniging*
van in plaats van een vervanging, en voegt de test toe die dat vastlegt. Die
test is groen op kale trunk en op deze patch, en rood op `43534-v2.patch`.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `2563fa6a5` = r24882 van 2026-08-03. De mirror
  liep dus ongeveer een maand achter op het moment van bouwen (2026-09-03).
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

The value list becomes the union of what the project can assign and what the
query can return, the filter endpoint builds the query from the request instead
of only from the project, and the browser tells that endpoint what the current
filters are.

| File | Change |
|---|---|
| `app/models/query.rb` | `fixed_version_values` unions `project.shared_versions` with `Version.visible.where(project_statement)` |
| `app/controllers/queries_controller.rb` | `filter` calls `build_from_params`, after the permission check |
| `app/assets/javascripts/application-legacy.js` | `addFilter` sends the filter form along with the field name |
| `test/unit/query_test.rb` | five tests on the value list |
| `test/functional/queries_controller_test.rb` | one test on the endpoint |

Three details are deliberate:

- **Union, not replacement.** `Version.visible.where(project_statement)` alone
  loses every version shared into this project from outside the queried tree.
  See "Alternatives considered".
- **`build_from_params` after `raise Unauthorized`, not before.** Building the
  query evaluates `available_filters`, which runs several queries. There is no
  reason to do that for a request that is about to be rejected.
- **`$('#filters-table').closest('form')`, not a list of form ids.** The filters
  partial always renders `#filters-table` inside whichever form the page uses,
  so one selector covers the issue list, the gantt, the calendar, the spent-time
  list, the project and user lists, and the query editor — including
  `#query-form` on `queries/new` and `queries/edit`, which an id list based on
  `#query_form` silently misses.

**New setting / migration / gem / route / permission:** none.

**Translations:** none — the patch adds no user-visible string. No locale file
is touched, so there is one patch file rather than two.

**Backward compatibility:** the value list only grows, and only with versions
the user may already see (`Version.visible`) that belong to projects the query
already covers. Saved queries are untouched: nothing about the stored filter
changes, and a stored value that is no longer valid was already handled the same
way. `TimeEntryQuery`'s `issue.fixed_version_id` filter picks up the same
improvement because it calls the same method.

# Alternatives considered

**Replace `project.shared_versions` with `Version.visible.where(project_statement)`.**
This is what the patch currently attached to #43534 does, in both its versions,
and it is the reason for the extra test in this one. It gains the subproject
versions and loses everything shared into the project from elsewhere: a version
with `sharing: 'system'`, a version shared down a tree from an ancestor, a
version shared up from a descendant that the query does not cover. Redmine's own
fixtures show it: the filter for `Project.find(1)` goes from
`["3", "4", "6", "7", "2", "1"]` to `["3", "4", "2", "1"]`. Version 7 is
"OnlineStore - Systemwide visible version", shared system-wide from a project
outside the tree, and version 6 is shared from the private subproject. Both
silently stop being filterable. The union costs one extra query and keeps them.

**Override `fixed_version_values` on `IssueQuery`.** That was the 5.1 shape, and
it made sense when the method was not yet generic. Since r16170 it is on
`Query`, and an override would duplicate it and leave `TimeEntryQuery`'s
`issue.fixed_version_id` filter with the old list.

**Send only the subproject filter to `/queries/filter`.** Smaller request, but it
hard-codes into the JavaScript which filter influences which value list.
`build_from_params` is what every other controller uses to turn filter params
into a query, and the next filter whose values depend on the query then needs no
JavaScript change at all.

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

| Test | What it proves |
|---|---|
| `QueryTest#test_fixed_version_filter_should_include_versions_shared_from_outside_the_project_tree` | the system-shared version 7 is still offered — the regression guard against the replacement approach |
| `QueryTest#test_fixed_version_filter_should_include_subproject_versions_when_displaying_subproject_issues` | an unshared subproject version is offered when subproject issues are displayed |
| `QueryTest#test_fixed_version_filter_should_not_include_subproject_versions_when_not_displaying_subproject_issues` | and is not offered when they are not |
| `QueryTest#test_fixed_version_filter_should_respect_selected_subprojects` | one selected subproject brings its own version and not the sibling's |
| `QueryTest#test_fixed_version_filter_should_include_all_subproject_versions_when_filtering_any_subproject` | the `*` operator on the subproject filter overrides the setting |
| `QueriesControllerTest#test_filter_should_take_the_current_filters_into_account` | `GET /queries/filter` answers for the query in the request, not for a bare project |

**Evidence (INV-8 — figures, not claims):**

- **full** suite with the patch: `RAILS_ENV=test bundle exec ruby bin/rails test`
  → `5796 runs, 30701 assertions, 27 failures, 2 errors, 92 skips`
- **full** suite on a pristine trunk worktree at the same revision →
  `5790 runs, 30684 assertions, 27 failures, 2 errors, 92 skips`
- the 29 failing test names are **identical** on both sides (`diff` empty); all
  29 are repository, changeset and `SysController` tests that need `svn`, `hg`,
  `bzr` or `cvs`, none of which exist in this image
- RuboCop on the four changed Ruby files: **0** offences (baseline at the merge
  base on the same files: **0**)
- each new test verified red on the old code: the four that assert the new
  behaviour were run against the unpatched `query.rb` and
  `queries_controller.rb` in the same worktree — 4 failures, each naming the
  version id that is missing from the list. The two guard tests
  (`..._shared_from_outside_the_project_tree` and
  `..._not_include_subproject_versions_when_not_displaying...`) are green on
  trunk by design; the first was additionally run against the rejected
  replacement implementation, where it fails with
  `"7" not found in ["3", "4", "2", "1"]`.
- patch applies to pristine `origin/master` r24882: yes
- `tools/check-patch-clean.sh`: PASS

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

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| Subprojects excluded (`Subproject` operator `none`) | `before-dropdown-main-project-only.png`, `dropdown-main-project-only.png` | no subproject version offered, before or after | identical lists on both sides: the project's own version and the system-shared one |
| A version shared from outside the tree | every shot above | present before and after | present in all eight |
| The other subproject's version, with one subproject selected | `dropdown-one-subproject.png` | absent | absent |

Screenshots read, not just generated: yes. All eight were opened and checked for
the option list actually being *visible* in the image, not merely present in the
DOM — the listbox opens at a fixed height and the fourth entry was scrolled out
of the first run, which is why `verify/version-subprojects.mjs` grows the select
before it shoots. `before-dropdown-one-subproject.png` is the single most
useful image: the issue row and the filter that cannot reach it are in the same
screenshot.

# Anticipated objections

| Objection | Answer |
|---|---|
| Sending the whole form makes the GET request long | It is the same form the page submits by GET when you press Apply. Any query a user can already run therefore already fits in a URL. |
| An extra query per call to `fixed_version_values` | One, and only when the query has a project. The list was already two round trips away (the AJAX call itself); the union adds one indexed `WHERE` on `versions` joined to `projects`. |
| Does this leak version names from projects the user cannot see? | No. The added scope is `Version.visible`, which is `Project.allowed_to_condition(User.current, :view_issues)`. The pre-existing `project.shared_versions` half is unchanged, including its own visibility behaviour. |
| Why not simply scope to the project tree, as the attached patch does? | Because that drops versions shared in from outside it. See "Alternatives considered" and the test that fails on that implementation. |
| `build_from_params` on a public endpoint | It only builds a `Query` in memory from filter params, exactly as `IssuesController#retrieve_query` does, and it now runs *after* the `view_permission` check rather than before it. Unavailable filters are ignored by `add_filters`. |
| The cached value list goes stale if the subproject filter is changed afterwards | True, and pre-existing for every remote filter; this patch does not touch that cache. Named under "Alternatives considered" so it is not mistaken for a regression. |
| Why does the "Subproject" filter influence another filter's values at all? | Because `project_statement` is what decides which issues the list contains, and a filter whose values do not match its own list is the defect being fixed. |

---

## Submission

- **Issue:** [#43534](https://www.redmine.org/issues/43534) — bestaat al, status
  New, met `43534-v2.patch` van Go MAEDA eraan
- **Patches attached:** `patches/version-subprojects/2026-09-03-r24882-feature.patch`
  (code, geen locales — er is geen nieuwe string)
- **Made against:** `origin/master` r24882 (2026-08-03)
- **Status:** klaar om als note aan #43534 te hangen
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `TBD`
- **Suites daar groen:** `TBD`
- **`nl.yml` toegevoegd:** n.v.t. — geen nieuwe string
- **`tools/check-geoxyz-branch.sh`:** TBD
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus: pas als GEOxyz naar de release gaat
  die deze wijziging bevat.
