# Review run — 2026-09-03 — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `patch/wiki-export-attachments` at `2cb6231c7` against `origin/master` `bee32a926` — **and**, because the two disagree (F01), the actual deliverables: `patches/wiki-export-attachments/2026-09-01-r24882-{feature,locales}.patch` and `7.0-stable-GEOxyz` commit `28c618860`
- **Dossier read:** `docs/features/wiki-export-attachments/dossier.md` — yes
- **Status read:** `docs/features/wiki-export-attachments/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes — throwaway worktree at `origin/master` `bee32a926` + both patch files, PostgreSQL. `test/functional/wiki_controller_test.rb`: **111 runs, 645 assertions, 0 failures, 0 errors, 0 skips** (12.2 s). RuboCop on the changed Ruby files (`--force-exclusion --format simple`): **2 files inspected, 0 offences**. Both numbers reproduce the dossier exactly. I did **not** run the full `test:all` suite — I re-ran only the touched suite plus my own probes.
- **Scope covered:** minimality, feature scope, settings surface, conventions of the touched files, backward compatibility, authorization, escaping, i18n (all five locale files, every cited source key checked), tests-as-code, test pollution, dossier accuracy, and — as the brief asked — path traversal / filename safety, name collisions, `bulk_download_max_size` behaviour and ordering, memory and streaming. Four hostile-input cases were constructed and run against the patched code, and the resulting archives opened with Info-ZIP `unzip`.
- **Scope NOT covered:**
  - The full `test:all` run (the dossier's own figures, and its SCM-binary explanation for the 29 non-green tests, I took on trust — they match what other dossiers in this repo report for the same image).
  - `7.0-stable-GEOxyz`: I read commit `28c618860` and confirmed it is the same change as the patch files, but I did not check the branch out, run its suite, or run `tools/check-geoxyz-branch.sh`.
  - No browser. I did not re-do G9; I checked the three committed archives with `unzip -l` (they match the dossier's listings byte-for-byte in structure) and read the screenshot filenames, but I did not open the PNGs.
  - PDF and HTML export paths, and the wiki system tests, were not exercised beyond what the functional suite does.
  - Database portability: nothing in this patch issues SQL of its own, so I did not look at it.

## Summary

The engineering here is good and the dossier is unusually honest — the trunk check
is real, the i18n table cites source keys that all exist with the quoted values, the
`bulk_download_max_size` check happens *before* the archive is built rather than
after, `readable?` is applied, and the size guard is opt-in precisely so it cannot
turn today's working source-only export into a failure. Trunk's `export` action
already does `includes([:content, {:attachments => :author}])`, so there is no N+1:
I measured exactly **one** attachment-table query for an eight-page wiki. Page-title
path traversal, which I expected to be the finding, is genuinely not reachable —
`WikiPage#title=` runs `Wiki.titleize`, which deletes `,./?;|:`, so a title can
contain neither a dot nor a slash, and the patch reuses trunk's own sanitizer with
`gsub`, not `sub`.

But a committer would not accept it as it stands, for two independent reasons.

The first is bookkeeping and it has to be fixed before anything else: **the branch I
was pointed at is not the patch.** `patch/wiki-export-attachments` still carries the
design Jan rejected — a second `ZIP with attachments` link, a flat archive when
attachments are off, and a locale key called `label_export_zip_with_attachments`.
The dossier, the two `.patch` files and the GEOxyz commit carry the design Jan chose
(always nested, one ZIP link opening an export-options dialog, `label_include_attachments`).
The branch commit is ten hours older than the others. So the dossier's
"Alternatives considered" section rejects, in writing, exactly what the branch does.

The second is a real defect in the deliverable. The new layout puts a page's source
and that page's attachments in the same directory, but the de-duplication that
protects attachment names against each other does not know about the page source
file or about the child pages' directories. I constructed both collisions and
extracted the archives. An attachment named `CookBook_documentation.txt` on the page
`CookBook_documentation` produces two ZIP entries at the identical path, and the
page's own text is then **silently missing** from the archive — `unzip -l` lists the
attachment and no longer lists the page. An attachment named after a child page
(`Page_with_an_inline_image`) collides with that child's directory, and `unzip`
refuses: "exists but is not directory — unable to process
CookBook_documentation/Page_with_an_inline_image/Page_with_an_inline_image.txt".
Both are reachable by any user who can attach a file to a wiki page, and both are
plain user error, not an attack. That matters more than usual here, because
answering #43978's "filename collisions" question is one of the three things this
submission is built on claiming.

Everything else is small: 14 lines copy `Attachment.archive_attachments`' rename
loop instead of reusing it, one `sort_by(&:title)` is redundant and disagrees with
the association's own `LOWER(title)` ordering, and the updated `test_export_to_zip`
now computes its expected paths with a helper that mirrors the production algorithm
instead of naming the six literal paths the dossier itself prints.

**Counts:** blocker 2 · major 1 · minor 4 · nit 3 · question 2

**Lines in the diff not strictly required by the feature:** 3 — the `.sort_by(&:title)`
in `wiki_page_directories` (F08) and the two-line comment above it (F12). Separately,
14 lines duplicate logic that already exists in core (F04); they are needed
functionally, but not as new lines.

---

### F01 — `patch/wiki-export-attachments` implements the design Jan rejected; the dossier, the `.patch` files and the GEOxyz commit implement the one he chose

- **Status:** fixed
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `origin/patch/wiki-export-attachments` @ `2cb6231c7` vs `patches/wiki-export-attachments/2026-09-01-r24882-feature.patch` and `7.0-stable-GEOxyz` @ `28c618860`
- **Invariant touched:** none directly; it defeats INV-2/INV-9's purpose, since the branch is what a re-export would `format-patch` from
- **Resolution:** fixed 2026-09-05 — `patch/wiki-export-attachments` rebuilt from `origin/master` `bee32a926` (r25037) as one commit, `f434bff64`, carrying the chosen design plus the round-2 fixes; `patches/wiki-export-attachments/2026-09-05-r25037-{feature,locales}.patch` are exported from it and `tools/check-patch-clean.sh` confirms branch and files agree (Jan g04)

