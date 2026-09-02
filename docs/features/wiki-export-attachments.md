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
- **Kans dat Redmine dit aanneemt:** redelijk. Twee dingen werken voor ons:
  Go MAEDA, die de ZIP-export zelf aanleverde, schreef in #43978 letterlijk
  dat hij bijlagen bewust wegliet omdat die "additional design questions"
  opwerpen, en noemde er drie — archiefstructuur, naamconflicten, en
  verwijzingen naar bijlagen in de tekst. Dit dossier beantwoordt alle drie.
  Wat ertegen werkt: het verandert de indeling van een export die op
  30 juni 2026 in 7.0.0 is uitgekomen, en daarmee twee bestaande tests. Dat
  moet vooraan in het issue staan, niet weggemoffeld.
- **Wat jij nog moet doen:** issue aanmaken op redmine.org als follow-up van
  #43978. De twee keuzes zijn beslist: geneste indeling altijd (K-02), en de
  bijlagen via het keuzevenster (2026-09-01).

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `2563fa6a5` = r24882 van 2026-08-03. De mirror
  liep op het moment van schrijven (2026-09-01) bijna een maand achter op de
  echte SVN-trunk; het issue moet die revisie noemen.
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
with the page source inside it. Redmine's own test wiki, which is three levels
deep, exports as:

    Another_page/Another_page.txt
    Another_page/Child_1/Child_1.txt
    Another_page/Child_1/Child_1_1/Child_1_1.txt
    Another_page/Child_2/Child_2.txt
    CookBook_documentation/CookBook_documentation.txt
    CookBook_documentation/Page_with_an_inline_image/Page_with_an_inline_image.txt

instead of the current six files in one directory. `wiki_page_directories`
walks the tree exactly as core's `render_page_hierarchy` does — same
`group_by(&:parent_id)`, same recursive signature — and reuses
`archived_wiki_page_filename` unchanged, so the sanitising and the `(n)`
de-duplication are the ones already there, applied per sibling group.

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

Attachments are opt-in rather than always included because their total size is
checked against `Setting.bulk_download_max_size`, exactly as
`AttachmentsController#find_downloadable_attachments` does. Including them
unconditionally would make the wiki export fail outright for a project whose
attachments are large, where today it works. With the option unticked the
export is unaffected by that limit, which is the escape hatch that makes the
guard acceptable.

Attachment entries carry the attachment's `created_on` as their DOS and UT
timestamp, the same way page entries carry `updated_on`; the timestamp code is
lifted into a `zip_entry` helper so both use it. That extraction is the only
existing code this patch moves.

| File | Change |
|---|---|
| `app/controllers/wiki_controller.rb` | include `ActionView::Helpers::NumberHelper`; `format.zip` honours `with_attachments` and checks the bulk-download size; `wiki_pages_to_zip` now builds the nested archive; new private `wiki_page_attachments`, `wiki_attachments_too_big?`, `wiki_page_directories`, `zip_entry` and `archived_attachment_filename` |
| `app/views/wiki/_export_options.html.erb` | new: the export-options dialog, shared by both index views |
| `app/views/wiki/index.html.erb` | the `ZIP` link opens the dialog; render the partial |
| `app/views/wiki/date_index.html.erb` | the same |
| `config/locales/en.yml` | one new key |
| `config/locales/{nl,fr,de,es}.yml` | the same key, translated (second patch file) |
| `test/functional/wiki_controller_test.rb` | eleven new tests; `test_export_to_zip` and `test_export_to_zip_should_sanitize_non_portable_entry_name_characters` updated for the new entry paths |

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
what it was. Two existing tests assert the old flat paths and are updated with
that reasoning, rather than being relaxed.

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

**Filtering attachments by `visible?`.** Not done, for the same reason
`Attachment.archive_attachments` does not: the controller has already
authorised the request through `:export_wiki_pages` on this project, and the
existing export already hands the full text of every page in the wiki to the
same user. `readable?` is still applied, which is what keeps a row whose file
is missing from disk out of the archive and out of `File.binread`.

# Tests

