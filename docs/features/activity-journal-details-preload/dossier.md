# activity-journal-details-preload — de activiteitenpagina laadt journal details in één query in plaats van één per journal

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** de pagina *Activiteit* haalde voor elke issue-wijziging apart de details op (welk veld veranderde), dus 1000 wijzigingen = 1000 extra databasevragen. Nu is dat één vraag voor allemaal; wat er op het scherm staat verandert niet.
- **Waar het vandaan komt:** geen 5.1-commit. Gemeten door de coördinator van de Redmine 7-migratie (core zonder plugins, 20.000 issues: `/activity` 1,8 à 1,9 s, ~1000 queries, waarvan 943 `journal_details`).
- **Doel:** upstream + GEOxyz.
- **Afwijking GEOxyz ↔ upstream:** geen. Dezelfde regel en dezelfde test op beide.
- **Kans dat Redmine dit aanneemt:** goed. Het issue bestaat al (#44252, target 7.1.0 gezet door Marius), met precies deze ene regel als patch; dezelfde committers namen #42077 en #44363 aan, dezelfde soort preload op dezelfde plek. Wat ontbrak was een test en een meting op PostgreSQL op schaal; die leveren wij.
- **Wat jij nog moet doen:** een notitie op #44252 plaatsen met `patches/activity-journal-details-preload/2026-10-14-r25236-feature.patch` erbij (tekst hieronder onder "Note for #44252"). Geen nieuw issue aanmaken.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** mirror `origin/master` `1d6194503` (r25236, 2026-10-13). Echte trunk aan het eind van de sessie: `d1f69043e` (r25254, 2026-10-14), dus de mirror loopt **12 commits** achter. Geen ervan raakt de activity-provider; wel r25237 (`da0134110`, #44579) de `has_many :details`-regel zelf (`order(:id)` erbij), twee regels boven onze hunk. De patch applyt op r25254 zonder fuzz, en de nieuwe test is daar rood zonder en groen met de wijziging — zie Tests.
- **Lost trunk dit al op?** Nee. `Journal`'s `acts_as_activity_provider`-scope preloadt `{:issue => :project}, {:issue => :tracker}, :user`, niet `:details`; ook op r25254.
- **Bestaand issue op redmine.org?** Ja: **#44252** "Preload journal details when retrieving Activity events to avoid N+1 queries", kyohei yamada, 2026-07-10, status New, target 7.1.0, met patch (attachment 36470, dezelfde ene regel) en een variant van Florian Walchshofer (36501, met `user: :email_address` bij Gravatar). Geen test bij beide. Verwant en gesloten: #42077 (r23446/r23447, tracker-preload en `journalized`, zit in 7.0-stable) en #44363 (r25118, preloads voor Attachment/Document/WikiContentVersion/TimeEntry; **niet** in 7.0-stable).
- **Verandert iets in trunk het ontwerp?** Nee. `order(:id)` op de association (r25237) wordt door `preload` gewoon toegepast: één `SELECT ... WHERE journal_id IN (...) ORDER BY id`.

---

# Note for #44252

*(This is the text Jan pastes as a note on https://www.redmine.org/issues/44252, with the patch attached.)*

We hit this on a PostgreSQL installation with 20,000 issues and about 20,000 journals: `/activity` took 1.8 to 1.9 s and about 1,000 queries, 943 of them `JournalDetail Load`, one per journal event. The cost is the same with and without plugins.

The attached patch is the change from attachment 36470, unchanged, rebased onto r25236 (it also applies to r25254, after r25237 added `order(:id)` to the association, and the test behaves the same there), plus a unit test that pins the N+1 down: it reads `details` of every journal the Activity fetcher returns and asserts that this runs no query. Without the preload the test fails with one `SELECT "journal_details".*` per journal (5 on the fixtures).

Measured in a running instance (PostgreSQL 16, development mode, 1,010 journal events in the default 10-day window, median of 5 full renders):

| Page | Before: time, DB queries | After: time, DB queries |
|---|---|---|
| `/activity` (admin) | 5,061 ms, 1,033 | 3,172 ms, 34 |
| `/activity` (project member) | 5,602 ms, 1,041 | 2,990 ms, 42 |
| `/projects/:id/activity` (admin) | 5,252 ms, 1,039 | 3,170 ms, 40 |
| `/projects/:id/activity?show_issues=1` (admin) | 5,150 ms, 1,034 | 3,177 ms, 35 |
| `/projects/:id/activity?show_wiki_edits=1` (no journals) | 79 ms, 25 | 78 ms, 25 |

"DB queries" excludes the ones answered by the query cache (Rails logs both; the cached ones, about 2,000 here, are `IssueStatus.find_by_id` from `Journal#new_status` and are the same before and after).

The rendered activity is identical before and after (same SHA-1 over the page text).

# The problem

The Activity view renders every journal event through `event_title` and `event_type`, and both call `Journal#new_status`, which looks through `journal.details`. The provider scope of `Journal` preloads the issue, its project and tracker, and the user, but not the details. The `LEFT OUTER JOIN journal_details` in that scope is there to filter on `prop_key = 'status_id'` and does not load the association. So each journal event costs one `SELECT "journal_details".* WHERE journal_id = ?`.

On a busy project that is the bulk of the page: with about a thousand journals in the default window, the page runs about a thousand queries.

# Why this belongs in core

The scope is defined inside `Journal`'s `acts_as_activity_provider` call and is consumed by `Redmine::Activity::Fetcher`. A plugin could only change it by overriding the registered provider options, which is the kind of patch that breaks on every core change to that block. #42077 already fixed the neighbouring preloads at this exact spot.

# Proposed change

| File | Change |
|---|---|
| `app/models/journal.rb` | add `:details` to the `preload` of the activity provider scope |
| `test/unit/activity_test.rb` | `test_journal_events_should_preload_details` |

**New setting / migration / gem / route / permission:** none.

**Translations:** none; no user-visible text.

**Backward compatibility:** nothing changes in what is returned or rendered. The `last_by_project` path (`group(...).maximum(...)`) ignores `preload`, as it already ignores the existing ones. The Atom feed uses the same scope with a limit and gets the same benefit.

# Alternatives considered

- **`eager_load(:details)`.** The scope already joins `journal_details` for its filter and uses `distinct`; an eager load adds a second join of the same table and, with the Atom feed's `limit`, makes Rails run its two-step "distinct ids, then rows" query. `preload` is one plain `WHERE journal_id IN (...)` query, the same mechanism as the preloads already on that line.
- **Also preloading `user: :email_address` when Gravatar is on** (attachment 36501 on this issue). That N+1 is per distinct author, not per journal, and only with Gravatar enabled. It is a separate condition and is left to that attachment.
- **Caching `IssueStatus.find_by_id` in `Journal#new_status`.** It is called twice per journal but answered by the request's query cache (no round-trip). Not needed for this issue.

# Tests

| Test | What it proves |
|---|---|
| `ActivityTest#test_journal_events_should_preload_details` | after `Redmine::Activity::Fetcher#events` for the `issues` scope, reading `details` of every returned journal runs no query. Red on the old code: `5 instead of 0 queries were executed`, five times `SELECT "journal_details".* FROM "journal_details" WHERE "journal_details"."journal_id" = $1` |

**Evidence (INV-8 — figures, not claims):**

- **full** suite with the patch, `tools/test-env.sh <worktree> bundle exec ruby bin/rails test:all` → `6219 runs, 32804 assertions, 28 failures, 2 errors, 87 skips`
  - 29 of them are in five SCM test files (`repositories_controller_test`, `sys_controller_test`, `api_test/repositories_test`, `api_test/issues_test`, `user_test`; no `svn` in this image). The same five files on pristine trunk r25236: `288 runs, 976 assertions, 27 failures, 2 errors, 10 skips`, the 29 failing test names identical.
  - the 30th is `IssuesSystemTest#test_update_issue_form_should_include_time_entry_form_only_for_users_with_permission`, failing in the login helper (`expected "/my/page" to equal "/login"`, `application_system_test_case.rb:76`), not in anything this patch touches. Re-run alone: `1 runs, 4 assertions, 0 failures`; the whole `test/system/issues_test.rb`: `30 runs, 265 assertions, 0 failures, 0 errors`.
- `test/unit/activity_test.rb` with the patch: `17 runs, 40 assertions, 0 failures`; on real trunk r25254 with the patch applied: the same, and `test/unit/journal_test.rb` `25 runs, 102 assertions, 0 failures`
- RuboCop on `app/models/journal.rb` and `test/unit/activity_test.rb`: `2 files inspected, no offenses detected`; baseline at the merge base: 0
- the new test red on the old code: run with the change reverted, on r25236, on `7.0-stable-GEOxyz` and on real trunk r25254: `5 instead of 0 queries were executed`, the five being `SELECT "journal_details".* FROM "journal_details" WHERE "journal_details"."journal_id" = $1` (with `ORDER BY "journal_details"."id" ASC` on r25254)
- patch applies to pristine `origin/master` r25236: yes. Real trunk was r25254 at the end of the session (the mirror is 12 commits behind); the patch applies there too (`git apply`, no fuzz)
- `tools/check-patch-clean.sh activity-journal-details-preload`: PASS. With `--submit`: FAIL, only because the mirror is behind redmine.org; that sync is Jan's (K-19)

# Live verification (G9)

Exercised in a real Redmine at `http://127.0.0.1:3000`, seeded by `tools/dev-seed.rb`, plus 1,000 journals inserted by `verify/activity-journal-details-preload.mjs` on the issues of `geoxyz-verify` (half status changes, half notes with an assignee change), all inside the default 10-day window. Before = pristine trunk r25236 (`/tmp/claude-0/base`), after = `patch/activity-journal-details-preload`, same database. Every number is the median of 5 full renders taken from the server log's `Completed` line; `If-None-Match` is stripped, because the controller answers a repeat with 304 and skips the rendering. Development mode, so absolute times are higher than in production; the query counts are not affected by the mode.

| Function | Before | After | What it shows |
|---|---|---|---|
| global activity, admin | `before-activity-global.png` | `after-activity-global.png` | 1,010 events; 5,061 ms / 3,029 queries (1,996 cached) → 3,172 ms / 2,030 (1,996 cached) |
| project activity, admin | `before-activity-project.png` | `after-activity-project.png` | same events; 5,252 → 3,170 ms |
| project activity, issues only | `before-activity-issues-only.png` | `after-activity-issues-only.png` | 5,150 → 3,177 ms |
| the journal events themselves | `before-journal-events.png` | `after-journal-events.png` | scrolled to the first status change: titles carry the new status read from the details (*Rejected*, *Feedback*, *In Progress*), closed-status icon on *Rejected*; identical before and after |
| the same pages as a project member (`dev`) | `before-member-*.png` | `after-member-*.png` | same events and same page text as admin; 5,602 → 2,990 ms on `/activity` |

The SHA-1 over the text of `#content` is the same before and after on every page (`/activity` `a13957ddaff05870`, project activity `ea9d9c01fba13c92`), for admin and member.

Failure paths:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| issues not selected, so no journal is fetched | `before-activity-no-issues.png`, `after-activity-no-issues.png` (+ `-member`) | unchanged, no extra query | 3 wiki events; 25 DB queries before and after (admin; 33 as member, also unchanged) |
| an empty period | `before-activity-empty.png`, `after-activity-empty.png` (+ `-member`) | "No data to display", no error | as expected; 27 DB queries before and after (admin; 36 as member, also unchanged) |

Same measurement on `7.0-stable-GEOxyz` (own development database, change reverted for the before run): `/activity` 5,073 ms / 3,030 queries → 3,071 ms / 2,030, page text identical before and after. Those shots were not kept; they show the same as the trunk ones.

Screenshots read, not just generated: yes. Before and after shots compared side by side: identical content; the journal-events pair shows the status-change titles, which are exactly what `new_status` computes from the details, so a wrongly loaded association would show here as a missing status.

# Anticipated objections

| Objection | Answer |
|---|---|
| This duplicates #44252. | It is the same change, deliberately: posted as a note on #44252, adding a test and a measurement, not a competing patch. |
| A test that asserts zero queries is brittle. | It asserts zero queries only around reading `details` of already-fetched journals, which is exactly what preloading guarantees; anything else the fetcher does is outside the block. |
| Preloading loads details for journals that are later dropped by `limit`. | `limit` is applied in SQL before the preload runs; `preload` only loads details for the rows actually returned. |
| The preload ignores the `prop_key` filter and loads all details. | That is intended: `new_status` needs only `status_id`, but the association must be complete, or `journal.details` would be wrong for anything else that reads it later in the request. |

---

## Submission

- **Issue:** #44252 (bestaand) — https://www.redmine.org/issues/44252
- **Patches attached:** `patches/activity-journal-details-preload/2026-10-14-r25236-feature.patch` (code + test; geen locales)
- **Made against:** `origin/master` r25236 (2026-10-13); applyt ook op echte trunk r25254 (2026-10-14)
- **Status:** patch klaar, nog niet geplaatst
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `83693089a` (same commit, cherry-picked)
- **Suites daar groen:** `tools/test-env.sh /home/user/wt/geoxyz bundle exec ruby bin/rails test:all` → `6269 runs, 32960 assertions, 0 failures, 0 errors, 29 skips`
- **`nl.yml` toegevoegd:** n.v.t., geen tekst
- **`tools/check-geoxyz-branch.sh`:** PASS (lint 8 on 78 files, all upstream's own lines, baseline 8). `tools/check-symmetry.sh activity-journal-details-preload`: PASS
- **Wanneer kan deze commit vervallen?** Als GEOxyz naar de release gaat die #44252 bevat (target 7.1.0). Tot dan blijft hij nodig; Redmine backport dit niet naar 7.0-stable.
