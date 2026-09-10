# Review run — 2026-09-10 — claude-opus5-round4

- **Reviewer:** Claude Code (Opus 5), round 4 (Deel A of `docs/review/prompt-round4.md`)
- **Reviewed:** `patch/revision-branches` at `53faa9a0f` against its base `bee32a926` (r25037), and against real trunk `167e487ee` (r25065) for applicability
- **Dossier read:** `docs/features/revision-branches/dossier.md` — yes
- **Status read:** `docs/features/revision-branches/status.md` — yes
- **Ran the test suite:** partly — the six touched files in one process, with `tmp/test/git_repository` extracted so the Git adapter tests actually run. Not `test:all` for this feature; the r25037 baseline this dossier quotes (5977 runs) is the one I measured today for `imap-oauth` on the same revision, and it matches.
- **Scope covered:** every production line; the four new settings against INV-6; the regexp construction in both glob and regex mode; `git branch --contains` output parsing including the detached-HEAD and worktree marker lines; **URL generation for branch names containing slashes, uppercase letters, spaces and non-ASCII**, probed against the real router; which views render the changed partials, to check the "one command per page" claim; INV-5 across all five locales with every `label_branch` compared to its new plural; RuboCop both sides; INV-10 through `tools/check-symmetry.sh`; the dossier read as a submission; the screenshots opened and the three exclusion shots compared with `md5sum`.
- **Scope NOT covered:** no `test:all` and no `7.0-stable-GEOxyz` suite for this feature. I did not re-drive the browser, and I did not measure how long `git branch --contains` takes on a large repository — the dossier's cost argument is structural (one process per changeset) and I checked the structure, not the milliseconds.

## Summary

**No findings.** I went looking for a defect on five fronts and every one of
them held, so this file is mostly a record of what was attacked and why it did
not give.

The one I expected to land was URL generation. The patch links each branch name
with `:rev => branch`, and Redmine's `revisions/:rev/show` route constrains
`:rev` to `/[a-z0-9.\-_]+/` — no slash, no uppercase. Branch names with slashes
are the norm, and the settings screen's own example is `dependabot/*`. I probed
the real router with seven names and every one generates: Rails falls back to
`projects/:id/repository/:repository_id` and puts the branch in a query
parameter, so `feature/foo` becomes `?rev=feature%2Ffoo`. Then I found the
patch already pins exactly that, by name, in
`test_show_changesets_tab_should_display_the_branches_of_each_revision`, and
`shots/revision-branches.png` shows `dependabot/bundler/rails-8.1.4` and
`wip/experiment` rendered as working links. Three independent confirmations of
something I thought was a blocker.

The four new settings are the other thing a committer will stop at, and the
justification table gives a reason per setting that I cannot argue with,
including the honest paragraph about what reusing `repository_log_display_limit`
costs (you cannot tune "branches on the issue tab" apart from "revisions per
repository log page"). The `MailHandler` anchoring bug is reported and
deliberately not fixed, with the reason, which is INV-1 done right.

The i18n is the best in the register: each new `label_branch_plural` is the
exact plural of that file's existing `label_branch` (Branch/Branches,
Branche/Branches, Zweig/Zweige, Rama/Ramas), and the Dutch string reuses core's
own spelling `geassociëerde` from `label_associated_revisions` — which is
misspelled in core, and copying it is the right call under INV-5 and INV-1
rather than quietly correcting a word in a file this feature does not own.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0. The exclusion
settings are the one place I looked hard for scope creep, and the dossier's
own answer holds: without them the feature produces an unreadable list on any
repository with bot branches, which is the state `shots/revision-branches.png`
shows before exclusion.

## Evidence I re-measured

