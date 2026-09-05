# Review run — 2026-09-03 — assignee-nobody — claude-opus5

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `patch/assignee-nobody` at `d6f6a7325` against `origin/master` `bee32a926`
  (the branch's merge base is `2563fa6a5` = r24882, so trunk has moved 40-odd
  commits since the patch was cut)
- **Dossier read:** `docs/features/assignee-nobody/dossier.md` — yes
- **Status read:** `docs/features/assignee-nobody/status.md` (the "already settled" section) — yes
- **DECISIONS read:** yes (K-05 = option A, assignee list only; not re-litigated here)
- **Ran the test suite:** yes, partially.
  - `test/unit/query_test.rb` + `test/functional/queries_controller_test.rb` together
    in one process, at the branch tip (merge base): **356 runs, 1166 assertions,
    0 failures, 0 errors, 0 skips**
  - the same two files with the patch `git apply`'d onto **today's** trunk
    (`bee32a926`): **356 runs, 1166 assertions, 0 failures, 0 errors, 0 skips**
  - `git apply --check` of `patches/assignee-nobody/2026-09-02-r24882-feature.patch`
    against today's trunk: **clean, all three files**
  - RuboCop (1.90, `--cache false`) on `app/models/query.rb`,
    `test/unit/query_test.rb`, `test/functional/queries_controller_test.rb` at
    today's trunk: **3 files, 0 offences** baseline and **3 files, 0 offences**
    patched
  - four probes and three mutations of my own, to confirm F01/F02/F03/F04
  - PostgreSQL 16 only. I did **not** run the full suite; the dossier's
    5798/5790 figures are taken on trust.
- **Scope covered:** minimality; scope of the feature; database portability
  (PostgreSQL — SQL generated and executed for all seven operators, with
  `['none']`, `['none','2']` and `['2']`); blast radius of the generic placement
  (every one of the 31 call sites of `sql_for_field` in trunk enumerated and
  classified); backward compatibility; conventions of the touched file; i18n;
  authorization (n/a — no new entry point); tests-as-code and test pollution;
  the two previously-red tests; the dossier and the G9 screenshots; equality of
  the trunk patch and the `7.0-stable-GEOxyz` commit.
- **Scope NOT covered:** the full test suite (see above); **MySQL and SQLite**
  — only PostgreSQL is available in this container, and portability is this
  patch's whole selling point, so the MySQL/SQLite halves of the claim remain
  unverified by me (the dossier scopes its 500-claim to PostgreSQL, which is
  correct as far as it goes); re-running `verify/assignee-nobody.mjs` in a
  browser (I read the fourteen screenshots, I did not regenerate them); the
  suites on `7.0-stable-GEOxyz`; SCM symmetry and escaping, both genuinely n/a
  (no repository code, no view changes).

## Summary

This is a good patch and a much better answer to #5535 than the ones already on
the issue. The design decision the dossier is proudest of is the right one: the
pseudo-value is resolved where the operator's SQL is built, so all seven
operators of `list_optional_with_history` are covered instead of just `=`. I
checked that claim rather than believing it — I generated and executed the SQL
for every operator with `['none']`, `['none','2']` and `['2']`, and none of them
puts the string `'none'` anywhere near an integer column any more. The patch is
genuinely minimal (18 lines of production code, no reformatting, no tidying of
neighbours, no new setting, gem, migration, route, permission or translation
key — `label_nobody` really does already exist, in all 50 of trunk's locale
files), it still applies cleanly to today's trunk a month past the revision it
was cut against, RuboCop is clean on both sides, the two tests the framework's
history remembers as red are green and were **strengthened** rather than
weakened, and the `7.0-stable-GEOxyz` commit is byte-identical to the trunk
patch.

**The one reason a committer would send it back is F01, and it is the flip side
of the very generality the dossier sells.** `Query#sql_for_field` has an
unwritten contract: whatever it returns gets spliced into a bigger expression by
callers, so every branch returns either a single clause or a fully parenthesised
one. The new `=` and `!` lines break that contract — they return a top-level
`OR`/`AND` with no wrapping parentheses. On the main path in `Query#statement`
that is harmless, because that caller adds its own parentheses. But
`UserQuery#sql_for_is_member_of_group_field` splices the return value in after
an `AND` inside an `EXISTS` subquery, and its filter is `:list_optional`, so the
gate is open. `/users?...&v[is_member_of_group][]=none&v[is_member_of_group][]=10`
returns **all nine fixture users** instead of the one member of group 10, and
with the `!` operator it returns **none** instead of eight. On trunk today that
same URL raises a PostgreSQL 500. So in one place the patch converts a loud
error into a silently wrong answer — which is exactly the failure mode the
dossier (rightly) criticises the older patches for. It is reachable only by a
hand-built URL, not from any dropdown, and the same code is live on
`7.0-stable-GEOxyz`.

