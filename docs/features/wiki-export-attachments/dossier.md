# wiki-export-attachments — page attachments inside the wiki ZIP export

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** Redmine 7.0 kan de hele wiki al als ZIP
  downloaden, maar gooit daarbij de mappenstructuur weg: alle pagina's komen
  als losse bestanden in één map te liggen. Deze wijziging geeft de wikiboom
  terug, elke pagina in haar eigen map onder haar ouder. En in het
  keuzevenster dat bij de ZIP-link hoort kan je aanvinken dat de bijlagen
  meegaan; die belanden dan naast hun eigen paginatekst, zodat een verwijzing
  als `!diagram.png!` gewoon werkt als je het archief uitpakt.
- **Waar het vandaan komt:** 5.1-commit `3c3e9368e` (de ZIP-helft; de
  TXT-helft is vervallen, zie K-03)
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen — de GEOxyz-branch krijgt exact
  hetzelfde ontwerp
- **Ronde 2 (2026-09-05):** de review van 2026-09-03 vond twee echte fouten
  en tien kleinere punten; alle twaalf zijn afgewerkt volgens jouw keuzes g03,
  g04, g14, g16c en g18. De grootste: een bijlage die net zo heette als de
  pagina (`Wiki.txt` op pagina `Wiki`) overschreef stil de paginatekst in het
  archief, en een bijlage die heette als een kindpagina botste met de map van
  dat kind. Beide zijn nagespeeld in een echte browser, vóór en na de fix; de
  twee archieven staan naast dit dossier. Verder is de archiefopbouw naar
  `lib/redmine/export/` verhuisd (g16c), is de branch opnieuw opgebouwd uit
  het gekozen ontwerp (g04), en zijn alle cijfers opnieuw gedraaid tegen trunk
  r25037.
- **Kans dat Redmine dit aanneemt:** redelijk. Twee dingen werken voor ons:
  Go MAEDA, die de ZIP-export zelf aanleverde, schreef in #43978 letterlijk
  dat hij bijlagen bewust wegliet omdat die "additional design questions"
  opwerpen, en noemde er drie — archiefstructuur, naamconflicten, en
  verwijzingen naar bijlagen in de tekst. Dit dossier beantwoordt alle drie,
  en het naamconflict is nu ook echt gedekt voor het geval dat de nieuwe
  indeling zelf creëert. Wat ertegen werkt: het verandert de indeling van een
  export die op 30 juni 2026 in 7.0.0 is uitgekomen, en daarmee twee bestaande
  tests. Dat moet vooraan in het issue staan, niet weggemoffeld.
- **Wat jij nog moet doen:** issue aanmaken op redmine.org als follow-up van
  #43978. De keuzes zijn beslist: geneste indeling altijd (K-02), de bijlagen
  via het keuzevenster (2026-09-01), geen extra zichtbaarheidscontrole (g14),
  archiefopbouw in `lib/` (g16c).

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `bee32a926` = r25037 van 2026-09-03; de patch
  is daartegen gemaakt en ververst. De eerste versie (2026-09-01) stond op
  r24882; tussen die twee raakt trunk `wiki_controller.rb` alleen met #44228
  (de `\x00` in de sanitizer), en dat overleeft de patch omdat die regel
  ongewijzigd meeverhuist.
