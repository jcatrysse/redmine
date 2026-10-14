# group-membership-preload — Class A decisions

Feature-specific, one line each. Class B goes to `docs/DECISIONS.md`.

- 2026-10-14 — every membership is still saved with `save!` and its callbacks; no `insert_all`. That was Jan's choice before this session (bulk insert is 50–100× faster but skips per-user callbacks), not re-opened.
- 2026-10-14 — a separate issue, not an addition to #43946: that patch is about `Group#user_added` and explicitly leaves `MemberRole#add_role_to_group_users` alone; one issue per entry point keeps each review to one design.
- 2026-10-14 — no `skip_subproject_propagation`-style flag as in #43946: the per-level preload inside `add_role_to_subprojects` keeps the recursion in one place and gets 70 → 36 queries per user (5 subprojects, 2 roles) with two lines.
- 2026-10-14 — the per-user subproject query (`children.where(:inherit_members => true)`) stays: removing it needs state shared across users (a cache on `Project` or a flag), for one query per user per non-leaf level.
- 2026-10-14 — `preload(:project, :principal)` on the existing memberships: without it every user who is already a member reloads both during validation (2 extra queries each), and the second role of a group added with two roles always hits that path.
- 2026-10-14 — tests measure the difference between N and 2N users, with `<=`, not an absolute `assert_queries_count`: fixtures and the queries outside the loop then cannot make them brittle, and the bound is still well below the old cost (15 vs 35, 55 vs 100).
- 2026-10-14 — the tests go in `test/unit/member_test.rb` with a private `count_queries` helper; there is no `member_role_test.rb`, and Rails' `assert_queries_count` only asserts an exact number.
- 2026-10-14 — no extra correctness test for "user already a member": deliberately breaking the preload makes 11 existing tests fail, so that path is covered.
- 2026-10-14 — no locale patch: the change adds no user-visible text.
- 2026-10-14 — the upstream merge of `origin/7.0-stable` into `7.0-stable-GEOxyz` (26 commits) was attempted first, as CLAUDE.md asks, and aborted: 8 files conflict (webhooks, git adapter test, the five locales), all owned by other features. The feature commit sits on `1d8c2a3`, the revision the coordinator measured.