The other confirmed findings are all about evidence rather than shipped
behaviour, and three of them came from mutations. Two guards and one whole half
of the `ev`/`!ev` semantics can be deleted without a single test going red
(F02, F03): the `is_custom_filter` guard is the patch's own stated safety
argument, and I built a list custom field with `none` as a real possible value
to show what breaks when it goes — the filter flips from "the 1 issue whose
value is none" to "the 12 issues with no value at all" — with the suite still
green. F04 is a factual error in a sentence that is on its way onto
redmine.org: the adapted `assigned_to_values[1..]` test never had a `<< me >>`
entry to skip (`User.current` is anonymous there), so the explanation given for
the offset change is wrong even though the new offset happens to be right.

**Counts:** blocker 0 · major 1 · minor 4 · nit 2 · question 1

**Lines in the diff not strictly required by the feature:** 0 — I looked for
reformatting, renaming, tidied neighbours and stray comments and found none.
The one comment added is a `# Returns ...` doc comment on a new private
method, which is what its neighbours in `query.rb` already have.

---

### F01 — the NULL folding returns an unparenthesised `OR`, and one core filter splices it into an `AND`, giving wrong rows

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/models/query.rb:1290` (the `=` branch) and `app/models/query.rb:1302`
  (the `!` branch); the victim is `app/models/user_query.rb:160`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the folded clause is returned parenthesised, so the fragment is self-contained for all 31 callers; two `UserQueryTest` tests and a before/after screenshot pair pin it (Jan g06)

**What is wrong**

The two new lines are

```ruby
sql = "#{db_table}.#{db_field} IS NULL OR (#{sql})" if match_null      # "="
sql = "#{db_table}.#{db_field} IS NOT NULL AND (#{sql})" if match_null # "!"
```

Both return an expression whose **top-level** operator is `OR` (resp. `AND`)
with nothing wrapping it. Every other branch of `sql_for_field` returns either
a single clause (`col IN (...)`, `col IS NULL`) or an already-parenthesised one
(`"(col IS NULL OR col NOT IN (?))"`). That is not a coincidence: `sql_for_field`
is a fragment builder, and its 31 callers in trunk splice the fragment into
larger expressions. `Query#statement`'s generic path (`query.rb:1042`) wraps the
fragment in `'(' … ')'` and is therefore safe. The `sql_for_<field>_field`
dispatch at `query.rb:1039` does **not** wrap, and neither does
`UserQuery#sql_for_is_member_of_group_field`, which builds

```ruby
"(#{e} (SELECT 1 FROM groups_users WHERE #{User.table_name}.id = groups_users.user_id AND #{sql_for_field(field, '=', value, 'groups_users', 'group_id')}))"
```

`is_member_of_group` is declared `:list_optional` (`user_query.rb:57`) and
`is_custom_filter` is left at its default `false`, so `match_null` is true as
soon as the value list contains `none`. The `OR` then escapes the `AND` that
correlates the subquery to the outer row.

**Why a committer would push back**

Concretely, on the admin user list:

`/users?set_filter=1&f[]=is_member_of_group&op[is_member_of_group]==&v[is_member_of_group][]=none&v[is_member_of_group][]=10`

generates

```sql
(EXISTS (SELECT 1 FROM groups_users
         WHERE users.id = groups_users.user_id
           AND groups_users.group_id IS NULL OR (groups_users.group_id IN ('10'))))
```