- **Lost trunk dit al op?** deels. `WikiController#export` heeft sinds
  r24605 (#43978, Go MAEDA, 2026-04-24) een `format.zip` die via
  `wiki_pages_to_zip` één `<titel>.txt` per pagina in een platte ZIP zet, met
  `updated_on` als DOS- én UT-tijdstempel en een `(n)`-suffix bij
  naamconflicten. Bijlagen zitten er niet in. De GEOxyz-implementatie uit 5.1
  bestond nog vóór die trunk-feature en bouwde een tweede, eigen ZIP naast de
  bestaande export; dat is hier vervangen door voortbouwen op wat er staat.
- **Bestaand issue op redmine.org?** #43978 (Closed, in 7.0.0) is de directe
  aanleiding. Gezocht op: "wiki export ZIP attachments", "wiki export
  hierarchy", "export all wiki pages". Verwant maar niet hetzelfde: #550
  (whole-wiki export, gesloten), #5000, #16323 (markdown-export per pagina).
  Geen open issue gevonden dat bijlagen in de wiki-ZIP vraagt.
- **Verandert iets in trunk het ontwerp?** ja, ingrijpend. Het ontwerp is
  hierdoor niet "een nieuwe actie `export_attachments`" (5.1) maar "een
  parameter op de bestaande `export`-actie", en het hergebruikt
  `archived_wiki_page_filename` in plaats van een eigen sanitizer.

---

# The problem

Since #43978, Redmine can export a whole wiki as a ZIP archive of raw page
sources. That is enough to move page text out of Redmine, but a wiki is rarely
only text: pages carry attachments, and a Redmine wiki that documents a process
usually carries the diagrams, spreadsheets and scans that the text refers to.
Those files are not in the archive, and there is no bulk way to get them out.

Today an administrator who wants a complete offline copy of a project wiki has
to take the ZIP for the text and then walk the wiki page by page, using the
per-page "Download all files" link on each one. For a wiki of any size that is
not practical, and the result has no relation between a page and its files
beyond whatever the person doing it invents.

Go MAEDA said as much when contributing the ZIP export: "This patch
intentionally focuses on exporting Wiki page source only. Even without
attachments, it is already useful", and "Including attachments would introduce
additional design questions" — naming archive structure, filename collisions,
and attachment references in wiki content. This change answers those three
questions and completes the export.

# Why this belongs in core

The archive is built by a private method of `WikiController`
(`wiki_pages_to_zip`) that a plugin can only reach by reopening the controller
and replacing it wholesale, which would break on the next core change to that
method. The link that triggers it is rendered inside the `other_formats_links`
block of two core views, which a plugin can only extend by patching the view or
by a hook that does not exist there. And the size guard belongs on the same
setting (`bulk_download_max_size`) that core already applies to every other
bulk download, which a plugin has no clean seam to participate in.

There is also a consistency argument: the wiki is the last attachment container
in Redmine without a bulk download of its files. Issues, documents, versions,
messages and projects all have one through `AttachmentsController#download_all`.

# Proposed change

Behaviour, in two parts.

**The archive mirrors the wiki.** One directory per page, nested by parent,
with the page source inside it. Redmine's own test wiki (eight pages, three
levels deep) exports as:

    Another_page/Another_page.txt
    Another_page/Child_1/Child_1.txt
    Another_page/Child_1/Child_1_1/Child_1_1.txt
    Another_page/Child_2/Child_2.txt
    CookBook_documentation/CookBook_documentation.txt
    CookBook_documentation/Page_with_an_inline_image/Page_with_an_inline_image.txt
    Page_with_sections/Page_with_sections.txt
    Этика_менеджмента/Этика_менеджмента.txt

instead of the current eight files in one directory. The tree is walked from
`pages.group_by(&:parent_id)` with the same recursive shape as core's
`render_page_hierarchy`, in the order the `pages` association already applies
(`LOWER(title)`), and reuses `archived_wiki_page_filename` unchanged, so the
sanitising and the `(n)` de-duplication are the ones already there, applied per
sibling group. A page whose parent is not among the exported pages is written
at the archive root rather than dropped, so every page given appears exactly
once whatever collection a caller passes.

**Attachments are an option on the export.** The `ZIP` entry in "Also
available in" now opens the export-options dialog that Redmine already uses for
CSV in six places, with one checkbox:

    ZIP export options
      [ ] Include attachments
                             [ Export ]  Cancel

Ticked, each page's readable attachments are written into that page's own
directory, next to its source:

    Wiki/Wiki.txt
    Wiki/notes.txt
    Wiki/Child_one/Child_one.txt
    Wiki/Child_one/diagram.txt
    Wiki/Child_one/diagram(1).txt

That placement is the point. Redmine wiki syntax refers to an attachment by
bare filename — `!diagram.png!` in Textile, `![](diagram.png)` in Markdown —
so a file next to its source resolves in any editor once the archive is
unpacked, without this patch rewriting a single character of the exported
source.

**One namespace per directory.** Putting a page's source and its attachments
in one directory creates a collision the flat layout never had: an attachment
may be called `<PageTitle>.txt`, which is the name of the page source file, or
may be called after a child page, which is the name of that child's directory.
Both are ordinary user input, not attacks. The list of names an attachment is
renamed against therefore starts with the page source file and the child page
directory names before the first attachment is looked at, so `Wiki.txt` on page
`Wiki` becomes `Wiki/Wiki(1).txt` and an extension-less `Child_one` becomes
`Wiki/Child_one(1)`, while the page source and the child directory keep their
paths. The renaming is the `(n)` rule Redmine already applies in
`Attachment.archive_attachments`.

Attachments are opt-in rather than always included because their total size is
checked against `Setting.bulk_download_max_size`, exactly as
`AttachmentsController#find_downloadable_attachments` does. Including them
unconditionally would make the wiki export fail outright for a project whose
attachments are large, where today it works. With the option unticked the
export is unaffected by that limit, which is the escape hatch that makes the
guard acceptable.