| Claim | What I measured | Same? |
|---|---|---|
| pristine trunk r25037: 5977 runs | **5977 runs** (measured today, same revision, matched lock) | yes |
| touched suites: 672 runs, 4271 assertions, 0 failures, 0 errors, 16 skips | **673 runs, 4273 assertions, 0 failures, 0 errors, 16 skips** | one run and two assertions more, inside the image variance `status.md` itself notes for this suite |
| RuboCop on the 10 changed files: 0, baseline 0 | **0** on all ten (rubocop 1.90.0) | yes |
| `tools/check-symmetry.sh revision-branches`: PASS | **PASS**, and its 30 locale keys read the same on both branches | yes |
| `tools/check-patch-clean.sh revision-branches --submit`: PASS | **PASS** against real trunk r25065 | yes |
| the three exclusion screenshots show different states | **confirmed** by `md5sum`: four distinct images, and the captions match what is in them — five branches unfiltered, two left after `.*/.*` | yes |
| each `label_branch_plural` follows its file's `label_branch` | **confirmed** in all five: Branch/Branches (en, nl), Branche/Branches (fr), Zweig/Zweige (de), Rama/Ramas (es) | yes |
| "one command per page" on the revision page | **confirmed**: `repositories/_changeset` is rendered by exactly two views, `revision.html.erb` and `diff.html.erb`, both single-changeset. The log table `_revisions.html.erb` does not render it, so there is no per-row fork there | yes, and the setting label "revision and diff pages" is accurate |

## What I attacked and what held

Recorded because a zero-finding review is only worth reading if it says what it
tried.

1. **Branch names that cannot be a URL segment.** Probed
   `url_for(:action => 'show', :rev => name)` for `main`, `feature/foo`,
   `Feature-X`, `dependabot/npm_and_yarn/lodash-4.17.21`, `release_1.0`,
   `wip-ä` and `a b`. All seven generate; none raises. Already covered by a
   test and a screenshot.
2. **`git branch --contains` output that is not a branch.** `line[2..]` handles
   the two-character marker column for both `* ` and `+ `, and
   `(HEAD detached at …)` is skipped by the `start_with?('(')` guard. A branch
   name that fails `scm_iconv` is dropped rather than inserted as nil.
3. **A pattern list typed one per line in the textarea.** `split(',')` leaves
   an embedded newline in the pattern, so it silently matches nothing. This is
   real, and it is **core's**: `MailHandler#accept_attachment?` is
   `setting_textarea` plus `split(',').map(&:strip)` in exactly the same shape,
   and the dossier says the new code is that method renamed. Copying it is
   right under INV-1; fixing it here would be scope creep in a file this
   feature does not own.
4. **`repository_log_display_limit` set to 0.** `display_changeset_branches?`
   requires `limit > 0`, so 0 means no branches. I checked that 0 means "show
   nothing" in core too — `latest_changesets(..., 0)` is `limit(0)` — so the
   two readings agree.
5. **An unbounded fan-out of git processes.** Bounded on the issue tab by the
   limit above, and structurally impossible on the log page because that view
   does not render the changed partial. The remaining cost, up to 100 processes
   on one issue tab at the default, is stated in the dossier in those words and
   recorded as exception E-02.

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks.

**I disagree with nothing, and the one thing I would flag is a compliment
rather than a finding.** The `MailHandler` anchoring paragraph — the patch
anchors `\A(?:pattern)\z` where core writes `\A#{pattern}\z`, so core's
`feature|hotfix` means "starts with feature or ends with hotfix" — is the model
for how INV-1 should read in a dossier: the difference is named, the reason is
given, the core bug is reported and not touched, and a test pins the new
behaviour. Three other features in this register have a "Found but not fixed"
list; this is the only one that explains a deliberate *divergence* from the code
it was copied from, in the submitted text, before a reviewer can call it an
inconsistency.

**One thing earlier rounds did that saved me time.** `status.md` says which
suites were run with `tmp/test/git_repository` extracted and which without.
That distinction is what let me compare my 673 runs against their 672 and
conclude "same environment, image variance" rather than "someone measured a
different thing". Every feature that touches SCM code should record it.

**Nothing in `docs/DECISIONS.md` looks wrong to me.**