which SQL parses as `(users.id = gu.user_id AND gu.group_id IS NULL) OR (gu.group_id IN ('10'))`.
The second disjunct is no longer correlated to the outer row, so the `EXISTS`
is true for **every** user as soon as group 10 has any member at all. Measured
on the standard fixtures: **9 users returned instead of 1**. With the `!`
operator the `NOT EXISTS` inverts it and **0 users are returned instead of 8**.
On pristine trunk the same URL raises
`PG::InvalidTextRepresentation: invalid input syntax for type integer: "none"`,
i.e. a visible 500. The patch replaces that with a silently wrong result set,
which is the specific defect the dossier's own "Anticipated objections" table
holds against the existing patches on #5535 (`cf` giving "a silently empty
result … which is worse than the 500"). A committer who reviews a change to
`sql_for_field` — the single most central method in the query engine — will
check the other callers, find this, and ask for the fragment to be
self-contained. The same code path is present on `7.0-stable-GEOxyz` (commit
`9d28be94d`; `user_query.rb:153-161` there is identical), so it is live in
GEOxyz production, not only in the proposed patch.

Not reachable from the UI: the `is_member_of_group` value list contains only
real group ids, so a user has to hand-build the URL (or save a query built from
one). That is why this is `major` and not `blocker`.

**How I verified it**

Throwaway worktree on today's trunk with the patch applied, own PostgreSQL
database, a probe under `test/probe/` driving `UserQuery` directly and printing
both the SQL and the resulting user ids:

```
group 10 members: [8]        users in no group: [1,2,3,4,5,6,7,9]
is_member_of_group =  ["10"]        -> 1 users [8]
is_member_of_group =  ["none"]      -> 0 users []
is_member_of_group =  ["none","10"] -> 9 users [1,2,3,4,5,6,7,8,9]      <-- wrong
   SQL: (EXISTS (SELECT 1 FROM groups_users WHERE users.id = groups_users.user_id
                 AND groups_users.group_id IS NULL OR (groups_users.group_id IN ('10'))))
is_member_of_group !  ["none","10"] -> 0 users []                        <-- wrong
```

and the same probe against the unpatched file in the same worktree:

```
BASE is_member_of_group = ["none"] -> RAISED ActiveRecord::StatementInvalid:
     PG::InvalidTextRepresentation: ERROR: invalid input syntax for type integer: "none"
```

I also enumerated every `sql_for_field(` call site in trunk
(`git grep -n "sql_for_field(" origin/master`, 31 hits) and classified each by
`is_custom_filter`, by the `type_for(field)` it passes, and by whether the
caller parenthesises. Only `is_member_of_group` combines an open gate,
user-supplied values and an unparenthesised splice. The other open-gate callers
are safe for a reason, not by luck: `sql_for_member_of_group_field`
(`issue_query.rb:598`) and `sql_for_user_group_field` (`time_entry_query.rb:306`)
spoof `field` to `assigned_to_id`/`user_id` — so the gate *is* open — but the
values they pass come from `group_and_member_ids`, which can only produce id
strings, and they add their own `'(' … ')'`. `sql_for_fixed_version_status_field`
and `sql_for_fixed_version_due_date_field` likewise spoof `fixed_version_id`
with ids from a query. `sql_for_custom_field_attribute` (`query.rb:1242`) leaves
`is_custom_filter` at `false` and does **not** parenthesise, but the only
`cf_<id>.<attribute>` filters core registers are `:date` and `:list`
(`query.rb:1614`, `query.rb:1621`), so the gate is closed there — the dossier's
claim about that is accurate.

**Suggested direction**

Make the fragment self-contained, so the fix holds for every current caller and
for plugin filters using the same seam, and does not depend on remembering
which callers wrap. State the contract wherever it is now implicit. Worth a
regression test that goes through a `sql_for_<field>_field` caller rather than
only through `Query#statement`, since that is the whole class of caller the
current tests never touch.

**Resolution:** fixed, 2026-09-05, per Jan's g06. Both folded clauses are now
returned parenthesised — `"(#{db_table}.#{db_field} IS NULL OR (#{sql}))"` and
the `IS NOT NULL AND` counterpart — so the fragment is self-contained for every
one of the 31 callers instead of only for the ones that happen to wrap. The
alternative, wrapping inside `UserQuery#sql_for_is_member_of_group_field`, was
rejected: it repairs one caller and leaves the seam open for the next one and
for plugin filters. A line above `sql_for_field` now states the contract that
was implicit.

Pinned by two new tests in `test/unit/user_query_test.rb`, which go through a
`sql_for_<field>_field` caller rather than through `Query#statement` — the whole
class of caller the existing tests never touched:

```
test_group_filter_with_a_nobody_value_should_stay_correlated      = ['none','10'] -> [8]
test_group_filter_not_with_a_nobody_value_should_stay_correlated  ! ['none','10'] -> not 8, and not empty
```

