# Review run — 2026-09-09 — ChatGPT Codex

- **Reviewer:** ChatGPT Codex (GPT-5.6 Sol)
- **Reviewed:** `patch/wiki-export-attachments` at `8121846be` against mirror `origin/master` `bee32a926`; submission readiness checked against real trunk `upstream/master` `8de368193`
- **Dossier read:** `docs/features/wiki-export-attachments/dossier.md` — yes
- **Status read:** `docs/features/wiki-export-attachments/status.md` (the "already settled" section) — yes
- **Ran the test suite:** no — the patch cannot be applied unchanged to current trunk, so its Rubyzip 3.6 behaviour was not represented by the prepared branch.
- **Scope covered:** current-trunk applicability, Rubyzip dependency delta by inspection, hierarchy traversal, orphan handling, filename sanitization/collisions, attachment readability/size guard, permissions, views/modal, translations, tests, minimality and INV-10.
- **Scope NOT covered:** a resolved/rebased candidate on Rubyzip 3.6, full suite, browser interaction, archive extraction across platforms and very large archives.

## Summary

This is not ready to submit today because its feature patch does not apply to current Redmine trunk. The conflict is in `config/initializers/zeitwerk.rb`, which trunk changed while moving to Rubyzip 3.6; consequently none of the prepared evidence establishes that the exact candidate submitted to Redmine works with the current ZIP library. That is known staleness rather than a design defect, but INV-2 makes it a blocker at submission time. On the reviewed branch, the archive design itself is coherent: hierarchy, source/attachment/child collisions, orphan pages, readable files, timestamps and the size escape hatch all have direct tests.

**Counts:** blocker 1 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** approximately 84 changed lines — the two existing ZIP helper methods are removed from the controller and reintroduced under `lib/redmine/export/zip/`. This is the deliberate INV-1 exception recorded in `docs/exceptions.md` (g16c), not hidden cleanup; the feature could function without the move.

---

### F01 — The feature patch cannot be submitted to current trunk or claim Rubyzip 3.6 verification

- **Status:** fixed
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** backward-compat
- **Where:** `patches/wiki-export-attachments/2026-09-08-r25037-feature.patch`, hunk for `config/initializers/zeitwerk.rb`
- **Invariant touched:** INV-2, INV-8

**What is wrong**

The downloadable feature patch was prepared against mirror revision `bee32a926`. Real trunk is `8de368193` and changed the same Zeitwerk inflector while updating Rubyzip. The patch fails to apply, and the prepared branch still resolves the older Rubyzip line, so the current-trunk compatibility claim has not been executed.

**Why a committer would push back**

Concrete failure path: a committer downloads the advertised feature patch and runs `git apply` on current trunk; Git stops at `config/initializers/zeitwerk.rb`, leaving no candidate to test or commit. Manually resolving that collision would create code that is not the reviewed/exported patch, and ZIP generation is precisely the area affected by the dependency update.

**How I verified it**

Fetched `https://github.com/redmine/redmine.git` master at `8de368193`, created a pristine detached worktree, and ran `git apply --check` for both exports. The locale patch applied; the feature patch reported `patch failed: config/initializers/zeitwerk.rb:21` and `patch does not apply`. I did not resolve the patch or claim a Rubyzip 3.6 test run.

**Suggested direction**

Refresh the branch and both exported files against real current trunk, resolve the inflector change without changing the chosen design, install the resulting lock with Rubyzip 3.6, and rerun the focused ZIP tests, full suite, lint and live export before submission.

- **Resolution:** fixed 2026-09-09, and this finding is **correct on the tip it reviewed**. Codex read `8121846be` against the mirror at `bee32a926`; the refresh had been done a few hours earlier and the branch tip is now **`eed205828`** on real trunk **r25063** (`8de368193`). The finding is therefore confirmed rather than disputed — it names exactly the gap the refresh closed, and it names it from the right place: `git apply --check` against real trunk rather than against the mirror the gate was reading. **The suggested direction was followed step for step.** (1) *Refresh the branch and both exported files against real current trunk.* Rebased onto `origin/master` after Jan synced the mirror, so the mirror and real trunk now both read `8de368193`; the two exports are `patches/wiki-export-attachments/2026-09-09-r25063-{feature,locales}.patch`. (2) *Resolve the inflector change without changing the chosen design.* Trunk's `e0e38cb9b` (#44396) added `'itcpdf' => 'ITCPDF'` to the same acronym hash our patch adds `'zip' => 'ZIP'` to — both sides append at the same point, so both lines are kept, with ours last to keep the diff against the new trunk minimal. Nothing else in the change moved: `diff` of our own diff before and after the rebase differs only in that hunk's anchor lines. (3) *Install the resulting lock with Rubyzip 3.6 and rerun the focused ZIP tests, full suite, lint and live export.* rubyzip **3.6.0** and json 2.21.2 confirmed via `bundle list`. Focused: the three touched suites in one process, `173 runs, 814 assertions, 0 failures, 0 errors, 4 skips`. Full suite with the patch: `5995 runs, 31777 assertions, 27 failures, 2 errors, 92 skips`; pristine trunk r25063 on a **byte-identical `Gemfile.lock`** (copied across, since the lock is gitignored): `5981 runs, 31724 assertions, 27 failures, 2 errors, 92 skips` — 14 runs more, **zero extra failures and zero extra errors**, and the 29 failing names are identical on both sides with `diff` empty in both directions. RuboCop: 0 on the 7 changed Ruby files, 0 baseline on the 5 that pre-exist. `tools/check-patch-clean.sh wiki-export-attachments --submit`: **PASS** on r25063. **On the part of this finding the suggested direction could not settle by rebasing — whether the ZIP still works on the new library — the answer is not a green suite.** The helper leans on five Rubyzip APIs that could have broken between 2.x and 3.x, so an archive was built against Redmine's own fixtures and read back: the hierarchy is three levels deep (`Another_page/Child_1/Child_1_1/Child_1_1.txt`), the attachment sits beside its page at the correct 31620 bytes, Cyrillic directory names survive (so `Zip.unicode_names = true` still functions), and entry mtimes are the pages' `updated_on` (so `Zip::DOSTime` and the `universaltime` extra field still function). Then driven through a real browser in both variants, which also exercises the download path rather than only the buffer: 3 entries without attachments, 6 with, including the `diagram(1).txt` collision rename. **One point of this finding I am recording rather than fixing, because it is right and it is about the framework, not the patch:** Codex checked applicability against `upstream/master` while our own gate checked it against `origin/master`, a mirror nobody syncs. That is precisely why the staleness went unnoticed, it is logged as **K-19** in `docs/DECISIONS.md` with the measurement, and Jan's answer to it is still open. **On the count of unrequired lines:** the ~84 lines Codex attributes to moving the two helper methods out of the controller are the g16c exception, and it found and cited that exception itself — noted, not disputed.

---

## Where I disagree with the previous rounds

I agree with the previous rounds' fixes for duplicate archive paths, orphaned pages, test-side algorithm duplication, helper visibility, locale wording and controller size. I also accept the documented decisions on hierarchy depth and attachment visibility. My disagreement is temporal: those rounds called the prepared branch clean against mirror r25037, but that cannot support a submission-ready verdict now that real trunk has moved to Rubyzip 3.6 and the exported feature patch no longer applies. F01 is not a rebuttal of their design review; it is the current INV-2/INV-8 gate they could not have run against later trunk.