**What is wrong**

Three artifacts that are supposed to be the same change are two different changes.

The branch adds a **second** entry to "Also available in" —
`f.link_to('ZIP', :url => {..., :with_attachments => 1}, :caption => l(:label_export_zip_with_attachments))`
in both index views — keeps `wiki_pages_to_zip` flat for the source-only export, adds
a separate `wiki_pages_with_attachments_to_zip` for the nested one, and introduces the
key `label_export_zip_with_attachments` ("ZIP with attachments") in five locale files.
There is no `app/views/wiki/_export_options.html.erb` on the branch, and
`test/functional/wiki_controller_test.rb` is `+136 −0` — no existing test was touched.

The patch files and GEOxyz `28c618860` do the opposite: one ZIP link with
`:onclick => "showModal('zip-export-options', '350px'); return false;"`, a new shared
partial `app/views/wiki/_export_options.html.erb`, a single always-nested
`wiki_pages_to_zip(pages, attachments_by_page)`, the key `label_include_attachments`
("Include attachments"), and `test/functional/wiki_controller_test.rb` at `+175 −11`
with `test_export_to_zip` and
`test_export_to_zip_should_sanitize_non_portable_entry_name_characters` rewritten for
the nested paths.

The second shape is the one Jan decided: `docs/DECISIONS.md`, 2026-09-01, "**De keuze
bijlagen ja/nee gaat via het exportkeuzevenster**, niet via een tweede link — Jan: 'ja
doe optie b'" and "**Doorgetrokken: de ZIP is altijd genest**, niet alleen bij
bijlagen". `status.md`'s settled list says the same. The branch is the pre-decision
iteration; its commit is dated 2026-09-02 06:31, the other two 2026-09-02 16:33.

**Why a committer would push back**

Not the committer — Jan, first. The dossier's "Alternatives considered" section
contains the paragraph "**Keeping the flat layout and adding a second `ZIP with
attachments` link** … it was built and verified before being rejected", and
"**Nesting only when attachments are included** … Rejected for the same reason".
Those two paragraphs describe the branch. Anyone who reviews the branch instead of
the patch file — as I was asked to — reads a dossier that argues against the code in
front of it, cites a file that does not exist, and claims two existing tests were
updated when none were. And because a patch branch is the thing you regenerate a
`.patch` from, the next export from this branch silently ships the rejected design
under the accepted design's commit message.

**How I verified it**

```
git log -1 --format='%H %ad %s' --date=iso origin/patch/wiki-export-attachments
  2cb6231c7 2026-09-02 06:31:42 +0000 Add wiki page attachments to the wiki ZIP export.
git log -1 --format='%H %ad %s' --date=iso 28c618860
  28c618860 2026-09-02 16:33:09 +0000 Preserve the wiki page hierarchy and include page attachments in the ZIP export.

git diff --stat origin/master...origin/patch/wiki-export-attachments
  9 files changed, 248 insertions(+), 23 deletions(-)   # no _export_options.html.erb; test file +136 -0
head -33 patches/wiki-export-attachments/2026-09-01-r24882-feature.patch
  6 files changed, 281 insertions(+), 28 deletions(-)   # create mode 100644 app/views/wiki/_export_options.html.erb
```
`git log --all --oneline --grep=hierarchy` finds the accepted design only as
`28c618860` on `7.0-stable-GEOxyz`; no branch points at it.

**Suggested direction**

One commit, one design, three places. Whatever the mechanism, the invariant worth
restoring is that `patch/<slug>` is regenerable into the committed `.patch` byte for
byte, and that a reviewer handed only the branch name sees the submitted change.
Everything else in this findings file was assessed against the patch files, which are
the deliverable; if the branch is brought forward rather than the patch files back,
the rest of this review still applies.

**Resolution:** fixed, 2026-09-05, per Jan's g04. The branch was reset to
`origin/master` `bee32a926` (r25037), the two committed patch files were applied
to it, the round-2 fixes below were made on top, and the whole was committed as
one commit, `f434bff64`, authored by Jan. The old branch tip `2cb6231c7` (the
rejected design) is gone; the old `2026-09-01-r24882-*.patch` files are
replaced by `2026-09-05-r25037-{feature,locales}.patch`, exported from the new
commit. `tools/check-patch-clean.sh wiki-export-attachments` now runs its drift
check against that branch and passes. The GEOxyz branch carries the same change
as a second commit, `7006c4f00`, on top of `28c618860`.

---

### F02 — An attachment named `<PageTitle>.txt` produces two ZIP entries at the same path, and the page's own source text silently disappears from the archive

- **Status:** fixed
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/controllers/wiki_controller.rb` — `wiki_pages_to_zip` (the `archived_file_names = []` reset inside the per-page loop) and `archived_attachment_filename`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the page source file and the child page directories are seeded into the names an attachment is renamed against; `test_export_to_zip_with_attachments_should_rename_an_attachment_named_after_the_page` is red on the old code and the case was reproduced and re-run in a browser (Jan g03)

**What is wrong**

In the nested layout each page contributes an entry at
`File.join(directory, "#{File.basename(directory)}.txt")` and then its attachments at
`File.join(directory, archived_attachment_filename(attachment, archived_file_names))`.
`archived_file_names` is initialised to `[]` *after* the page entry is written, so the
page's own source filename is not in the set the `(n)` rename loop checks against. An
attachment whose sanitised filename equals `<PageTitle>.txt` therefore keeps its name
and is written to a path that is already occupied.

rubyzip does not refuse the duplicate. It writes a second local header and, because
its entry set is keyed by name, the central directory ends up describing only one
entry at that path — the attachment. The page's text is still physically in the
stream but nothing points at it.

**Why a committer would push back**