Both were run against the unfixed code by putting the two unparenthesised lines
back: `2 runs, 2 assertions, 2 failures`, with `Expected: [8] Actual: [1, 2, 3,
4, 7, 8, 9]` — the nine-instead-of-one this finding measured, reproduced by the
test itself. Also verified in a browser (G9): on the seeded instance the same
URL lists all three users before the fix
(`shots/regression-group-filter-nobody.png`) and exactly the one member of
`verify-group` after it (`shots/group-filter-nobody.png`).

---

### F02 — the "currently has no assignee" half of `ev`/`!ev` is untested: deleting it keeps the suite green

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/unit/query_test.rb` — `test_operator_has_been_nobody`,
  `test_operator_has_never_been_nobody`; the code is
  `app/models/query.rb:1493` (`sql_ev`)
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the three history tests now assert a complete id list on the fixtures, with one issue matching through each half of the disjunction; the mutation that used to stay green now fails two tests

**What is wrong**

`ev` ("has been") is a disjunction: the value appears in
`journal_details.old_value`, **or** it is the column's current value. Both
halves matter for `none` — an issue that has simply never been assigned "has
been nobody" without any journal at all. The two new tests each generate exactly
two issues, one with a journal recording nil → 2 and one always assigned, and
assert only `assert_include` / `assert_not_include` on those two. Both issues
are decided by the journal half alone, so the current-value half is never
exercised. This is a step down from the neighbouring trunk tests
(`test_operator_has_been`, `test_operator_changed_from`, `query_test.rb:844-908`),
which assert the complete expected id list.

**Why a committer would push back**

I removed the current-value half for the `none` case — one line, `sql_ev`
becomes `value.any? ? … : ''` — and the whole of `query_test.rb` stayed green
(**292 runs, 859 assertions, 0 failures, 0 errors**). The behaviour that
mutation destroys is not marginal: on the standard fixtures `ev none` goes from
`[1,5,6,7,9,10,13,14]` to `[]`, and `!ev none` goes from `[2,3,4]` to
`[1,2,3,4,5,6,7,9,10,13,14]`. In other words the headline case of this
feature — "issues that are, or have been, unassigned" — can be reduced to
returning nothing at all without a single test noticing. Since this patch's
argument for existing is precisely that the older ones handled some operators
and silently mishandled others, a test that cannot tell the difference is the
wrong test to ship with it.

**How I verified it**

Mutation in the review worktree, then the file run whole:

```
sql_ev = if %w[ev !ev].include?(operator)
           value.any? ? (" OR " + sql_for_in_or_null("...", value, false)) : ''
```

`bundle exec ruby bin/rails test test/unit/query_test.rb` →
`292 runs, 859 assertions, 0 failures, 0 errors, 0 skips`. A probe printing the
result ids before and after the mutation gave the two id lists quoted above,
and confirmed that unmutated `ev none` is exactly equal to the `!*` operator's
result on these fixtures.

**Suggested direction**

Assert the full result set for the history operators, the way the neighbouring
trunk tests do, so both halves of the disjunction are pinned — in particular an
issue that is currently unassigned and has no journal at all must be in `ev`
and out of `!ev`.

**Resolution:** fixed, 2026-09-05. The three history tests no longer generate
their own issues and assert membership; they journal two of Redmine's own
fixture issues and assert the complete id list, the way `test_operator_has_been`
and `test_operator_changed_from` next to them do. Issue 1 (unassigned, then
assigned to 2) matches only through `journal_details.old_value`; issue 4
(assigned to 2, then unassigned) matches only through the column's current
value. So each half of the disjunction carries an id of its own:

```
ev  none -> [1, 4, 5, 6, 7, 9, 10, 13, 14]
!ev none -> [2, 3]
cf  none -> [1]
```

The exact mutation this finding used — `value.any? ? (" OR " + …) : ''`, which
left the suite green — now gives `2 runs, 2 assertions, 2 failures`, with
`!ev none` coming back as `[2, 3, 4, 5, 6, 7, 9, 10, 13, 14]`. Removing the
journal half instead raises in three of the tests.

---

### F03 — neither of the two gates is pinned by a test, including the `is_custom_filter` guard the patch's safety argument rests on

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `app/models/query.rb:1248-1251`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — one test per gate (a list custom field with `none` as a real value, and a plain `:list` filter asserting no `IS NULL`), plus a test on a second gated filter

**What is wrong**

`match_null` is gated on two conditions — `!is_custom_filter`, and
`type_for(field)` being one of the two optional list types. The dossier presents
the first as the reason the change is safe ("a list custom field may
legitimately have `none` among its possible values") and the second as the
reason it is narrow. Neither has a test. There is also no test for any
`list_optional` filter other than `assigned_to_id`, although the patch changes
the SQL of six more of them.

**Why a committer would push back**

I replaced both gates with a bare `value.include?('none')` and ran the two
touched files together: **356 runs, 1166 assertions, 0 failures, 0 errors, 0
skips**. So nothing in Redmine's own tests distinguishes the shipped code from a
version with no guards at all. What the guard actually prevents, measured: with
a list custom field whose possible values are `['none', 'yes']`, one issue set
to `none`, one set to `yes`, one with no value —

```
patch as submitted : cf_12 = ['none'] -> matches the "none" issue only, total = 1   (correct)
gates removed      : cf_12 = ['none'] -> matches the empty-valued issues, total = 12 (wrong)
```

That is a customer-visible wrong answer on an ordinary list custom field, one
refactor away, with no test standing in the road. For a change to
`Query#sql_for_field` a committer will want that pinned; it is also the cheapest
possible answer to the reviewer question "are you sure this does not touch
custom fields?".