Attachment entries carry the attachment's `created_on` as their DOS and UT
timestamp, the same way page entries carry `updated_on`.

**Where the code lives.** The archive construction is
`Redmine::Export::ZIP::WikiZipHelper` under `lib/redmine/export/zip/`, the
place and the shape of `Redmine::Export::PDF::WikiPdfHelper` and
`Redmine::Export::Text::VersionsTextHelper`; the controller includes it next to
`Redmine::Export::PDF`. Two pieces of existing code move there, unchanged:
`wiki_pages_to_zip` and `archived_wiki_page_filename` from #43978. Two more are
extracted so that page and attachment entries share them: the DOS/UT timestamp
code becomes `zip_entry`, and the `(n)` rename loop in
`Attachment.archive_attachments` becomes `Attachment#archived_filename`, which
`archive_attachments` and the wiki export both call. `ZIP` is registered as an
acronym in `config/initializers/zeitwerk.rb`, like `PDF` and `CSV`, which is
also what keeps the new namespace from shadowing the `Zip` gem. What stays in
the controller is the decision, not the construction: reading the parameter,
selecting readable attachments and applying the size limit, as
`AttachmentsController` does for `download_all`.

| File | Change |
|---|---|
| `lib/redmine/export/zip/wiki_zip_helper.rb` | new: `wiki_pages_to_zip` (nested, with attachments), `wiki_page_directories`, `zip_entry`, and `archived_wiki_page_filename` moved from the controller |
| `app/controllers/wiki_controller.rb` | include the helper and `ActionView::Helpers::NumberHelper`; `format.zip` honours `with_attachments` and checks the bulk-download size; new private `wiki_page_attachments` and `wiki_attachments_too_big?`; the two archive methods move out |
| `app/models/attachment.rb` | `archived_filename` extracted from `archive_attachments`, which now calls it |
| `config/initializers/zeitwerk.rb` | `'zip' => 'ZIP'` |
| `app/views/wiki/_export_options.html.erb` | new: the export-options dialog, shared by both index views |
| `app/views/wiki/index.html.erb` | the `ZIP` link opens the dialog; render the partial |
| `app/views/wiki/date_index.html.erb` | the same |
| `config/locales/en.yml` | one new key |
| `config/locales/{nl,fr,de,es}.yml` | the same key, translated (second patch file) |
| `test/functional/wiki_controller_test.rb` | twelve new tests; `test_export_to_zip` and `test_export_to_zip_should_sanitize_non_portable_entry_name_characters` updated for the new entry paths |
| `test/unit/attachment_test.rb` | one test for `archived_filename` |
| `test/unit/lib/redmine/export/zip/wiki_zip_helper_test.rb` | new: one test for the helper on a subset of pages |

**New setting / migration / gem / route / permission:** none. The route is the
existing `GET /projects/:project_id/wiki/export` with `format=zip`; the flag
travels as a query parameter, so `config/routes.rb` is untouched. The
permission is the existing `:export_wiki_pages`. The size limit reuses the
existing `bulk_download_max_size` setting, which is what it is for. `rubyzip`
is already a dependency, used by the export this builds on.

**Translations** (INV-5 — every row names the existing key it was patterned on):

| Key | en | nl | fr | de | es | Patterned on |
|---|---|---|---|---|---|---|
| `label_include_attachments` | Include attachments | Bijlagen meesturen | Inclure les pièces jointes | Mit Anhängen | Incluir los adjuntos | en: `error_bulk_download_size_too_big` ("These attachments…"); nl: `label_edit_attachments` ("Bijlagen bewerken") for the noun and the noun-verb order; fr: verb from `setting_show_status_changes_in_mail_subject` ("Inclure les…"), noun from `error_bulk_download_size_too_big` ("Ces pièces jointes"); de: form from `label_cross_project_descendants` ("Mit Unterprojekten"), noun from `label_copy_attachments` ("Anhänge kopieren"); es: verb from `field_searchable` ("Incluir en las búsquedas"), noun from `label_copy_attachments` ("Copiar adjuntos") |

That is the **only** new string. The dialog's title comes from the existing
`label_export_options`, which is already parameterised by format
(`"%{export_format} export options"` → "ZIP export options"), and the button
from the existing `button_export`. Both are already translated in all five
languages, so the dialog needs no new wording beyond the checkbox.

**Backward compatibility:** this deliberately changes the entry paths of the
ZIP export that shipped in Redmine 7.0.0 on 30 June 2026, and that is the main
thing a reviewer has to agree with. A script that reads `Child_1.txt` will have
to read `Another_page/Child_1/Child_1.txt`. Nothing else moves: no setting
changes meaning, no stored data is touched, the filename of the archive is the
same, the timestamps are the same, and the source of each page is byte for byte
what it was. `Attachment.archive_attachments` produces exactly the archive it
produced before; its three existing tests pass against the extracted method.
Two existing tests assert the old flat paths and are updated with that
reasoning, rather than being relaxed.