Silent data loss in an export whose entire purpose is a complete offline copy, from a
filename an ordinary user picks by accident. Concretely, on the ecookbook fixture
wiki, attaching a file called `CookBook_documentation.txt` to the page
`CookBook_documentation` and exporting with `with_attachments=1` gives an archive in
which `CookBook_documentation/CookBook_documentation.txt` is the attachment (57 bytes,
today's date) and the page's 101 bytes of wiki source are simply not listed. The
archive reports 8 files where 9 entries were written. rubyzip's own sequential reader
is worse: `Zip::InputStream` stops at the duplicate, so the four entries written after
it are invisible to it as well.

This lands directly on the claim the submission rests on. The dossier answers
#43978's "filename collisions" question with "the existing `(n)` scheme, per
directory, so two pages can each have a `diagram.png`" — but the collision the new
layout actually creates is between an attachment and the page file it was moved next
to, and that one is unhandled. The near miss is visible in the G9 evidence itself:
the verification wiki has a page `Wiki` with an attachment `notes.txt`; had it been
called `Wiki.txt`, the committed `zip-with-attachments.zip` would be missing
`Wiki/Wiki.txt`.

**How I verified it**

Worktree at `origin/master bee32a926` with both patch files applied, then a throwaway
functional test that attaches `CookBook_documentation.txt` to that page, exports, and
dumps the response body to disk:

```
$ unzip -l /tmp/probe-dup.zip
      117  2007-03-07 23:18   Another_page/Another_page.txt
       38  2007-03-07 23:18   Another_page/Child_1/Child_1.txt
       25  2007-03-07 23:18   Another_page/Child_1/Child_1_1/Child_1_1.txt
       38  2007-03-07 23:18   Another_page/Child_2/Child_2.txt
       57  2026-09-03 21:58   CookBook_documentation/CookBook_documentation.txt   <-- the attachment
       67  2007-03-07 23:18   CookBook_documentation/Page_with_an_inline_image/Page_with_an_inline_image.txt
      373  2007-03-07 23:18   Page_with_sections/Page_with_sections.txt
       24  2007-03-07 23:18   #U042d.../#U042d....txt
                              8 files
```
The page's own source entry (101 bytes, 2007-03-06) is gone; `unzip -t` reports "No
errors detected". Reading the same body with the test suite's own
`zip_entries_from_response` (`Zip::InputStream`) returned only five entries, stopping
at the duplicate. The probe test files were deleted before I removed the worktree.

**Suggested direction**

The set of names already used inside a directory has to include the page source file
before any attachment is renamed against it — and, per F03, the names of that page's
child directories too. The `(n)` scheme itself is fine; it is the set it is checked
against that is incomplete. Worth a test that asserts the page source is present
*and* the attachment is present *and* they are at different paths, since the current
tests only ever assert presence.

**Resolution:** fixed, 2026-09-05, per Jan's g03. `wiki_pages_to_zip` now
starts the per-directory name list with the page source file and the names of
the child page directories before any attachment is renamed against it, so an
attachment called `<PageTitle>.txt` becomes `<PageTitle>(1).txt` and the page
source keeps its path. The rename loop itself is the one core already had, now
`Attachment#archived_filename` (F04). Pinned by
`test_export_to_zip_with_attachments_should_rename_an_attachment_named_after_the_page`,
which asserts the page text at `CookBook_documentation/CookBook_documentation.txt`
and the attachment bytes at `CookBook_documentation/CookBook_documentation(1).txt`.
On the old code it errors — the `(1)` entry does not exist — and the archive it
produced was the one this finding describes. Reproduced live as well: on the
verification wiki an attachment `Wiki.txt` on page `Wiki` gave, before the fix,
a 7-entry archive whose `Wiki/Wiki.txt` was the 33-byte attachment
(`before-fix-zip-colliding-attachments.zip`); after it, 8 entries with the
37-byte page source at `Wiki/Wiki.txt` and the attachment at `Wiki/Wiki(1).txt`
(`zip-colliding-attachments.zip`). Both archives are committed next to the
dossier.

---

### F03 — An attachment named after a child page collides with that child's directory, and `unzip` then refuses to extract the child page's source

- **Status:** fixed
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/controllers/wiki_controller.rb` — `wiki_pages_to_zip` / `wiki_page_directories`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — same name list as F02, so an attachment named after a child page becomes `<name>(1)`; `test_export_to_zip_with_attachments_should_rename_an_attachment_named_after_a_child_page` is red on the old code, and `unzip` of the live archive goes from exit 2 to a clean extraction

**What is wrong**

The same missing-namespace problem as F02, in the other direction: a page's
attachment names are de-duplicated only against each other, never against the
directory names the page's children occupy. An attachment whose sanitised filename
equals a child page's directory name produces a *file* entry at a path that other
entries use as a *directory* prefix.

**Why a committer would push back**

Unlike F02 this one is loud, but it still loses a page. Attaching a file named
`Page_with_an_inline_image` (no extension — accepted) to `CookBook_documentation`,
which has a child page of that title, yields an archive containing both
`CookBook_documentation/Page_with_an_inline_image` and
`CookBook_documentation/Page_with_an_inline_image/Page_with_an_inline_image.txt`.
Info-ZIP extracts the first, then:

```
checkdir error:  CookBook_documentation/Page_with_an_inline_image exists but is not directory
                 unable to process CookBook_documentation/Page_with_an_inline_image/Page_with_an_inline_image.txt.
```
and exits 0, so a script that only checks the exit status believes the export
succeeded. Which of the two survives depends on entry order, i.e. on whether the
attachment sorts before or after the child page. Extension-less filenames are common
enough (`Makefile`, `README`, `LICENSE`, a photo saved without a suffix) that this is
not contrived.

**How I verified it**

Same worktree and probe harness as F02; `unzip -o /tmp/probe-dir.zip` into an empty
directory produced the `checkdir error` quoted above, and `find` afterwards showed
`CookBook_documentation/Page_with_an_inline_image` as a 57-byte file with the child
page's source absent.

**Suggested direction**

Whatever fixes F02 should treat one directory as one namespace holding three kinds of
name — the page source file, the child directories, and the attachments — and rename
within it. Reserving the child directory names before writing attachments is the
narrow version; a single helper that hands out a unique name inside a directory is
the version that cannot be got wrong again later.

**Resolution:** fixed, 2026-09-05, together with F02: the child page directory
names are part of the seeded list, so the attachment gets the suffix and the
directory keeps its name. Pinned by
`test_export_to_zip_with_attachments_should_rename_an_attachment_named_after_a_child_page`,
which asserts that `CookBook_documentation/Page_with_an_inline_image` is *not*
an entry, that the attachment is at `CookBook_documentation/Page_with_an_inline_image(1)`,
and that the child page's source is still at its own path. Red on the old code
with exactly the entry this finding predicted. Live: before the fix `unzip -o`
of the verification archive exited 2 with three `checkdir error … exists but is
not directory` lines and the child page's source and both `diagram*.txt` never
reached the disk; after it all eight entries extract. The extraction output is
quoted in the dossier.

---

### F04 — `archived_attachment_filename` re-implements `Attachment.archive_attachments`' rename loop line for line, and the dossier says nothing was copied

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** minimality
- **Where:** `app/controllers/wiki_controller.rb` — `archived_attachment_filename`; compare `app/models/attachment.rb` — `Attachment.archive_attachments`
- **Invariant touched:** INV-1
- **Resolution:** fixed 2026-09-05 — the rename loop is lifted out of `Attachment.archive_attachments` into `Attachment#archived_filename`, which both archives call; `archive_attachments` loses ten lines, a unit test pins the method, and the dossier names the extraction

**What is wrong**

The new private method is the `while archived_file_names.include?(filename)` block out
of `Attachment.archive_attachments`, with the same `dup_count`, the same
`File.extname` / `File.basename` pair and the same `"#{basename}(#{dup_count})#{extname}"`
format, transplanted into the controller. Core now has the same attachment-rename
algorithm in two places, and a change to one (say, F02/F03's fix) leaves the other
behind.

**Why a committer would push back**

Redmine already owns "give this attachment a unique name inside an archive"; it lives
on `Attachment` because that is where the filename comes from. A reviewer who
recognises the loop asks why the wiki export could not call it, and the honest answer
— the existing one is welded into a method that also builds a whole ZIP — is an
argument for extracting it, not for a second copy. It also makes the dossier's
sentence "That extraction is the only existing code this patch moves" inaccurate:
the `zip_entry` timestamp helper is moved, but this method is *copied* and the
dossier does not mention it, so a reviewer discovers the duplication on their own.

**How I verified it**

Read both against each other in the patched worktree:
`sed -n '/def self.archive_attachments/,/^  end/p' app/models/attachment.rb` versus
the patch's `archived_attachment_filename`. The only differences are the method
boundary and `extname`/`extension` naming.

**Suggested direction**

Either reuse core's version by lifting the rename loop to a small `Attachment` class
method that both call sites use, or say plainly in the dossier that it is duplicated
and why. What would be worse than either is fixing F02/F03 in the controller copy
only.

**Resolution:** fixed, 2026-09-05. `Attachment#archived_filename(archived_file_names)`
is the `while … include?` loop from `archive_attachments`, moved, not copied:
`archive_attachments` now calls it and is ten lines shorter, and the wiki export
calls the same method with its pre-seeded list. The controller copy is gone.
`test_archived_filename_should_rename_a_file_whose_name_is_already_taken` pins
the method directly (`NoMethodError` on the old code), and the three existing
`archive_attachments` tests still pass against the shortened method. The
dossier's "Proposed change" now says that two pieces of existing code move —
the timestamp helper and this loop — and why.

---

### F05 — `test_export_to_zip` now computes its expected paths with a test-side copy of the production algorithm, and its set-equality assertion was weakened to a count

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/functional/wiki_controller_test.rb` — `test_export_to_zip` and the new private `wiki_page_titles_to_root`
- **Invariant touched:** INV-7 in spirit (the assertion is not weakened to get green, but it is weakened)
- **Resolution:** fixed 2026-09-05 — `test_export_to_zip` asserts the eight literal entry paths of the fixture wiki as a sorted array again, and the test-side `wiki_page_titles_to_root` helper is deleted

**What is wrong**

Two changes in one test. The whole-archive assertion
`assert_equal pages.keys.sort.map {|t| "#{t}.txt"}, zip_entries.keys.sort` became
`assert_equal pages.size, zip_entries.size`, and the per-entry path is now checked
against `File.join(wiki_page_titles_to_root(page).reverse + [title, "#{title}.txt"])`,
where `wiki_page_titles_to_root` walks `page.parent` upward — which is
`wiki_page_directories` written a second time in the test file.

**Why a committer would push back**

The forbidden-constructs table names this exact shape: a test method that
reimplements the code it tests passes even when both are wrong. Here the mirror is
partial (the helper uses raw titles where production uses sanitised ones, so the
sanitising test still bites), but the structural half — which page nests under which,
and where the source file sits inside its directory — is asserted against a
re-derivation rather than against a fact. And replacing set equality with a count
means the test no longer notices an archive that has the right number of entries at
the wrong paths, which is precisely the failure mode F02 produces: my F02 probe
archive has 8 listed entries for 8 pages and passes a count check.

The dossier already prints the six literal paths the ecookbook fixture wiki must
produce. Those six strings in the test would be shorter than the helper and would
have caught F02.

**How I verified it**

Read the diff. Ran the suite with the patch applied: 111 runs, 645 assertions, 0
failures — so the test is green, which is the point: it is green on an archive whose
page source is missing, because nothing asserts the full key set any more.

**Suggested direction**

Assert the literal expected entry names for the fixture wiki, as a set, the way the
test did before. If a helper is still wanted for readability it should not be the
production algorithm; the fixture hierarchy is six pages and does not change.

**Resolution:** fixed, 2026-09-05. The test lists the eight paths the ecookbook
fixture wiki must produce and compares them with `zip_entries.keys.sort`, the
same shape the trunk test had; the per-entry loop keeps the content and the two
timestamp assertions. The `wiki_page_titles_to_root` helper is gone. With set
equality restored, the F02 archive (eight entries, one of them wrong) fails this
test too, which is the point. The dossier's own listing of the fixture wiki said
six pages; it is eight (`Page_with_sections` and `Этика_менеджмента` are roots
too), and the dossier is corrected.

---

### F06 — No test exercises an attachment on a nested page, which is the combination the feature exists for

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/functional/wiki_controller_test.rb` — `test_export_to_zip_with_attachments` and the four other `with_attachments` tests
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — `test_export_to_zip_with_attachments` attaches to `Child_1_1`, three levels deep, and asserts `Another_page/Child_1/Child_1_1/testfile.txt` next to `Another_page/Child_1/Child_1_1/Child_1_1.txt`

**What is wrong**

Every attachment test attaches to `CookBook_documentation`, which is a root page
(`parent_id:` empty in `test/fixtures/wiki_pages.yml`). So the asserted path is always
`CookBook_documentation/<file>` — one level deep, the one case where nesting and
flatness look the same. Nesting is proved separately, by
`test_export_to_zip_should_nest_pages_by_hierarchy`, but only for page sources.

**Why a committer would push back**

The whole argument of the submission is that an attachment must land beside the source
that refers to it, "so that `!diagram.png!` resolves once the archive is unpacked" —
and for a child page that means `Another_page/Child_1/diagram.png`. Nothing asserts
that. A regression that wrote attachments to the archive root, or to the top-level
ancestor's directory, would keep all twelve tests green. The dossier's G9 evidence
does cover it (`Wiki/Child_one/diagram.txt` in `zip-with-attachments.zip`), so the
behaviour is right today; it is the guard that is missing.

**How I verified it**

Read the fixtures (`wiki_pages_001` has an empty `parent_id`) and every new test's
assertions. Confirmed by construction: my own probes had to attach to a root page to
match the existing tests' shape, and the nested-attachment path never appears in an
assertion.

**Suggested direction**

One of the existing `with_attachments` tests moved onto a page with a parent, or one
extra assertion on a grandchild, would close it. `Child_1_1` under `Child_1` under
`Another_page` already exists in the fixtures.

**Resolution:** fixed, 2026-09-05. The existing attachment test moved from the
root page to the grandchild `Child_1_1`, as suggested, and asserts the literal
nested path for both the attachment and the page source beside it. A regression
that wrote attachments to the archive root or to the top-level ancestor now
fails here. Red on pristine trunk (no attachments in the archive at all), green
on the old patch — the behaviour was right, the guard was missing, exactly as
the finding said.

---

### F07 — A page whose parent is not in the exported collection is silently dropped instead of exported

- **Status:** fixed
- **Severity:** minor
- **Confidence:** probable
- **Category:** correctness
- **Where:** `app/controllers/wiki_controller.rb` — `wiki_pages_to_zip` / `wiki_page_directories(pages.group_by(&:parent_id))`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — a page whose parent is not among the exported pages is grouped with the roots instead of being unreachable; `WikiZipHelperTest` exports `[Child_1, Child_1_1]` and gets `Child_1/Child_1.txt` and `Child_1/Child_1_1/Child_1_1.txt`

**What is wrong**

The old code iterated `pages` and wrote one entry per element, so the archive
contained every row it was given. The new code walks down from `parent_id => nil` and
only reaches a page whose whole ancestor chain is present in the same collection. A
page whose `parent_id` points at a row that is not in `pages` is unreachable and
contributes no entry — and no error either.

**Why a committer would push back**

For the export action as it stands, `@pages` is the whole wiki, so the two are
equivalent today and I could not construct the case through the UI:
`validate_parent_title` and `acts_as_tree :dependent => :nullify` keep `parent_id`
either null or pointing inside the same wiki. What changes is the failure mode. Any
future caller that passes a subset — an export of one page's subtree, which is the
obvious next request on a feature like this — or any row left dangling by a plugin,
a migration or a `update_column`, now loses pages quietly rather than exporting them
at the archive root. A tree walk that cannot see its own inputs is also where the
sibling risk lives: a `parent_id` cycle would recurse until the stack goes, where the
old loop would simply write two entries. Core's `render_page_hierarchy` has the same
shape, so this is a pattern Redmine accepts — but `render_page_hierarchy` renders a
navigation list, and this is the artifact of record.

**How I verified it**

Read only, for the drop itself — I did not construct a dangling `parent_id`, because
the model validations block every route to one that I could find, which is why this is
`probable` and `minor` rather than higher. The equivalence for today's caller I did
confirm: `export` loads `@wiki.pages.includes([:content, {:attachments => :author}])`,
i.e. the complete wiki, and my probe exports listed all eight fixture pages.

**Suggested direction**

Nothing elaborate; the point is only that "every page in `pages` appears exactly once"
should be a property of the builder rather than a coincidence of the caller. A
reviewer would be satisfied by pages the walk did not reach being written at the
archive root, or by the test asserting set equality (F05) over the *whole* wiki so
that a dropped page fails loudly.

**Resolution:** fixed, 2026-09-05. `wiki_pages_to_zip` groups by
`parent_id` only when that parent is in the collection; otherwise the page is a
root. So every page given appears exactly once, whatever subset a caller passes,
and the property no longer depends on `export` loading the whole wiki. One line
of code. Pinned by
`test_wiki_pages_to_zip_should_export_a_page_whose_parent_is_not_given_at_the_root`
in the new `test/unit/lib/redmine/export/zip/wiki_zip_helper_test.rb`, which
calls the helper with `Child_1` and `Child_1_1` but not `Another_page`, and
expects `Child_1` at the root. Together with F05's set equality over the whole
fixture wiki, a dropped page now fails loudly in two places. A `parent_id`
cycle is still not handled; `validate_parent_title` makes it unreachable and it
is named in the dossier's "Found but not fixed".

---

### F08 — `.sort_by(&:title)` is redundant and disagrees with the ordering the `pages` association already applies

- **Status:** fixed
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** minimality
- **Where:** `app/controllers/wiki_controller.rb` — `wiki_page_directories`, `pages_by_parent_id.fetch(parent_id, []).sort_by(&:title)`
- **Invariant touched:** INV-1
- **Resolution:** fixed 2026-09-05 — `.sort_by(&:title)` removed; the walk uses the order of the `pages` association, which is `LOWER(title)`

**What is wrong**

`Wiki` declares `has_many :pages, lambda {order(Arel.sql('LOWER(title)').asc)}`, so
`@pages` reaches the builder already sorted, case-insensitively, by the database. The
added `sort_by(&:title)` re-sorts it case-*sensitively* in Ruby, so it does not
preserve that order — with sibling pages `apple` and `Banana` the association yields
`apple, Banana` and this line yields `Banana, apple`.

**Why a committer would push back**

One line that is not needed and, where it does have an effect, disagrees with the
project's own ordering of the same collection. It also makes the dossier's claim that
`wiki_page_directories` "walks the tree exactly as core's `render_page_hierarchy`
does — same `group_by(&:parent_id)`, same recursive signature" not quite true:
`render_page_hierarchy` does no sorting at all, precisely because it trusts the
association. The visible consequence is confined to entry order inside the ZIP and to
which of two colliding siblings receives the `(1)` suffix, so it is a nit, not a bug.

**How I verified it**

`grep -n "has_many :pages" -A3 app/models/wiki.rb` in the worktree, against
`render_page_hierarchy` in `app/helpers/application_helper.rb`, which iterates
`pages[node]` unsorted.

**Suggested direction**

Drop it and rely on the association, or keep an explicit sort and make it the same
`LOWER(title)` comparison the association uses — and then say in the dossier that the
ordering is deliberate rather than inherited.

**Resolution:** fixed, 2026-09-05. The line is gone, so sibling order inside the
archive is the association's case-insensitive order and `wiki_page_directories`
does no sorting, like `render_page_hierarchy`. The dossier's comparison with
`render_page_hierarchy` is accurate again.

---

### F09 — Wiki-page attachments go into the archive without the container-level visibility check that every other bulk download applies

- **Status:** wont-fix
- **Severity:** question
- **Confidence:** confirmed
- **Category:** security
- **Where:** `app/controllers/wiki_controller.rb` — `wiki_page_attachments`; compare `app/controllers/attachments_controller.rb` — `find_downloadable_attachments`
- **Invariant touched:** none
- **Resolution:** wont-fix 2026-09-05 — Jan's g14: no `attachments_visible?` guard; the dossier now states the accurate comparison (the `download_all` caller checks it, the export does not) and why `:export_wiki_pages` on the project is sufficient

**What is wrong — and this is a settled decision, so it is a question for Jan, not a change request**

`docs/DECISIONS.md`, 2026-09-01: "Bijlagen worden gefilterd op `readable?`, niet op
`visible?` — precies wat `Attachment.archive_attachments` doet." That is accurate about
`archive_attachments` itself, but incomplete about the comparison, and I think the
recorded rationale should be corrected whichever way the decision goes.

`Attachment.archive_attachments` has exactly one caller,
`AttachmentsController#download_all`, and its `find_downloadable_attachments` opens with

```ruby
unless @container.try(:attachments_visible?)
  deny_access
  return
end
```

`WikiPage#attachments_visible?` (from `acts_as_attachable`) is
`user.allowed_to?(:view_wiki_pages, project)`, and `Attachment#visible?` resolves to
the same call. So core does not skip the visibility check for bulk downloads — it
performs it once, at the container, before reaching `archive_attachments`. The wiki
export performs no equivalent check.

**Why this is a question rather than a nit**

`:export_wiki_pages` and `:view_wiki_pages` are independent permissions —
`lib/redmine/preparation.rb:125-127` declares them as separate `map.permission` entries
with no dependency, and the roles form lists them as separate checkboxes. A role with
`export_wiki_pages` but not `view_wiki_pages` therefore gets the ZIP (that is true on
trunk today, for the page text) and, with this patch, also gets every attachment
binary — while `GET /attachments/download_all/wiki_pages/<id>` for the same page
refuses that same user. Two doors to the same files, one of which checks and one of
which does not.

Whether that combination is worth defending is genuinely Jan's call, and there is a
real argument that it is not: the existing export already hands that user the full
text of every page, so the marginal disclosure is the file bytes, and a role
configured that way is arguably already misconfigured. But it is not the argument the
decision currently records, and it would be raised on redmine.org — a one-line
`attachments_visible?` guard is the kind of thing a committer adds themselves and then
asks why it was not there.

**How I verified it**

Read `find_downloadable_attachments` (`app/controllers/attachments_controller.rb:241`),
`attachments_visible?` (`lib/plugins/acts_as_attachable/lib/acts_as_attachable.rb:73`),
`Attachment#visible?` and `Attachment#readable?` (`app/models/attachment.rb`), and the
permission map (`lib/redmine/preparation.rb:124-129`) in the patched worktree. I did
**not** build the role combination and drive it — the code path is short enough to
read, but the claim that it is exploitable in practice is read-only.

**Suggested direction**

Either add the container check and say so in the dossier's anticipated-objections
table, or keep the current behaviour and replace the rationale with the accurate
version: that `archive_attachments`' caller *does* check `attachments_visible?`, that
the wiki export deliberately does not, and why the `:export_wiki_pages` grant is
considered sufficient. Anticipating the objection is worth more than avoiding it.

**Resolution:** wont-fix, 2026-09-05, decided by Jan (g14, 2026-09-04): there
is no leak to close, so one paragraph in the dossier instead of code. The
rationale is corrected as this finding asked: `AttachmentsController#download_all`
does check `attachments_visible?` on the container before calling
`archive_attachments`; the wiki export does not, deliberately, because within a
project Redmine has no per-page read right — `WikiPage#visible?` and
`attachments_visible?` both resolve to `:view_wiki_pages` on the project, the
export already requires `:export_wiki_pages` on that same project and already
hands that user every page's text, and a role granted export without view is a
misconfiguration rather than a boundary this export can defend. `readable?` is
still applied. The "Alternatives considered" paragraph and a row in "Anticipated
objections" now say exactly this.

---

### F10 — ~85 lines of archive construction now live in `WikiController` rather than under `lib/redmine/export/`

- **Status:** fixed
- **Severity:** question
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `app/controllers/wiki_controller.rb` — `wiki_pages_to_zip`, `wiki_page_directories`, `zip_entry`, `archived_attachment_filename`, `wiki_page_attachments`, `wiki_attachments_too_big?`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the archive construction moved to `Redmine::Export::ZIP::WikiZipHelper` under `lib/redmine/export/zip/`, next to the PDF and text helpers; the two policy helpers stay in the controller like `find_downloadable_attachments` (Jan g16c)

**What is wrong**

The controller's private section grows from two export helpers to six, and now holds
a recursive tree walk, ZIP entry construction, DOS/UT timestamp encoding, a filename
de-duplicator and a size policy. Redmine keeps that kind of thing in
`lib/redmine/export/` — `Redmine::Export::PDF`, which this same controller includes
two lines above the patch's own `include`, is the local example.

**Why this is a question rather than a finding**

The honest counterpoint is that trunk put it there. `wiki_pages_to_zip` and
`archived_wiki_page_filename` were added to `WikiController` by #43978 (r24605), and
following the file you are editing is normally the right instinct — INV-1 would be
against moving code the feature does not need to move. So this is a judgement about
where a reviewer's tolerance runs out as the block grows, not a defect: two helpers in
a controller is unremarkable, six that include a recursive tree walk is where a
committer starts asking for `Redmine::Export::WikiZip`. Worth deciding *before*
submission, because "please move this to lib/" arriving as review feedback costs a
round trip and a re-verification.

**How I verified it**

Read the patched file end to end; counted the added private methods and lines. Checked
`lib/redmine/export/` for the existing pattern and confirmed `Redmine::Export::PDF` is
included in this very controller.

**Suggested direction**

If it stays in the controller, the dossier should say so and why (following #43978),
so the reviewer sees it was considered. If it moves, moving trunk's two existing
methods along with it turns a minimality objection into a scope objection instead —
which is the trade to think about, and a reason a committer might well prefer it left
alone for now.

**Resolution:** fixed, 2026-09-05, per Jan's g16c: moved, not rewritten.
`wiki_pages_to_zip`, `wiki_page_directories`, `zip_entry` and
`archived_wiki_page_filename` live in `lib/redmine/export/zip/wiki_zip_helper.rb`
as `Redmine::Export::ZIP::WikiZipHelper`, the shape of
`Redmine::Export::PDF::WikiPdfHelper` and `Redmine::Export::Text::VersionsTextHelper`;
the controller includes it next to `Redmine::Export::PDF`. `ZIP` is registered
as an acronym in `config/initializers/zeitwerk.rb` like `PDF` and `CSV`, which
is also what keeps the namespace from shadowing the `Zip` gem. Trunk's two
methods from #43978 move along unchanged, which the dossier states as the one
place this patch touches lines the feature did not need to touch (Jan's choice,
recorded in `docs/exceptions.md`). `wiki_page_attachments` and
`wiki_attachments_too_big?` stay in the controller: they read `params` and a
setting and decide, which is where `AttachmentsController` keeps the same
decision. `bin/rails zeitwerk:check` passes.

---

### F11 — An attachment filename of `..` reaches the archive as `<Page>/..`; page titles, by contrast, cannot escape at all

- **Status:** wont-fix
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** security
- **Where:** `app/controllers/wiki_controller.rb` — `archived_attachment_filename`; `Attachment#sanitize_filename`
- **Invariant touched:** none
- **Resolution:** wont-fix 2026-09-05 — not this patch's gap, as the finding says; the `sanitize_filename` hole is named in the dossier's "Found but not fixed" for a separate report

**What is wrong**

This is the path-traversal answer, and it is mostly good news, so it is recorded as
one finding rather than left implicit.

Page titles are safe by construction. `WikiPage#title=` runs `Wiki.titleize`, which
does `delete(',./?;|:')` — a title cannot contain a dot or a slash at all, so `..`,
`../x` and a leading `/` are unreachable, and `File.basename(directory)` can never
strip anything the code did not append. The patch reuses trunk's
`archived_wiki_page_filename` unchanged, including its `gsub` (not `sub`) over
`[\/?%*:|"'<>\n\r\x00]+`, and — because the patch does not touch that line — the
`\x00` that trunk added after r24882 in #44228 survives applying the patch to today's
trunk. I checked that specifically.

Attachment filenames are the weaker half. `Attachment#sanitize_filename` strips
everything up to the last slash or backslash and replaces the same character class,
which removes `../../etc/passwd` down to `passwd`, but leaves a filename of exactly
`..` intact. `AttachmentsController#upload` assigns `params[:filename]` directly, so
that value is caller-controlled for anyone with `edit_wiki_pages`. The export then
writes an entry named `<PageDirectory>/..`.

**Why this is a nit and not a security finding**

Because it does not escape and it is not new. Info-ZIP `unzip` silently skips the
entry — I extracted the archive into a subdirectory and nothing was written above it —
and one `..` from inside a page directory reaches at worst the archive root. The
nesting the patch adds actually *improves* this: core's existing per-page "Download
all files" runs the same attachment through `Attachment.archive_attachments`, which
puts it at the archive root as a bare `..`, which is the version that could escape.
So the pre-existing gap is in `sanitize_filename`, upstream of this patch, and worth
its own redmine.org issue rather than a fix here.

One related pre-existing wart the nesting makes more visible: with
`Zip.unicode_names = true`, Info-ZIP renders the Cyrillic fixture page as
`#U042d#U0442#U0438#U043a#U0430_...` — and now as a *directory* name as well as a
file name. Same behaviour on trunk's flat export, so also not this patch's doing.

**How I verified it**

Constructed all three cases in the patched worktree. `WikiPage.new(:title => '..')`
is invalid ("Title cannot be blank") because `titleize` empties it; `'a/b'` and
`'x.txt'` are accepted but stored as `ab` and `xtxt`. An attachment saved with
`filename = '..'` keeps `".."`, and the export produced the entry
`CookBook_documentation/..`; `unzip -o` of that archive into `/tmp/ex-dd/sub` wrote
nothing outside `sub`. `grep -n 'x00' app/controllers/wiki_controller.rb` after
applying both patch files still shows the `\x00` in the character class.

**Suggested direction**

Nothing in this patch. If the fixing session wants belt and braces, rejecting or
renaming an entry component that is `.` or `..` inside the archive builder is cheap
and defensible; the `sanitize_filename` gap itself is a separate report, and the
dossier's "Found but not fixed" section is the right place to name it.

**Resolution:** wont-fix, 2026-09-05. Nothing changed in the archive builder:
the entry `<Page>/..` cannot escape, `unzip` skips it, and the same filename
reaches the root as a bare `..` through core's existing per-page download, which
is the version worth reporting. The dossier's "Found but not fixed" now names
the `Attachment#sanitize_filename` gap with the reproduction, and says that the
nesting this patch adds makes the wiki export the safer of the two paths.

---

### F12 — The comment above `wiki_page_directories` half restates what the method does

- **Status:** fixed
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `app/controllers/wiki_controller.rb`, immediately above `def wiki_page_directories`
- **Invariant touched:** INV-3
- **Resolution:** fixed 2026-09-05 — the comment above `wiki_page_directories` keeps the reason and drops the restatement

**What is wrong**

```ruby
# Pairs every page with the directory that mirrors its place in the wiki
# hierarchy, so that an attachment sits next to the page source referring to it.
```
The second clause is a genuine non-obvious *why* and earns its place. The first is the
method name and its return value spelled out in prose, which is what INV-3 and
Redmine's near-comment-free style are against.

**Why a committer would push back**

Barely — this is a nit and the file it is in already carries two comments from #43978
in the same register ("DOS timestamp stores user's displayed local time"). It is
listed only because it is the one line in the diff a reviewer could ask to shorten
without touching behaviour.

**How I verified it**

Read the diff.

**Suggested direction**

Keep the reason, drop the restatement.

**Resolution:** fixed, 2026-09-05. The comment is now "Directories mirror the
wiki hierarchy so that an attachment sits next to the page source referring to
it" — the why, without spelling out the return value.

---

## Checked and found sound — recorded so the next reviewer does not redo it

- **The size check runs before the archive is built, not after.** `wiki_page_attachments`
  → `wiki_attachments_too_big?` → build. No work is thrown away, and the redirect
  carries core's own `error_bulk_download_size_too_big` with `number_to_human_size`,
  exactly as `find_downloadable_attachments` does. `include ActionView::Helpers::NumberHelper`
  mirrors `AttachmentsController:21`.
- **The size guard cannot break today's export.** With `bulk_download_max_size = 0` and
  no `with_attachments`, `attachments_by_page` is `{}` and `0 > 0` is false, so the
  source-only ZIP is still sent. Their own test asserts it and the committed
  `zip-without-attachments-at-limit-zero.zip` is structurally identical to the normal one.
- **No N+1.** Trunk's `export` already does `includes([:content, {:attachments => :author}])`.
  Instrumenting `sql.active_record` during an export of the eight-page fixture wiki
  counted **one** query touching `attachments`.
- **Memory is no worse than core's.** `Zip::OutputStream.write_buffer` + `File.binread`
  per attachment, i.e. archive-in-memory plus one whole file — the same shape as
  `Attachment.archive_attachments`, and now bounded by a setting where trunk's wiki ZIP
  is bounded by nothing. The dossier says this plainly instead of hiding it.
- **i18n is honest.** All five files, one key, and every "patterned on" citation in the
  dossier's table exists with the quoted value: `label_edit_attachments` (nl "Bijlagen
  bewerken"), `error_bulk_download_size_too_big` (fr "Ces pièces jointes…"),
  `setting_show_status_changes_in_mail_subject` (fr "Inclure les…"),
  `label_cross_project_descendants` (de "Mit Unterprojekten"), `label_copy_attachments`
  (de "Anhänge kopieren", es "Copiar adjuntos"), `field_searchable` (es "Incluir en las
  búsquedas"). `label_export_options` and `button_export` already exist translated in
  all five, so the dialog needs exactly the one new key it adds.
- **The dialog follows core's pattern.** `showModal('…-export-options', '350px'); return false;`,
  `<h3 class="title">` with `label_export_options`, `submit_tag … :onclick => "hideModal(this);"`,
  `link_to_function l(:button_cancel)` — the same as `app/views/issues/index.html.erb`
  and six siblings. Sharing it as a partial across two views, where core inlines it, is
  a defensible deviation. `params[:with_attachments] == '1'` is core's own idiom.
- **The permission gating is consistent.** Both views already wrap `other_formats_links`
  in `unless @pages.empty?` on trunk, and the partial is rendered under the same
  `:export_wiki_pages` check and the same emptiness check — so there is no state where
  the ZIP link exists and the dialog it opens does not.
- **Both patch files still apply cleanly to today's trunk** `bee32a926`, five weeks
  past the r24882 they were made against, and the `\x00` fix from #44228 survives.
  `git apply --check` on each, then applied together.
- **Suite and lint reproduce.** `test/functional/wiki_controller_test.rb`: 111 runs,
  645 assertions, 0 failures, 0 errors, 0 skips. RuboCop on the changed Ruby files: 0
  offences. Both match the dossier's figures.
- **G9 evidence is real.** The three committed archives' `unzip -l` listings match the
  dossier's quoted trees exactly, including `Wiki/Child_one/diagram(1).txt`, and
  `verify/wiki-export-attachments.mjs` exists.
- **The backward-compatibility cost is stated up front, not buried.** The dossier leads
  with "this deliberately changes the entry paths of the ZIP export that shipped in
  7.0.0" and gives a reviewer the fallback position. That is the right way to open this
  issue on redmine.org.

<!-- Status values:
     open       not yet acted on                      (reviewer sets)
     fixed      changed, with a test red on old code  (fixer)
     invalid    factually wrong — say why, with evidence (fixer)
     wont-fix   real but deliberately not changed — reason required, and a line
                in docs/DECISIONS.md if user-visible (fixer)
     duplicate  same as another finding — name it     (fixer)
     deferred   real, out of scope — name what it waits on (fixer)
     question   needs Jan, not code                   (either)

     A fixer leaves no finding at `open` without a Resolution line.
     "Ran out of time" is acceptable; silence is not. -->