**How I verified it**

Two mutations in the throwaway worktree (both gates removed; suites green as
quoted), plus a probe under `test/probe/` that creates the list custom field
with `none` among its possible values, assigns the three issues, and prints
which of them the filter matches — run once against the mutated file and once
against the patch as submitted, giving the two lines quoted above.

**Suggested direction**

One test per gate. For `is_custom_filter`, a list custom field with `none` as a
real possible value, asserting that `= ['none']` returns the issue holding the
literal value and not the empty ones — that test is red the moment the guard
goes. For the type gate, one assertion that a plain `:list` filter is unaffected.
And at least one test for a second `list_optional` filter (target version or
category) so the shared code path is not proven by a single field.

**Resolution:** fixed, 2026-09-05. One test per gate, plus one on a second
gated filter:

- `test_filter_nobody_should_not_apply_to_list_custom_fields` builds exactly the
  list custom field this finding describes (`possible_values` `['none','yes']`),
  gives one issue the literal value `none`, one `yes` and one nothing, and
  asserts the filter returns only the first. With both gates replaced by a bare
  `value.include?('none')` it returns `[1, 3, 5, 7, 8, 11, 12, 13, 17, 2]`
  instead of `[15]`.
- `test_filter_nobody_should_not_apply_to_list_filters` asserts that a plain
  `:list` filter (`priority_id`) compiles no `IS NULL`. Under the same mutation
  the statement becomes
  `((issues.priority_id IS NULL OR (issues.priority_id IN ('5'))))` and the test
  fails. The type gate has no visible behaviour to assert on — without it a
  `:list` filter over an integer column raises — so this is asserted on the
  generated SQL, which is how trunk's own `test_operator_none` next to it works.
- `test_filter_fixed_version_nobody_or_version` covers a second
  `list_optional_with_history` filter end to end.

Measured with the gates removed: `11 runs, 17 assertions, 2 failures`, where the
same run was `0 failures` before the mutation.

---

### F04 — the dossier explains the adapted `assigned_to_values[1..]` test wrongly, and that sentence is going onto redmine.org

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/assignee-nobody/dossier.md`, "One existing test
  adapted"; the test is `test/unit/query_test.rb:3554`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the dossier now says what index 0 really was, and the test stops counting positions: it rejects the pseudo-values instead

**What is wrong**

The dossier says: *"`test_assigned_to_values_should_be_sorted_by_status_and_name`
asserts on `assigned_to_values[1..]` — it skips the one pseudo-value that used
to precede the real users."* That is not what index 0 was. That test calls
`User.delete_all` and never sets `User.current`, so `User.current` resolves to
`User.anonymous` — which is **not** `logged?`, so `<< me >>` is never added to
the list at all. Element 0 on trunk was the `AnonymousUser` **principal**, which
`User.anonymous` re-creates lazily during the call, after `expected_names` has
already been computed without it. So `[1..]` was skipping a real user record,
not a pseudo-value, and the reason it worked is that `AnonymousUser` sorts first
by `status`.

**Why a committer would push back**

The new `[2..]` is correct — element 0 is now `<< nobody >>` and element 1 is
still `AnonymousUser` — so nothing is broken. But the justification is wrong,
and it is one of the few paragraphs of this dossier that is destined verbatim
for the issue note. A committer who opens that test to check the claim will find
no `<< me >>` in it and will discount the rest of the note. It also means the
patch is relying on an offset whose behaviour the author has mis-modelled: the
count of leading entries to skip is `1 + (User.current.logged? ? 1 : 0)`, and
the two pseudo-values are added under different conditions (`<< me >>`
conditionally, `<< nobody >>` unconditionally), so a positional slice will keep
being wrong for a reason nobody expects.

**How I verified it**

A probe that replays the test's exact setup and prints the intermediate state:

```
expected count: 20
User.current.logged? = false (AnonymousUser)
values count: 22
first 4: [["<< nobody >>", "none"], ["Anonymous", "34", "Translation missing: en.status_anon"],
          ["000 000", "14", "active"], ["002 002", "16", "active"]]