The case for accepting that cost: the flat layout throws away structure Redmine
holds and cannot be reconstructed from the archive, the feature is two months
old in a stable release so few installations can depend on it yet, and trunk
targets a feature release where this kind of refinement belongs.

# Alternatives considered

**A separate `export_attachments` action, as GEOxyz has on 5.1.** That is what
the original GEOxyz change did, because it predates #43978 and had nothing to
build on. Against it: a new route, a second entry in the permission map, a
duplicated ZIP builder, and two archives a user has to merge by hand.

**Keeping the flat layout and adding a second `ZIP with attachments` link.**
Fully backward compatible, one click instead of two, and it was built and
verified before being rejected. Two things sank it. The archive then has two
shapes behind one action, which is hard to justify and was the heaviest
objection anticipated against it. And with the flat layout the attachment does
not sit next to the source that refers to it, so `!diagram.png!` still does not
resolve, leaving the third of #43978's design questions unanswered.

**Nesting only when attachments are included.** The intermediate position:
flat when text-only, nested when attachments are asked for. Rejected for the
same reason — one action, two shapes — and because the hierarchy is worth
preserving on its own, independently of attachments.

**Including attachments unconditionally**, so there is no option at all.
Rejected because `bulk_download_max_size` would then be able to make the wiki
export fail entirely for a project whose attachments are large, with no way for
a user to get the source out. The option is what keeps that guard from being a
regression.

**A setting instead of a per-export option.** Rejected: a global setting cannot
express "this time without the files", it is permanent API surface and
translation burden for one boolean, and it does not answer the size problem
either.

**Naming every page file `page.txt` inside its directory**, which is what the
GEOxyz 5.1 code does. Rejected: every tab in an editor then reads "page.txt"
and the title is thrown away. The page file is named after its own directory.

**`Another_page.txt` beside a directory `Another_page/` holding only the
children**, which is how some markdown wikis lay out a tree and avoids the
repeated name. Rejected because the attachments of `Another_page` would then
sit among its children rather than beside its own source, which breaks the
reference-resolving property the whole layout exists for.

**Leaving the archive code in `WikiController`, where #43978 put it.** The
smaller diff, and following the file you edit is normally right. Rejected
because the block grows from two private methods to six, including a recursive
tree walk and ZIP timestamp encoding, and Redmine keeps that under
`lib/redmine/export/` — the PDF export of this same controller is the local
example. Moving trunk's two methods along is the one place this patch touches
lines the feature did not strictly need to touch; the alternative is the same
request arriving as review feedback, with a second verification round.

**A second copy of the attachment rename loop in the wiki export.** Fourteen
lines, no change to `Attachment`. Rejected because core would then own the same
algorithm twice, and the fix for the collision case would have to be made in
one copy and not the other. Extracting `Attachment#archived_filename` is
behaviour-preserving, and the existing `archive_attachments` tests prove it.

**A visibility check on the attachments, as `download_all` has.**
`AttachmentsController#find_downloadable_attachments` calls
`attachments_visible?` on the container before `archive_attachments`; the wiki
export does not, and that is deliberate. Within a project Redmine has no
per-page read right: `WikiPage#visible?` and `WikiPage#attachments_visible?`
both resolve to `:view_wiki_pages` on the project, the export already requires
`:export_wiki_pages` on that same project, and the existing export already
hands that user the full text of every page. A role granted export without view
is a misconfiguration, not a boundary this action can defend, so the guard
would check the same project permission a second time under a different name.
`readable?` is still applied, which is what keeps a row whose file is missing
from disk out of the archive and out of `File.binread`.

# Tests

