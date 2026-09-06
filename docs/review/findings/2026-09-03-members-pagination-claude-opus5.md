# Review run — 2026-09-03 — members-pagination — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** no patch branch of ours. Two upstream patch files
  (`patches/members-pagination/0001-members-pagination.patch`,
  `0002-groups-pagination.patch`, by Takenori TAKAKI), the three GEOxyz commits
  `351fe9e54`, `55ae9d1dd`, `885f04097`, and the note text in
  `docs/features/members-pagination/dossier.md` ("The finding", "Suggested
  fix"). Baseline `origin/master` r24882 = `2563fa6a5`; current trunk head at
  review time `bee32a926`.
- **Dossier read:** `docs/features/members-pagination/dossier.md` — yes
- **Status read:** `docs/features/members-pagination/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes. Built a throwaway worktree at r24882, applied
  both of Takenori's patches, applied and reverted the clamp several times, and
  ran the affected suites in both states. Affected suites with all three
  changes: `183 runs, 855 assertions, 0 failures, 0 errors, 0 skips` — exactly
  the number the dossier claims. Also ran the full `test:all` under
  `tools/test-env.sh`: `5934 runs, 31507 assertions, 27 failures, 2 errors,
  92 skips`, matching the dossier on every count but assertions (31506 there),
  with all 29 red tests Subversion-dependent — details under "What I checked and
  found clean".
- **Scope covered:** correctness of the bug report (reproduced end to end),
  correctness and completeness of the suggested fix, test quality including one
  mutation experiment, whether unpatched core behaves the same way, minimality
  and AI traces on the three GEOxyz commits, INV-10 (GEOxyz vs upstream
  divergence), patch applicability to current trunk, RuboCop, escaping in the
  new pagination link blocks, the note's tone and its screenshot evidence.
- **Scope NOT covered:**
  - No browser. G9 was not re-driven; the screenshots were opened and read as
    images, not regenerated.
  - PostgreSQL only. MySQL and SQLite untested.
  - The other twelve own commits on `7.0-stable-GEOxyz` were not reviewed, and
    `tools/check-geoxyz-branch.sh` / `tools/check-patch-clean.sh` were not run
    (they write nothing, but running them was not needed for these findings).
  - No performance measurement on a large project. The claim "seconds saved on
    thousands of members" is taken on trust.
  - Takenori's eleven tests were run but not audited line by line; only the
    three tests that are ours were examined for vacuity.
  - The 5.1 origin commit `455f5753c` was not compared against what is here.

## Summary

The bug report is correct. I reproduced it exactly as the dossier describes it,
in an unmodified checkout of trunk r24882 carrying only Takenori's two patches:
a project with seven members, `per_page_options = 2,25,50`, remove the single
member on page 4, and the tab comes back with `No data to display` on a project
that still has six members, with no pagination links in the response at all. The
group users tab does the same thing, and it is reachable by clicking, not by
editing the URL. The suggested four-line clamp fixes both, does not touch the
in-range case, and the three tests attached to it are genuinely red without it —
I saw all three fail. They are also not vacuous: mutating the members clamp to
reset to page 1 instead of falling back to the last page — a change that also
removes the empty page — still fails both members tests (the group helper was
not mutated). The two GEOxyz commits that
carry Takenori's work are byte-identical to his patch files applied to trunk, so
INV-10 holds and the only divergence is the clamp, which is what the dossier
says.

The one thing that would change what Jan publishes: **unpatched Redmine already
behaves this way everywhere else.** `/issues?page=99` on plain trunk renders
`No data to display` with no pagination links, and deleting the last issue on
the last page from the context menu redirects back to that same out-of-range
page, because the context menu puts the list URL in `back_url`. I confirmed both
by experiment. So the note as drafted — "one defect found in them", "it will be
reported as a bug" — attributes to Takenori's patch a behaviour that is
Redmine's own paginator convention. The behaviour he introduces on the members
tab is new *for that tab*, and there is a genuine reason it is worse there (the
project settings tabs are pre-rendered divs toggled by JavaScript, so unlike the
issue list there is nothing left on the page to click), but the note does not
say any of that, and a committer who knows the codebase will answer with the
`/issues?page=99` example within a day. Reframing costs nothing and makes the
same fix much more likely to be taken.

Two smaller things about the note itself: the English text prepared for pasting
contains no thanks to Takenori and no confirmation that `0002` covers what
GEOxyz needed, although `status.md` says the note must do both — the prepared
text opens straight with the defect. And the single screenshot Jan is told to
attach shows an empty Members tab with nothing in it that says the project has
members, no page number and no URL bar, so on its own it does not show what the
note claims it shows.

**Counts:** blocker 0 · major 3 · minor 5 · nit 1 · question 1

**Lines in the diff not strictly required by the feature:** 4 — the two
two-line comments in the clamp commit (`885f04097`), one duplicated verbatim in
each helper. Defensible under INV-3 as a non-obvious *why*, and they match the
comment density of the patch they sit in. Everything else in all three commits
is required.

---

### F01 — The note attributes to Takenori's patch a behaviour unpatched Redmine already has everywhere

- **Status:** resolved 2026-09-06
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/members-pagination/dossier.md` — "The problem"
  ("plus one defect found in them"), "The finding" (last paragraph), and
  `docs/features/members-pagination/status.md` — "Wat Jan nog moet doen"
- **Invariant touched:** none

**What is wrong**

The note presents the empty out-of-range page as a defect that Takenori's
patches introduced. It is Redmine's existing behaviour for every paginated list:
`Redmine::Pagination::Paginator` clamps a page number up to 1 but never down to
the last page, and the list views render their pagination block inside the
"there are rows" branch — `app/views/issues/index.html.erb:29-34` and
`app/views/users/index.html.erb:18-23` are the same shape as the members
partial — so an out-of-range page renders `No data to display` with nothing to
navigate back with. The issue list does exactly this
today, on plain trunk, and it is reachable by clicking, not only by editing the
URL: the issue context menu writes the current list URL (page number included)
into `back_url`, and `IssuesController#destroy` redirects to it.

The behaviour *is* new on the members tab, because that tab had no pagination
before. But "a defect in these patches" is not how a committer will read it, and
the note gives him a one-line rebuttal.

**Why a committer would push back**

The predictable reply is "that is how `/issues?page=99` has always worked; if
you want it fixed, fix `Paginator`". The dossier already anticipates that
question and answers it under *Alternatives considered*, but that answer is not
in the two sections Jan is told to paste, so the reviewer never sees it. Worse,
the accusation is in someone else's issue, addressed to the contributor who did
the rebasing work — the tone risk and the technical risk point the same way.

There is one asymmetry that is genuinely in Jan's favour and that the note does
not use: the project settings tabs are rendered server-side into hidden divs and
switched by `showTab()` in JavaScript (`app/views/common/_tabs.html.erb`,
`app/assets/javascripts/application-legacy.js:405`). Clicking another settings
tab and back does not re-render the members tab, so the empty tab really does
persist in a way the issue list's empty page does not (there, the sidebar,
filters and the Issues menu item all lead back to page 1).

