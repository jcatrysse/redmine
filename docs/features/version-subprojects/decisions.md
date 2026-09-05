# version-subprojects — Class A decisions

Feature-specific, one line each. Class B goes to `docs/DECISIONS.md`.

- 2026-09-03 — the change goes in `Query#fixed_version_values`, not as an
  `IssueQuery` override: the method has been generic since r16170.
- 2026-09-03 — union with `project.shared_versions`, not replacement: the
  replacement silently drops versions shared in from outside the tree.
- 2026-09-03 — `$('#filters-table').closest('form')` rather than a list of form
  ids, because both `#query_form` and `#query-form` exist.
- 2026-09-05 — the endpoint gets `params.slice(:f, :op, :v)` rather than the
  whole request. The values of a filter can only depend on the other filters, so
  everything else is surface: the action's own `name` argument, `c`, `t`,
  `query[...]`.
- 2026-09-05 — the browser serialises the `f[]`, `op[...]` and `v[...]` fields
  rather than the whole form, so a POST form's `authenticity_token` never
  reaches a GET URL. `$.grep` over `serializeArray()`, so the settled
  `closest('form')` selector is untouched.
- 2026-09-05 — one short comment above that `$.grep` saying why. The *why* is
  not visible from the code, and `application-legacy.js` carries a comment every
  32 lines, so this is at the file's own density (INV-3).
- 2026-09-05 — the patch branch is rebuilt on current trunk rather than rebased,
  and the r24882 patch file is replaced rather than kept beside the new one: it
  was never attached to the issue, so there is nothing to diff later against.
