# patches/members-pagination

**None of these files are ours.** They are the patches Takenori TAKAKI
(user:takenory) attached to [#43355](https://www.redmine.org/issues/43355),
downloaded unchanged and committed here so a later revision can be diffed
against what we tested. There are now two rounds of them:

| Files | Posted | Attachments | Applies to |
|---|---|---|---|
| `0001-members-pagination.patch`, `0002-groups-pagination.patch` | 2026-08-05 | `/36564/`, `/36565/` | `origin/master` r24882 (`2563fa6a5`) |
| `0001-Add-pagination-to-the-project-members-management-list.patch`, `0002-Add-pagination-to-the-group-users-management-list.patch` | 2026-09-10 | `/36763/`, `/36764/` | `origin/master` r25065 (`167e487ee`), verified 2026-09-11 |

The second round wraps both lists in an `autoscroll` div, renders the table from
the total count rather than from the loaded page (so an out-of-range page shows
the pagination links instead of "No data to display"), renames the two redirect
helpers to `*_url_params`, and shortens the comments. Measured here on trunk
r25065: the five touched test files give **185 runs, 866 assertions, 0 failures,
0 errors**. Katsuya HIDAKA confirmed the same on 2026-09-11, and Takenori reports
a members tab going from ~4.9 s to ~0.33 s on a project with ~4000 members.

There is no patch of ours in this directory, and there will not be one: the
framework's decision for this feature is to hang on to #43355 rather than to
submit a competing patch. The one improvement we found (see *The finding* in
`../../docs/features/members-pagination/dossier.md`) is a diff on top of these
files, so it cannot apply standalone to a pristine trunk and INV-2 keeps it out
of this directory. It lives in the dossier as text, ready to paste into a note —
and the second round did **not** overtake it: it removes the "No data to
display" message but still renders an empty table for an out-of-range page,
where the clamp lands on the last page that has rows. Measured on the same
request (`members_page=99`, `per_page_options` `2,5`, project 1): upstream's
round two gives 0 rows, this branch gives 1.