| Test | What it proves | Red on the old code? |
|---|---|---|
| `test_export_to_zip` *(existing, updated)* | the archive holds exactly the eight literal paths of the fixture wiki, each with the page's source and its DOS and UT timestamps unchanged | yes — it asserted the flat paths |
| `test_export_to_zip_should_sanitize_non_portable_entry_name_characters` *(existing, updated)* | `Foo*` still becomes `Foo_`, now as `Foo_/Foo_.txt` | yes — it asserted the flat path |
| `test_export_to_zip_should_nest_pages_by_hierarchy` | a page three levels deep lands three levels deep: `Another_page/Child_1/Child_1_1/Child_1_1.txt` | yes |
| `test_export_to_zip_with_attachments` | an attachment on the grandchild `Child_1_1` lands in `Another_page/Child_1/Child_1_1/` with the right bytes and its `created_on` as timestamp, and the page source is in that same directory | yes |
| `test_export_to_zip_with_attachments_should_rename_duplicate_attachment_filenames` | two attachments with the same filename on one page both survive, the second as `name(1).ext` | yes |
| `test_export_to_zip_with_attachments_should_rename_an_attachment_named_after_the_page` | an attachment `CookBook_documentation.txt` on that page becomes `CookBook_documentation(1).txt`, and the page source keeps its path and its text | yes |
| `test_export_to_zip_with_attachments_should_rename_an_attachment_named_after_a_child_page` | an attachment `Page_with_an_inline_image` becomes `Page_with_an_inline_image(1)`, and the child page's directory and source are intact | yes |
| `test_export_to_zip_with_attachments_should_be_denied_when_total_size_exceeds_maximum` | over `bulk_download_max_size` the user is redirected with the existing error and no archive is sent | yes |
| `test_index_should_show_zip_export_options` | the ZIP link opens the dialog, and the dialog's form posts to the URL the export actually answers with the checkbox the controller actually reads | yes |
| `test_date_index_should_show_zip_export_options` | the dialog is on both index views, not only one | yes |
| `test_export_to_zip_should_not_include_attachments_by_default` | no attachments without the option | no, by design — a regression guard |
| `test_export_to_zip_with_attachments_set_to_zero_should_not_include_attachments` | an unticked checkbox means no | no, same reason |
| `test_export_to_zip_should_be_allowed_when_bulk_download_max_size_is_exceeded` | the source-only export still works when the attachment limit is zero — the thing that makes the option worth having | no, same reason |
| `test_index_should_not_show_zip_export_options_without_permission` | the dialog is gated by `:export_wiki_pages` like the links | no — trivially true before |
| `AttachmentTest#test_archived_filename_should_rename_a_file_whose_name_is_already_taken` | given a list that already holds `testfile.txt` and `testfile(1).txt`, the method returns `testfile(2).txt` and adds it to the list | yes — `NoMethodError` |
| `WikiZipHelperTest#test_wiki_pages_to_zip_should_export_a_page_whose_parent_is_not_given_at_the_root` | exporting `Child_1` and `Child_1_1` without `Another_page` yields `Child_1/Child_1.txt` and `Child_1/Child_1_1/Child_1_1.txt` | yes — the module does not exist |

Ten of the fourteen functional tests are red on pristine trunk r25037 — run
with `-i /zip/` against the unchanged controller: **14 runs, 7 failures,
3 errors** — including the two existing tests, which is the honest signal that
behaviour deliberately moved. The other four are regression guards on
behaviour that must not move. Both unit tests are red on trunk as well.

Against the *first* version of this patch (2026-09-01, the one reviewed), the
two collision tests are the ones that are red — **14 runs, 1 failure,
1 error**: the page-file case errors because the `(1)` entry does not exist,
the child-page case fails with `CookBook_documentation/Page_with_an_inline_image`
present as a file. That is the pair of defects the review found, reproduced by
the tests before they were fixed.

**Evidence (INV-8 — figures, not claims):**

- touched suites together on `patch/wiki-export-attachments`
  (`test/functional/wiki_controller_test.rb`, `test/unit/attachment_test.rb`,
  `test/unit/lib/redmine/export/zip/wiki_zip_helper_test.rb`, one process):
  **173 runs, 814 assertions, 0 failures, 0 errors, 4 skips** (the skips are
  the ImageMagick and pandoc previews, absent from this image).
- RuboCop on the changed Ruby files (7 files): **0 offences**; baseline on the
  same files at `origin/master` r25037: **0 offences**.
- `bin/rails zeitwerk:check`: passes (the new namespace loads under eager
  loading, as production does).
- patch applies to pristine `origin/master` r25037: **yes**, each of the two
  files on its own, and together they reproduce the branch exactly
  (`tools/check-patch-clean.sh wiki-export-attachments`: **PASS**).
- **full** suite on `patch/wiki-export-attachments`
  (`tools/test-env.sh … bundle exec ruby bin/rails test:all`, system tests
  included): **5991 runs, 31764 assertions, 27 failures, 2 errors, 92 skips in 875 s**.
- **full** suite on pristine `origin/master` r25037 in the same image:
  **5977 runs, 31710 assertions, 27 failures, 2 errors, 92 skips in 855 s**. The 29 failing test names are identical on both runs (`diff` of the sorted lists is empty): all of them are the `Repository::Subversion` validation failures of an image without `svn`, `hg`, `bzr` or `cvs` (see "Found but not fixed"). The 14 extra runs on the patch are the 12 new functional tests and the 2 new unit tests.