| Test | What it proves | Red on the old code? |
|---|---|---|
| `test_export_to_zip` *(existing, updated)* | every page entry is at the path its place in the hierarchy dictates, with the DOS and UT timestamps unchanged | yes — it asserted the flat path |
| `test_export_to_zip_should_sanitize_non_portable_entry_name_characters` *(existing, updated)* | `Foo*` still becomes `Foo_`, now as `Foo_/Foo_.txt` | yes — it asserted the flat path |
| `test_export_to_zip_should_nest_pages_by_hierarchy` | a page three levels deep lands three levels deep: `Another_page/Child_1/Child_1_1/Child_1_1.txt` | yes |
| `test_export_to_zip_with_attachments` | the attachment lands in the page's own directory with the right bytes and its `created_on` as timestamp, and the page source is in that same directory | yes |
| `test_export_to_zip_with_attachments_should_rename_duplicate_attachment_filenames` | two attachments with the same filename on one page both survive, the second as `name(1).ext` | yes |
| `test_export_to_zip_with_attachments_should_be_denied_when_total_size_exceeds_maximum` | over `bulk_download_max_size` the user is redirected with the existing error and no archive is sent | yes |
| `test_index_should_show_zip_export_options` | the ZIP link opens the dialog, and the dialog's form posts to the URL the export actually answers with the checkbox the controller actually reads | yes |
| `test_date_index_should_show_zip_export_options` | the dialog is on both index views, not only one | yes |
| `test_export_to_zip_should_not_include_attachments_by_default` | no attachments without the option | no, by design — a regression guard |
| `test_export_to_zip_with_attachments_set_to_zero_should_not_include_attachments` | an unticked checkbox means no | no, same reason |
| `test_export_to_zip_should_be_allowed_when_bulk_download_max_size_is_exceeded` | the source-only export still works when the attachment limit is zero — the thing that makes the option worth having | no, same reason |
| `test_index_should_not_show_zip_export_options_without_permission` | the dialog is gated by `:export_wiki_pages` like the links | no — trivially true before |

Eight of the twelve are red without the change, including the two existing
tests, which is the honest signal that behaviour deliberately moved. The other
four are regression guards on behaviour that must not move.

**Evidence (INV-8 — figures, not claims):**

- wiki suite on `patch/wiki-export-attachments`: **111 runs, 645 assertions,
  0 failures, 0 errors** (`test/functional/wiki_controller_test.rb`).
- RuboCop on the changed Ruby files: **0 offences**; baseline on the same files
  at the merge base: **0 offences**.
- patch applies to pristine `origin/master` r24882: **yes**, each of the two
  files on its own, and together they reproduce the branch exactly.
- `tools/check-patch-clean.sh`: **PASS** (7 checks).
- **full** `test:all` on both branches: being re-measured on this build; the
  figures land in the next commit.

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`: a wiki with `Wiki` as root and `Child_one` and `Child_two`
under it, `notes.txt` attached to `Wiki`, and two attachments both named
`diagram.txt` on `Child_one` — the collision case. Screenshots in
`docs/features/wiki-export-attachments/shots/`, the archives next to them.
**Every archive below was produced by clicking through the interface**, not by
calling the controller.

| Function | Screenshot | What it shows |
|---|---|---|
| The export line before | `before-wiki-index.png` | `Also available in: PDF \| HTML \| ZIP \| Atom` |
| The export line after | `wiki-index.png` | unchanged — still one `ZIP` entry, which is the point of the dialog |
| The dialog, opened by clicking ZIP | `zip-export-dialog.png` | "ZIP export options" with one checkbox, "Include attachments", plus Export and Cancel |
| The dialog with the box ticked | `zip-export-dialog-checked.png` | the state the second download was made from |
| Same dialog in Dutch | `nl-zip-export-dialog.png` | "ZIP export opties", "Bijlagen meesturen", "Exporteren", "Annuleren" — three of the four from keys that already existed |
| Same line on the date index | `wiki-date-index.png` | the dialog is on both index views |

Exported by clicking Export with the box **unticked**
(`zip-without-attachments.zip`):

    Wiki/Wiki.txt
    Wiki/Child_one/Child_one.txt
    Wiki/Child_two/Child_two.txt

and with the box **ticked** (`zip-with-attachments.zip`):

    Wiki/Wiki.txt
    Wiki/notes.txt
    Wiki/Child_one/Child_one.txt
    Wiki/Child_one/diagram.txt
    Wiki/Child_one/diagram(1).txt
    Wiki/Child_two/Child_two.txt

The hierarchy is mirrored in both, each page's attachments sit beside its own
source, and both `diagram.txt` uploads survive with the second renamed.

Failure paths verified:

| Case | Evidence | Expected | Observed |
|---|---|---|---|
| Over `bulk_download_max_size`, box ticked | `shots/size-limit-error.png` | refused, not truncated | redirected to the wiki index with Redmine's own `error_bulk_download_size_too_big` banner |
| Same limit, box unticked | `zip-without-attachments-at-limit-zero.zip` | unaffected | `cmp`-identical to the normal source-only archive — the escape hatch works |
| `:export_wiki_pages` absent | `shots/no-permission-wiki-index.png` | no export links and no dialog | as user `dev` with the permission removed: `Also available in: Atom` only |
| Direct URL without the permission | logged | 403 | `GET /projects/geoxyz-verify/wiki/export.zip?with_attachments=1` → **HTTP 403** |

Screenshots read, not just generated: yes, and the click matters here. The
verification script fails if `#zip-export-options` does not become visible
within five seconds of clicking the link, because a dialog that is in the DOM
but never opens is precisely the defect this gate exists for — the 2026 port
shipped a link that passed `assert_select` and did nothing when clicked. Both
downloads were then taken from the open dialog by pressing its Export button.

