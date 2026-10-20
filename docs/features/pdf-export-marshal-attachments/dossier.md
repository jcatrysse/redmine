# pdf-export-marshal-attachments — PDF-export van een issue faalt met "can't dump hash with default proc"

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** de PDF-export van een issue of wikipagina met
  een tabel geeft een 500 zodra een gebruiker die aan dat issue hangt (auteur,
  toegewezene) in hetzelfde verzoek al naar zijn rollen gevraagd is. De fix laat
  rbpdf de bijlagen niet meer mee-kopiëren wanneer het een "ongedaan maken"-kopie
  van het PDF-object maakt; ze worden gedeeld in plaats van gekopieerd.
- **Waar het vandaan komt:** productie 5.1, `GET /issues/22240.pdf` → 500. Gevonden
  en gereproduceerd door de coördinatorsessie, geen bestaande GEOxyz-commit.
- **Doel:** upstream + GEOxyz.
- **Afwijking GEOxyz ↔ upstream:** geen in gedrag. Mechanisch: trunk heeft
  `ITCPDF` sinds r25047 in `lib/redmine/export/pdf/itcpdf.rb`, 7.0-stable nog in
  `lib/redmine/export/pdf.rb`. Dezelfde methode, ander bestand.
- **Kans dat Redmine dit aanneemt:** goed — een 500 bij een gewone export, twaalf
  regels in één klasse, twee unit tests die rood zijn zonder de fix, en het
  ontwerp laat rbpdf ongemoeid. Het zwakke punt: in core zonder plugin heb je een
  pad nodig dat de rollen van de auteur of toegewezene vooraf berekent (zie
  "Anticipated objections").
- **Wat jij nog moet doen:** een issue aanmaken op redmine.org (Defect, categorie
  PDF export) met de Engelse tekst hieronder en
  `patches/pdf-export-marshal-attachments/2026-10-20-r25262-feature.patch`. Vlak
  daarvoor de mirror syncen en `tools/check-patch-clean.sh --submit` draaien.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** mirror `origin/master` `32a519d8c` (r25262,
  2026-10-16). Echte trunk op 2026-10-20 is `69893ce42` (r25284): de mirror loopt
  **18 commits achter**. Geen van die 18 raakt `lib/redmine/export/` of de PDF-tests;
  de patch is ook tegen r25284 gecontroleerd met `git apply --check`: past.
- **Lost trunk dit al op?** nee. `ITCPDF#RDMwriteFormattedCell` zet nog steeds
  `@attachments = attachments`, en er is geen `objclone`, `marshal_dump` of
  `rollbackTransaction` in `itcpdf.rb`. De enige recente commits op de PDF-laag
  zijn r25047 (`e0e38cb9b`, rbpdf pas laden bij de eerste PDF, `ITCPDF` naar een
  eigen bestand) en de RuboCop-opkuis `741a44368`; geen van beide raakt dit.
- **Bestaand issue op redmine.org?** niets gevonden. Gezocht (issues, alle
  projecten) op: `dump hash default proc`, `default proc`, `Marshal`,
  `rbpdf error`, `writeHTML`, `writeHTMLCell error`, `rbpdf transaction`,
  `pdf table header error`. Het dichtste is #12154 "Redmine pdf error if page
  contain table" (2012, gesloten, andere oorzaak).
- **Verandert iets in trunk het ontwerp?** r25047 verplaatste `ITCPDF` naar
  `itcpdf.rb`; daarom wijkt het bestandspad af tussen patch en GEOxyz.

---

# The problem

Exporting an issue to PDF fails with an internal error when its description
contains a table and a user attached to the issue has already had their roles
computed during the same request. The log shows:

    pdf: writeHTML: can't dump hash with default proc
    RBPDFError (RBPDF error: writeHTMLCell Error.)

RBPDF wraps a table header in a "no break" block. To be able to undo it when the
header does not fit on the page, `RBPDF#startTransaction` copies the whole PDF
object with `Marshal.load(Marshal.dump(self))` (`objclone`). `ITCPDF` keeps the
attachments it was given in `@attachments`, for `get_image_filename`. For an
issue that is `issue.attachments`, an association whose owner is the issue, so
Marshal walks the issue and every association loaded on it, including its author
and assignee. `User#membership` caches roles in `Hash.new {...}`, and so do
`projects_by_role` and `project_ids_by_role`. A hash with a default proc cannot
be marshaled, so as soon as one of those users carries such a cache, the export
fails.