- **full** suite on `7.0-stable-GEOxyz` with the same change, on the pushed tip `7006c4f00`:
  **6088 runs, 32244 assertions, 0 failures, 0 errors, 39 skips** in 889 s. Completely green.
- `tools/check-geoxyz-branch.sh`: merge with upstream, AI traces and locales **ok**; lint **1 offence**, `Rails/StrongParametersExpect` at `wiki_controller.rb:369`, which is an upstream line present in `origin/7.0-stable`, already reported on `origin/7.0-stable-GEOxyz` before this session, and not in the diff (baseline 1, after 1).

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`: a wiki with `Wiki` as root and `Child_one` and `Child_two`
under it, `notes.txt` attached to `Wiki`, and two attachments both named
`diagram.txt` on `Child_one` — the duplicate-name case. For round 2 the page
`Wiki` also got an attachment `Wiki.txt` (the name of its own source file) and
one called `Child_one` without extension (the name of a child page's
directory). Screenshots in `docs/features/wiki-export-attachments/shots/`, the
archives next to this dossier. **Every archive below was produced by clicking
through the interface**, not by calling the controller.

| Function | Screenshot | What it shows |
|---|---|---|
| The export line before | `before-wiki-index.png` | `Also available in: PDF \| HTML \| ZIP \| Atom` on unpatched trunk |
| The export line after | `wiki-index.png` | unchanged — still one `ZIP` entry, which is the point of the dialog |
| The dialog, opened by clicking ZIP | `zip-export-dialog.png` | "ZIP export options" with one checkbox, "Include attachments", plus Export and Cancel |
| The dialog with the box ticked | `zip-export-dialog-checked.png` | the state the download with attachments was made from |
| Same dialog in Dutch | `nl-zip-export-dialog.png` | "ZIP export opties", "Bijlagen meesturen", "Exporteren", "Annuleren" — three of the four from keys that already existed |
| Same line on the date index | `wiki-date-index.png` | the dialog is on both index views |
| The colliding attachments | `wiki-page-colliding-attachments.png` | page `Wiki` with its Files list open: `notes.txt`, `Wiki.txt` and `Child_one` |

Exported by clicking Export with the box **unticked**
(`zip-without-attachments.zip`):

    Wiki/Wiki.txt
    Wiki/Child_one/Child_one.txt
    Wiki/Child_two/Child_two.txt

and with the box **ticked** (`zip-with-attachments.zip`), after the round-2 fix:

    Wiki/Wiki.txt                 37 bytes — the page source
    Wiki/notes.txt
    Wiki/Wiki(1).txt              33 bytes — the attachment named after the page
    Wiki/Child_one(1)             51 bytes — the attachment named after the child page
    Wiki/Child_one/Child_one.txt
    Wiki/Child_one/diagram.txt
    Wiki/Child_one/diagram(1).txt
    Wiki/Child_two/Child_two.txt

`unzip -o` extracts all eight. The same export from the first version of the
patch, taken the same way a few minutes earlier
(`before-fix-zip-with-attachments.zip`), lists seven entries: `Wiki/Wiki.txt`
is the 33-byte attachment and the page's own source is gone, and
`Wiki/Child_one` is a file, so `unzip -o` exits 2 with

    checkdir error:  Wiki/Child_one exists but is not directory
                     unable to process Wiki/Child_one/Child_one.txt.

and the same for both `diagram*.txt`; four of the seven entries reach the disk.
That pair of archives is the collision answer made visible.

Failure paths verified:

| Case | Evidence | Expected | Observed |
|---|---|---|---|
| Over `bulk_download_max_size`, box ticked | `shots/size-limit-error.png` | refused, not truncated | redirected to the wiki index with Redmine's own `error_bulk_download_size_too_big` banner, "(0 Bytes)" |
| Same limit, box unticked | `zip-without-attachments-at-limit-zero.zip` | unaffected | `cmp`-identical to the normal source-only archive — the escape hatch works |
| `:export_wiki_pages` absent | `shots/no-permission-wiki-index.png`, `shots/no-permission-wiki-date-index.png` | no export links and no dialog | as user `dev` with the permission removed from Manager: `Also available in: Atom` only, on both index views |
| Direct URL without the permission | logged | 403 | `GET /projects/geoxyz-verify/wiki/export.zip?with_attachments=1` as `dev` → **HTTP 403** |

Screenshots read, not just generated: yes, and the click matters here. The
verification script fails if `#zip-export-options` does not become visible
within five seconds of clicking the link, because a dialog that is in the DOM
but never opens is precisely the defect this gate exists for — the 2026 port
shipped a link that passed `assert_select` and did nothing when clicked. Both
downloads were then taken from the open dialog by pressing its Export button,
and the collision archives were extracted with Info-ZIP, not only listed,
because a duplicate entry and a file/directory clash show up on disk and not in
`unzip -l`.