**How I verified it**

In `/tmp/rev-memb` (r24882 + `0001` + `0002`), a throwaway functional test
against `IssuesController`, which neither patch touches:

```
PROBE core issues?page=99 nodata=true pagination=false
PROBE core issue destroy redirect (back_url as the context menu sends it)
      -> "http://test.host/projects/ecookbook/issues?page=99"
```

`app/views/context_menus/issues.html.erb:177` sends `:back_url => @back`, and
`@back = back_url` is set in `app/controllers/context_menus/issues_controller.rb:56`,
so the page number in that `back_url` is the one the user was looking at. Read of
`lib/redmine/pagination.rb:34-38` confirms the paginator clamps `page < 1` to 1
and never clamps upwards. A redmine.org search for a pre-existing issue about
out-of-range pages was inconclusive — I did not find one, and I am not claiming
none exists.

**Suggested direction**

Keep the report; change what it claims. Good would be a note that says the
pagination inherits Redmine's existing out-of-range behaviour, shows it is now
reachable by an ordinary click on the members tab, names the one reason it is
worse there than on the issue list (the tabs are client-side toggles, so nothing
on the page recovers it), and then offers the four-line clamp as the local fix
*and* the `Paginator`-level fix as the alternative, saying plainly which one is
being proposed for this issue and why. That is a contribution rather than a
correction, and it removes the rebuttal.

- **Resolution:** fixed 2026-09-06. Jan settled the direction himself as **g15**:
  the note becomes an improvement proposal rather than a defect report. The
  dossier's pasteable text now opens by saying that an out-of-range page renders
  `No data to display` on every Redmine list, `/issues?page=99` included, and that
  the pagination is not what introduces it. What it does introduce — reaching that
  state on the members tab by an ordinary click — is stated as the reason to
  handle it here, together with the asymmetry this review supplied: the settings
  tabs are pre-rendered divs toggled by `showTab()`, so nothing on the page
  recovers it, while the issue list has a sidebar, filters and a menu item that
  all lead back to page 1. The `Paginator`-level fix is now named in the note's own
  *Alternatives considered* as the wider fix that may well be the right one, with
  the reason it belongs in its own issue, so the rebuttal is answered before it is
  made. `status.md` carries the same framing.

---

### F02 — The English text prepared for the note has no thanks and no confirmation, only the defect

