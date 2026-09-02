# wiki-export-attachments — page attachments inside the wiki ZIP export

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** Redmine 7.0 kan de hele wiki al als ZIP
  downloaden, maar alleen de tekst van de pagina's. Deze wijziging zet er een
  tweede link naast die dezelfde ZIP maakt mét de bijlagen erbij, in een
  mappenstructuur die de wikiboom volgt: elke pagina in haar eigen map, met
  haar bijlagen ernaast. Een afbeeldingsverwijzing in de tekst werkt daardoor
  gewoon als je het archief uitpakt.
- **Waar het vandaan komt:** 5.1-commit `3c3e9368e` (de ZIP-helft; de
  TXT-helft van diezelfde commit is een aparte regel in het register geworden,
  `wiki-export-txt`)
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen — de GEOxyz-branch krijgt exact
  hetzelfde ontwerp
- **Kans dat Redmine dit aanneemt:** goed — Go MAEDA, die de ZIP-export zelf
  in april 2026 heeft aangeleverd, schreef in #43978 letterlijk dat hij
  bijlagen bewust heeft weggelaten omdat die "additional design questions"
  opwerpen, en noemde er drie: archiefstructuur, naamconflicten, en verwijzingen
  naar bijlagen in de paginatekst. Dit dossier beantwoordt precies die drie.
- **Wat jij nog moet doen:** issue aanmaken op redmine.org als follow-up van
  #43978. De indelingskeuze (K-02) heb jij op 2026-09-01 beslist: geneste
  mappen, optie B.

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

Behaviour: the wiki index and the wiki date index gain a second entry in the
"Also available in" line, next to the existing `ZIP`, captioned "ZIP with
attachments". It points at the same `wiki#export` action and the same `zip`
format, with `with_attachments=1`.

With that parameter the archive is laid out as the wiki itself is: one
directory per page, nested by parent, with the page source and that page's
attachments inside it.

    Wiki/Wiki.txt
    Wiki/notes.txt
    Wiki/Child one/Child one.txt
    Wiki/Child one/diagram.png
    Wiki/Child one/diagram(1).png
    Wiki/Child two/Child two.txt

That layout is not cosmetic. Redmine wiki syntax refers to an attachment by
bare filename — `!diagram.png!` in Textile, `![](diagram.png)` in Markdown —
so putting the file next to the page source makes the reference resolve when
the archive is unpacked and opened in any editor. This is the third of the
design questions #43978 left open, and it is answered without touching the
exported source at all.

**Without the parameter nothing changes.** The existing flat export is not
merely compatible, it is byte-identical: the same `wiki_pages_to_zip` produces
it, and a download from a patched instance `cmp`s clean against a download from
a pristine trunk instance. The nested layout exists to hold attachments, so it
appears only when attachments are asked for.

Attachment entries carry the attachment's `created_on` as their DOS and UT
timestamp, the same way page entries carry `updated_on`. Two things are lifted
out of `wiki_pages_to_zip` so both layouts share them, `zip_entry` and
`write_zip`, and `archived_wiki_page_filename` gains a defaulted `extension`
argument so the directory names reuse its sanitising and its `(n)`
de-duplication unchanged. That is the whole of what this patch moves.

Before building the archive, the total size of the attachments to be included
is checked against `Setting.bulk_download_max_size`, exactly as
`AttachmentsController#find_downloadable_attachments` does, and the user is
redirected back to the wiki index with the existing
`error_bulk_download_size_too_big` message when it is exceeded. Because the
attachments are opt-in, a wiki whose attachments exceed the limit can still be
exported without them.

| File | Change |
|---|---|
| `app/controllers/wiki_controller.rb` | include `ActionView::Helpers::NumberHelper`; `format.zip` honours `with_attachments` and checks the bulk-download size; new private `wiki_page_attachments`, `wiki_attachments_too_big?`, `wiki_pages_with_attachments_to_zip`, `wiki_page_directories`, `write_zip`, `zip_entry` and `archived_attachment_filename`; `archived_wiki_page_filename` gains a defaulted `extension` argument |
| `app/views/wiki/index.html.erb` | one extra `f.link_to` in the existing `other_formats_links` block |
| `app/views/wiki/date_index.html.erb` | the same |
| `config/locales/en.yml` | one new key |
| `config/locales/{nl,fr,de,es}.yml` | the same key, translated (second patch file) |
| `test/functional/wiki_controller_test.rb` | eight new tests |

