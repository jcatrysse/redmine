# group-membership-preload — een groep aan een project toevoegen met minder queries per gebruiker

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** als je een groep aan een project toevoegt, maakt Redmine voor elke gebruiker van die groep een eigen lidmaatschap aan, en zocht daarbij per gebruiker opnieuw de gebruiker, het project, de rol en het bestaande lidmaatschap op. De patch haalt die dingen één keer per niveau op en geeft ze door; elk lidmaatschap wordt nog altijd gewoon opgeslagen, met alle callbacks.
- **Waar het vandaan komt:** geen 5.1-commit. Opdracht van Jan van 2026-10-14 via de coördinator van de Redmine 7-migratie ("cache + zuinige core"): de cache-helft zit in de plugin `redmine_custom_workflows` (andere sessie), dit is de corehelft. Gemeten op `7.0-stable-GEOxyz` `1d8c2a3`.
- **Doel:** upstream + GEOxyz.
- **Afwijking GEOxyz ↔ upstream:** geen. Dezelfde twee bestanden, dezelfde regels.
- **Kans dat Redmine dit aanneemt:** goed — klein (11 regels erbij, 5 eraf in één model), geen gedragswijziging, callbacks blijven, en het is hetzelfde soort werk als #36696 (aangenomen in 5.0.0) en #43946 (open).
- **Vergelijking met het prototype van de coördinator:** dat haalde -45 % (6,0 → 3,2 s en 34 → 18,6 s). Deze patch: -47 % zonder subprojecten en -36 % tot -40 % met 5 subprojecten, met dezelfde eindtoestand. Het verschil met subprojecten: de children-query per gebruiker blijft (zie decisions.md).
- **Wat jij nog moet doen:** de mirror syncen (11 commits achter op 2026-10-14), dan `--submit`, en een issue aanmaken met `patches/group-membership-preload/2026-10-14-r25236-feature.patch`. Geen localepatch: er is geen nieuwe tekst.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** mirror `origin/master` `1d6194503` = r25236 (2026-10-13). Echte trunk op 2026-10-14 is r25249: de mirror loopt 11 commits achter. Geen van die 11 raakt `app/models/member_role.rb`, `member.rb` of `group.rb`, en de patch applyt ook schoon op r25249 (`git apply --check`).
- **Lost trunk dit al op?** nee. `MemberRole#add_role_to_group_users` en `#add_role_to_subprojects` zijn in trunk regel voor regel gelijk aan `7.0-stable` (laatste wijziging aan het bestand: `ddde0ff47`, alleen de callbackvolgorde voor RuboCop).
- **Bestaand issue op redmine.org?** Niet voor deze richting. Gezocht via de REST-API op onderwerp: `group`, `member`, `member_role`, `MemberRole`, `inherit`, `add_role_to_group_users`, `adding a group`, gefilterd op slow/perform/quer/optimi/speed. Verwant:
  - #43946 (New, patch) — `Group#user_added`: een gebruiker toevoegen aan een groep, de omgekeerde richting. De patch zegt zelf dat hij `MemberRole#add_role_to_group_users` niet aanraakt. Hij voegt een vlag `skip_subproject_propagation` toe en doet de subprojecten dan zelf.
  - #43203 (New, patch) — `Project#remove_inherited_member_roles`, verwijderen.
  - #36696 (Closed, 5.0.0, r21447) — "Improve performance of adding or removing members of a group", ook de omgekeerde richting.
  - #22850 (Closed) — `remove_inherited_roles`, verwijderen.
