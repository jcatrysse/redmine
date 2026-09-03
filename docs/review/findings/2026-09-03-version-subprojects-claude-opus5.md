# Review run — 2026-09-03 — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `patch/version-subprojects` at `f4dd91175` against `origin/master` `bee32a926`
- **Dossier read:** `docs/features/version-subprojects/dossier.md` — yes
- **Status read:** `docs/features/version-subprojects/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes — the touched suites in one process, plus a wider run, plus targeted
  experiments; counts under "Evidence I produced" below. I also downloaded the real
  `43534-v2.patch` from redmine.org and reproduced the regression against it rather than against the
  dossier's paraphrase.
- **Scope covered:** minimality; scope of the feature; conventions of the touched files; backward
  compatibility; authorization and information disclosure on the new endpoint behaviour; version
  sharing semantics across all five modes; whether the filter's value list matches the query's
  result set; query cost (SQL statements counted); the JavaScript half exercised in a real browser
  (Playwright against a live Redmine on the patched worktree); test quality and red-on-old-code;
  patch hygiene (applies to today's trunk, no AI traces, no trailing whitespace); RuboCop delta;
  and the accuracy of the claims the dossier tells Jan to put in the redmine.org note.
- **Scope NOT covered:**
  - **MySQL and SQLite.** Only PostgreSQL was exercised. I reasoned about portability from the
    generated SQL (below) but did not run the suite on another adapter.
  - **The full suite.** I did not reproduce the dossier's 5796-run figure. I ran the touched
    suites plus the suites most likely to be disturbed by a change to `Query#fixed_version_values`.
  - **The GEOxyz branch (G8).** I did not check out `7.0-stable-GEOxyz` or verify that its two
    commits carry the same diff.
  - **The screenshots.** I did not open the eight images in `shots/`; I re-derived the same
    behaviour in my own browser session instead.
  - **`ProjectQuery` / `UserQuery` / admin query pages** beyond the one `name`-parameter collision
    in F06.

## Summary

This is a good patch and a Redmine committer could take it close to as-is. Four production lines,
six tests, no new setting, route, migration or string; it applies cleanly to today's trunk
(`bee32a926`, a month newer than the r24882 it was built against); the touched suites are green;
and it adds no RuboCop offence. **The central claim of the submission — that Go MAEDA's
`43534-v2.patch` contains a regression — is true, and I verified it against the real attachment
downloaded from redmine.org, not against the dossier's description of it.** v2 replaces
`project.shared_versions` with `Version.visible.where(project_statement)`, and with Redmine's own
fixtures the guard test then fails with exactly the output the dossier quotes:
`"7" not found in ["3", "4", "2", "1"]`. Version 7 is `sharing: 'system'` in a project outside the
queried tree; it stops being filterable. I also confirmed that **none of Redmine's existing 348
tests in the two touched files catches that regression**, which is the strongest possible argument
for keeping the new guard test.

Two things about the *note* need fixing before Jan posts it, and they are the reason this review
has two `major`s. First, the headline number is wrong for the reader most likely to check it: the
filter for project 1 goes from six values to **four only for a user who cannot see the private
projects**; for an admin it goes from six to **five** (F01). Go MAEDA will very plausibly rerun it
as admin, get five, and stop trusting the rest of the note. Second, the dossier's "anticipated
objections" table answers "Does this leak version names from projects the user cannot see?" with
"No" — and that answer is wrong for the filter as a whole. `project.shared_versions` is not
permission-scoped, so on trunk *and with this patch* an anonymous visitor to public project 1 is
shown the version names of private projects 2 and 5. v2's replacement happens to remove that. So
v2 is not simply worse: it trades a sharing regression for a visibility improvement, and that is
exactly the rebuttal the note has to answer in advance (F02).

The remaining findings are small. The union still misses one narrow case of the very defect class
it fixes — a version shared `descendants` from a project sitting between the query's project and a
selected subproject (F03, reproduced). "One extra query" is really four (F04, measured). On
`queries/new` and `queries/edit` the new JavaScript puts the session's CSRF token into a GET query
string, where Redmine logs it unfiltered (F05, log line captured). And handing the whole `params`
hash to `build_from_params` makes the endpoint's own `name` argument double as a `ProjectQuery`
filter value (F06, reproduced).

