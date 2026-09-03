# assignee-nobody — "nobody" as a selectable value in the assignee filter

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** In het filter "Toegewezen aan" kun je nu
  `<< niemand >>` aanvinken naast echte gebruikers. Daarmee is
  "toegewezen aan mij **of** nog aan niemand" één filter in plaats van twee
  aparte lijsten.
- **Waar het vandaan komt:** 5.1-commit `9b03b74b2`, geen port-commit (de
  7.0-branch had deze feature nog niet)
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen
- **Kans dat Redmine dit aanneemt:** redelijk — het issue staat al zestien jaar
  open met veel bijval, en het enige echte bezwaar van een committer (Jean-Baptiste
  Barth, 2010: "liever een generieke oplossing") wordt door deze vorm juist
  ingewilligd, waar de bestaande patches dat niet deden.
- **Wat jij nog moet doen:** de nieuwe patch als note hangen aan
  [#5535](https://www.redmine.org/issues/5535) en zeggen waarom hij anders is
  dan jouw patch van november.
- **Keuzes:** geen open keuzes. K-05 beslist op 2026-09-02, optie A: alleen de
  toewijzingslijst krijgt `<< niemand >>`, doelversie en categorie niet.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `2563fa6a5` = r24882 van 2026-08-03 (de mirror
  liep op dat moment een maand achter op SVN-trunk)
- **Lost trunk dit al op?** Nee. Trunk kent alleen de *operator* "geen"
  (`!*`), die per definitie niet met gekozen gebruikers te combineren is: een
  filterrij heeft één operator. Gelezen: `Query#assigned_to_values`,
  `Query#statement`, `Query#sql_for_field` en de operatorentabel
  `Query::OPERATORS_BY_FILTER_TYPE`.
- **Bestaand issue op redmine.org?** Ja, en dat is de belangrijkste vondst van
  deze sessie: [Patch #5535](https://www.redmine.org/issues/5535) —
  *"Assigned to issuelist filter: added \<nobody\> value"*, aangemaakt in 2010,
  status **New**, categorie *Issues filter*. Feature #28924 (2018) is er als
  duplicaat aan gekoppeld. Jan heeft er op 2025-11-22 zelf al de 5.1-patch aan
  gehangen. Gezocht op redmine.org met: *nobody filter*, *unassigned filter*,
  *assignee none*. Feature #10300 en #689 gaan over de operator "geen" en zijn
  allebei afgesloten.
- **Verandert iets in trunk het ontwerp?** Ja, twee dingen.
  1. In 2010 deelden `author_id` en `assigned_to_id` één waardelijst, en dáár
     ging Barths eerste bezwaar over ("author cannot be none"). Trunk heeft
     sinds lang een aparte `Query#author_values`, dus dat bezwaar is
     vanzelf verdwenen — maar alleen als je de pseudo-waarde in
     `assigned_to_values` zet en niet in de gedeelde laag.
  2. Het filter is sinds de historie-operatoren (`ev`, `!ev`, `cf`) van type
     `list_optional_with_history` en biedt dus **zeven** operatoren aan, niet
     twee. Elke patch die er maar één van afhandelt, is per definitie kapot
     voor de andere zes.

---

# The problem

Redmine can filter issues by assignee, and it can filter for issues that have
no assignee at all — but not both at once. "Assignee is none" is an *operator*
(`!*`), and a filter row has exactly one operator, so the two conditions cannot
be combined. The query a team actually wants is "assigned to me, or not yet
picked up by anybody" — the personal list plus the queue, on one page, sortable
and exportable as one result set. Today that needs two saved queries and two
page loads, and the two cannot be summed, grouped or totalled together.

This is [Patch #5535](https://www.redmine.org/issues/5535), open since 2010,
with Feature #28924 closed as its duplicate.

There is a second, smaller problem that only shows up once the value exists.
The assignee filter is of type `list_optional_with_history` and offers seven
operators: `=`, `!`, `ev` (has been), `!ev` (has never been), `cf` (changed
from), `!*` (none) and `*` (any). The two published patches on #5535, and the
one attached in 2025, all add the pseudo-value to the value list and then
handle it for `=` only. With any of the other operators the literal string
`'none'` reaches a comparison against `issues.assigned_to_id`, an integer
column:

    PG::InvalidTextRepresentation: invalid input syntax for type integer: "none"

which is an HTTP 500 on the issue list for four of the seven operators, and for
`cf` a silently empty result, because `journal_details.old_value` is a text
column where nothing ever equals the string `'none'`. Reproduced on PostgreSQL
16 against trunk r24882; the screenshots below are of those 500 pages.

# Why this belongs in core

The value list of a filter and the SQL that a filter compiles to are both built
inside `Query`, in private methods (`assigned_to_values`, `sql_for_field`). A
plugin can only add this by reopening `Query` and patching a private method
whose signature and internals change between releases — and it would have to
patch the operator handling too, not just the list, or it reintroduces the 500
above. It is also not an add-on concept: "no value" is a state the column
already has, and the filter already has an operator for it. What is missing is
the ability to express it as one alternative among several, which is a property
of Redmine's filter language rather than of any one installation.

# Proposed change

Two changes, in one file.

**1. The pseudo-value.** `Query#assigned_to_values` gains
`["<< #{l(:label_nobody)} >>", "none"]`, directly after `<< me >>` and before
the real principals. `label_nobody` already exists in every locale Redmine
ships, and `'none'` is already the value Redmine itself uses for "unassign" in
the bulk-edit form and the context menu, so the vocabulary is not new either.

**2. The semantics, for every operator, generically.** `Query#sql_for_field`
recognises `'none'` as "this column is NULL" for filters of type
`:list_optional` and `:list_optional_with_history` — the two types whose very
name says the column may have no value, and the only two that offer the `!*`
operator. Custom-field filters are excluded (`is_custom_filter`), because a
list custom field may legitimately have `none` among its possible values.

The resulting semantics, with `V` the real values selected alongside `none`:

| Operator | SQL |
|---|---|
| `=` | `assigned_to_id IS NULL OR assigned_to_id IN (V)` |
| `!` | `assigned_to_id IS NOT NULL AND (assigned_to_id NOT IN (V))` |
| `ev` | ever had, or has, no assignee — or one of `V` |
| `!ev` | the negation of `ev` |
| `cf` | changed away from having no assignee — or from one of `V` |
| `!*`, `*` | unchanged; these take no values |

With `none` as the only value, `=` becomes exactly `!*` and `!` becomes exactly
`*`; two of the tests assert that equivalence rather than a literal id list, so
the new value can never drift away from the operator that already means the
same thing.

| File | Change |
|---|---|
| `app/models/query.rb` | `assigned_to_values`: the `<< nobody >>` entry. `sql_for_field`: recognise `'none'` on optional list filters (3 lines), fold NULL into the `=` and `!` clauses (1 line each), and make the `ev`/`!ev`/`cf` subquery NULL-aware through a new private helper `sql_for_in_or_null`. |
| `test/unit/query_test.rb` | eight new tests; one existing test adapted (below). |

**New setting / migration / gem / route / permission:** none. Nor a new
translation key: `label_nobody` exists in all 63 locale files Redmine ships.

**Translations:** none. The patch introduces no user-visible string.
`label_nobody` is reused, so `nl`, `fr`, `de` and `es` need no change and there
is no second patch file.

**Backward compatibility:** additive. No existing filter, saved query, REST
call or Atom feed changes its meaning — the pseudo-value only does something
when a user selects it. A saved query that already contains `assigned_to_id=none`
(hand-written, or made by an installation carrying one of the older patches)
went from an HTTP 500 to a correct result. The `!*` and `*` operators are
untouched, and `sql_for_field` produces byte-identical SQL for every input that
does not contain `'none'`.

**One existing test adapted.**
`test_assigned_to_values_should_be_sorted_by_status_and_name` asserts on
`assigned_to_values[1..]` — it skips the one pseudo-value that used to precede
the real users. With a second pseudo-value it becomes `[2..]`. The assertion
itself (real users sorted by status then name) is unchanged; only the offset
moves. This is the same kind of adaptation Redmine makes whenever a value list
grows a fixed entry.

# Alternatives considered

**A dedicated `sql_for_assigned_to_id_field` on `IssueQuery`.** The dispatcher
in `Query#statement` already looks for `sql_for_<field>_field`, so this is the
obvious seam and it was the first design. It was rejected because the
`ev`/`!ev`/`cf` branch would have to be reimplemented there — a fifteen-line
journal subquery, duplicated, that must stay in step with the original forever.
The generic version is no larger and has no copy.

**Handling `'none'` in `Query#statement`, next to the `"me"` and `"mine"`
substitutions.** That is where Redmine puts its other pseudo-values, and it is
what the patches attached to #5535 do. It does not work: `"me"` and `"mine"`
substitute *other values* into the list and let the operator do its job, while
`none` changes the shape of the clause, differently per operator. `statement`
does not know the operator's SQL, so the handling ends up as an `elsif` that
covers `=` and silently mishandles the rest. That is the source of the 500
described above.

**Blanket handling in `sql_for_field` for every filter type.** Rejected: a list
custom field, or a plain list filter, may have `none` as a real value. Gating on
`list_optional*` plus `!is_custom_filter` keeps the mechanism to the fields
where NULL is by definition meaningful.

**Also putting the pseudo-value in the target-version and category filters.**
Barth asked for exactly that in 2010 ("assigned to, target version, category …
but only when it makes sense"), and both are `list_optional_with_history`, so
the mechanism already covers them — `?v[fixed_version_id][]=none` works with
this patch. Only the assignee list is wired up, because that is what #5535 is
about and because each extra list is a separate judgement about whether
`<< none >>` reads well next to that field's values. Adding either is a
one-line follow-up, deliberately left to the reviewer.

# Tests

| Test | What it proves |
|---|---|
| `test_assigned_to_values_should_include_nobody` | the pseudo-value is offered in the filter's value list |
| `test_filter_assigned_to_nobody_or_user` | `=` returns unassigned issues **and** the selected user's, and nobody else's |
| `test_filter_assigned_to_not_nobody_and_not_user` | `!` excludes unassigned issues, which trunk's `!` deliberately includes |
| `test_filter_assigned_to_nobody_alone_should_match_the_none_operator` | `= none` is exactly the `!*` operator |
| `test_filter_assigned_to_not_nobody_alone_should_match_the_any_operator` | `! none` is exactly the `*` operator |
| `test_operator_has_been_nobody` | `ev` finds an issue that was unassigned and is not any more |
| `test_operator_has_never_been_nobody` | `!ev` is its complement, and excludes that same issue |
| `test_operator_changed_from_nobody` | `cf` finds the issue picked up from the queue, and not an issue that is still in it |

**Evidence (INV-8):**

- full suite with the patch: `bundle exec ruby bin/rails test` in
  `/home/user/wt/patch-assignee-nobody` → **5798 runs, 30700 assertions, 27 failures, 2 errors, 92 skips**
- full suite on a pristine trunk worktree at the same revision → **5790 runs,
  30686 assertions, 27 failures, 2 errors, 92 skips**
- the 29 failing test names are **identical on both sides**, and all 29 are
  repository or changeset tests needing `svn`, `hg`, `bzr` or `cvs`, none of
  which exist in this container. Diff of the two name lists: **empty**
- RuboCop on `app/models/query.rb` and `test/unit/query_test.rb`: **0** offences
  (baseline on the same two files at `origin/master`: **0**)
- each new test verified red on the old code: `app/models/query.rb` was reverted
  to `origin/master` in the patch worktree with the new tests left in place, and
  the same nine tests were run: **9 runs, 3 assertions, 3 failures, 6 errors**.
  Six of them error with the PostgreSQL cast failure, two fail on the missing
  value list entry, and `test_operator_changed_from_nobody` fails rather than
  errors — which is the silent-wrong-answer case, and is the reason the `cf`
  operator is in this patch at all.
- patch applies to pristine `origin/master` r24882: **yes**
- `tools/check-patch-clean.sh`: **PASS**

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb` (project `geoxyz-verify`: nine open issues — four
unassigned, four assigned to `dev`, one to `tester`; one of dev's, "Picked up
from the queue", carries a journal recording the change from nobody).
Screenshots in `docs/features/assignee-nobody/shots/`, driven by
`verify/assignee-nobody.mjs`.

| Function | Before | After | What the pair shows |
|---|---|---|---|
| Assignee **is** nobody or `dev` | `before-is-nobody-or-dev.png` — HTTP 500 | `is-nobody-or-dev.png` — 8 of 9 issues | the four unassigned plus dev's four, in one list, sorted and exportable as one result set |
| Assignee **is not** nobody or `dev` | `before-is-not-nobody-or-dev.png` — HTTP 500 | `is-not-nobody-or-dev.png` — 1 issue | only "Assigned to the tester" is left; unassigned issues are excluded, which trunk's plain `!` would have included |
| Assignee **is** nobody, alone | `before-is-nobody-alone.png` — HTTP 500 | `is-nobody-alone.png` — 4 issues | identical to the `!*` operator, which is what the unit test asserts as well |
| Assignee **has been** nobody | `before-has-been-nobody.png` — HTTP 500 | `has-been-nobody.png` — 5 issues | the four still unassigned plus #9, which was picked up from the queue |
| Assignee **has never been** nobody | `before-has-never-been-nobody.png` — HTTP 500 | `has-never-been-nobody.png` — 4 issues | the exact complement of the previous row |
| Assignee **changed from** nobody | `before-changed-from-nobody.png` — "No data to display" | `changed-from-nobody.png` — 1 issue | the silent failure, and the only case that never raised: the old code compares `journal_details.old_value` with the literal string `'none'` and matches nothing |
| The value list itself | `before-filter-dropdown.png` | `filter-dropdown.png` | `<< nobody >>` appears directly under `<< me >>` and above the `active` group |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| the value does not exist yet (unpatched) | `before-*.png` | the URL asks for `none`, the select cannot hold a value that is not among its options and falls back to `<< me >>` | exactly that, in all seven before shots — which is why the before shots of `cf` show `<< me >>` in the widget while the URL asked for `none` |
| `none` on an operator that takes no values (`!*`, `*`) | covered by the unit tests, not a screenshot | the value is ignored, the operator decides | `= none` ≡ `!*` and `! none` ≡ `*`, asserted against the operators' own results |
| `none` on a field where it could collide | not applicable | custom field filters never reach the new code path | `is_custom_filter` guard, and the enumeration in the objections table |

Beyond the browser, the REST short filter was exercised against the same
instance: `GET /projects/geoxyz-verify/issues.json?assigned_to_id=none` returns
the four unassigned issues, and `?assigned_to_id=none|4` returns eight — so the
pseudo-value works through the API's pipe-separated form too, not only through
the filter form.

Screenshots read, not just generated: yes. Every one of the fourteen images was
opened and looked at, not just checked for existence. What was looked for, and
found: that the before shots are Redmine's own 500 page rather than an empty
list (which would have proven nothing); that the `<< nobody >>` entry sits
between `<< me >>` and the `active` optgroup rather than inside it; that in
`is-nobody-or-dev.png` both `<< nobody >>` and `Dev Verify0` are highlighted as
selected in the widget, so the list of 8 is the union and not a filter that was
silently dropped; and that `has-never-been-nobody.png` lists exactly the four
issues `has-been-nobody.png` does not.

# Anticipated objections

| Objection | Answer |
|---|---|
| "What is the difference between the `none` operator and `<< nobody >>` as a value?" — Marius Bălteanu, #5535 note 14 | The operator cannot be combined; the value can. With only `none` selected the two are identical, and two of the tests assert exactly that. The use case Radek Antoniuk gave in note 16 is the whole point: "issues assigned to me + the queue". |
| "I'd prefer a generic solution … `<< none >>` in some fields: assigned to, target version, category" — Jean-Baptiste Barth, #5535 note 4 | That is what this is. The mechanism sits in `Query#sql_for_field` and applies to any `list_optional` filter, so target version and category already work by URL. Only the assignee *list* is wired up, because that is #5535's subject; adding the other two is one line each, and the choice is the reviewer's. |
| "The 2010 patch broke `author_id`, which cannot be none" — Barth, same note | Trunk has had a separate `Query#author_values` for years, and this patch touches only `assigned_to_values`. The author filter is unaffected. |
| "This is what a plugin is for." | A plugin would have to reopen `Query` and patch two private methods, one of which (`sql_for_field`) is a 250-line operator dispatcher. It would also have to keep the operator coverage in step with core, which is precisely what the existing patches on this issue failed to do. |
| "Adding entries to the value list will break code that indexes into it." | One test in core does (`assigned_to_values[1..]`) and is adapted in this patch. No production code indexes the list. |
| "`none` might collide with a real value." | Only for a filter of type `:list_optional`/`:list_optional_with_history` that is not a custom field. Those are, in all of core: assignee, target version, category, `member_of_group`, `assigned_to_role`, the time-entry equivalents, and user status / auth source / group / 2FA scheme. Every one of them holds numeric ids or a fixed short vocabulary; custom fields, which are the realistic place for a literal "none", are excluded by the `is_custom_filter` guard. `cf_<id>.<attribute>` filters are `:date` and `:list`, so they are outside the gate as well. |
| "Why is `cf` (changed from) in scope?" | Because the filter offers it. Leaving it out does not mean the user cannot pick it — it means they pick it and get an empty list with no error, which is worse than the 500. |

---

## Submission

- **Issue:** [#5535](https://www.redmine.org/issues/5535) — exists since 2010,
  status New. This is a note with a replacement patch, not a new issue.
- **Patches attached:** `patches/assignee-nobody/2026-09-02-r24882-feature.patch` — one file, code
  plus tests. No locale patch: the feature adds no string.
- **Made against:** `origin/master` r24882 (2026-08-03)
- **Status:** klaar om in te dienen
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `9d28be94d`
- **Suites daar groen:** **5803 runs, 30987 assertions, 0 failures, 0 errors, 39 skips** — fully green, no known-failing set at all, because the SCM tests that fail on trunk do not fail on 7.0-stable. RuboCop 0 on the three changed files, baseline 0 at `origin/7.0-stable`. The trunk patch applied to 7.0-stable **verbatim** (`git apply` clean, identical diffstat), and the feature was driven in a browser there too with the same seven cases passing.
- **`nl.yml` toegevoegd:** n.v.t. — geen nieuwe string
- **`tools/check-geoxyz-branch.sh`:** PASS (`REF=7.0-stable-GEOxyz`)
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus pas als GEOxyz naar de release gaat die
  hem bevat — op zijn vroegst 7.1.