**New setting / migration / gem / route / permission:** none. The route is the
existing `GET /projects/:project_id/wiki/export` with `format=zip`; the flag
travels as a query parameter, so `config/routes.rb` is untouched. The
permission is the existing `:export_wiki_pages`. The size limit reuses the
existing `bulk_download_max_size` setting, which is what it is for. `rubyzip`
is already a dependency, used by the export this builds on.

**Translations** (INV-5 — every row names the existing key it was patterned on):

| Key | en | nl | fr | de | es | Patterned on |
|---|---|---|---|---|---|---|
| `label_export_zip_with_attachments` | ZIP with attachments | ZIP met bijlagen | ZIP avec les pièces jointes | ZIP mit Anhängen | ZIP con adjuntos | en: `error_bulk_download_size_too_big` ("These attachments…"); nl: `label_edit_attachments` ("Bijlagen bewerken"); fr: `error_bulk_download_size_too_big` ("Ces pièces jointes…"); de: `error_bulk_download_size_too_big` ("…dieser Anhänge…"); es: `label_copy_attachments` ("Copiar adjuntos") |

The obvious candidate, `label_download_all_attachments`, was not used as the
pattern: it is still untranslated in `nl.yml` and `es.yml` and carries a typo
in `de.yml` ("heruterladen"), so it establishes nothing. Each locale's own
attachment noun was taken from a key that is actually translated in that file.

**Backward compatibility:** total, and demonstrated rather than asserted.
Without `with_attachments` the response is byte-identical to today's: same
entry names, same order, same timestamps, same filename, same bytes. No
setting changes meaning, no stored data is touched, and an existing script that
fetches `export.zip` keeps getting exactly what it got.

# Alternatives considered

**A separate `export_attachments` action, as GEOxyz has on 5.1.** That is what
the original GEOxyz change did, because it predates #43978 and had nothing to
build on. Against it: a new route, a second entry in the permission map, a
duplicated ZIP builder, and two archives a user has to merge by hand. Building
on `wiki_pages_to_zip` gives one archive and no new API surface.

**Keeping the archive flat when attachments are included** —
`Child one.txt` at the root with the attachments in a sibling
`Child one/` directory. It has one real advantage: page entries then keep the
exact names they have today in both variants. It was rejected because the
attachment then does *not* sit next to the page source that refers to it, so
`!diagram.png!` still does not resolve, which leaves the third of #43978's
three design questions unanswered. The nested layout answers it for free, and
it costs nothing that matters: the flat export is still there, unchanged, on
the link that has always produced it.

**Nesting the plain ZIP as well**, so there is a single layout. Rejected: that
changes an export that shipped in 7.0.0 four months ago, for people who never
asked for attachments, and breaks any script that reads it. Two layouts behind
one action is a fair objection, and the answer is that the directory exists to
hold the attachments — with none to hold, it would be an empty wrapper around a
single file.

**Naming every page file `page.txt` inside its directory**, which is what the
GEOxyz 5.1 code does. Rejected: every tab in an editor then reads "page.txt"
and the title is thrown away. The page file is named after its own directory,
so `Child one/Child one.txt`.

**Including attachments unconditionally.** Simpler UI, no parameter, no second
link. Rejected because `bulk_download_max_size` would then be able to make the
wiki export fail entirely for a project whose attachments are large, which is a
regression against what works today.

**Filtering attachments by `visible?`.** Not done, for the same reason
`Attachment.archive_attachments` does not: the controller has already
authorised the request through `:export_wiki_pages` on this project, and the
existing export already hands the full text of every page in the wiki to the
same user. `readable?` is still applied, which is what keeps a row whose file
is missing from disk out of the archive and out of `IO.binread`.