An earlier verification run of this feature produced an archive with **no**
attachments even though the link rendered and every test passed: the dev
database is shared between worktrees but `files/` is not, so
`Attachment#readable?` was silently false for every attachment. Fixed in
`tools/dev-server.sh`.

# Found but not fixed

Reported, not touched — INV-1.

- **`page.content.text` in `wiki_pages_to_zip` has no nil guard.** A
  `WikiPage` only `validates_associated :content`, so a page row without
  content is possible and would raise `NoMethodError` during the ZIP export.
  This is trunk's existing line, not one this patch adds, and the HTML export
  template has the same shape. Left alone.
- **Trunk r24882 fails 29 repository tests on a machine without the SCM client
  binaries; `7.0-stable` fails none.** Cause: trunk added
  `Setting.enabled_scm` (`app/models/setting.rb`), which filters the setting
  through `Repository.repository_class(scm_name)&.scm_available`. On
  `7.0-stable` that reader does not exist and `Repository::Subversion` stays
  valid. Confirmed by running the same five test files on both branches: 27
  failures + 2 errors on trunk, 0 on `7.0-stable`. Setting
  `scm_subversion_path_regexp` does not help, so it is the missing binary and
  not the new `path_regexp` condition that bites here. Whether Redmine intends
  this (their CI has the clients installed) is theirs to say; worth mentioning
  on redmine.org separately if Jan wants to.

# Anticipated objections

| Objection | Answer |
|---|---|
| "This changes the ZIP layout that shipped in 7.0.0." | It does, deliberately, and that is the decision being asked for. The flat layout discards the page tree, which Redmine has and the archive cannot reconstruct. The feature is two months old in a stable release, and trunk targets a feature release. If the answer is no, the same work fits behind a second link instead, at the cost of two shapes for one format. |
| "Two existing tests had to change." | Yes: `test_export_to_zip` and `test_export_to_zip_should_sanitize_non_portable_entry_name_characters` assert the flat entry paths. They are updated to the new paths, not relaxed — the first still asserts the full path per page, the DOS timestamp and the UT timestamp, and the second still asserts that `Foo*` is sanitised and that the unsanitised name is absent. |
| "Attachments were left out of #43978 on purpose." | Because of three named design questions, not because they are unwanted; the same comment calls the source-only export useful "even without attachments". Archive structure: the wiki hierarchy. Filename collisions: the existing `(n)` scheme, per directory, so two pages can each have a `diagram.png`. Attachment references in content: the next row. |
| "What happens to `!diagram.png!` in the exported source?" | It resolves. The source is exported raw, exactly as now — this patch rewrites nothing — but the attachment is written next to the page file, which is where a bare-filename reference looks. |
| "Why an option rather than always including attachments?" | `bulk_download_max_size`. With attachments always in, a project whose files exceed the limit could not export its wiki at all, where today it can. Verified: with the limit at 0 the source-only export still produces exactly the normal archive. |
| "Why a dialog rather than a second link?" | It keeps one entry per format in "Also available in", and it is the pattern core already uses for CSV in six views, down to `label_export_options` and `button_export`, which are already translated in every language. It also leaves room for a further option later without touching the export line again. |
| "A ZIP with attachments can be huge." | It is bounded by `bulk_download_max_size`, the setting Redmine already applies to every other bulk download. |
| "It builds the whole archive in memory." | So does the current `wiki_pages_to_zip`, and so does `Attachment.archive_attachments`; `Zip::OutputStream.write_buffer` returns a `StringIO`. The difference is that the size is now bounded by a setting where the existing wiki ZIP is bounded by nothing. Streaming would be a worthwhile change to all three call sites and does not belong here. |
| "Why move the timestamp code?" | Attachment entries need the same treatment and duplicating ten lines to get it would be worse. The extraction is behaviour-preserving and is covered by `test_export_to_zip`, which still asserts the DOS and UT times of page entries. |

---

## Submission

- **Issue:** nog aan te maken door Jan — follow-up van
  [#43978](https://www.redmine.org/issues/43978)
- **Patches attached:** `patches/wiki-export-attachments/2026-09-01-r24882-feature.patch` (code + `en.yml`) en `-locales.patch` (`nl`, `fr`, `de`, `es`)
- **Made against:** `origin/master` r24882 (2026-08-03)
- **Status:** nog niet ingediend — wacht op Jan
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `8716ee8c8` — de branch had nul eigen
  commits en heeft er nu één. Eerst bijgewerkt naar upstream `7.0-stable`
  (`a7fe622f9` → `ffc731ed7`, fast-forward).
- **Suites daar groen:** ja, volledig — `test:all` met systeemtests erbij:
  5919 runs, 31716 assertions, 0 failures, 0 errors, 39 skips.
- **`nl.yml` toegevoegd:** ja, en `fr`, `de`, `es` — identiek aan de patch
  (INV-10).
- **`tools/check-geoxyz-branch.sh`:** PASS
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus: pas als GEOxyz naar de release gaat
  die deze wijziging bevat (7.1 op zijn vroegst).
