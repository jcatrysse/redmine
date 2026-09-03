# members-pagination — paginatie op de projectleden- en de groepsledenlijst

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** de tab *Leden* in de projectinstellingen en
  de tab *Gebruikers* van een groep tonen nu één pagina tegelijk in plaats van
  alle leden. Op een project met duizenden leden scheelt dat seconden per
  paginaweergave.
- **Waar het vandaan komt:** 5.1-commit `455f5753c`. Geen port-commit — de
  7.0-branch had deze feature nog niet.
- **Doel:** upstream + GEOxyz, maar **de upstream-kant is niet van ons.**
  Takenori TAKAKI heeft op 2026-08-05 jouw eigen issue
  [#43355](https://www.redmine.org/issues/43355) opgepakt, jouw patch op de
  huidige trunk gerebased, hem in twee losse patches gesplitst en er een echte
  bug uit gehaald. Wij dienen dus **niets nieuws in** — dat zou de kans op
  allebei verkleinen. GEOxyz gaat zijn code draaien.
- **Afwijking GEOxyz ↔ upstream:** één commit, en die is een verbetering die we
  hem aanbieden. Zie "The finding" hieronder: in zijn patches loopt de lijst
  dood zodra je de laatste rij van de laatste pagina verwijdert. GEOxyz draait
  de fix nu al; upstream krijgt hem als note. Neemt hij hem over, dan is er
  geen afwijking meer.
- **Kans dat Redmine dit aanneemt:** goed — het is een issue van jou dat een
  actieve bijdrager zelf heeft opgepakt en op trunk heeft gezet, en de
  categorie is al toegekend.
- **Wat jij nog moet doen:** één note aan #43355 met de bevinding en de
  voorgestelde diff. De Engelse tekst staat kant-en-klaar onder
  "The finding" en "Suggested fix", inclusief de screenshot die het laat zien.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `2563fa6a5` = SVN **r24882** van **2026-08-03**.
  De mirror liep twee dagen achter op de datum waarop Takenori zijn patches
  postte (2026-08-05); beide patches applyen desondanks schoon op r24882.
- **Lost trunk dit al op?** Nee. `app/views/projects/settings/_members.html.erb`
  doet op r24882 nog `@project.memberships.preload(:project).sorted.to_a` en
  `app/views/groups/_users.html.erb` nog `@group.users.sort.each`. Geen van
  beide kent een paginator.
- **Bestaand issue op redmine.org?** Ja:
  [#43355](https://www.redmine.org/issues/43355) (Feature, New, categorie
  *Groups*, geen doelversie), aangemaakt door Jan Catrysse op 2025-10-15, met
  note 1 van Takenori TAKAKI op 2026-08-05 en twee bijlagen:
  `0001-members-pagination.patch` en `0002-groups-pagination.patch`. Verder
  gezocht op "members pagination": alleen #30981 (los onderwerp: selectie
  onthouden in de nieuw-lid-modal) en drie gesloten issues uit 2011/2017.
- **Verandert iets in trunk het ontwerp?** Nee.

---

# The problem

The Members tab of the project settings renders every membership of the
project, and the Users tab of a group renders every user in the group. On an
installation where a project has a few thousand members, that tab alone takes
seconds to build and produces a page nobody can usefully read.