```

No `<< me >>` entry; `Anonymous` at index 1.

**Suggested direction**

Correct the sentence, and consider whether the assertion should stop counting
positions at all — selecting the real principals by rejecting the pseudo-values
(`'me'`, `'none'`) says what the test means and survives the next entry
somebody adds. (The `Translation missing: en.status_anon` in that output is a
pre-existing trunk quirk, not this patch's business — reported, not to be fixed
here, per INV-1.)

**Resolution:** fixed, 2026-09-05, and the correction is in both directions.
The dossier paragraph now says what index 0 actually was — the `AnonymousUser`
principal, re-created lazily by `User.current` during the call, with `<< me >>`
never added because `User.anonymous` is not `logged?` — instead of the wrong
"the one pseudo-value that used to precede the real users".

The test stopped counting positions altogether, which is the second half of the
suggestion. It now rejects the entries whose value is `'me'` or `'none'` and
compares the remainder with the users in the database, so it survives the next
fixed entry somebody adds and no longer depends on an offset the author
mis-modelled. Green on the patch; the `Translation missing: en.status_anon`
quirk was left alone as a pre-existing trunk matter (INV-1).

---

### F05 — six other core filters silently gain `none` semantics, with no test and no way to reach them from the UI

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** backward-compat
- **Where:** `app/models/query.rb:1248-1251`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — `test_filter_fixed_version_nobody_or_version` proves the shared path on a second field, and the dossier names all seven gated filters and says only the assignee list is wired into the UI; K-05 stands

**What is wrong**

K-05 settled that only the assignee list gets `<< nobody >>`, and I am not
re-opening that. But the *mechanism* is not scoped to the assignee filter: seven
core filters pass the gate, and six of them get no test and no UI entry. Beyond
`assigned_to_id`, those are `fixed_version_id` and `category_id` (IssueQuery),
`user_id` and `author_id` (TimeEntryQuery), and `status`, `auth_source_id` and
`twofa_scheme` (UserQuery). Two of the gated columns — `users.status` and
`time_entries.user_id` — are `NOT NULL`, so the dossier's rationale ("the two
types whose very name says the column may have no value") does not hold for
them; `none` there is simply a condition that can never be true.

**Why a committer would push back**

Not a wrong answer today — I executed all of them and every one produces valid,
executable SQL, and where the column is `NOT NULL` the result is an empty set
rather than an error, which is an improvement on the 500 they gave before. The
objection is the one the dossier itself anticipates and then leaves open: a
change to a shared code path arrives with coverage for exactly one of the seven
fields that traverse it. It also creates an asymmetry a committer will notice —
`?v[fixed_version_id][]=none` works but the target-version dropdown does not
offer it, so the feature exists and is undiscoverable. That is Jan's K-05 call
and the dossier states it explicitly, which is the right way to handle it; the
missing part is one test proving the other fields are not harmed.

**How I verified it**

Probe printing generated SQL and executing it for `fixed_version_id` and
`category_id` (operators `=`, `!`, `ev`, `!ev`, `cf`), for UserQuery `status`,
`auth_source_id`, `twofa_scheme` and for TimeEntryQuery `user_id`, `author_id`
(`=`, `!`), all with `['none']`. Every one returned `OK (<n>)`; no statement
raised. Example: `UserQuery auth_source_id = ['none']` →
`(users.status IN (1)) AND (users.auth_source_id IS NULL OR (1=0))` → 7 users,
i.e. "internally authenticated users", a new and undocumented capability.

For completeness on the "no more 500s" framing: a `:list` filter over an
integer column is untouched and still raises. `?v[status_id][]=none` on the
issue list gives `(issues.status_id IN ('none'))` →
`PG::InvalidTextRepresentation`, both before and after the patch. That is a
pre-existing trunk behaviour for any non-numeric value and out of scope here,
but the note should not leave a reader thinking `none` is now safe everywhere.

**Suggested direction**

One test on a second gated filter is enough to make the shared path honest. If
the note keeps the "generic solution" argument (and it should — it is the answer
to Barth's 2010 objection), say plainly which fields it reaches and that only
the assignee list is wired into the UI, so a committer is not surprised by it.

**Resolution:** fixed as far as this patch's scope allows, 2026-09-05, per Jan's
g18 and without re-opening K-05. Two changes, neither of them to the mechanism:

- `test_filter_fixed_version_nobody_or_version` proves the shared path on a
  second gated filter, so it is no longer demonstrated by a single field.
- the dossier's objections table now names all seven gated filters
  (`assigned_to_id`, `fixed_version_id`, `category_id`, TimeEntryQuery's
  `user_id` and `author_id`, UserQuery's `status`, `auth_source_id` and
  `twofa_scheme`), says they produce valid SQL and an empty set where the column
  is `NOT NULL`, and says plainly that only the assignee value list is wired
  into the UI. A committer reading the note is told, rather than surprised.

K-05 stands: no `<< nobody >>` entry is added to the target-version or category
value lists.

---

### F06 — the two equivalence tests would pass on two empty sets

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/unit/query_test.rb` —
  `test_filter_assigned_to_nobody_alone_should_match_the_none_operator`,
  `test_filter_assigned_to_not_nobody_alone_should_match_the_any_operator`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — both equivalence tests assert the shared result is non-empty before asserting equality