- **Status:** resolved 2026-09-06
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/members-pagination/dossier.md` — "The finding",
  "Suggested fix"; requirement stated in `status.md` — "Wat Jan nog moet doen"
- **Invariant touched:** none

**What is wrong**

`status.md` tells Jan the note must do three things: thank Takenori for the
rebase and the split, confirm that `0002-groups-pagination.patch` covers the
group users list and the separated `members_page` / `users_page` parameters that
GEOxyz needed, and then report the finding. The dossier's English sections
deliver only the third. "The finding" opens with
"Removing the last row of the last page leaves the tab on a page that no longer
exists, and there is no way back from it in the interface." There is no prepared
sentence of acknowledgement anywhere in the two sections Jan is told to paste.

The acknowledgement that does exist ("Takenori TAKAKI rebased the change onto
current trunk … What follows is a verification of those two patches plus one
defect found in them") sits in "The problem", a section Jan is not told to
paste, and it credits without thanking.

**Why a committer would push back**

Not a committer — the contributor. This is a note in his thread on Jan's own
issue, and if the only text is a defect report it reads as a complaint. The
framework asked for the opposite, and the missing confirmation ("your `0002`
covers what we needed, nothing is missing") is also the single most useful thing
Jan can tell him, because it closes the original feature request.

**How I verified it**

Read both files. The strings "thank", "thanks" and "0002 … covers" do not occur
anywhere in the English sections of the dossier.

**Suggested direction**

Two or three prepared English sentences at the top of the pasteable block:
thanks for the rebase and the split, confirmation that `0002` covers the group
users list and the separate page parameters so the original request is fully
answered, and only then the finding. Also worth saying explicitly in the dossier
which sections are for pasting, because "The problem", "Why this belongs in
core", "What the two patches on #43355 do" and "Anticipated objections" are
written as if for a submission of our own and would explain his patch back to
him if pasted by accident.

- **Resolution:** fixed 2026-09-06. The pasteable text now opens with a section
  *Confirmation, and thanks*: thanks for the rebase and the split, then the
  confirmation that `0002-groups-pagination.patch` covers the group users tab and
  the separated `members_page` / `users_page` parameters, that nothing is missing
  from GEOxyz's side, and that the eleven added tests stay green. Only after that
  does the proposal start. The finding's second point is fixed too: the dossier
  now marks explicitly which section is for pasting. *The problem*, *Why this
  belongs in core* and *What the two patches on #43355 do* carry a
  "**Not for pasting**" block naming them, the note is one contiguous section
  called *The note to post on #43355*, it ends with an explicit *End of the note*
  marker, and the "our own competing patch" bullet — which was inside
  *Alternatives considered* and would have been pasted — has been moved out into a
  separate section below that marker.

---

### F03 — The screenshot attached as the note's evidence does not show what the note says it shows

- **Status:** resolved 2026-09-06
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/members-pagination/shots/defect-empty-page-after-delete.png`,
  cited in `dossier.md` ("The finding", "Live verification") and in `status.md`
  ("Hang er … bij — dat is een screenshot van een project met zes leden waar
  'No data to display' staat")
- **Invariant touched:** none

**What is wrong**

The image is a 1280-wide capture of the project settings page with the Members
tab selected, containing the "New member" link, the "Administration" link and
the yellow `No data to display` box. There is no browser chrome, so no URL and
no `members_page=4`; there is no pagination line, because the empty branch does
not render one; and there is nothing else on the page that reveals how many
members the project has. A reader who has not read the surrounding text cannot
tell it apart from a project with no members at all — which is the exact claim
the note rests on.

**Why a committer would push back**

The note says "a project that has members". The attachment does not show that.
Attaching a picture that does not demonstrate the claim in a thread where you
are reporting someone else's bug is the kind of thing that costs credibility
disproportionately.

**How I verified it**

Opened both images. `defect-empty-page-after-delete.png` shows only what is
described above. `members-last-page.png`, by contrast, shows the same project on
page 4 of 4 with `(7-7/7)`, the pagination row `« Previous 1 2 3 4 Next »` and
one member — it does carry the member count and the page number.

**Suggested direction**

The before/after pair the framework already asks for. `members-last-page.png`
followed by `defect-empty-page-after-delete.png` tells the whole story in two
images and proves the project had seven members a moment earlier. Alternatively
a single capture that includes the address bar with `members_page=4`. Either
way, name both images in the note text so the reader knows what to compare.

- **Resolution:** fixed 2026-09-06, along the line g15 asked for (member count
  *and* address bar). Playwright captures the viewport only, so the shots have been
  re-taken with a headed Chromium on an Xvfb display, grabbing the X root window
  with `xwd` — a new `MODE=note-shots` in `verify/members-pagination.mjs`. Three
  images were replaced, all against a real running Redmine:
  `members-last-page.png` (`?members_page=4` in the address bar, page 4 of 4,
  `(7-7/7)`, one member), `defect-empty-page-after-delete.png` (same URL, "No data
  to display"), and `members-page-clamped-after-delete.png`. The note attaches the
  first two as a pair and names both in its text, so the first proves the project
  had seven members a moment earlier and the second proves which page is being
  shown. The `xwd` route needed `x11-apps` and `imagemagick`, which were not in the
  image; that is recorded in `docs/traps.md`.

---

### F04 — Two mechanism sentences in the note text are wrong

- **Status:** resolved 2026-09-06
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `docs/features/members-pagination/dossier.md` — "The finding",
  paragraph beginning "The tab is re-rendered for `members_page=4`"
- **Invariant touched:** none

**What is wrong**

Both sentences are in text destined for a public note, and both are checkable in
thirty seconds by anyone who reads them.

1. "`ordered_ids[offset, per_page]` is `nil`". In the reproduction the note
   itself gives — six members left, `per_page` 2, page 4, so offset 6 — Ruby
   returns `[]`, not `nil`. `nil` only comes back when the offset is strictly
   greater than the array size, i.e. from page 5 onwards. The outcome is the
   same because of the `|| []`, but the sentence does not describe its own
   example. (It also does not describe the group tab at all, which uses SQL
   `limit`/`offset` and gets an empty relation.)

2. "The group users tab has the same shape: `remove_users` redirects back to the
   referer, which still carries `users_page`." `redirect_back_or_default` does
   not use the referer; it uses `params[:back_url]`
   (`app/controllers/application_controller.rb:506-518`). What actually happens
   is that removing a group user is a two-step confirmation, the confirmation
   view emits `back_url_hidden_field_tag` (whose value comes from the referer of
   the confirmation request), and that `back_url` carries `users_page`. Takenori's
   own `group_users_query` is not what preserves the page here: the confirmation
   form posts to `group_users_path(@group, :user_ids => …)` without
   `users_page`, so `params[:users_page]` is absent at that point.

**Why a committer would push back**

Item 2 in particular: telling the author of a patch how his own code behaves,
and getting the mechanism wrong, invites him to answer the mechanism instead of
the bug.

**How I verified it**

1. `ruby -e 'a=(1..6).to_a; p a[6,2]; p a[8,2]'` → `[]` then `nil`.
2. Functional probe in `/tmp/rev-memb`, patches applied, clamp reverted:
   ```
   PROBE confirm page form_action=[…, "/groups/14/users?user_ids%5B%5D=15"]  back_url_field=[]
   PROBE fallback redirect -> "http://test.host/groups/14/edit?tab=users"
   ```
   (no referer → no back_url → the page is *lost*, back to page 1), versus, with
   a `back_url` as a real browser would send it:
   ```
   PROBE group remove redirect -> "http://test.host/groups/14/edit?tab=users&users_page=2"
   PROBE group page2 after delete: users=2 rows=0 nodata=true pagination_in_users_tab=0
   ```
   which is the group half of the finding, confirmed reachable.

**Suggested direction**

Either state the mechanism accurately for both tabs, or drop the mechanism
sentence and keep the reproduction — the reproduction is the persuasive part and
it is correct. If the accurate version is written, it is worth deciding whether
to mention that `group_users_query`'s `users_page` branch never fires in the
browser flow; my recommendation is not to, because it is a second, much smaller
point and it dilutes the note.

- **Resolution:** fixed 2026-09-06, both sentences.
  1. The note now says `ordered_ids[offset, per_page]` returns `[]` at an offset
     exactly equal to the member count and `nil` beyond it, and that the partial
     takes its `else` branch either way — so it describes its own example instead
     of contradicting it.
  2. The referer sentence is gone. The note now says what actually happens:
     removing a group user is a two-step confirmation, and the confirmation view
     emits a `back_url` hidden field taken from the referer of the confirmation
     request, which still carries `users_page`. The review's recommendation not to
     mention that `group_users_query`'s `users_page` branch never fires in the
     browser flow was followed — it is a second, smaller point and it would dilute
     the note.

---

### F05 — "leaving the tab recovers it" is not true, which understates the finding

- **Status:** resolved 2026-09-06
- **Severity:** minor
- **Confidence:** probable (read, not driven in a browser)
- **Category:** correctness
- **Where:** `docs/features/members-pagination/dossier.md` — "The finding"
- **Invariant touched:** none

**What is wrong**

The note says "Only editing the URL or leaving the tab recovers it." Switching
to another settings tab and back does not recover it. All settings tab partials
are rendered server-side into hidden `div`s and the tab links call
`showTab(name, url)`, which only hides and shows those divs and calls
`replaceInHistory(url)` — there is no request, so the members div keeps its
already-rendered empty content.

**Why a committer would push back**

He would not push back; he would test the sentence, find it wrong, and trust the
rest less. The correction makes the report stronger, not weaker: the user really
is stuck on that tab until the page is reloaded.

**How I verified it**

Read `app/views/common/_tabs.html.erb` (all `tab[:partial]` divs rendered,
`:onclick => "#{action}; return false;"`), `get_tab_action` in
`app/helpers/application_helper.rb:546-554` (`showTab('<name>', this.href)`),
and `showTab` in `app/assets/javascripts/application-legacy.js:405-414` (hide,
show, `replaceInHistory`, `return false`). Not driven in a browser, so the
severity is minor and the confidence is "probable" rather than "confirmed" — the
`replaceInHistory` call rewrites the address bar to the tab URL, which has no
`members_page`, so a manual reload does recover.

**Suggested direction**

Say what is true: nothing on the page recovers it; the user has to reload or
navigate away from the settings page. This is also the strongest single sentence
available for F01's reframing.

- **Resolution:** fixed 2026-09-06. "Only editing the URL or leaving the tab
  recovers it" is gone. The note now says that nothing on the page recovers it,
  because the settings tabs are rendered server-side into hidden divs and switched
  by `showTab()` in JavaScript, so clicking another tab and coming back does not
  re-render the members tab — the user has to reload. As the finding predicted,
  the correction makes the report stronger, and it is now the sentence the whole
  reframing of F01 rests on.

---

### F06 — The clamp corrects the paginator but not `params[:members_page]`, so the address bar and every row link keep the dead page

- **Status:** resolved 2026-09-06
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/helpers/members_helper.rb` and `app/helpers/groups_helper.rb`
  in `885f04097`; consumed by `app/views/projects/settings/_members.html.erb`
  and `app/views/groups/_users.html.erb`
- **Invariant touched:** none

**What is wrong**

The clamp is local to the paginator. The views go on reading the raw
`params[:members_page]` in eight places — the "New member" link, each row's Edit
and Remove links, and the two modal form actions — so after the clamp has
silently rendered page 3, those links all still say `members_page=4`, and the
address bar still says 4 as well. I saw this directly in the response body of the
clamped delete: every row carries `href="/memberships/NN/edit?members_page=3"`
while the paginator is showing page 2.

**Why a committer would push back**

It is a mild inconsistency rather than a fault: every subsequent request is
clamped again, so nothing breaks. The visible consequences are that the URL
disagrees with the page being displayed, and that a URL copied from the address
bar at that moment points at a page that does not exist and will quietly show a
different one. A reviewer may also prefer the controller to redirect to a valid
page instead of rendering a different one than was asked for, which would fix
both. That option is not among the three the dossier lists under *Alternatives
considered*.

**How I verified it**

The failure output of the mutation run (described under "What I checked and
found clean") prints the whole re-rendered tab: every row carries
`href="/memberships/NN/edit?members_page=3"` and the "New member" link carries
`?members_page=3`, while the pagination block below the table shows a different
page with `(1-25/50)`. The same holds for the unmutated clamp, which renders
page 2 while the links keep saying 3 — that half follows from the views, which
read `params[:members_page]` / `params[:users_page]` directly in every one of
those places and never see the paginator's effective page; I did not dump the
body of an unmutated clamped render.

**Suggested direction**

Either accept it and say so in the note in one clause ("the requested page
number is left in the links; every request is clamped again"), or have the view
use the paginator's effective page instead of the raw parameter. Naming the
"redirect to a valid page" option in *Alternatives considered* would also close
the obvious reviewer question.

- **Resolution:** fixed 2026-09-06, by stating it rather than by changing the
  clamp — the four-line change is what is being proposed to someone else's patch,
  and widening it would work against that (INV-1). The note's *Suggested fix* now
  carries a paragraph saying that the clamp is local to the paginator, so the row
  links and the address bar keep the page number that was asked for while a
  different page is rendered; that nothing breaks, because every request is
  clamped again; and that a URL copied at that moment points at a page that does
  not exist. The finding's second half is fixed as well: **redirect to a valid
  page from the controller** is now the fourth entry in *Alternatives considered*,
  with what it costs (an extra round trip, and touching the controllers instead of
  two helpers) and why the clamp is proposed anyway. The re-taken
  `members-page-clamped-after-delete.png` happens to show the whole mismatch in
  one image — address bar on `members_page=4`, paginator on page 3 of 3
  `(5-6/6)`, hovered row link on `/memberships/6?members_page=4` — and the dossier
  points at it.

---

### F07 — The RuboCop evidence is not reproducible: 4 offences on those files, not 0

- **Status:** resolved 2026-09-06
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `dossier.md` and `status.md` — "RuboCop op de 10 gewijzigde
  Ruby-bestanden: `0` (baseline op dezelfde 10 bestanden op r24882: `0`)"
- **Invariant touched:** INV-8 (evidence with numbers), G4

**What is wrong**

With the RuboCop available in this image, the same ten files report four
offences, both with the three commits applied and on pristine r24882:

```
== app/controllers/application_controller.rb ==
C:384:37 Rails/StrongParametersExpect: Use expect(:project_id) instead.
C:402:34 Rails/StrongParametersExpect: Use expect(:id) instead.
C:414:31 Rails/StrongParametersExpect: Use expect(:id) instead.
== app/controllers/groups_controller.rb ==
C:169:39 Rails/StrongParametersExpect: Use expect(:id) instead.
10 files inspected, 4 offenses detected
```

All four are on pre-existing lines; the patch adds none and removes none, so the
conclusion the dossier draws ("no new offences") is right. The absolute numbers
are not. The likely cause is the version: the Gemfile pins `rubocop ~> 1.88.0`
but that gem is not installed here, so `bundle exec rubocop` does not run and the
global 1.90.0 is what answers — and `Rails/StrongParametersExpect` is a newer
cop.

**Why a committer would push back**

He would not; this is internal evidence hygiene. But INV-8 is the invariant the
previous attempt broke, and "0, baseline 0" is a number the next session cannot
reproduce, which makes every other number in the dossier slightly less trusted.

**How I verified it**

```
/opt/rbenv/versions/3.3.6/bin/rubocop --force-exclusion --format simple <the 10 files>
```
run twice in `/tmp/rev-memb`: once with all three changes applied, once with
`git stash` back at pristine r24882. Identical output both times.

**Suggested direction**

Record the tool version alongside the count, and record the delta rather than an
absolute zero when the baseline is not zero: "4 offences before, 4 after, same
four lines, none on changed code, rubocop 1.90.0".

- **Resolution:** fixed 2026-09-06, and the finding's diagnosis was right — it was
  the RuboCop version. Re-measured with the version the `Gemfile` pins, **rubocop
  1.88.2** with rubocop-rails 2.34.3, in two detached worktrees, one at the r24882
  baseline `2563fa6a5` and one at the feature tip `885f04097`:
  `10 files inspected, no offenses detected` in both. So the dossier's `0` and
  baseline `0` were correct; what was missing was the tool version that makes them
  reproducible, and that is now recorded in both `dossier.md` and `status.md`.
  The four `Rails/StrongParametersExpect` offences the review saw come from the
  unpinned 1.90.0: the cop is `Enabled: pending` and Redmine sets
  `NewCops: enable`, so it does run under 1.88.2, but rubocop-rails 2.34.3 does not
  yet flag the plain `params[:id]` / `params[:project_id]` reads in
  `find_optional_project`, `find_model_object` and `find_group` that a later
  version does. All four are on pre-existing upstream lines, so the delta is `0`
  under either version. Both facts are now in the dossier, next to each other.

---

### F08 — The committer-identity count in `status.md` does not match the branch

- **Status:** resolved 2026-09-06
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/members-pagination/status.md` — "Elf van de veertien
  eigen commits hadden dit al"
- **Invariant touched:** INV-8

**What is wrong**

At review time `7.0-stable-GEOxyz` (through `885f04097`) carries fifteen own
commits, of which eight have `Claude` as committer — the three from this feature
plus five of the twelve that predate it. "Eleven of fourteen" matches neither
count, and it overstates how normal the situation already was.

**Why a committer would push back**

Internal only. It matters because the sentence is the justification for not
correcting the identity, and the justification leans on the number.

**How I verified it**

```
git log --format='%h %an|%cn %s' origin/7.0-stable..885f04097
git log --format='%cn'          origin/7.0-stable..885f04097 | sort | uniq -c
   8 Claude
   7 Jan Catrysse
```
Other sessions push to this branch in parallel, so the count can move; it was
8 of 15 when I looked.

**Suggested direction**

Recount, or state it without a number ("most of the own commits on this branch
already have it").

- **Resolution:** fixed 2026-09-06 by removing the number rather than correcting
  it, because it keeps moving — the review saw 8 of 15, and on 2026-09-06 the
  branch carried 33 own commits of which 16 have `Claude` as committer. Counting it
  per feature was the mistake. `status.md` now states the cause in one sentence,
  gives the 2026-09-06 measurement as a snapshot, and points at **K-13** in
  `docs/DECISIONS.md`, which is where the question now lives. See Q01.

---

### N01 — The clamp's comment and its arithmetic are duplicated verbatim in two helpers

- **Status:** resolved 2026-09-06
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** minimality
- **Where:** `app/helpers/members_helper.rb`, `app/helpers/groups_helper.rb` in
  `885f04097`
- **Invariant touched:** INV-3 (comments), INV-1 (minimality)

**What is wrong**

The same two-line comment and the same `[requested, (count + per_page - 1) /
per_page].min` expression appear in both helpers, differing only in the words
"member"/"user" and the parameter name. Four of the eight added application
lines are comment.

**Why a committer would push back**

He probably would not — the comment states a *why*, which INV-3 allows, and the
patch it sits on top of has comments of its own on every added method, so the
density matches its surroundings. Redmine core is otherwise near comment-free,
and a committer trimming a four-line fix would plausibly drop them. Extracting
the arithmetic into `Redmine::Pagination` would remove the duplication but is
the change the dossier has already settled on *not* making, so it is out of
bounds here.

**How I verified it**

Read `git show 885f04097`.

**Suggested direction**

Leave it, or keep one sentence instead of two. Not worth a round trip on its
own; mentioned so the fixing session can decide once.

- **Resolution:** decided 2026-09-06, and the decision is to leave it — which is
  the first of the two options the finding offers, taken deliberately so the next
  session does not weigh it again. Three reasons, in order of weight. The comment
  states a *why* and not a *what*, which is exactly what INV-3 allows and what
  Redmine's own measured density supports (29% of core methods carry a comment
  line). The duplication is two helpers of four lines each, and the only way to
  remove it is to extract the arithmetic into `Redmine::Pagination` — which is the
  change the dossier has already settled on *not* making, and which the note now
  names as an alternative belonging in its own issue. And the diff is a proposal
  on someone else's patch: trimming it further to save two comment lines costs a
  round trip and gains nothing a committer would ask for. Logged in
  `docs/features/members-pagination/decisions.md`.

---

### Q01 — The three commits GEOxyz will run carry `Committer: Claude <noreply@anthropic.com>`

- **Status:** raised to Jan as K-13, 2026-09-06
- **Severity:** question
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `351fe9e54`, `55ae9d1dd`, `885f04097` on `7.0-stable-GEOxyz`
- **Invariant touched:** INV-4

**What is wrong**

INV-4 forbids AI traces anywhere that reaches the repo, and Jan's K-01 (option
A, `docs/DECISIONS.md` line 25) says it in as many words: AI attribution belongs
in commits on `geoxyz/framework`, **never** in a commit on a `patch/<slug>`
branch or on `7.0-stable-GEOxyz`. The author of all three
commits is Jan, and the commit messages are clean — I grepped them for `claude`,
`anthropic`, `generated`, `co-authored` and model names and found nothing — but
the committer field of all three is `Claude <noreply@anthropic.com>`, and
`git log --format=%cn` shows it plainly.

**Why this is a question and not a finding**

The rule is not in doubt — K-01 settles it — so the open part is only *how*.
`status.md` discloses it, explains the cause (`tools/session-push.sh` replays
commits and a replay rewrites the committer), and states that correcting it
needs a force-push on a branch other sessions push to. That is a framework
trade-off between two rules, not a code decision, so it belongs to Jan. It does
not touch any patch: `git format-patch` carries the author, not the committer,
and no patch of ours is being submitted for this feature at all.

**How I verified it**

`git show --format='Author: %an <%ae>%nCommitter: %cn <%ce>' 351fe9e54 55ae9d1dd 885f04097`,
and a grep of all three commit messages for AI traces (clean).

**Suggested direction**

Jan's call: accept it as a permanent property of this branch and stop reporting
it per feature, or schedule one force-push at a moment when no session is
pushing. Either way it should be decided once in `docs/DECISIONS.md` rather than
re-disclosed in every status file.

- **Resolution:** raised to Jan on 2026-09-06 as **K-13** in `docs/DECISIONS.md`,
  which is what this question asked for — decided once, framework-wide, instead of
  re-disclosed in every status file. The block states the cause (a
  `tools/session-push.sh` replay rewrites the committer), the current measurement
  (16 of 33 own commits on `7.0-stable-GEOxyz`), and three options: accept it
  permanently; force-push once at a quiet moment; or fix the cause in
  `session-push.sh` so it stops growing while leaving history intact. The
  recommendation is the third, optionally followed by the second. It is explicitly
  not urgent, because `git format-patch` carries the **author** and not the
  committer, so no patch is affected. `status.md` no longer spells the issue out
  per feature — it points at K-13.

---

## What I checked and found clean

Listed so the fixing session does not redo it.

- **The reproduction, exactly as written.** Trunk r24882 + `0001` + `0002`, no
  clamp, a project generated with 7 members and `per_page_options = 2,25,50`,
  page 4 holding one member, removed through `MembersController#destroy` with
  `:members_page => 4` and `:xhr => true` exactly as the row's Remove link does:
  `remaining=6 nodata=true pagination=false rows=0`. With the clamp:
  `remaining=6 nodata=false pagination=true rows=2`. The dossier's three steps
  produce the dossier's screen.
- **Not the last page specifically — any requested page past the last.** Removing
  a row from page 2 of 4 leaves six members and renders two rows, no `nodata`,
  both with and without the clamp. Through the interface only the last page can
  be emptied by one removal, so "removing the last row of the last page" is a
  fair description of the reachable case; the underlying condition is
  `offset >= count`.
- **Both tabs are affected.** The group users tab reaches the same state through
  the confirmation form's `back_url` (`rows=0`, no pagination) and is fixed by
  the clamp (`rows=2`). The dossier says which; it says it correctly.
- **The three tests are red without the fix**, with the exact messages the
  dossier quotes: `Expected: 2, Actual: 9` twice, and `"nodata" found in …` for
  the controller test.
- **The three tests are not vacuous.** I mutated the members clamp to reset to
  page 1 instead of clamping to the last page — a fix that also removes the
  empty page — and both the helper test (`Expected: 2, Actual: 1`) and the
  controller test (`"members_page=1" not found`) fail. They pin the intended
  behaviour, not merely "not empty".
- **The fix does not disturb the in-range case.** Affected suites with all three
  changes: `183 runs, 855 assertions, 0 failures, 0 errors, 0 skips`, matching
  the dossier exactly. Takenori's eleven tests stay green unchanged.
- **Edge cases of the clamp.** No page parameter → `0` → the paginator's own
  lower clamp gives page 1. A project or group with no members → `(0 + n - 1)/n
  = 0` → page 1, empty list, correct. Negative or non-numeric → 1. No division
  by zero is possible: `Setting.per_page_options_array` selects `n > 0` and
  `per_page_option` falls back to 25.
- **INV-10.** All fifteen files touched by `351fe9e54` and `55ae9d1dd` are
  byte-identical (md5) to Takenori's two patch files applied to a clean r24882,
  and the same fifteen files are byte-identical between r24882 and the GEOxyz
  base commit. The only divergence from upstream is the clamp commit, which is
  what the dossier records.
- **The committed patch files are the real attachments.** 12858 and 7430 bytes,
  which are the 12.6 KB and 7.26 KB that redmine.org reports for
  `0001-members-pagination.patch` and `0002-groups-pagination.patch` on #43355.
  Both apply cleanly to r24882 (individually and in sequence) and, checked
  separately, to current trunk head `bee32a926` — so the note will not be posted
  against a stale base.
- **Issue state.** #43355 is Feature / New / category Groups, author Jan
  Catrysse, one note by Takenori TAKAKI, three attachments (Jan's original plus
  Takenori's two).
- **No link injection through the new pagination blocks.** Both views pass
  `request.query_parameters.merge(parameters)` as the trailing options hash of a
  named path helper, which is *not* core's idiom — every one of the ~15
  `request.query_parameters` call sites in trunk wraps it as
  `{:params => …}`. I tested whether the reserved `url_for` keys leak through:
  `?host=evil.example.com`, `?script_name=//evil.example.com`, `?anchor=x` and
  `?only_path=false&host=…&protocol=https` all come back as ordinary escaped
  query parameters on a relative path. No external or protocol-relative href is
  producible. Not a finding.
- **CSV export is unaffected**, as the dossier's objection table claims: a
  project with 30 members and `per_page_options = 25,50,100` exports 30 rows
  with `members_page=1` in the request.
- **Commit hygiene.** No trailing whitespace added, final newlines present, no
  AI traces in any of the three commit messages, and the commit subjects follow
  Redmine's convention with `(#43355)`.
- **Full suite, independently reproduced.**
  `tools/test-env.sh /tmp/rev-memb bundle exec ruby bin/rails test:all` on
  r24882 + both patches + the clamp gives
  `5934 runs, 31507 assertions, 27 failures, 2 errors, 92 skips`. The dossier
  claims `5934 runs, 31506 assertions, 27 failures, 2 errors, 92 skips` — runs,
  failures, errors and skips identical; the one-assertion difference is
  run-to-run variance, not a discrepancy worth a finding. The 29 red tests are
  14 `RepositoriesControllerTest`, 8 `Redmine::ApiTest::RepositoriesTest`, 5
  `SysControllerTest`, plus `Redmine::ApiTest::IssuesTest#test_GET_/issues/:id.xml_should_not_disclose_associated_changesets…`
  and `UserTest#test_destroy_should_nullify_changesets` — the last two are named
  as if unrelated but both build a `Repository::Subversion`, so the dossier's
  "all of them are Subversion repository tests" is accurate. `svn` is absent
  from this image. None touch members or groups.

## Verdict

The bug report is correct, reproducible and fairly stated as far as the observed
behaviour goes, and the suggested fix is right, complete for what it claims, and
properly tested. Nothing here is a blocker. What needs work before Jan posts is
the framing (F01), the two missing courtesy/confirmation sentences (F02) and the
attachment (F03) — all in the note, none in the code.