Two things the browser run taught, both now in `docs/traps.md`: the attachment
list on a wiki page is a collapsed fieldset, so a screenshot of the page shows
"Files (3)" and no names until the legend is clicked; and the dev database is
shared between worktrees but `files/` is not, so an attachment uploaded while
one worktree served the app is unreadable from the next one
(`tools/dev-server.sh` points every worktree at one storage directory).

# Found but not fixed

Reported, not touched — INV-1.

- **`page.content.text` in `wiki_pages_to_zip` has no nil guard.** A
  `WikiPage` only `validates_associated :content`, so a page row without
  content is possible and would raise `NoMethodError` during the ZIP export.
  This is trunk's existing line, moved along, and the HTML export template has
  the same shape. Left alone.
- **`Attachment#sanitize_filename` accepts a filename of exactly `..`.** It
  strips everything up to the last slash and replaces the forbidden
  characters, which turns `../../etc/passwd` into `passwd` but leaves a bare
  `..` intact, and `AttachmentsController#upload` assigns `params[:filename]`
  directly. Through this export the entry is `<Page>/..`, which cannot escape
  the archive and which Info-ZIP skips; through core's existing per-page
  "Download all files" the same attachment reaches the archive root as a bare
  `..`, which is the version that could. The gap is upstream of this patch and
  worth its own report; the nesting here makes the wiki export the safer of the
  two paths.
- **A `parent_id` cycle would recurse without end** in the tree walk, as it
  would in core's `render_page_hierarchy`. `validate_parent_title` refuses a
  page as its own ancestor, so no route to a cycle was found; a dangling
  `parent_id`, the reachable half of that family, is handled (the page is
  exported at the root).
- **Trunk fails 29 repository tests on a machine without the SCM client
  binaries; `7.0-stable` fails none.** Cause: trunk added
  `Setting.enabled_scm` (`app/models/setting.rb`), which filters the setting
  through `Repository.repository_class(scm_name)&.scm_available`. On
  `7.0-stable` that reader does not exist and `Repository::Subversion` stays
  valid. Setting `scm_subversion_path_regexp` does not help, so it is the
  missing binary and not the new `path_regexp` condition that bites. Whether
  Redmine intends this (their CI has the clients installed) is theirs to say;
  worth mentioning on redmine.org separately if Jan wants to.

# Anticipated objections

