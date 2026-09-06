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
  hem aanbieden. Zie "The note to post on #43355" hieronder: in zijn patches
  loopt de lijst dood zodra je de laatste rij van de laatste pagina verwijdert.
  GEOxyz draait de fix nu al; upstream krijgt hem als note. Neemt hij hem over,
  dan is er geen afwijking meer. **Let op:** onbewerkt Redmine doet dit overal
  al — `/issues?page=99` geeft net zo goed "No data to display" — dus de note
  is een verbetervoorstel en geen defectmelding (jouw keuze g15).
- **Kans dat Redmine dit aanneemt:** goed — het is een issue van jou dat een
  actieve bijdrager zelf heeft opgepakt en op trunk heeft gezet, en de
  categorie is al toegekend.
- **Wat jij nog moet doen:** één note aan #43355. De Engelse tekst staat
  kant-en-klaar onder **"The note to post on #43355"** — bedankje, bevestiging
  dat `0002` dekt wat GEOxyz nodig had, het voorstel, de diff van vier regels
  en de afgewogen alternatieven. Kopieer die ene sectie van begin tot eind, en
  niets erboven of eronder. Twee screenshots eraan hangen:
  `shots/members-last-page.png` en `shots/defect-empty-page-after-delete.png`;
  in allebei staat de adresbalk met `members_page=4`, en de eerste laat zien
  dat het project zeven leden had.

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
patches and one improvement offered on top of them, not a competing submission.

> **Not for pasting.** This section, *Why this belongs in core* and *What the
> two patches on #43355 do* are our own analysis; pasting them into #43355
> would explain Takenori's patch back to him. The text to post is the single
> section **The note to post on #43355** below, from its first line to its
> last.

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

# The note to post on #43355

Everything from here down to the end of *Alternatives considered* is the note,
in the order it should be posted. Nothing above this line and nothing below
that section goes to redmine.org.

## Confirmation, and thanks

Thank you for rebasing this onto current trunk and for splitting it into two
patches — that is a good deal more work than the original report deserved.

I have applied both patches to a clean trunk checkout, run the affected suites
and driven both tabs in a browser. `0002-groups-pagination.patch` covers the
part we needed on top of the original request: the group users tab is
paginated too, and `members_page` and `users_page` are separate parameters, so
the tab list and the principal list inside the add modals no longer move
together. From our side nothing is missing, and the eleven tests you added
stay green.

One improvement to offer on top of the two patches.

## Out-of-range pages, and why the members tab is the place to handle them

Redmine's paginator clamps a page number up to 1 but never down to the last
page, and the list views render their pagination block inside the "there are
rows" branch. So an out-of-range page renders `No data to display` with nothing
to navigate back with, and that is long-standing behaviour rather than anything
these patches introduce: `/issues?page=99` does it on plain trunk today, and
the issue context menu can even get you there by writing the current list URL
into `back_url`.

What the pagination does add is a way to reach that state on the members tab
by an ordinary click. With `per_page_options = 2,25,50`:

1. give a project 7 members and open **Settings → Members**; there are 4 pages
2. go to page 4, which holds one member (`members-last-page.png`)
3. remove that member

Six members remain, so there are three pages, but the tab is re-rendered for
`members_page=4`. `ordered_ids[offset, per_page]` returns `[]` at an offset
exactly equal to the member count and `nil` beyond it; either way the partial
takes its `else` branch and shows **"No data to display"** on a project that
has six members, with no pagination links below it.

The two attachments are that sequence, one screen each, and the address bar in
both says which page is being shown:

- `members-last-page.png` — step 2. Page 4 of 4, `(7-7/7)`, one member,
  `…/settings/members?members_page=4`.
- `defect-empty-page-after-delete.png` — step 3. Same URL, same tab,
  "No data to display".

The reason this is worth handling here rather than living with it as elsewhere:
the project settings tabs are rendered server-side into hidden `div`s and
switched by `showTab()` in JavaScript (`app/views/common/_tabs.html.erb`,
`app/assets/javascripts/application-legacy.js`). Clicking another settings tab
and coming back does not re-render the members tab, so nothing on the page
recovers it — the user has to reload. On the issue list the sidebar, the
filters and the *Issues* menu item all lead back to page 1.

The group users tab ends up in the same state by the same route. Removing a
group user is a two-step confirmation, and the confirmation view emits a
`back_url` hidden field taken from the referer of the confirmation request —
which still carries `users_page`.

## Suggested fix

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

One consequence worth stating rather than leaving to be found: the clamp is
local to the paginator, so the row links and the address bar keep the page
number that was asked for while a different page is rendered.
`members-page-clamped-after-delete.png` shows all three at once — the address
bar on `members_page=4`, the paginator on page 3 of 3 `(5-6/6)`, and the
hovered row link at the bottom of the window still pointing at
`/memberships/6?members_page=4`. Nothing breaks, because every subsequent
request is clamped again, but a URL copied at that moment points at a page that
does not exist. A controller-side redirect to a valid page would fix both; it
is the last of the alternatives below.

## Alternatives considered

- **Render the pagination links outside the `if members.any?` branch**, so an
  out-of-range page at least shows the links. Rejected: the paginator would
  then print `(13-14/6)` and offer a link to a page that does not exist. The
  page number is what is wrong, not the rendering.
- **Clamp inside `Redmine::Pagination::Paginator` itself**, which would fix
  every out-of-range page in Redmine at once — `/issues?page=99` included.
  That is the wider fix and it may well be the right one, but it changes the
  behaviour of every paginated list in the application, so it belongs in its
  own issue rather than in this one.
