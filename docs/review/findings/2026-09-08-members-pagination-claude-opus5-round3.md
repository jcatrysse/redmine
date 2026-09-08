# Review run — 2026-09-08 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** the `members-pagination` change on `7.0-stable-GEOxyz`, commits
  `148faafb6`, `02ca8b044` and `22a4244c0` — all three on the branch. There is
  no `patch/members-pagination` branch and there will be no submission of our
  own: the upstream work is **Takenori TAKAKI's**, on Jan's own issue
  [#43355](https://www.redmine.org/issues/43355).
- **Dossier read:** none exists — the upstream side is not ours
- **Status read:** `docs/features/members-pagination/status.md` — yes, including
  the part that says the first two commits are Takenori's two patches applied
  one-to-one and only the third (the clamp) is GEOxyz's own
- **Round-1 findings read:** **no, deliberately.**
  `docs/review/findings/2026-09-03-members-pagination-claude-opus5.md` was not
  opened. `status.md` names its F01 and Jan's g15 in passing, so I knew a
  finding about the last-page edge case existed and became the third commit.
- **Ran the test suite:** **no.** `7.0-stable-GEOxyz` was not among the four
  worktrees I built this session. What I did instead: read the three diffs
  against `origin/7.0-stable`, read the tests, and check the two Redmine
  internals the design leans on (`Redmine::Pagination::Paginator` and
  `Redmine::Pagination#pagination_links_full`) against the actual source.
- **Scope covered:** the ordering and whether it still matches `Member.sorted`,
  the page clamp at both ends, the parameter naming and its collision with the
  add-member modal, whether the CSV export was caught by the pagination, the
  redirect helpers that preserve the page, query counts and N+1, the tests as
  code, and where the code lives.
- **Scope NOT covered:**
  - **No execution.** No test run, no page loaded, no query counted. Every
    statement below is from reading, and the two "clean" rows that would most
    benefit from a run are marked.
  - **A large project.** The performance claim in F01 is arithmetic about the
    query shape, not a measurement against thousands of members.
  - **MySQL and SQLite.** The `ORDER BY roles.position` here is core's own
    expression, unchanged, so I did not chase the NULL-ordering difference.

## Summary

Clean, and the interesting part is how little of it is ours. Two of the three
commits are Takenori TAKAKI's upstream patches applied unchanged, which is the
right call — writing a competing patch on Jan's own issue would only lower the
odds of either landing. The GEOxyz delta is the four-line clamp, and it is
correct at both ends: the upper bound is the `.min` against the last page, and
the lower bound is `Paginator#initialize`, which already turns any page below 1
into 1. So `members_page=-5`, `members_page=abc` and `members_page=9999` all
land on a real page.

Two things I went looking for and did not find, both worth stating because they
are what pagination usually breaks. The CSV export is untouched:
`MembersController#index`'s `format.csv` builds its own `@members` from the full
scope and the patch does not go near it, so the export is still every member and
not the visible page. And the two page parameters do not collide: the list uses
`members_page` / `users_page` while the add-member modal keeps `page`, which is
deliberate and commented in both views.

The design also turns out to follow core more closely than it first appears.
`request.query_parameters.merge(parameters)` in the two views is not an
invention — it is character for character what `Redmine::Pagination#pagination_links_full`
does itself when no block is given (`lib/redmine/pagination.rb:148`). And
because `Paginator#page_param` here is the **string** `'members_page'`, the
merge is string-key onto string-key, so the double-key hazard I went looking for
is not there.

**Counts:** blocker 0 · major 0 · minor 0 · nit 2 · question 0

**Lines in the diff not strictly required by the feature:** 0.

## What came back clean

| Hypothesis | Outcome |
|---|---|
| the page order no longer matches `Member.sorted`, so paginating reshuffles the list | clean — `Member.sorted` is `reorder("roles.position").order(Principal.fields_for_order_statement)` and `paginate_members` uses the identical two clauses; only the join is spelled out (`left_joins(:member_roles => :role).joins(:principal)`) instead of relying on `includes` |
| the join against roles paginates join rows, so a member with two roles is counted twice and pages come out short | clean, and this is the thing the design is built around — the ids are plucked, `uniq`'d (keeping the first occurrence, which is the lowest role position because of the `reorder`), and only then sliced. See F01 for what it costs |
| a page beyond the last one shows "No data to display" with no way back | clean, and this is exactly the GEOxyz commit — `[params['members_page'].to_i, (count + per_page - 1) / per_page].min`, with a test on each helper and a controller test that deletes the last member of the last page |
| a negative or non-numeric page slips past the clamp | clean at the other end — `.to_i` makes `abc` into 0 and `-5` stays negative, and `Paginator#initialize` does `page = (page \|\| 1).to_i; page = 1 if page < 1` |
| the CSV export now exports only the visible page | clean — `MembersController#index` `format.csv` sends `members_to_csv(@members)` where `@members = scope.includes(:principal, :roles).order(:id)`, and the patch's only change to that controller is the redirect helper |
| the list's page parameter collides with the add-member modal's `page` | clean and deliberate — `members_page` / `users_page` for the lists, `page` left to `render_principals_for_new_members`; both views carry a comment saying so |
| the page is lost on add, edit or remove | clean — `members_settings_query` and `group_users_query` carry `members_page`/`users_page` and `per_page` into the redirect, and the row links carry them too |
| `request.query_parameters.merge(parameters)` mixes a symbol key into a string-keyed hash and emits the parameter twice | clean — `page_param` is the string `'members_page'`, so both sides are strings; and the pattern is core's own default branch in `pagination_links_full` |
| paginating a page is an N+1 over principals and roles | clean — one `pluck`, then one `where(:id => page_ids).preload(:project, :principal, :roles)`, then `filter_map` to restore the plucked order. Not measured, but there is no per-row query in the code |
| the helpers do controller work | clean by this file's own precedent — `MembersHelper#render_principals_for_new_members` is upstream core in the same file and does `scope.count`, `Paginator.new(…, params['page'])`, `offset`/`limit`. A helper is also the only place that serves both `ProjectsController#settings` and the JS re-render without duplicating it |
| the commit shas in the register are stale, as they are for ten other features | clean here — all three are on the branch, and `status.md` explains that they changed with the K-13 rewrite |

---

### F01 — every page view reads the id of every member in the project

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed (by reading; not measured)
- **Category:** performance
- **Where:** `app/helpers/members_helper.rb` — `paginate_members`, the `pluck("#{Member.table_name}.id").uniq`
- **Invariant touched:** none

**What is wrong**

Nothing, for the sizes involved, and the change is a large net improvement — but
it is worth being precise about what it does and does not do. The pagination is
applied in Ruby, not in SQL:

```ruby
ordered_ids = project.memberships.
  left_joins(:member_roles => :role).joins(:principal).
  reorder("roles.position").order(Principal.fields_for_order_statement).
  pluck("members.id").uniq
```

For a project with *N* members holding *R* roles each, that query returns
*N × R* rows and materialises *N × R* integers in Ruby before `uniq` reduces
them to *N*. Only then is one page's worth sliced out. So the cost of rendering
page 1 of a 5 000-member project is the same as the cost of rendering page 200:
it is O(all members) either way, on every request.

**Why a committer would push back**

They would not reject it over this, and the honest comparison is what makes that
clear: the line it replaces was `@project.memberships.preload(:project).sorted.to_a`,
which loaded *N* full `Member` objects with their principals and roles. Trading
*N* objects for *N × R* integers is a big win, and it is why the feature's claim
("a project with thousands of members opens in a fraction of the time") is true.

It is a nit and marked as one because of where the code is going, not where it
is. Jan is writing a note to #43355 anyway, and "this paginates the display but
still scans the whole membership list per request" is the first thing a Redmine
committer looking at scaling will notice. Better to name it in the note than to
have it raised there.

**How I verified it**

Read the method and the `Member.sorted` scope it replaces. Counted the query
shape rather than running it: one `pluck` with a `LEFT JOIN member_roles JOIN
roles JOIN principals`, no `LIMIT`. I did not measure it against a large
project, and the finding claims no timing.

**Suggested direction**

Nothing in the code, unless upstream asks. If it comes up on #43355, the honest
answer is the trade-off: doing the `LIMIT`/`OFFSET` in SQL needs the duplicate
role rows collapsed there too, and the portable way to do that —
`GROUP BY members.id` with `MIN(roles.position)` — drags every column of
`Principal.fields_for_order_statement` into the `GROUP BY` on PostgreSQL, which
is strict about it. `DISTINCT ON` would be cleaner and is PostgreSQL-only.
Plucking the ids is the portable middle, and saying so pre-empts the question.

**Resolution:**

---

### F02 — the last-page test generates about 45 users to prove a four-line clamp

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/functional/members_controller_test.rb` — `test_destroy_a_member_that_removes_the_last_page_should_render_the_new_last_page`, the line `(51 - project.memberships.count).times {member = User.add_to_project(User.generate!, project)}`
- **Invariant touched:** none

**What is wrong**

Project 1 has **3** memberships in the fixtures, so that line runs
`User.generate!` and `User.add_to_project` **48** times, to get past two pages of
25. The assertion it supports is that after deleting the last member of page 3
the response comes back on page 1 rather than empty.

The two helper tests added in the very same commit show the cheaper way:

```ruby
stubs(:per_page_option).returns(2)
project = Project.generate!
3.times {User.add_to_project(User.generate!, project)}
```

Three records instead of forty-eight, for the same property.

**Why a committer would push back**

Redmine's own guidance is to lean on the fixtures rather than generate rows, and
48 `User.generate!` calls is the kind of thing that shows up as a slow test long
after everyone has forgotten why the number is 51. There is no correctness
problem — the test passes, it asserts literal values (`assert_equal 25,
response.body.scan(/member-\d+-roles/).size` and `assert_include
'members_page=1'`), and it would be red without the clamp.

The reason it is worth one line rather than nothing: this is a **controller**
test, so it cannot stub `per_page_option` the way the helper tests do — but it
already uses `with_settings :per_page_options => '25,50,100'`, and setting that
to `'2,5'` would let three generated members do the same job.

**How I verified it**

Counted the fixture rows: `members.yml` has 10 memberships, of which 3 are on
project 1, so `51 - 3 = 48` generations. Read the two helper tests in the same
commit for the contrast. Not run.

**Suggested direction**

Lower `per_page_options` in the `with_settings` block and generate the handful
of members that then span three pages. The assertions can stay as they are, with
25 becoming whatever the new page size is.

**Resolution:**