**Hiding the new link when the wiki has no attachments.** It would need an
extra `EXISTS` query on every wiki index render to remove a link that is
harmless when the wiki has no files: it produces the same archive as the plain
ZIP. Not worth the query.

# Tests

| Test | What it proves | Red on the old code? |
|---|---|---|
| `test_export_to_zip_with_attachments` | attachment entries appear under a directory named after the page entry, with the right bytes and the attachment's `created_on` as timestamp | yes — `Expected nil to not be nil` |
| `test_export_to_zip_should_not_include_attachments_by_default` | the default archive is unchanged — the guarantee the whole design rests on | no, by design: it is a regression guard, and it passes before and after |
| `test_export_to_zip_with_attachments_set_to_zero_should_not_include_attachments` | `with_attachments=0` means no | yes — `Expected ["CookBook_documentation/testfile.txt"] to be empty` |
| `test_export_to_zip_with_attachments_should_rename_duplicate_attachment_filenames` | two attachments with the same filename on one page both survive, the second as `name(1).ext` | yes — the entry list has no directory in it |
| `test_export_to_zip_with_attachments_should_be_denied_when_total_size_exceeds_maximum` | over `bulk_download_max_size` the user is redirected with the existing error and no archive is sent | yes — `Expected response to be a <3XX: redirect>, but was a <200: OK>` |
| `test_index_should_show_export_link_for_zip_with_attachments` | the link is on the page, with the URL the export actually answers | yes — `found 0` |