| Objection | Answer |
|---|---|
| "This changes the ZIP layout that shipped in 7.0.0." | It does, deliberately, and that is the decision being asked for. The flat layout discards the page tree, which Redmine has and the archive cannot reconstruct. The feature is two months old in a stable release, and trunk targets a feature release. If the answer is no, the same work fits behind a second link instead, at the cost of two shapes for one format. |
| "Two existing tests had to change." | Yes: `test_export_to_zip` and `test_export_to_zip_should_sanitize_non_portable_entry_name_characters` assert the flat entry paths. They are updated to the new paths, not relaxed — the first still asserts the complete set of entry paths as literals, the content, the DOS timestamp and the UT timestamp, and the second still asserts that `Foo*` is sanitised and that the unsanitised name is absent. |
| "Attachments were left out of #43978 on purpose." | Because of three named design questions, not because they are unwanted; the same comment calls the source-only export useful "even without attachments". Archive structure: the wiki hierarchy. Filename collisions: the next row. Attachment references in content: the row after. |
| "What about filename collisions?" | Three kinds, all handled by the one `(n)` rule core already has. Two attachments with the same name on one page: `diagram.txt`, `diagram(1).txt`, as `download_all` does today. Two pages on the same level whose titles sanitise to the same name: `archived_wiki_page_filename`'s existing suffix, now per sibling group. And the collision the nested layout itself creates — an attachment named after the page source (`Wiki.txt` on page `Wiki`) or after a child page's directory — is handled by seeding the name list with those two before any attachment is renamed, and is covered by two tests and by a before/after archive pair. Two pages in different branches may each have a `diagram.png` with no suffix at all, which the flat layout could not offer. |
| "What happens to `!diagram.png!` in the exported source?" | It resolves. The source is exported raw, exactly as now — this patch rewrites nothing — but the attachment is written next to the page file, which is where a bare-filename reference looks. |
| "Why an option rather than always including attachments?" | `bulk_download_max_size`. With attachments always in, a project whose files exceed the limit could not export its wiki at all, where today it can. Verified: with the limit at 0 the source-only export still produces exactly the normal archive. |
| "Why a dialog rather than a second link?" | It keeps one entry per format in "Also available in", and it is the pattern core already uses for CSV in six views, down to `label_export_options` and `button_export`, which are already translated in every language. It also leaves room for a further option later without touching the export line again. |
| "A ZIP with attachments can be huge." | It is bounded by `bulk_download_max_size`, the setting Redmine already applies to every other bulk download. |
| "It builds the whole archive in memory." | So does the current `wiki_pages_to_zip`, and so does `Attachment.archive_attachments`; `Zip::OutputStream.write_buffer` returns a `StringIO`. The difference is that the size is now bounded by a setting where the existing wiki ZIP is bounded by nothing. Streaming would be a worthwhile change to all three call sites and does not belong here. |
| "Why move code out of `WikiController`?" | Because the archive construction grows from two private methods to six, including a recursive tree walk and ZIP timestamp encoding, and Redmine keeps that under `lib/redmine/export/` — this controller already includes `Redmine::Export::PDF` for the same reason. The two methods from #43978 move unchanged; `git diff` shows them as deleted and added, `git show --color-moved` shows them as moved. The controller keeps what is a controller decision: the parameter, the readable filter and the size limit. |
| "Why touch `Attachment`?" | To avoid owning the `(n)` rename rule twice. `archived_filename` is the loop that was inside `archive_attachments`, and `archive_attachments` now calls it: same input, same output, ten lines shorter, its three existing tests untouched and green. The wiki export needs the same rule with a pre-seeded list, which is exactly what the extracted method takes. |
| "Why a Zeitwerk inflection?" | `lib/redmine/export/zip/` would otherwise autoload as `Redmine::Export::Zip`, and every `Zip::…` reference inside `Redmine::Export` would then resolve to that empty module instead of the gem. `'zip' => 'ZIP'` is the same treatment `pdf` and `csv` already get in the same initializer. |
| "The export does not check `attachments_visible?` like `download_all`." | Deliberately. Both `WikiPage#visible?` and `attachments_visible?` resolve to `:view_wiki_pages` on the project, and the export already requires `:export_wiki_pages` on that project and already hands the same user every page's text. There is no per-page read right inside a project for the guard to protect; a role with export but not view is misconfigured. `readable?` is still applied so a missing file cannot break the archive. |
| "Why move the timestamp code?" | Attachment entries need the same treatment and duplicating ten lines to get it would be worse. The extraction is behaviour-preserving and is covered by `test_export_to_zip`, which still asserts the DOS and UT times of page entries. |

---

## Submission

- **Issue:** nog aan te maken door Jan — follow-up van
  [#43978](https://www.redmine.org/issues/43978)
- **Patches attached:** `patches/wiki-export-attachments/2026-09-05-r25037-feature.patch` (code + `en.yml`) en `-locales.patch` (`nl`, `fr`, `de`, `es`)
- **Made against:** `origin/master` r25037 (`bee32a926`, 2026-09-03)
- **Status:** nog niet ingediend — wacht op Jan. Vóór het indienen:
  `tools/check-patch-clean.sh wiki-export-attachments --submit` (g05).
- **Feedback en wat ermee gebeurde:** interne review 2026-09-03
  (`docs/review/findings/2026-09-03-wiki-export-attachments-claude-opus5.md`,
  12 bevindingen) — alle twaalf afgewerkt op 2026-09-05, zie de
  `Resolution:`-regels daar.

## GEOxyz

- **Commits op `7.0-stable-GEOxyz`:** `28c618860` (2026-09-02, het ontwerp) en
  `7006c4f00` (2026-09-05, de ronde-2 fix). Twee commits, omdat de branch die
  GEOxyz draait nooit herschreven wordt; het registerveld wijst naar de
  laatste.
- **Suites daar groen:** 6088 runs, 32244 assertions, 0 failures, 0 errors, 39 skips in 889 s — volledig groen, gemeten op de gepushte tip.
- **`nl.yml` toegevoegd:** ja, en `fr`, `de`, `es` — identiek aan de patch
  (INV-10).
- **`tools/check-geoxyz-branch.sh`:** FAIL op lint alleen — 1 offence, `Rails/StrongParametersExpect` op `wiki_controller.rb:369`, een regel van upstream die al vóór deze sessie op `origin/7.0-stable-GEOxyz` faalde (baseline 1, na 1; niet in de diff); merge met upstream, AI-traces en locales: ok
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus: pas als GEOxyz naar de release gaat
  die deze wijziging bevat (7.1 op zijn vroegst).