- **Drop the page parameter on delete**, sending the user back to page 1.
  Rejected: it also throws away the page after every ordinary delete, which is
  exactly what the patches added the parameter to prevent.
- **Redirect to a valid page** from the controller instead of clamping in the
  helper, so that the URL and the rendered page agree. It fixes the paragraph
  above as well, at the cost of an extra round trip and of touching the
  controllers rather than two helpers. Worth doing if the mismatch between the
  address bar and the rendered page is judged to matter; the clamp is proposed
  because it is the smaller change.

---

*End of the note.* What follows is our own record.

# Not pasted: why there is no patch file from us

**Our own competing patch on #43355.** Rejected on principle. The work is
Takenori's, it is on trunk, and a second full patch on the same issue makes it
less likely that either gets read. The clamp goes as a diff inside the note
text, not as an attachment: a fix stacked on `0001`/`0002` cannot apply
standalone to a clean `origin/master`, and INV-2 keeps such a file out of
`patches/`.

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
- RuboCop on the 10 changed Ruby files, with the version the `Gemfile` pins
  (**rubocop 1.88.2**, rubocop-rails 2.34.3): `0` offences at `885f04097`,
  `0` at the r24882 baseline on the same 10 files. Re-measured 2026-09-06 in
  two detached worktrees, one at `2563fa6a5` and one at `885f04097`, with
  `ruby …/rubocop-1.88.2/exe/rubocop --force-exclusion --format simple`.
  A **newer** RuboCop is not silent on these files: with an unpinned 1.90.0 the
  first review run reported 4 `Rails/StrongParametersExpect` offences, three in
  `application_controller.rb` and one in `groups_controller.rb`. All four sit on
  pre-existing `params[:id]` / `params[:project_id]` lines that neither
  Takenori's patches nor the clamp touch, so the delta is `0` under either
  version — but the absolute number only reproduces with the pinned one.
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
so one run is evidence for both.

**Three of them carry the browser's own chrome, and deliberately so.** The two
images the note attaches have to show *which page* is being displayed, and a
page number lives in the address bar — a viewport-only capture of an empty tab
cannot be told apart from a project with no members at all, which is exactly
what the note claims it is not. Playwright screenshots the viewport only, so
`MODE=note-shots` in `verify/members-pagination.mjs` drives a headed browser on
an Xvfb display and captures the X root window with `xwd` instead. Re-taken
2026-09-06:

| Shot | Server state | What the address bar and the page say together |
|---|---|---|
| `members-last-page.png` | clamp reverted in the working tree | `?members_page=4`, page 4 of 4, `(7-7/7)`, one member — the project demonstrably has seven |
| `defect-empty-page-after-delete.png` | same | same URL, "No data to display" — six members, nothing to click |
| `members-page-clamped-after-delete.png` | clamp restored | `?members_page=4` in the address bar, `(5-6/6)` on page 3 of 3, and the hovered row link at the bottom still `/memberships/6?members_page=4` — the recovery *and* the mismatch of the paragraph in *Suggested fix* |

The remaining eight shots are the earlier viewport-only captures; they document
the feature rather than the note, and nothing in them turns on a page number
that is not already visible in the page itself.

| Function | Screenshot | What it shows |
|---|---|---|
| The members tab before the change | `before-members-page-1.png` | all 7 members at once, no pagination line |
| The group users tab before the change | `before-group-users-page-1.png` | all 4 group users at once, no pagination line |
| Members tab paginates | `members-page-1.png` | 2 of 7 rows, `« Previous 1 2 3 4 Next » (1-2/7) Per page: 2, 25` |
| A second page is reachable | `members-page-2.png` | rows 3-4, URL `?members_page=2` |
| Page size can be raised | `members-per-page.png` | "Per page: 25" puts all 7 back on one page — and shows *Pager User2* with two roles on **one** row |
| The list keeps its page across an edit | `members-stay-on-page-after-edit.png` | Developer added to *Pager User2*, saved, still `(3-4/7)` on page 2 |
| The last page | `members-last-page.png` | page 4 of 4, `(7-7/7)`, one member, with `?members_page=4` in the address bar |
| Group users tab paginates | `group-users-page-1.png` | 2 of 4 rows with pagination |
| A second group page is reachable | `group-users-page-2.png` | rows 3-4, URL `?tab=users&users_page=2` |

Failure paths:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| Remove the only member of the last page, **without** the clamp | `defect-empty-page-after-delete.png` | the tab shows the remaining 6 members | "No data to display" on a project with 6 members, no pagination links, address bar still on `members_page=4` — **the finding** |
| Remove the only member of the last page, **with** the clamp | `members-page-clamped-after-delete.png` | the tab falls back to the new last page | page 3 of 3, `(5-6/6)`, *Pager User4* and *Pager User5*; the address bar and the row links keep `members_page=4` |
| Out-of-range page requested directly (`?members_page=9`) | — | falls back to the last page | covered by the two helper tests; not shot separately because it is the same code path as the row above |
| Group users tab, out-of-range page | — | falls back to the last page | covered by `GroupsHelperTest#test_paginate_group_users_clamps_a_page_past_the_last_one`. Not driven in the browser: removing a group user is a two-step confirmation flow, and the helper is the same code path |

Screenshots read, not just generated: yes. What was checked in each image —
that the pagination block is actually rendered and not merely present in the
DOM; that the row count matches the page size; that `(1-2/7)` and `(5-6/6)`
report the counts the fixture has; that the saved role change really shows
"Manager, Developer" rather than an edit form left open (the first run caught
exactly that and the script was corrected); and, in the three re-taken shots,
that the address bar reads `members_page=4` in all three and that the paginator
below the table disagrees with it in the clamped one.

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