Core itself fills that cache: `Issue#notified_users` calls `visible?(user)` on
the author and the assignee, and a non-admin's `allowed_to?` goes through
`roles_for_project`. Any plugin that does the same while showing an issue has
the same effect; that is how this was found, on an installation where every PDF
export of an issue with a table failed. The same applies to wiki pages
(`page.attachments`) and to the issue list PDF with descriptions.

Besides failing, the copy is pointless: the attachments are only read, never
changed by RBPDF, and deep-copying an issue's object graph for every table
header is wasted work.

# Why this belongs in core

The failing code is `Redmine::Export::PDF::ITCPDF`, a core class, and the
condition that triggers it can be produced by core's own `Issue#notified_users`.
A plugin can only work around it by monkey-patching `ITCPDF`, which is what an
affected installation has to do today.

# Proposed change

`ITCPDF` overrides `objclone`, the method `startTransaction` uses to copy the PDF
object. It takes `@attachments` out of the object while RBPDF copies it, puts
the original back afterwards, and gives the copy the same reference instead of
a marshaled one.

Giving the copy the reference matters. When the header does not fit,
`rollbackTransaction(true)` calls `destroy(true, true)`, which sets every
instance variable to `nil`, and then restores only the ones the copy carries.
Without `@attachments` on the copy, an inline image after a table that moved to
the next page would no longer be found.

| File | Change |
|---|---|
| `lib/redmine/export/pdf/itcpdf.rb` | `objclone` override, 10 lines plus a 2-line comment |
| `test/unit/lib/redmine/export/pdf_test.rb` | two tests |

**New setting / migration / gem / route / permission:** none.

**Translations:** none; the change has no user-visible text.

**Backward compatibility:** output is unchanged; only the transaction copy
differs, and only in `@attachments`. In RBPDF's disk-cache mode `objclone`
already makes a shallow `dup`, which shares `@attachments` anyway; the override
makes the memory mode behave the same for that one variable.

# Alternatives considered

**`marshal_dump` / `marshal_load` that leave `@attachments` out, plus a
`rollbackTransaction` override that restores it.** This works and was the first
candidate. It needs two overrides instead of one, and `marshal_dump` changes how
`ITCPDF` marshals everywhere, not only in the transaction copy. Overriding
`objclone` hooks exactly the one place RBPDF copies itself, and since the copy
then carries the reference, the existing `rollbackTransaction` restores it
without help.

**Store `attachments.to_a` instead of the association.** Does not help: each
record keeps its own loaded `container`, so Marshal still reaches the issue and
its users.

**Clear the users' role caches before exporting, or make those hashes
marshalable.** Treats one symptom. Any other default-proc hash, proc or IO object
reachable from an attachment breaks the export in the same way, and Marshal
still copies the whole issue graph for nothing.

# Tests

| Test | What it proves |
|---|---|
| `PdfTest#test_write_formatted_cell_with_table_should_not_marshal_attachments` | a table followed by an inline image of an attachment renders, after the author's roles were cached; the image is in the output |
| `PdfTest#test_write_formatted_cell_with_table_across_page_break_should_keep_attachments` | the same, with the header row straddling the page break so RBPDF rolls the transaction back and moves the table to page 2; the inline image after it is still found |

**Evidence (INV-8 — figures, not claims):**

- **full** suite with the patch: `tools/test-env.sh <worktree> bundle exec ruby bin/rails test:all` → see `status.md` "Bewijs" for the figures and the comparison with clean trunk
- `test/unit/lib/redmine/export/pdf_test.rb` with the patch: 7 runs, 53 assertions, 0 failures, 0 errors
- RuboCop 1.91.0 on both changed files: 0 offences (baseline at the merge base: 0)
- each new test red on the old code, by running it there: without the change both
  error with `RBPDFError: RBPDF error: writeHTMLCell Error.` (7 runs, 2 errors).
  With only half the change (the copy does not get `@attachments`), the second
  test errors and the first passes: that is what the second test is for.
  Probing the page position showed that RBPDF rolls back exactly once for
  `set_y` from 266 to 270, and not at all from 272 on; the test uses 270.
- Marshal is the cause, shown directly: `Marshal.dump(Issue.find(14).attachments)`
  succeeds, and after `issue.notified_users`, `issue.visible?(issue.author)` or
  `issue.author.roles_for_project(issue.project)` raises
  `TypeError: can't dump hash with default proc`
- patch applies to pristine `origin/master` r25262: yes; and to real trunk r25284: yes (`git apply --check`)
- `tools/check-patch-clean.sh`: PASS

