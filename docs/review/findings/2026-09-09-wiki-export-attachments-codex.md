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

- **Status:** open
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

**Resolution:**

---

## Where I disagree with the previous rounds

I agree with the previous rounds' fixes for duplicate archive paths, orphaned pages, test-side algorithm duplication, helper visibility, locale wording and controller size. I also accept the documented decisions on hierarchy depth and attachment visibility. My disagreement is temporal: those rounds called the prepared branch clean against mirror r25037, but that cannot support a submission-ready verdict now that real trunk has moved to Rubyzip 3.6 and the exported feature patch no longer applies. F01 is not a rebuttal of their design review; it is the current INV-2/INV-8 gate they could not have run against later trunk.
