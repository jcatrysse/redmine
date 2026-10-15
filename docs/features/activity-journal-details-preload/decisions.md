# activity-journal-details-preload — Class A decisions

Feature-specific, one line each. Class B goes to `docs/DECISIONS.md`.

- 2026-10-14 — no new redmine.org issue: #44252 (kyohei yamada, 2026-07-10, status New, target 7.1.0) asks for exactly this, with the same one-line patch. A second issue would be closed as a duplicate. What we add is a test and a PostgreSQL measurement at scale, as a note on #44252.
- 2026-10-14 — the code change is character-for-character the one in attachment 36470 of #44252, only rebased (the context line moved by the `order(:id)` commit r25237 on real trunk is not part of the hunk). No variant of our own, so a committer has one design to judge.
- 2026-10-14 — Florian Walchshofer's variant on #44252 (attachment 36501) also preloads `user: :email_address` when Gravatar is on. Not taken: that N+1 is per distinct author, not per journal, and only with Gravatar enabled; it is a second change with its own condition, and the committer can take it from that attachment. It stays outside this slug.
- 2026-10-14 — the test asserts zero queries when every fetched journal's `details` is read (`assert_no_queries`), instead of comparing N against 2N journals: preloading makes the per-journal cost exactly zero, so "0" is the strongest statement that is still independent of the number of journals, and it needs no extra fixtures. Old code: 5 queries for the 5 fixture journals, one per journal.
- 2026-10-14 — the test goes in `test/unit/activity_test.rb`, next to `test_journal_with_notes_and_changes_should_be_returned_once`, because it tests what `Redmine::Activity::Fetcher` returns for the `issues` scope, not a `Journal` method.
- 2026-10-14 — `IssueStatus.find_by_id` in `Journal#new_status` (called twice per journal, by `event_type` and `event_title`) is left alone: the request's query cache answers it (1,996 "cached" in the 1,010-event measurement), so it costs no round-trip. Reported, not fixed (INV-1).
- 2026-10-14 — #44363 (r25118, preloads for Attachment, Document, WikiContentVersion and TimeEntry events) is on trunk but not on 7.0-stable. It is a different change and is not carried to GEOxyz in this slug; reported to the coordinator instead.
- 2026-10-14 — no locale patch: the change adds no user-visible text.
- 2026-10-14 — G9 is measured in development mode on the dev server, with the `If-None-Match` header stripped: ActivitiesController answers a repeated request with 304, which skips the rendering where the N+1 sits, so a plain reload measured nothing.