- **Past het in #43946?** Nee, als aparte patch. #43946 gaat over `Group#user_added` en heeft zijn eigen pad met een vlag; deze patch gaat over `MemberRole`. Ze verdragen elkaar: met deze patch eerst toegepast applyt #43946 nog met `patch -p1` (één hunk met fuzz 1), en de MemberRoles die #43946 *niet* overslaat profiteren van de per-niveau-preload hier. Ze in één issue stoppen zou een reviewer twee ontwerpen tegelijk laten beoordelen.
- **Verandert iets in trunk het ontwerp?** Nee. Trunk heeft sinds 7.0 de scopes `Member.like`, `with_role`, `status` (ledenpaginering, #43355); die raken dit pad niet.

---

# The problem

Adding a group to a project creates one membership for every user of the
group, and does it one user at a time with a full lookup per user.
`MemberRole#add_role_to_group_users` iterates over the user ids of the group and
for each one calls `Member.find_or_initialize_by(project_id, user_id)`, builds a
`MemberRole` from a `role_id`, and saves. Saving then reloads what the code
already had in memory: `validates_presence_of :principal, :project` loads the
user and the project again, and the `MemberRole` validation loads the role. For
a project without subprojects that is **7 queries per user per role**.

Every new `MemberRole` then runs `add_role_to_subprojects`, which queries the
children of the project again for each user and, for each inheriting
subproject, does the same find, user/project reload and save: another
**6 queries per user per subproject**, recursively.

Measured in a development instance on PostgreSQL 16 (trunk r25236), adding a
group of 1000 users with one role through *Project > Settings > Members > New
member*:

| Case | Queries | Time |
|---|---|---|
| project without subprojects | 7,021 | 17.5 s |
| project with 5 subprojects that inherit members | 38,046 | 95.1 s |

The second case is past the timeout of most reverse proxies. The same code runs
when an administrator adds a group to projects from *Administration > Groups >
Projects* (`Member.create_principal_memberships`).

# Why this belongs in core

The work happens in two private `after_create` callbacks of `MemberRole`. A
plugin can only change them by overriding private core methods, which is
exactly what plugins should not have to do for a core performance problem.

# Proposed change

Same behaviour, same callbacks, fewer lookups. Both callbacks now do what the
caller already does elsewhere in Redmine: load the existing memberships of the
level in one query, index them, and build new memberships from the objects in
hand.

- `add_role_to_group_users` loads the group's users once, loads their existing
  memberships in the project in one query (with their project and principal
  preloaded), and builds a missing membership with `:project => member.project,
  :principal => user` and the `MemberRole` with `:role => role` instead of ids.
- `add_role_to_subprojects` loads the inheriting subprojects as records, loads
  the member's existing memberships in those subprojects in one query, and
  builds a missing one with `:project => subproject, :principal =>
  member.principal`.

Every membership is still saved with `save!`, one at a time, so validations,
callbacks, the recursion into deeper subprojects and anything a plugin hooks
onto `Member` or `MemberRole` run exactly as before.

| File | Change |
|---|---|
| `app/models/member_role.rb` | the two callbacks above, 11 lines added, 5 removed |
| `test/unit/member_test.rb` | two tests fixing the per-user query cost, plus a private `count_queries` helper |

**New setting / migration / gem / route / permission:** none.

**Translations:** none. The patch adds no user-visible text, so there is no
locale patch.

**Backward compatibility:** the resulting `members` and `member_roles` rows are
identical, including `inherited_from`. Checked with a checksum over every
`member_roles` row of the test projects, with `inherited_from` resolved to the
project, user and role it points at, before and after the change: equal in the
unit benchmark (20 runs: 0 or 5 subprojects, a user who is already a direct
member or not, 10 or 20 users, both entry points) and in the live instance
(`MEMBERS=7008 MEMBER_ROLES=7014`, same checksum).

# Alternatives considered

**Bulk insert (`insert_all`) of the members and member roles.** 50 to 100 times
faster in a prototype, but it skips validations and every `Member` and
`MemberRole` callback, including the recursion into subprojects and anything a
plugin attaches to them. That changes behaviour, not just speed, so it is not
proposed here.

**A transient flag that suppresses `add_role_to_subprojects` and propagates
explicitly, as #43946 does for `Group#user_added`.** It would also remove the
per-user subproject query and could batch across users, but it duplicates the
recursion in a second place and is roughly four times the code. The two-line
per-level preload in `add_role_to_subprojects` gets most of the gain while the
recursion stays where it is.

**Caching the subproject list on the `Project` object.** `Project#children` is
a fresh relation each call, so caching would need new state on `Project` that
can go stale within a request. Not worth one query per user.

# Tests

| Test | What it proves |
|---|---|
| `MemberTest#test_adding_a_group_member_should_not_query_each_user_beyond_its_inserts` | adding a group of 10 users costs at most 3 queries per user more than a group of 5: one uniqueness check, one insert in `members`, one in `member_roles`. Was 7 per user |
| `MemberTest#test_adding_a_group_member_should_not_query_each_user_and_subproject_beyond_its_inserts` | with 2 inheriting subprojects, at most 3 queries per user in the project, 2 per user for the subproject level (children and existing memberships) and 3 per user per subproject. Was 20 per user, now 11 |

The difference between N and 2N users is used instead of an absolute count, so
fixture data and query overhead outside the loop do not make the tests brittle.

The existing tests already cover the path where a user is already a member
(in the project or the subproject): with the preload deliberately broken (index
emptied, so every user is treated as new) 11 existing tests in
`member_test.rb`, `group_test.rb`, `project_members_inheritance_test.rb` and
`user_test.rb` fail. So no extra correctness test was added.

**Evidence (INV-8 — figures, not claims):**

- **full** suite: `tools/test-env.sh /home/user/wt/patch-group-membership-preload bundle exec ruby bin/rails test:all` (system tests included) → `6220 runs, 32807 assertions, 27 failures, 2 errors, 87 skips`. All 29 are in five SCM test files (`repositories_controller_test`, `sys_controller_test`, `api_test/repositories_test`, `api_test/issues_test`, `user_test#test_destroy_should_nullify_changesets`) and come from `svn` not being installed in this container (`Type is invalid` for `Repository::Subversion`). The same five files on clean trunk r25236: `288 runs, 976 assertions, 27 failures, 2 errors`, failing test names identical (`diff` empty)
- RuboCop on changed files: 0 offences (baseline at merge base: 0)
- each new test verified red on the old code: run against `app/models/member_role.rb` from `origin/master` with the new tests in place: `Expected 35 to be <= 15.` and `Expected 100 to be <= 55.`, 2 runs, 2 failures; with the patch 2 runs, 0 failures
- patch applies to pristine `origin/master` r25236: yes; to real trunk r25249: yes (`git apply --check`)
- `tools/check-patch-clean.sh`: PASS (without `--submit`: the mirror is 11 commits behind real trunk, see G1)

**Query count per user, unit benchmark** (test database, PostgreSQL 16, two roles
`[1, 3]`, the difference between 10 and 20 users divided by 10):

| Case | Before | After |
|---|---|---|
| no subprojects | 13.0 | 5.0 |
| no subprojects, one user already a direct member | 13.0 | 5.0 |
| 5 inheriting subprojects | 70.0 | 36.0 |
| 5 inheriting subprojects, one user already a direct member | 70.0 | 36.0 |
| *Administration > Groups > Projects*, 1 role, 5 subprojects | 38.0 | 20.0 |

Same benchmark with **1000 users** (test environment, one run each):

| Case | Before | After |
|---|---|---|
| two roles, no subprojects | 13,009 queries, 14.9 s | 5,012 queries, 7.9 s |
| two roles, 5 inheriting subprojects | 70,066 queries, 86.5 s | 36,043 queries, 52.3 s |
| *Administration > Groups > Projects*, 1 role, 5 subprojects | 38,040 queries, 47.8 s | 20,027 queries, 28.1 s |

The rows created are identical in every case (same checksum before and after).

# Live verification (G9)

Exercised in a real Redmine at `http://127.0.0.1:3000` (`tools/dev-server.sh`,
development mode, PostgreSQL 16), seeded by `tools/dev-seed.rb` plus the seed in
`verify/group-membership-preload.mjs`: a group `perf-group` of 1000 users, a
project `perf-flat` without subprojects, `perf-parent` with 5 subprojects that
inherit members, user `perf0001` already a direct Reporter in `perf-parent`,
and an empty group. Each run first deletes the memberships of those projects,
so before and after start from the same state. The group is added through
*Settings > Members > New member*, the path that was reported. Times and query
counts are the server's own `Completed` log line for that request.

| Function | Screenshot | What it shows |
|---|---|---|
| group of 1000 users added to a project without subprojects | `before-flat-added.png` | 17,454 ms, ActiveRecord 3,861 ms, **7,021 queries** |
| | `after-flat-added.png` | 9,118 ms, ActiveRecord 1,894 ms, **3,022 queries** |
| same group added to a project with 5 inheriting subprojects | `before-parent-added.png` | 95,122 ms, ActiveRecord 20,182 ms, **38,046 queries** |
| | `after-parent-added.png` | 60,784 ms, ActiveRecord 12,893 ms, **20,037 queries** |
| a subproject lists the group users with the inherited role | `before-subproject-inherited.png`, `after-subproject-inherited.png` | the same list |
| a user who was already a direct member keeps their own role | `before-direct-member-kept.png`, `after-direct-member-kept.png` | `perf0001`: "Developer, Reporter" in the parent and all five subprojects, in both |

The two member-list shots are filtered on "group" so the group row is in view;
the shots look the same before and after, which is the point: only the time
changed. Development mode logs every query, so absolute times are higher than
in production; the ratio is what matters (-48 % and -36 %). The earlier runs of
the same script gave 17.0–18.0 s / 95–106 s before and 9.0–9.1 s / 59.7–60.8 s
after.

After both runs, a checksum over every `member_roles` row of the test projects
(`inherited_from` resolved to project, login and role name) is the same:
`MEMBERS=7008 MEMBER_ROLES=7014 CHECKSUM=bb7f7984f7d8c111` before, after, and on
`7.0-stable-GEOxyz`.

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| a group without users | `before-empty-group.png`, `after-empty-group.png` | only the group membership is created | the group is listed alone with Manager; 8 queries after (the before run logged 8 and 21 in two runs, cache warm-up in development mode) |
| a group user who is already a direct member | `*-direct-member-kept.png` | own role kept, inherited role added, in the parent and the subprojects | as expected, same checksum |

There is no setting and no permission involved, so there is no "off" path.

Screenshots read, not just generated: yes — checked that the group appears in
the member list, that a subproject lists the group users with the inherited
Developer role, that `perf0001` shows "Developer, Reporter" in the parent and
in all five subprojects, and that the empty group was added alone.

# Anticipated objections

| Objection | Answer |
|---|---|
| Why not skip the callbacks and bulk insert? | That is 50 to 100 times faster but changes behaviour: validations, the recursion into subprojects and plugin callbacks would no longer run. This patch keeps all of them; see "Alternatives considered". |
| Loading every user of the group into memory. | The old code loaded every user too, one query each, during validation. Now it is one query. |
| `user_id IN (...)` with thousands of ids. | Rails inlines the values when a list exceeds the adapter's bind parameter limit (`bind_params_length`, e.g. SQL Server), so a large group does not hit the parameter limit. The old code already built `group.users.ids` as a list. |
| The preloaded memberships can go stale inside the loop. | Each iteration only writes the membership of its own user in `member.project` (and in subprojects, which belong to a different level). No iteration creates a membership another iteration looked up. The checksum comparison above includes a user who is already a member. |
| Overlap with #43946. | Different entry point (`Group#user_added`, adding a user to a group). Both apply together (#43946 needs fuzz 1 after this one), and the member roles #43946 does not flag profit from the preload here. |
| Deleting a group membership is still slow. | Yes, 8 queries per user. Not addressed here; #43203 and #22850 are about that side. |

---

## Submission

- **Issue:** nog niet aangemaakt
- **Patches attached:** `patches/group-membership-preload/2026-10-14-r25236-feature.patch` (one file; no locale patch, there are no strings)
- **Made against:** `origin/master` r25236 (2026-10-13)
- **Status:** patch klaar
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `2b9700a9c`, the same commit as the patch, cherry-picked onto `1d8c2a3`
- **Suites daar groen:** `tools/test-env.sh /home/user/wt/geoxyz bundle exec ruby bin/rails test:all` → `6196 runs, 32670 assertions, 0 failures, 0 errors, 28 skips` (the branch carries #42500, which skips the SCM tests when the client is missing). Live: 9,631 ms / 3,022 queries and 62,259 ms / 20,037 queries, same checksum as trunk
- **`nl.yml` toegevoegd:** n.v.t., geen tekst
- **`tools/check-geoxyz-branch.sh`:** for this feature ok: commit recorded, no AI identity, lint 8 offences = upstream baseline 8; `tools/check-symmetry.sh group-membership-preload` PASS. The run as a whole is 2 FAIL that were there before this commit: the branch is 26 commits behind `origin/7.0-stable` and that merge conflicts in 8 files of other features (webhooks, `git_adapter_test.rb`, the five locales)
- **Wanneer kan deze commit vervallen?** Pas als GEOxyz naar de Redmine-release gaat waarin de trunk-patch geland is (7.1 of later); een trunk-patch komt nooit in 7.0-stable.