# Live verification (G9)

Exercised in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`, with `verify/pdf-export-marshal-attachments.mjs`. The
instance runs a throwaway local plugin (never committed, `plugins/` is
gitignored) that does what core's notification code does, in
`IssuesController#show`:

```ruby
IssuesController.before_action(only: :show) { @issue&.notified_users unless params[:no_prime] }
```

Each run creates an issue with a CommonMark table and an inline image of an
attachment, assigned to the non-admin seed user (an admin's `allowed_to?` never
asks for roles), and exports it to PDF. The PDF is rendered to PNG with
`pdftoppm`; `pdfimages -list` showed the embedded image in every successful
export.

| Function | Screenshot | What it shows |
|---|---|---|
| The issue | `before-issue.png` | the table and the image on the issue page, unpatched trunk |
| PDF export, roles cached | `before-issue-pdf.png` | unpatched trunk: HTTP 500, `RBPDFError in Issues#show`, `writeHTMLCell Error`; the log has `TypeError (can't dump hash with default proc)` as the cause |
| PDF export, no roles cached | `before-issue-pdf-no-prime.png` | unpatched trunk: HTTP 200 and the right PDF, so it is the cached roles and not the content |
| The issue | `issue.png` | the same issue page, patched |
| PDF export, roles cached | `issue-pdf.png` | patched: HTTP 200, table and image in the PDF |
| PDF export, no roles cached | `issue-pdf-no-prime.png` | patched: HTTP 200, unchanged output |
| GEOxyz branch | `geoxyz-issue.png`, `geoxyz-issue-pdf.png`, `geoxyz-issue-pdf-no-prime.png` | the same three on `7.0-stable-GEOxyz` with the commit: HTTP 200 both ways |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| table header crossing a page break, then an inline image | none: covered by the second unit test | image still rendered after the rollback | as expected; red with only half the fix |
| export without cached roles | `before-issue-pdf-no-prime.png`, `issue-pdf-no-prime.png` | unchanged, 200 | 200 before and after |

Screenshots read, not just generated: yes. The before shot shows the Rails error
page with the `writeHTMLCell` frame; the after shots show the description table
with both rows and the "test" image under it, and the attachment listed under
Files.

# Anticipated objections

| Objection | Answer |
|---|---|
| Core alone does not do this in a PDF request; only plugins do. | Core's `Issue#notified_users` fills the cache, and so does any `visible?(user)` or `allowed_to?` on the author or assignee. A PDF rendered in the same request or job as such a call (a plugin, a mail hook, a custom export) fails. The test uses `roles_for_project` directly to pin the condition. Either way the fix also stops Marshal deep-copying the issue's whole object graph for every table header, which is wasted work regardless of plugins. |
| Why not fix `User` so its caches marshal? | That repairs one object type. Anything else reachable from an attachment, now or later, breaks it again; the PDF writer should not depend on the marshalability of ActiveRecord graphs it only reads. |
| `objclone` is RBPDF internals. | It is public in RBPDF and is the single method `startTransaction` uses to copy the object. Overriding it is narrower than `marshal_dump`, which would change marshaling of `ITCPDF` everywhere. RBPDF has been stable here for years (1.21.x); the tests fail if a future version stops calling it. |
| The test depends on `set_y(270)`. | It needs the header row to straddle the bottom margin so RBPDF rolls back. The assertion `assert_equal 2, pdf.get_page` makes the test fail rather than pass silently if a font or margin change moves that point. |

---

## Submission

- **Issue:** nog niet aangemaakt
- **Patches attached:** `patches/pdf-export-marshal-attachments/2026-10-20-r25262-feature.patch` (code + tests; geen vertalingen, dus geen locales-patch)
- **Made against:** `origin/master` r25262 (2026-10-16); past ook op echte trunk r25284 (2026-10-20)
- **Status:** patch klaar
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** zie `status.md` (front matter `geoxyz_commit`)
- **Suites daar groen:** zie `status.md` "Bewijs"
- **`nl.yml` toegevoegd:** n.v.t., geen vertalingen
- **`tools/check-geoxyz-branch.sh`:** zie `status.md`
- **Wanneer kan deze commit vervallen?** Pas als GEOxyz naar de Redmine-release
  gaat die de geaccepteerde trunk-patch bevat (7.1 of later; Redmine backport
  features niet, maar dit is een defect: als een committer het naar 7.0-stable
  merget, vervalt de commit bij de eerste 7.0.x die het bevat).