**What is wrong**

Both tests assert that two result sets are equal without asserting that either
is non-empty. `[] == []` satisfies them.

**Why a committer would push back**

Barely — this is a nit, and the tests are not vacuous today: I measured the two
sides at 8 and 3 issues respectively on the standard fixtures, and if
`match_null` failed to fire the `'none'` string would reach an integer column
and the test would error rather than pass. But the equivalence idea is the good
part of these two tests (it ties the new value to the operator that already
means the same thing, permanently), and one extra assertion makes it immune to a
future fixture change.

**How I verified it**

Probe output on the review database: `= ['none']` and `!*` both give
`[1,5,6,7,9,10,13,14]`; `! ['none']` and `*` both give 3 issues.

**Suggested direction**

Assert the shared result is not empty as well as equal.

**Resolution:** fixed, 2026-09-05. Both equivalence tests now assert the shared
result is non-empty before asserting the two sides are equal, so `[] == []` no
longer satisfies them. On the standard fixtures the two sides are 8 and 3 issues
respectively, unchanged.

---

### F07 — five of the seven "before" screenshots are the same file, and the dossier describes them as showing something they cannot show

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/assignee-nobody/shots/`, and the "Failure paths
  verified" table in the dossier
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the text was corrected, not the images: the five identical shots are named as Redmine's generic 500 page, and the widget claim is limited to the two shots that render one

**What is wrong**

`before-has-been-nobody.png`, `before-has-never-been-nobody.png`,
`before-is-nobody-alone.png`, `before-is-nobody-or-dev.png` and
`before-is-not-nobody-or-dev.png` are byte-identical (md5
`8aa74bada02929798c5525edd610a547`). They are a genuine Redmine 500 page — I
opened one, it is the real error page in the real project chrome, so the
before/after pairs are honest evidence that the page used to break. But the
dossier's failure-path table says the before shots show *"the select … falls
back to `<< me >>` … exactly that, in all seven before shots"*. A 500 page
renders no filter form at all, so that can only be true of
`before-changed-from-nobody.png` and `before-filter-dropdown.png`, the two that
are distinct.

**Why a committer would push back**

He would not — these files are not going on the issue. It matters for the
framework's own honesty about G9: five identical images prove "this URL 500s"
once, not five times, and the dossier's "every one of the fourteen images was
opened and looked at" reads oddly next to a claim that only two of them can
support.

**How I verified it**

`md5sum *.png` in the shots directory (five identical hashes), and I opened
`before-is-nobody-or-dev.png` and `is-nobody-or-dev.png`. The after shot is
solid: `<< nobody >>` sits between `<< me >>` and the `active` optgroup, both
`<< nobody >>` and `Dev Verify0` are highlighted as selected, and the list shows
8 of 9 issues — so it really is the union and not one filter silently dropped.

**Suggested direction**

Either say in the table that the five identical shots are the same generic 500
page, or drop the sentence about the widget falling back to `<< me >>` to the
two shots where a widget is visible.

**Resolution:** fixed, 2026-09-05, by correcting the text rather than the
images — the five identical shots are honest evidence of a 500, they were just
described as showing a filter widget they cannot show. The failure-path table
now names only `before-changed-from-nobody.png` and `before-filter-dropdown.png`
for the "falls back to `<< me >>`" claim, and says of the other five that they
are Redmine's generic 500 page, byte-identical to each other, and prove that
those URLs raise and nothing more. The "screenshots read" paragraph says the
same and drops the "fourteen images" count.

All shots were retaken on 2026-09-05 against trunk r25037, and two were added
for F01 (`regression-group-filter-nobody.png`, `group-filter-nobody.png`).

---

### F08 — "all 63 locale files" — trunk has 50

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/assignee-nobody/dossier.md`, "Proposed change" and
  "New setting / migration / gem / route / permission"