What surprised me positively, beyond the union itself: the patch is a strictly better-engineered
version of v2 in three ways it does not brag about, and each is worth one sentence in the note.
`$('#filters-table').closest('form')` demonstrably works on `queries/new`, where v2's
`$('#query_form')` finds nothing (that page's form is `id="query-form"`, with a hyphen) — I
verified in a browser that the patched selector sends the form from that page. `build_from_params`
runs *after* `raise Unauthorized` rather than before. And `preload(:project)` is the right shape
where v2 uses `includes(:project).references(:project).distinct` — the `distinct` cannot be needed,
because `Version.visible` joins a `belongs_to`, so no row can be duplicated; v2 also shadows `data`
between its outer variable and its own callback parameter.

**Counts:** blocker 0 · major 2 · minor 5 · nit 3 · question 1

**Lines in the diff not strictly required by the feature:** 0 in the production code. All four
production lines are load-bearing, `preload(:project)` included (without it the `collect` that
follows does one `SELECT projects` per added version). Of the 74 test lines, ~12 belong to
`test_fixed_version_filter_should_include_versions_shared_from_outside_the_project_tree`, which is
green on trunk and exists only as a guard against v2 — defensible and, given the evidence in F01,
the most valuable test in the patch.

## Evidence I produced

Throwaway worktree at `origin/patch/version-subprojects`, own PostgreSQL database
(`redmine_rev_version_subprojects`), plus a live dev server on port 3111 driven by Playwright.

| What | Result |
|---|---|
| `test/unit/query_test.rb` + `test/functional/queries_controller_test.rb`, one process | **354 runs, 1164 assertions, 0 failures, 0 errors, 0 skips** |
| the same two files + `issues_controller_test.rb` + `timelog_controller_test.rb` + `version_test.rb` + `project_test.rb`, one process | **1092 runs, 5152 assertions, 0 failures, 0 errors, 1 skip** |
| the four behaviour tests against the unpatched `query.rb` + `queries_controller.rb` | **4 failures**, each naming the missing version id — matches the dossier |
| the two guard tests against the unpatched code | green, as the dossier says |
| the guard test against v2's replacement implementation | **fails: `"7" not found in ["3", "4", "2", "1"]`** — the exact output the dossier quotes |
| trunk's own 348 tests in the two touched files, run against v2's replacement implementation | **0 failures** — Redmine's existing suite does not catch the regression |
| RuboCop 1.90 on the four changed Ruby files, patch | 3 offences |
| RuboCop 1.90 on the same files, `origin/master` baseline | 2 offences (`Rails/StrongParametersExpect` ×2, pre-existing lines) |
| new offences attributable to the patch | **0** (see F10 for the third one) |
| `git apply --check` of `patches/version-subprojects/2026-09-03-r24882-feature.patch` on `origin/master` `bee32a926` | clean |
| the committed patch file vs the branch diff | identical content |
| `git diff --check` (whitespace) | clean |
| AI traces in the patch (`claude`, `co-authored`, model names, session links) | none |
| SQL statements to compute `fixed_version_values` with a project, patched | **6** |
| the same on trunk's code path | **2** |

The wider run is the six files most likely to be disturbed by a change to
`Query#fixed_version_values`, loaded together in one process to catch pollution: no failures, and
the single skip is an unrelated thumbnail test (`convert` is not installed in this image). I did
not reproduce the dossier's full-suite figures.

Sharing modes, checked one by one against the union (admin, fixtures + created records):

| Mode | Case | Offered when the query can return it? |
|---|---|---|
| `none` | version of a subproject in scope | yes — via `project_statement` |
| `none` | version of a sibling subproject *not* in scope | no (correct) |
| `system` | version of a project outside the tree | yes — via `shared_versions` (this is what v2 loses) |
| `tree` | version of another project in the same root tree | yes — via `shared_versions` |
| `hierarchy` | version of an ancestor of the query's project | yes — via `shared_versions` |
| `hierarchy` | version of a descendant of the query's project | yes — via `shared_versions` |
| `descendants` | version of an ancestor of the query's project | yes — via `shared_versions` |
| `descendants` | version of a project *between* the query's project and a selected subproject | **no — F03** |
| any | version in an archived subproject | no (correct: `Version.visible` excludes archived) |
| any | version in a subproject whose issues the user may not see | no (correct, and consistent with `Issue.visible`) |

Portability, read from the generated SQL rather than run on MySQL/SQLite: the added statement is
`SELECT versions.* FROM versions INNER JOIN projects ON projects.id = versions.project_id WHERE
(<allowed_to_condition>) AND (projects.lft >= 1 AND projects.rgt <= 10)`. No `DISTINCT`, no
`ORDER BY` on a joined column, no `GROUP BY`, no `LIMIT` in a subquery, and every literal that
comes from user input goes through `to_i` in `project_statement` (I probed
`v[subproject_id][]=3) OR (1=1` and got a correct, unmodified value list). I see no portability
risk in these four lines. This is one of the places where v2 is worse, not better: its
`.distinct` puts a `SELECT DISTINCT` over eager-loaded columns, which is the construct that does
behave differently between adapters.

---

### F01 — The "six to four" figure the note is built on is only true for a user who cannot see the private projects; an admin sees six to five

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/version-subprojects/status.md` ("Wat Jan nog moet doen"),
  `docs/features/version-subprojects/dossier.md` ("Het belangrijkste van deze sessie" and
  "Alternatives considered"), `docs/DECISIONS.md:76`
- **Invariant touched:** none

**What is wrong**

The note Jan is told to post says that under v2 "project 1 goes from six to four values" and names
both version 7 (`sharing: 'system'`, owner outside the tree) and version 6 (shared from private
subproject 5) as silently disappearing. Only version 7 disappears *because of the sharing
semantics*. Version 6 disappears because `Version.visible` filters on `:view_issues`, and it only
disappears for a user who cannot see project 5. Run the same comparison as an administrator and
the list goes from six to **five**: `["3","4","6","7","2","1"]` → `["3","4","6","2","1"]`.

**Why a committer would push back**

Go MAEDA will reproduce the number, and the fastest way to reproduce anything in Redmine's test
environment is as an admin or as the fixture user 2. He gets five, not four. Worse, the note tells
him version 6 vanishes "because it is shared from the private subproject", and he can see it does
not vanish for him at all — which reads as either sloppiness or as an argument built on a case the
author did not understand. The part of the claim that holds for every user, and the part the guard
test actually pins, is version 7 alone. Losing the committer's trust over an avoidable arithmetic
detail is expensive on an issue where he has already shown he wants the feature.

**How I verified it**

A probe test in the patched worktree printing all three lists for project 1:

```
UNION anon:           ["3", "4", "6", "7", "2", "1"]
shared_versions only: ["3", "4", "6", "7", "2", "1"]
replacement only:     ["3", "4", "2", "1"]

UNION admin:          ["3", "4", "6", "7", "2", "1"]
replacement admin:    ["3", "4", "6", "2", "1"]
```

The same for fixture user 7 (a non-member) gives the anonymous result. Fixtures: project 5 is
`is_public: false` and version 6 belongs to it; project 2 is `is_public: false` and version 7 is
`sharing: 'system'`.

**Suggested direction**

The union decision is settled and correct; only the wording of the evidence needs to change. Good
would be a claim that is true for every reader — one version, named, with its sharing mode and its
owning project's position relative to the tree, and the test that pins it — plus, if a count is
wanted, the count with the user stated ("as an administrator: six values become five"). The
second, visibility-driven disappearance is a different phenomenon and belongs in F02's discussion,
not in the regression count.

**Resolution:**

---

### F02 — The dossier answers "does this leak version names you cannot see?" with "No", and that is wrong for the filter as a whole — it is also v2's best counter-argument

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/version-subprojects/dossier.md`, "Anticipated objections" table, the
  row "Does this leak version names from projects the user cannot see?"
- **Invariant touched:** none

**What is wrong**

The answer given is: "No. The added scope is `Version.visible`, which is
`Project.allowed_to_condition(User.current, :view_issues)`. The pre-existing
`project.shared_versions` half is unchanged, including its own visibility behaviour." Each sentence
is true, but the answer to the question asked is "yes, and it already did". `Project#shared_versions`
has no permission scoping at all — it is a pure sharing query — so the target-version filter on a
public project has always disclosed the names of versions belonging to private projects, and this
patch keeps that. v2's replacement removes it, because `Version.visible` is the only scope left.
So the honest comparison is not "union good, replacement broken": it is "the replacement fixes a
pre-existing disclosure and breaks sharing; the union keeps both behaviours as they are today".

**Why a committer would push back**

Concretely: log out, open `/projects/ecookbook/issues`, add the Target version filter. Trunk, this
patch, and nothing else in between return
`["Private child of eCookbook - Private Version of public subproject","6","open"]` and
`["OnlineStore - Systemwide visible version","7","open"]`. Both projects are `is_public: false`.
A committer who is told "no leak" and finds two private project names in a JSON response from an
anonymous session concludes the objections table was written to reassure rather than to inform —
and he now has a reason to prefer his own patch that the note never addressed. This row is in the
dossier precisely to pre-empt an objection, so getting it wrong costs more than saying nothing.

**How I verified it**

Anonymous functional request on the **patched** code and on **`origin/master`**, byte-identical
responses:

```
MASTER anon /queries/filter?project_id=1&name=fixed_version_id: 200
[["eCookbook - 2.0","3","open"],["eCookbook Subproject 1 - 2.0","4","open"],
 ["Private child of eCookbook - Private Version of public subproject","6","open"],
 ["OnlineStore - Systemwide visible version","7","open"],
 ["eCookbook - 1.0","2","locked"],["eCookbook - 0.1","1","closed"]]
```

and `git show origin/master:app/models/project.rb` lines 535-565 — `shared_versions` filters on
`sharing` and `projects.status`, never on a permission.

**Suggested direction**

Good would be an objections row that states the current behaviour plainly (the filter has always
listed shared versions without a visibility check, because a shared version can legitimately be
assigned to an issue in your project), says that v2 changes that as a side effect, and takes a
position: either "preserving it is deliberate, because narrowing what is filterable is a separate
change that needs its own issue", or "if you want the visibility tightening, it should apply to
both halves and be argued on its own". Whichever Jan picks, the note should raise it before Go
MAEDA does. It is also the natural place to note that the union can only ever *add* values, which
is what makes it the safe half of the choice.

**Resolution:**

---

### F03 — A version shared `descendants` from a project between the query's project and a selected subproject is still not offered, so the "matches what the query returns" framing overclaims

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/models/query.rb:660-666`
- **Invariant touched:** none

**What is wrong**

The new half asks "which versions are *owned* by a project the query covers", and the old half asks
"which versions can *this one project* assign". Neither asks "which versions can any project the
query covers assign". The gap is a version owned by a project M where M lies strictly between the
query's project P and a subproject S, with `sharing: 'descendants'`, when an explicit subproject
filter puts S in scope but not M. Such a version is assignable to S's issues, S's issues are in the
query, but the version is in neither half of the union: `descendants` sharing only appears in
`P.shared_versions` when the owner is an *ancestor* of P, and M is not in `project_statement`.
(`hierarchy` sharing does not have the gap, because `shared_versions` matches descendants of P for
that mode.)

**Why a committer would push back**

Fixtures, as admin: project 1 → project 5 → project 6, and a version in project 5 with
`sharing: 'descendants'`. `Project.find(6).shared_versions` contains it, so an issue in project 6
can sit on it. Filter "Subproject is not <Private child of eCookbook>" — a natural thing to do,
and project 6 stays in scope: `project_statement` becomes `projects.id IN (1,6,3,4)` and the value
list is `["3","4","6","7","2","1"]`, without the version. Same with "Subproject is
<Child of private child>": `projects.id IN (1,6)`, version absent. That is the same defect the
patch exists to fix — an issue visible in the list whose target version the filter cannot select —
so a committer who finds it will ask why the patch stopped where it did, and the dossier's
sentence "the value list becomes the union of what the project can assign and what the query can
return" will look like it was not tested against the sharing matrix.

**How I verified it**

Probe test in the patched worktree:

```
sanity: Project.find(6).shared_versions includes v9  -> assert passed
stmt(sub=6):   projects.id IN (1,6)      values: ["3","4","6","7","2","1"]   missing v9? true
stmt(sub!=5):  projects.id IN (1,6,3,4)  offered? false
no subproject filter, display_subprojects_issues on:  offered? true
```

**Suggested direction**

Two honest options and the choice is cheap. Either close it — the "assignable" question for a set
of projects is one more SQL condition, since `Project#shared_versions` is already a single WHERE
clause parameterised by `lft`/`rgt` — or leave the code as it is and make the dossier and the
redmine.org note say what the value list actually is ("the versions the project can assign, plus
the visible versions belonging to the projects the query covers"), naming this residual case so a
reviewer finds it in the note rather than in the code. Do not leave the wider claim standing with
the narrower implementation.

**Resolution:**

---

### F04 — "The union costs one extra query" is four; measured six SQL statements against trunk's two

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** performance
- **Where:** `docs/features/version-subprojects/dossier.md`, "Anticipated objections" row
  "An extra query per call to `fixed_version_values`"; `docs/DECISIONS.md:76`
- **Invariant touched:** none

**What is wrong**

Computing `fixed_version_values` for a query with a project runs 6 SQL statements on the patch and
2 on trunk. The four added are: the `projects.id` lookup for `project.descendants` inside
`project_statement`, the `settings` row for `display_subprojects_issues`, the new `versions`
SELECT, and the `preload(:project)` for the versions it returned. The dossier and the decisions log
both say "one".

**Why a committer would push back**

Not because four queries matter — they do not, and the endpoint is one AJAX call. Because
`fixed_version_values` also runs on every issue-list, gantt, calendar and spent-time page render
where the target-version filter is active (`available_filters_as_json` inlines the values for
filters already in the query), and because a reviewer who counts and gets four when the note says
one stops taking the other numbers at face value — the same failure mode as F01. Redmine's recent
trunk history has several commits purely about reducing SQL per request (`#44374`, `#44382`), so
the person reading this note counts.

**How I verified it**

`ActiveSupport::Notifications.subscribe('sql.active_record')` around
`query.available_filters['fixed_version_id'][:values]` in the patched worktree: 6 statements,
printed individually. The same instrumentation around trunk's expression
(`Version.sort_by_status(project.shared_versions.to_a).collect{...}`): 2.

**Suggested direction**

State the measured number, and say which of the four are amortised in a real installation
(`Setting` is served from the in-process cache after the first read). One line, and it turns a
number a reviewer can disprove into a number that shows the work was done.

**Resolution:**

---

### F05 — On `queries/new` and `queries/edit` the new JavaScript sends the session's CSRF token in a GET query string, where Redmine logs it unfiltered

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** security
- **Where:** `app/assets/javascripts/application-legacy.js:178-181`
- **Invariant touched:** none

**What is wrong**

`$('#filters-table').closest('form').serializeArray()` serialises *everything* in the form. On the
issue list, the gantt and the other list pages the form is `method="get"` and Rails emits no token,
so the request is clean. On `queries/new` (POST) and `queries/edit` (PUT) the same partial renders
inside a non-GET form, so `authenticity_token` — plus `query[name]`, `query[description]`,
`query[visibility]`, `query[role_ids][]`, `query[sort_criteria][...]`, `default_columns` and a
second copy of `type` — is appended to the URL of a `GET /queries/filter`.

**Why a committer would push back**

Redmine's `config.filter_parameters` is `[:password, :salt, :twofa_totp_key, /\Akey\z/]`;
`authenticity_token` is not in it. So the token lands verbatim in `production.log`, and — the part
that is new — in the query string of a GET, which every reverse proxy in front of Redmine records
in its access log while it never records a POST body. Anyone with read access to those logs can
forge state-changing requests for that session. The value is also useless to the endpoint: it
reads `params[:project_id]`, `params[:name]`, `params[:type]` and the filter params, nothing else.
Independently, the same over-serialisation is what makes the URL 550+ characters on `queries/new`,
which is the "the GET request gets long" objection the dossier anticipates — with a concrete
instance the note does not mention.

**How I verified it**

Playwright against the patched worktree on a live server: opened
`/projects/geoxyz-verify/queries/new?type=IssueQuery` as admin and added the Target version
filter. The request:

```
/queries/filter?project_id=1&type=IssueQuery&authenticity_token=SkRkCCMmeVdYrk_rIEwu4qbMZ7Rid...
  &type=IssueQuery&query[name]=&query[description]=&query[visibility]=0&query[role_ids][]=
  &query[display_type]=list&default_columns=1&query[group_by]=&t[]=&f[]=status_id&op[status_id]=o
  &f[]=&query[sort_criteria][0][]=id&...&name=fixed_version_id
```

and the same string, token included, at line 975 of `/tmp/redmine-dev-3111.log`
(`Started GET "/queries/filter?...authenticity_token=SkRkCC..."`). For contrast, the login POST in
the same log shows `"password"=>"[FILTERED]"` next to an unfiltered `"authenticity_token"=>"..."`,
which is how I know the filter list does not cover it. I also checked that `_method=put` from the
edit form is harmless: `curl` of `GET /queries/filter?...&_method=put` against the live server
returns 200 JSON and no `Started PUT` line, because `Rack::MethodOverride` only acts on POST.

**Suggested direction**

The `closest('form')` selector is settled and demonstrably better than v2's `#query_form` — this
finding is about *what* gets serialised, not which form is found. Good would be sending only the
fields the endpoint reads, and doing it without hard-coding which filter influences which value
list — the filter rows live inside `#filters-table`, which is the element the code already has a
handle on, and `set_filter`/`sort`/`group_by` are the only things outside it that
`build_from_params` consumes. Whatever the shape, `authenticity_token` should not be in a GET URL,
and the note should be able to say the request carries filter parameters and nothing else.

**Resolution:**

---

### F06 — Handing the whole `params` hash to `build_from_params` makes the endpoint's own `name` argument double as a `ProjectQuery` filter value

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/controllers/queries_controller.rb:103`
- **Invariant touched:** none

**What is wrong**

`build_from_params` has two branches. With `params[:f]` present it reads the filter arrays. With no
`f` it falls back to short filters: `available_filters.each_key {|field| add_short_filter(field,
params[field]) if params[field]}`. `ProjectQuery` has a filter called `name` — and `name` is this
endpoint's own parameter, carrying the field whose values are being requested. So
`GET /queries/filter?type=ProjectQuery&name=status` now builds a query filtered by *project name
equals "status"* before looking up the `status` filter's values.

**Why a committer would push back**

Nothing user-visible breaks today, because none of `ProjectQuery`'s value lambdas consults
`filters` — I checked all nine. But this patch is precisely the change that makes one value lambda
depend on `filters` (`fixed_version_values` → `project_statement` → `has_filter?("subproject_id")`),
so the pattern it establishes is "the values of filter X may depend on the filters in the request",
and the request's own control parameter is silently one of those filters. The next filter whose
values depend on the query inherits a bug nobody will look for. A reviewer reading
`q.build_from_params(params)` two lines above `params[:name]` will spot the collision on sight; it
is the kind of detail that gets a patch bounced with a one-line comment.

**How I verified it**

Probe test in the patched worktree:

```
ProjectQuery filters available: ["status","id","name","description","parent_id","is_public",
                                 "created_on","updated_on","cf_3"]
after build_from_params(name=status):
  filters={"status"=>{:operator=>"=", :values=>["1"]}, "name"=>{:operator=>"=", :values=>["status"]}}
```

The `f[]` branch is what the UI actually takes (`_filters.html.erb` always renders
`hidden_field_tag 'f[]', ''`), so the collision needs a caller that omits `f` — which any external
consumer of this public endpoint does. `IssueQuery` has no `name` filter, so the feature itself is
unaffected.

**Suggested direction**

Good would be for the endpoint to keep its own parameter out of what it feeds the query builder —
pass the filter parameters rather than the whole request, or take the field name from somewhere
that cannot collide with a filter field. Either way, a functional test asserting that
`?type=ProjectQuery&name=<field>` returns that field's values with no filter applied would pin it.

**Resolution:**

---

### F07 — Three of the six new tests are Go MAEDA's, near-verbatim, and neither the dossier nor the note says so

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `test/unit/query_test.rb:172-217`, `test/functional/queries_controller_test.rb:826-845`
- **Invariant touched:** none

**What is wrong**

`test_fixed_version_filter_should_include_subproject_versions_when_displaying_subproject_issues`,
`test_fixed_version_filter_should_respect_selected_subprojects` and
`test_fixed_version_filter_should_include_all_subproject_versions_when_filtering_any_subproject`
exist in `43534-v2.patch` under exactly those names, with the same bodies modulo inlined local
variables. The functional test is v2's `test_filter_should_build_query_from_params` renamed, with
the expected label written out as a literal instead of interpolated. The dossier presents all six
as "five tests on the value list" and "one test on the endpoint" of this patch, and lists them in a
table headed "Tests" with no attribution.

**Why a committer would push back**

Go MAEDA will read the patch. He wrote three of those tests five months ago and will recognise
them immediately. Silence reads badly in a note whose main point is that his patch has a
regression; a single sentence saying which tests were kept turns that into a courtesy. It also
makes the actual delta easy for him to see, which is the note's whole job: `+ union`,
`+ two guard tests`, `+ tightened one of your tests to run with the setting off`,
`+ selector that also matches #query-form`, `+ permission check first`.

**How I verified it**

Downloaded the real attachment,
`https://www.redmine.org/attachments/download/35977/43534-v2.patch` (5.23 KB, Go MAEDA,
2026-04-01), and compared it line by line with the branch diff. Note the difference the decisions
log already records: v2's `..._should_respect_selected_subprojects` runs on the default setting,
where the subproject is in scope anyway; this patch runs it with `display_subprojects_issues => '0'`,
which is what makes it prove widening rather than narrowing.

**Suggested direction**

One sentence in the note naming the three tests that came from v2, and a line in the dossier's test
table marking them. Nothing about the code needs to change.

**Resolution:**

---

### F08 — Every new test asserts membership in the value list; none asserts the newly offered value actually returns the issue, and `TimeEntryQuery` is claimed but untested

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/unit/query_test.rb:164-217`
- **Invariant touched:** none

**What is wrong**

All six tests end in `assert_include <id>, filter[:values].map(&:second)` or its negation. The
defect being fixed is a mismatch between two sets — the values the filter offers and the values the
list can return — and only one of those sets is asserted. Separately, the dossier states that
"`TimeEntryQuery`'s `issue.fixed_version_id` filter picks up the same improvement because it calls
the same method", which is a behavioural claim in the submission with no test behind it.

**Why a committer would push back**

A patch that lengthens a dropdown is worth much less than a patch that makes a dropdown entry
work, and the tests as written would pass against an implementation that offers versions the query
can never return — which is the failure mode of the *opposite* mistake to v2's. `test/unit/query_test.rb`
already has `assert_query_result` and `find_issues_with_query` helpers a few lines above the new
tests, so the missing assertion is one line: put an issue in the subproject on the subproject's
version, add the `fixed_version_id` filter for that version, and assert the issue comes back. That
also closes F03 by construction if anyone ever tries the wider predicate. The
`TimeEntryQuery` claim is a two-line test in the same style.

**How I verified it**

Read all six tests. Confirmed by hand that the `TimeEntryQuery` claim is true — a probe on
`TimeEntryQuery.new(:project => Project.find(1))` returns
`["3","4","6","9","7","2","1"]` including a newly created unshared version 9 in project 3 for the
`issue.fixed_version_id` filter — so the claim is correct, merely unpinned.

**Suggested direction**

One test that closes the loop from filter value to query result, and one that names
`issue.fixed_version_id` on a `TimeEntryQuery` so the dossier's sentence is backed. Both belong in
the files already touched, so the patch does not grow a new file.

**Resolution:**

---

### F09 — `GET /queries/filter?c=foo` now raises `NoMethodError` on an endpoint anonymous users can reach

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** backward-compat
- **Where:** `app/controllers/queries_controller.rb:103`
- **Invariant touched:** none

**What is wrong**

`build_from_params` does `self.column_names = params[:c]` and `self.totalable_names = params[:t]`,
and both setters call `names.select`, which is a private method on `String`. Passing `c` or `t` as a
scalar instead of an array therefore raises and the endpoint returns 500 HTML where it used to
return JSON. Before the patch this action ignored `c` and `t` entirely.

**Why a committer would push back**

Probably not at all, and that is why this is a nit: `/issues?c=foo` already raises the identical
`NoMethodError: private method 'select' called for an instance of String` on pristine trunk, so the
patch reaches a weakness that Redmine already carries on every list controller rather than
introducing one. There is no amplification and nothing is disclosed. It is worth one line in the
dossier only so that nobody discovers it later and mistakes it for a regression.

**How I verified it**

Functional probes on the patched code: `c` as a string → raised; `t` as a string → raised;
`v` as a string, missing `op`, `f` as a string, garbage `sort`, unknown `display_type`, unknown
filter name, `query[...]` hash, `_method=put`, `authenticity_token` → all 200. The same probe on
`origin/master` via `IssuesController#index` with `c=foo` → raised identically.

**Suggested direction**

Nothing, unless the fixing session is already touching the action for F06 — in which case keeping
the endpoint's JSON contract on malformed input is a one-line rescue. Name it in the dossier
either way.

**Resolution:**

---

### F10 — The branch is a month behind trunk, so the dossier's "RuboCop 0, baseline 0" no longer reproduces

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/version-subprojects/dossier.md`, evidence block; `status.md`, "Bewijs"
- **Invariant touched:** none

**What is wrong**

With RuboCop 1.90 against `origin/master` `bee32a926`, the four changed Ruby files carry 2 offences
before the patch and 3 after. Neither is caused by the patch: the two are
`Rails/StrongParametersExpect` on pre-existing `params[:project_id]` / `params[:id]` lines in
`queries_controller.rb`, and the third is `Style/DirectiveScope` on `app/models/query.rb:1519`,
which exists only because the branch still has `# rubocop:disable Lint/IneffectiveAccessModifier`
where today's trunk has `# rubocop:disable-next ...`. So the number of offences attributable to the
patch is 0, which is the claim that matters — but the figures written down do not reproduce.

**Why a committer would push back**

He would not; nothing here reaches the patch. It matters because INV-8 is about numbers that can
be re-measured, and these cannot be, which makes it harder to tell a stale figure from a real
regression next time. The patch file itself still applies cleanly to `bee32a926`, which I checked.

**How I verified it**

`rubocop --force-exclusion --format simple` on the four files at `f4dd91175` and at
`origin/master`; `git show origin/master:app/models/query.rb | sed -n '1510,1526p'` versus the same
region on the branch; `git apply --check` of the committed patch file against a pristine
`origin/master` worktree — clean.

**Suggested direction**

Record the trunk revision and RuboCop version next to the counts, or re-measure against current
trunk before Jan posts. Rebasing the branch is not needed — the patch applies.

**Resolution:**

---

### F11 — The commit message carries a three-paragraph body; trunk commits are single-line

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** commit `f4dd91175`, and therefore
  `patches/version-subprojects/2026-09-03-r24882-feature.patch`
- **Invariant touched:** none

**What is wrong**

The commit message is a subject plus three explanatory paragraphs. The last twelve commits on
`origin/master` are all a single line ending in `(#NNNNN).`, with no body at all — Redmine's
committers put the explanation in the issue and keep the commit to one sentence. Since
`git format-patch` carries the message into the attached file, the body is what a committer reads
first, and he will rewrite the whole message anyway when he commits.

**Why a committer would push back**

He would not reject a patch over this. It is worth a line because the body duplicates, less well,
the text the note itself will carry, and because the subject reads awkwardly in Redmine's own
register — "Target version filter offers the versions of the subprojects in the query" is a
description of a mechanism rather than of a change.

**How I verified it**

`git log -1 --format=%B origin/patch/version-subprojects` against
`git log --format="%s" origin/master -12`.

**Suggested direction**

One imperative line naming the change and the issue, in the register of the twelve trunk subjects
above; the reasoning belongs in the note, where Jan already has it in better English.

**Resolution:**

---

### F12 — Question for Jan: should the note lead with the regression, or with the credit?

- **Status:** open
- **Severity:** question
- **Confidence:** n/a
- **Category:** dossier
- **Where:** `docs/features/version-subprojects/status.md`, "Wat Jan nog moet doen"
- **Invariant touched:** none

**What is wrong**

The instruction as written is: attach the patch and "write that `43534-v2.patch` by **Go MAEDA**
contains a regression". That is factually right — I verified it against the real attachment — and
the settled decision to submit a union rather than a replacement is not in question here. But this
patch is, in substance, v2 plus one line, plus three of v2's own tests, and the person being told
his patch is broken is the committer who would have to accept the replacement. That is a
presentation choice with a real effect on whether the feature lands, and it is Jan's to make, not
mine.

**Why this needs Jan and not code**

Nothing in the code changes either way. Only Jan can weigh how he wants to talk to a core
committer on his own issue.

**How I verified it**

Read `status.md` and `docs/DECISIONS.md:76-82`; downloaded and diffed `43534-v2.patch`.

**Suggested direction**

If it were mine to write, the note would open by keeping v2 as the baseline ("your v2 is what I
built on; I kept your three tests"), state the single line that changes and the one version that
disappears without it, name the guard test, and then note the two smaller improvements (the
`#query-form` page, and the permission check before the query build) — with the visibility question
from F02 raised explicitly rather than left for him to find. Framed that way the note is a
follow-up to his work rather than a correction of it, and the diff a committer has to reason about
is one line.

**Resolution:**