**Evidence (INV-8 — figures, not claims):** de suites voor deze geneste versie
draaien nog. De cijfers hieronder horen bij de vorige, platte versie en worden
vervangen zodra beide runs klaar zijn. Niets in dit blok telt tot dat gebeurd
is.

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb` (a three-page wiki: `Wiki` with `Child_one` and
`Child_two`; `notes.txt` attached to `Wiki`, and two attachments both named
`diagram.txt` on `Child_one` — the collision case). Screenshots in
`docs/features/wiki-export-attachments/shots/`, the archives themselves next to
them.

| Function | Screenshot | What it shows |
|---|---|---|
| The export line before the change | `before-wiki-index.png` | `Also available in: PDF \| HTML \| ZIP \| Atom` |
| The export line after | `wiki-index.png` | `PDF \| HTML \| ZIP \| ZIP with attachments \| Atom` |
| Same on the date index | `wiki-date-index.png` | the link is on both index views, not only one |
| The translation is real | `nl-wiki-index.png` | `Exporteer naar PDF \| HTML \| ZIP \| ZIP met bijlagen \| Atom` |

The archive itself, downloaded by clicking the link in the browser, not by
calling the controller (`zip-with-attachments.zip`):

    Child_one.txt              43
    Child_one/diagram.txt      15
    Child_one/diagram(1).txt   31
    Child_two.txt              43
    Wiki.txt                   37
    Wiki/notes.txt             38

Both `diagram.txt` uploads survive, the second renamed. Page entries are
untouched.

Failure paths verified:

| Case | Evidence | Expected | Observed |
|---|---|---|---|
| Plain ZIP must not change | `zip-plain-before.zip` vs `zip-plain-after.zip` | identical | **byte-identical** (`cmp` clean) — the pristine-trunk download and the patched download are the same file |
| Over `bulk_download_max_size` | `shots/size-limit-error.png` | refused, not truncated | redirected to the wiki index with Redmine's own `error_bulk_download_size_too_big` banner |
| Plain ZIP still works at the limit | `zip-plain-at-limit-zero.zip` | unaffected | with `bulk_download_max_size = 0`, still byte-identical to pristine — this is what makes the opt-in design worth it |
| `:export_wiki_pages` absent | `shots/no-permission-wiki-index.png` | no export links at all | as user `dev` with the permission removed: `Also available in: Atom` only |
| Direct URL without the permission | logged | 403 | `GET /projects/geoxyz-verify/wiki/export.zip?with_attachments=1` → **HTTP 403** |

Screenshots read, not just generated: yes. The first run of the verification
produced an archive with **no** attachments even though the link rendered and
every test passed — the dev database is shared between worktrees but `files/`
is not, so `Attachment#readable?` was silently false for every attachment.
That is exactly the class of defect G9 exists for, and it was only visible by
looking at the downloaded archive. Fixed in `tools/dev-server.sh`.

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
| "Attachments were left out of #43978 on purpose." | They were left out because of three named design questions, not because they are unwanted — the same comment calls the text-only export useful "even without attachments". Archive structure: a directory per page, named after the page's own entry. Filename collisions: the existing `(n)` scheme, applied per directory, so two pages can each have a `diagram.png`. Attachment references in content: see the next row. |
| "What happens to `!diagram.png!` in the exported source?" | It resolves. The source is exported raw, exactly as it is now — this patch rewrites nothing — but the attachment is written next to the page file, which is where a bare-filename reference looks. That is the point of the nested layout. |
| "Why does one link give a flat archive and the other a nested one?" | Because the directories exist to hold attachments. A page with no attachments to place would get an empty directory wrapping a single file, which is worse than the flat list for the text-only export that people already use. The two links are labelled differently and produce different things on purpose. |
| "Why nest by hierarchy rather than one flat directory per page?" | The wiki tree is real structure that the current export throws away, and reconstructing it afterwards is not possible from a flat list. It also avoids the `(n)` suffix in the common case where two pages under different parents have similar titles. `wiki_page_directories` mirrors core's own `render_page_hierarchy` — same `group_by(&:parent_id)`, same recursive shape. |
| "Another link in `other_formats_links` clutters the line." | It is one entry, next to a ZIP it is a variant of, and it is the same pattern the repository diff view already uses (`link_to_with_query_parameters 'Diff', …, :caption => 'Unified diff'`) — the format name drives the CSS class, the caption is what the user reads. |
| "A ZIP with attachments can be huge." | That is why it is bounded by `bulk_download_max_size`, the setting Redmine already applies to every other bulk download, and why it is opt-in: the text-only export keeps working when the limit is hit. |
| "It builds the whole archive in memory." | So do `wiki_pages_to_zip` and `Attachment.archive_attachments` today; `Zip::OutputStream.write_buffer` returns a `StringIO`. The difference here is that the size is now bounded by a setting, where the existing wiki ZIP is bounded by nothing. Streaming the archive would be a worthwhile change to all three call sites and does not belong in this patch. |
| "Why move the timestamp and buffer code?" | Because both layouts need them and duplicating them would be worse. Both extractions are behaviour-preserving and are covered by the existing `test_export_to_zip`, which asserts the DOS and UT times of page entries and is untouched by this patch. |
| "Should the parameter be a checkbox or an export-options dialog?" | It could be, like the CSV export options. That is more UI for one boolean, and `other_formats_links` is where a user already looks for export variants. Happy to change it if a committer prefers. |

---

## Submission

- **Issue:** nog aan te maken door Jan — follow-up van
  [#43978](https://www.redmine.org/issues/43978)
- **Patches attached:** `patches/wiki-export-attachments/2026-09-01-r24882-feature.patch` (code + `en.yml`) en `-locales.patch` (`nl`, `fr`, `de`, `es`)
- **Made against:** `origin/master` r24882 (2026-08-03)
- **Status:** nog niet ingediend — wacht op Jan
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `ca3229506` — de branch had nul eigen
  commits en heeft er nu één. Eerst bijgewerkt naar upstream `7.0-stable`
  (`a7fe622f9` → `ffc731ed7`, fast-forward).
- **Suites daar groen:** ja, volledig — 5917 runs, 31706 assertions,
  0 failures, 0 errors, 39 skips.
- **`nl.yml` toegevoegd:** ja, en `fr`, `de`, `es` — identiek aan de patch
  (INV-10).
- **`tools/check-geoxyz-branch.sh`:** PASS
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus: pas als GEOxyz naar de release gaat
  die deze wijziging bevat (7.1 op zijn vroegst).