- **Invariant touched:** INV-5 (satisfied — no new key, no invented translation)
- **Resolution:** fixed 2026-09-05 — 50, with the counting command in the dossier; the substantive claim (every locale file has `label_nobody`) re-counted and unchanged

**What is wrong**

The dossier states `label_nobody` "exists in all 63 locale files Redmine
ships". `config/locales/` on trunk contains 50 `.yml` files.

**Why a committer would push back**

The substantive claim is correct and is the reason this patch needs no
translation work at all: all **50** locale files define `label_nobody`
(`nl: niemand`, `fr: personne`, `de: Niemand`, `es: nadie`). Only the number is
wrong, and it appears in the text that becomes the issue note.

**How I verified it**

```
locale files: 50, with label_nobody: 50
```

(loop over `git ls-tree --name-only origin/master config/locales/` grepping
`^  label_nobody:` in each).

**Resolution:** fixed, 2026-09-05. The dossier says **50**, with the command
that counts it, in the one place the number appears. The substantive claim —
`label_nobody` exists in every locale file, so the patch needs no translation
work — is unchanged and was re-counted: 50 files, 50 hits.

---

### F09 — question for Jan: is turning a 500 into a wrong answer on a neighbouring filter acceptable, or does F01 have to be fixed before the note goes up?

- **Status:** resolved
- **Severity:** question
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** see F01
- **Invariant touched:** INV-10 (GEOxyz and upstream do behave identically — both
- **Resolution:** answered 2026-09-05 — Jan decided it with g06: fix first, submit after. Done on both branches, so nothing is left open here
  carry F01)

**What is wrong**

Nothing extra; this is the decision F01 implies rather than a second defect.
F01 is not reachable from any dropdown — a user has to type
`v[is_member_of_group][]=none` into the address bar of the admin user list — and
the current behaviour there is a 500, so nobody has a working query that this
breaks. It is also live on `7.0-stable-GEOxyz` today.

**Why a committer would push back**

The reason to treat it as blocking anyway is presentational as much as
technical: the whole case for replacing the patches on #5535 is "the old ones
mishandled operators they did not think about, and one of them failed silently".
Posting a patch that does a smaller version of the same thing, on a filter in a
different query class, hands a reviewer the counter-argument. It is cheap to
fix, and the fix (a self-contained fragment) is strictly better engineering than
the current form.

**Suggested direction**

My recommendation: fix it before the note goes up, and add the regression test
F01 asks for. It is a small change with no design choice in it, and it removes
the only finding in this review that changes what the shipped code does.
Alternative, if Jan wants the note posted now: post it, and open the fix as a
follow-up on the GEOxyz side — but then the fix must land on
`7.0-stable-GEOxyz` too, since the bug is in production there.

**Resolution:** answered by Jan on 2026-09-04 (g06) in the direction this
finding recommended: F01 is fixed before the note goes up, with the regression
test it asked for, and the same fix is committed on `7.0-stable-GEOxyz`
(`d8e0db501`) so production does not keep the defect. The round-2 delta on the
two branches is literally identical (INV-10), checked by diffing the two diffs.
Nothing is left for Jan to decide here.