This was reported as [#43355](https://www.redmine.org/issues/43355) in October
2025. Takenori TAKAKI rebased the change onto current trunk on 2026-08-05 and
split it into `0001-members-pagination.patch` and `0002-groups-pagination.patch`.
Both still apply cleanly to r24882. What follows is a verification of those two
patches plus one defect found in them, not a competing submission.

# Why this belongs in core

Both lists are core views rendered by core controllers, and the change is a
change to how those views load their rows. A plugin would have to override
`app/views/projects/settings/_members.html.erb` and `app/views/groups/_users.html.erb`
wholesale and keep them in step with core forever.

# What the two patches on #43355 do

| File | Change |
|---|---|
| `app/controllers/application_controller.rb` | `helper_method :per_page_option`, so a view can ask for the effective page size |
| `app/helpers/members_helper.rb` | `paginate_members(project)` — collects the sorted, de-duplicated member ids, then loads only the current page |
| `app/helpers/groups_helper.rb` | `paginate_group_users(group)` — the same for a group's users |
| `app/controllers/members_controller.rb` | `members_settings_query`, so add/edit/remove redirect back to the page you were on |
| `app/controllers/groups_controller.rb` | `group_users_query`, the same for the group users tab |
| `app/views/projects/settings/_members.html.erb` | renders one page and the pagination links; every row action carries `members_page` |
| `app/views/groups/_users.html.erb` | the same, carrying `users_page` |
| `app/views/members/_edit.html.erb`, `_new_modal.html.erb` | the forms post back with `members_page` |
| `app/views/groups/_new_users_modal.html.erb` | the form posts back with `users_page` |

**New setting / migration / gem / route / permission:** none. The page size is
the existing `per_page_options` setting, and the page number is a query
parameter.

**Translations:** none — no new user-visible string. `pagination_links_full`
and the "Per page" links are already translated.

**Backward compatibility:** an installation that never passes `members_page` or
`users_page` gets page 1, which is what it saw before whenever the list fits on
one page. Two things do change for everyone: a list of any size now carries the
`(1-n/n)` line under the table, and a project with more members than
`per_page_options.first` no longer shows all of them at once.

Two details in the patches are worth naming because they are the answers to the
obvious objections:

- **`members_page` and `users_page`, not `page`.** The new-member modal and the
  add-user modal paginate their own principal lists with `page`
  (`render_principals_for_new_members`, `render_principals_for_new_group_users`).
  A shared parameter would move both lists at once.
- **Members, not join rows.** `Member.sorted` joins roles, so a member with two
  roles is two rows in the ordered result. Takenori's `paginate_members`
  plucks the ids first and de-duplicates them in Ruby (keeping the first
  occurrence, which is the lowest role position), so a member with several
  roles is counted once and appears on one page. Verified in the browser:
  `shots/members-per-page.png` shows *Pager User2* with "Manager, Developer"
  on a single row out of seven.

# The finding

Removing the last row of the last page leaves the tab on a page that no longer
exists, and there is no way back from it in the interface.

Reproduce on a stock instance with `per_page_options = 2,25,50`:

1. give a project 7 members, open **Settings → Members**; there are 4 pages
2. go to page 4, which holds one member (`shots/members-last-page.png`)
3. remove that member

The tab is re-rendered for `members_page=4`, but there are 6 members now and so
only 3 pages. `Redmine::Pagination::Paginator` does not clamp the page number,
`ordered_ids[offset, per_page]` is `nil`, and the partial takes its
`else` branch: **"No data to display"**, on a project with six members, with no
pagination links to navigate back with. Only editing the URL or leaving the tab
recovers it. `shots/defect-empty-page-after-delete.png` is that screen.

The group users tab has the same shape: `remove_users` redirects back to the
referer, which still carries `users_page`.

This is reachable without touching the URL, so it will be reported as a bug on
any installation large enough to want the feature.

# Suggested fix

Clamp the requested page to the last one, in both helpers. Four lines, no new
behaviour anywhere else — an in-range page number is unaffected.

```diff
--- a/app/helpers/members_helper.rb
+++ b/app/helpers/members_helper.rb
@@
-    member_pages = Redmine::Pagination::Paginator.new(ordered_ids.size, per_page_option, params['members_page'], 'members_page')
+    per_page = per_page_option
+    # Clamped to the last page, because removing the last member of a page must
+    # not leave the tab on a page that no longer exists.
+    page = [params['members_page'].to_i, (ordered_ids.size + per_page - 1) / per_page].min
+    member_pages = Redmine::Pagination::Paginator.new(ordered_ids.size, per_page, page, 'members_page')
--- a/app/helpers/groups_helper.rb
+++ b/app/helpers/groups_helper.rb
@@
-    user_pages = Redmine::Pagination::Paginator.new(user_count, per_page_option, params['users_page'], 'users_page')
+    per_page = per_page_option
+    # Clamped to the last page, because removing the last user of a page must
+    # not leave the tab on a page that no longer exists.
+    page = [params['users_page'].to_i, (user_count + per_page - 1) / per_page].min
+    user_pages = Redmine::Pagination::Paginator.new(user_count, per_page, page, 'users_page')
```

With three tests, each of which fails without the change above:

```ruby
# test/helpers/members_helper_test.rb
def test_paginate_members_clamps_a_page_past_the_last_one
  stubs(:per_page_option).returns(2)
  project = Project.generate!
  3.times {User.add_to_project(User.generate!, project)}
  params['members_page'] = '9'

  members, member_pages, member_count = paginate_members(project)

  assert_equal 3, member_count
  assert_equal 2, member_pages.page
  assert_equal 1, members.size
end

# test/helpers/groups_helper_test.rb
def test_paginate_group_users_clamps_a_page_past_the_last_one
  stubs(:per_page_option).returns(2)
  group = Group.generate!
  3.times {group.users << User.generate!}
  params['users_page'] = '9'

  users, user_pages, user_count = paginate_group_users(group)

  assert_equal 3, user_count
  assert_equal 2, user_pages.page
  assert_equal 1, users.size
end

# test/functional/members_controller_test.rb
def test_destroy_a_member_that_removes_the_last_page_should_render_the_new_last_page
  project = Project.find(1)
  member = nil
  (51 - project.memberships.count).times {member = User.add_to_project(User.generate!, project)}
  @request.session[:user_id] = 2

  with_settings :per_page_options => '25,50,100' do
    delete(:destroy, :params => {:id => member.id, :members_page => 3}, :xhr => true)
  end
  assert_response :success
  assert_equal 50, project.memberships.count
  # Page 3 no longer exists, so the tab falls back to the new last page
  # instead of rendering a list the user cannot navigate out of.
  assert_not_include 'nodata', response.body
  assert_equal 25, response.body.scan(/member-\d+-roles/).size
  assert_include 'members_page=1', response.body
end
```

# Alternatives considered

- **Render the pagination links outside the `if members.any?` branch**, so an
  out-of-range page at least shows the links. Rejected: the paginator would
  then print `(13-14/6)` and offer a link to a page that does not exist. The
  page number is what is wrong, not the rendering.
- **Clamp inside `Redmine::Pagination::Paginator` itself**, which would fix
  every out-of-range page in Redmine at once. Rejected here as out of scope for
  this issue: it changes the behaviour of every paginated list in the
  application and deserves its own issue.
- **Drop the page parameter on delete**, sending the user back to page 1.
  Rejected: it also throws away the page after every ordinary delete, which is
  exactly what the patches added the parameter to prevent.
- **Our own competing patch on #43355.** Rejected on principle. The work is
  Takenori's, it is on trunk, and a second full patch on the same issue makes
  it less likely that either gets read.

# Tests

| Test | What it proves |
|---|---|
| `MembersHelperTest#test_paginate_members_returns_only_the_requested_page` (Takenori) | one page is loaded, not the whole list |
| `MembersHelperTest#test_paginate_members_lists_a_member_with_several_roles_once` (Takenori) | a member with two roles is one row, not two |
| `MembersControllerTest#test_update_xhr_should_keep_members_tab_in_pagination_links` (Takenori) | the re-rendered tab keeps `settings/members?members_page=` |
| `MembersControllerTest#test_edit_xhr_should_keep_current_page_in_form_action` (Takenori) | the edit form posts back with the current page |
| `MembersControllerTest#test_new_xhr_should_keep_current_page_in_form_action` (Takenori) | the new-member form posts back with the current page |
| `ProjectsControllerTest#test_settings_members_should_be_paginated` (Takenori) | 25 rows and a pagination block on the settings page |
| `ProjectsControllerTest#test_settings_members_with_multiple_roles_should_not_appear_on_two_pages` (Takenori) | no member appears on two pages |
| `ProjectsControllerTest#test_settings_members_should_show_requested_page` (Takenori) | `members_page=2` returns the second page |
| `GroupsControllerTest#test_edit_users_tab_should_be_paginated` (Takenori) | 2 rows per page, links carry `users_page` |
| `GroupsControllerTest#test_new_users_xhr_should_keep_current_page_in_form_action` (Takenori) | the add-user form posts back with the current page |
| `GroupsHelperTest#test_paginate_group_users_returns_only_the_requested_page` (Takenori) | one page of group users is loaded |
| `MembersHelperTest#test_paginate_members_clamps_a_page_past_the_last_one` | page 9 of 2 resolves to page 2, not to an empty list |
| `GroupsHelperTest#test_paginate_group_users_clamps_a_page_past_the_last_one` | the same for the group users tab |
| `MembersControllerTest#test_destroy_a_member_that_removes_the_last_page_should_render_the_new_last_page` | the reachable path: after the delete the tab shows the new last page, not "No data to display" |

**Evidence (INV-8):**

- affected suites, pristine trunk r24882: `169 runs, 803 assertions, 0 failures, 0 errors, 0 skips`
- affected suites, + `0001` + `0002`: `180 runs, 844 assertions, 0 failures, 0 errors, 0 skips`
- affected suites, + the clamp (on `7.0-stable-GEOxyz`): `183 runs, 855 assertions, 0 failures, 0 errors, 0 skips`
- **full** suite on `patch/members-pagination`, all three commits:
  `tools/test-env.sh /home/user/wt/patch-members-pagination bundle exec ruby bin/rails test:all`
  → `5934 runs, 31506 assertions, 27 failures, 2 errors, 92 skips`
  (an earlier run of the same worktree carrying only `0001` and `0002` gave
  `5931 runs, 31493 assertions, 27 failures, 2 errors, 92 skips` — the three
  clamp tests are the difference)
- **full** suite on pristine trunk r24882: `5920 runs, 31455 assertions, 27 failures, 2 errors, 92 skips`
- **full** suite on `7.0-stable-GEOxyz` with all three commits: `6000 runs, 31988 assertions, 0 failures, 0 errors, 39 skips`
- failing names identical between the patched and the pristine run: ja — 29 namen, exact dezelfde verzameling.
  All of them are Subversion repository tests; `svn` is not installed in this
  image, which `docs/runbook.md` records. None of them touch members or groups.
- RuboCop on the 10 changed Ruby files: `0` offences (baseline at r24882 on the
  same 10 files: `0`)
- each of the three new tests verified red on the code without the clamp: the
  two helper tests report `Expected: 2, Actual: 9`, and the controller test
  reports `"nodata" found in "$('#tab-content-members').html(... <p class=\"nodata\">No data to display</p> ...)"`.
  The clamp was removed from both helpers, the three tests were run, all three
  failed, and the clamp was restored.
- both patches apply cleanly to pristine `origin/master` r24882: yes
- `tools/check-patch-clean.sh patch/members-pagination`: PASS

# Live verification (G9)

Real Redmine at `http://127.0.0.1:3000`, seeded by `tools/dev-seed.rb` plus the
`rails runner` block inside `verify/members-pagination.mjs` (five extra members,
three extra group users, `per_page_options = 2,25,50`). Screenshots in
`docs/features/members-pagination/shots/`.

The `before-*` shots come from the unpatched `7.0-stable-GEOxyz` worktree; the
`after` shots from the same worktree with all three commits. The touched files
are byte-identical between `origin/master` and `origin/7.0-stable-GEOxyz`
(`git diff origin/7.0-stable-GEOxyz origin/master -- <the ten files>` is empty),
so one run is evidence for both. The one exception is
`defect-empty-page-after-delete.png`, deliberately taken on the trunk worktree
carrying `0001` and `0002` **without** the clamp.

| Function | Screenshot | What it shows |
|---|---|---|
| The members tab before the change | `before-members-page-1.png` | all 7 members at once, no pagination line |
| The group users tab before the change | `before-group-users-page-1.png` | all 4 group users at once, no pagination line |
| Members tab paginates | `members-page-1.png` | 2 of 7 rows, `« Previous 1 2 3 4 Next » (1-2/7) Per page: 2, 25` |
| A second page is reachable | `members-page-2.png` | rows 3-4, URL `?members_page=2` |
| Page size can be raised | `members-per-page.png` | "Per page: 25" puts all 7 back on one page — and shows *Pager User2* with two roles on **one** row |
| The list keeps its page across an edit | `members-stay-on-page-after-edit.png` | Developer added to *Pager User2*, saved, still `(3-4/7)` on page 2 |
| The last page | `members-last-page.png` | page 4 of 4, one member |
| Group users tab paginates | `group-users-page-1.png` | 2 of 4 rows with pagination |
| A second group page is reachable | `group-users-page-2.png` | rows 3-4, URL `?tab=users&users_page=2` |

Failure paths:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| Remove the only member of the last page, **without** the clamp | `defect-empty-page-after-delete.png` | the tab shows the remaining 6 members | "No data to display" on a project with 6 members, no pagination links — **the finding** |
| Remove the only member of the last page, **with** the clamp | `members-page-clamped-after-delete.png` | the tab falls back to the new last page | page 3 of 3, `(5-6/6)`, *Pager User4* and *Pager User5* |
| Out-of-range page requested directly (`?members_page=9`) | — | falls back to the last page | covered by the two helper tests; not shot separately because it is the same code path as the row above |
| Group users tab, out-of-range page | — | falls back to the last page | covered by `GroupsHelperTest#test_paginate_group_users_clamps_a_page_past_the_last_one`. Not driven in the browser: removing a group user is a two-step confirmation flow, and the helper is the same code path |

Screenshots read, not just generated: yes. What was checked in each image —
that the pagination block is actually rendered and not merely present in the
DOM; that the row count matches the page size; that `(1-2/7)` and `(5-6/6)`
report the counts the fixture has; that the saved role change really shows
"Manager, Developer" rather than an edit form left open (the first run caught
exactly that and the script was corrected); and that the defect shot really is
an empty tab on a populated project.

# Anticipated objections

| Objection | Answer |
|---|---|
| "Small installations now get a pagination line they never asked for." | True, and it is the same line every other Redmine list carries. With fewer members than the smallest `per_page_options` value the block is just `(1-n/n)`; the "Per page" links only appear once the count exceeds it. |
| "`per_page_option` writes to the session and is now callable from a view." | That is `helper_method :per_page_option` in `0001`. It is the same method the controllers already call, and it stores the chosen page size the same way it always did. |
| "A `pluck` of every member id still touches every row." | It does, but it returns integers, not `Member` objects with their roles and principals preloaded. That is the difference between a few milliseconds and the seconds #43355 reports. |
| "The clamp changes what an out-of-range page number means." | Only for a page that has no rows. Any page number within range resolves exactly as before, which the eleven tests from `0001`/`0002` show by staying green unchanged. |
| "Why not fix the clamp in `Paginator` for the whole application?" | Because that changes every paginated list in Redmine and belongs in its own issue. See *Alternatives considered*. |
| "Does the CSV export now only export the page you are looking at?" | No. The export form posts to `project_memberships_path(format: 'csv')` and `MembersController#index` is untouched by both patches. Measured on a project with 30 members and `per_page_options = 25,50,100`: the tab shows 25 rows, `GET .../memberships.csv?members_page=1` returns 30. |

---

## Submission

- **Issue:** [#43355](https://www.redmine.org/issues/43355) — Jan's own issue,
  taken up by Takenori TAKAKI
- **Patches attached:** none by us. `patches/members-pagination/` holds the two
  files that Takenori attached, committed unchanged so a later revision can be
  diffed against them.
- **Made against:** `origin/master` r24882 (2026-08-03)
- **Status:** niet ingediend — er komt alleen een note met de bevinding
- **Feedback en wat ermee gebeurde:** n.v.t.

## GEOxyz

- **Commits op `7.0-stable-GEOxyz`:** `351fe9e54` (members) + `55ae9d1dd` (groups) + `885f04097` (clamp)
- **Suites daar groen:** volledige suite `6000 runs, 31988 assertions, 0 failures, 0 errors, 39 skips`; geraakte suites `183 runs, 855 assertions, 0 failures, 0 errors, 0 skips`
- **`nl.yml` toegevoegd:** nee — de feature heeft geen nieuwe tekst
- **`tools/check-geoxyz-branch.sh`:** PASS
- **Wanneer kan deze commit vervallen?** De eerste twee commits zijn Takenori's
  patches; die komen in de release waarin #43355 landt (7.1 op zijn vroegst,
  nooit in 7.0-stable), dus zij vervallen zodra GEOxyz naar die release gaat.
  De derde commit, de clamp, vervalt op hetzelfde moment **als** upstream hem
  overneemt; doet upstream dat niet, dan blijft dat een permanente eigen patch
  van vier regels.
