# pdf-export-marshal-attachments — Class A decisions

Feature-specific, one line each. Class B goes to `docs/DECISIONS.md`.

- 2026-10-20 — override `objclone`, not `marshal_dump`/`marshal_load` plus
  `rollbackTransaction` (the coordinator's candidate): one hook instead of two,
  it only touches the transaction copy, and because the copy carries the same
  `@attachments` reference RBPDF's own rollback restores it. Both designs pass
  the same tests.
- 2026-10-20 — share the reference rather than `attachments.to_a`: the records
  keep their loaded `container`, so Marshal would still reach the users.
- 2026-10-20 — tests in `test/unit/lib/redmine/export/pdf_test.rb`, against
  `ITCPDF` directly with HTML: independent of the text formatting setting, and
  the existing file already uses issue 14's PNG fixtures with
  `set_fixtures_attachments_directory`.
- 2026-10-20 — the second test asserts `pdf.get_page == 2`, so a change in fonts
  or margins that stops the rollback fails the test instead of letting it pass
  without covering the rollback.
- 2026-10-20 — one patch file, no locales patch: the change has no user-visible
  text.
- 2026-10-20 — G9 trigger is a throwaway local plugin calling core's
  `Issue#notified_users`, on an issue assigned to a non-admin; an admin's
  `allowed_to?` never fills the role cache, which is why the first two live
  runs showed 200 on unpatched trunk.
