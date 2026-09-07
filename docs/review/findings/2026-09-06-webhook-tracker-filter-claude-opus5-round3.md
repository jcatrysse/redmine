# Review run — 2026-09-06 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** the two patch files in `patches/webhook-tracker-filter/`
  (`2026-09-05-r25037-feature.patch`, `-locales.patch`) applied to a pristine
  `origin/master` `bee32a926` (r25037). **Not the branch** — see F01: the branch
  `patch/webhook-tracker-filter` at `90d3f6775` is a different, older change,
  and what Jan attaches to the issue is the patch file.
- **Dossier read:** `docs/features/webhook-tracker-filter/dossier.md` — yes
- **Status read:** `docs/features/webhook-tracker-filter/status.md` (the "already settled" section) — yes
- **Round-1 findings read:** **no, deliberately.** This is the blind pass of
  ronde 3 (`docs/STATE.md`): `docs/review/findings/2026-09-03-webhook-tracker-filter-claude-opus5.md`
  was not opened before or during the review. `status.md` refers to round-2
  findings by number in passing (F07, F08) and those sentences were read, so the
  pass is blind to the round-1 reasoning but not to the fact that it existed.
- **Ran the test suite:** yes, both sides, in fresh worktrees with their own
  PostgreSQL 16 databases, the Git fixture repository extracted, and — this
  mattered — **the same `Gemfile.lock` on both sides**. See **Suite**.
- **Scope covered:** minimality, feature scope, settings surface, the migration
  and its shape against Redmine's own join tables, backward compatibility,
  authorization/strong parameters, callback ordering on `Tracker#destroy`,
  i18n and locale symmetry, tests as code, red-on-old-code by mutation, the
  dossier, INV-10 against `7.0-stable-GEOxyz`, and INV-9/G6 — which is where the
  blocker is.
- **Scope NOT covered:**
  - **No browser.** The 19 G9 screenshots were read, not reproduced.
  - **MySQL and SQLite.** Everything on PostgreSQL 16.
  - **No load test** of `hooks_for`; the dossier's N+1 table was read, not
    re-measured.
  - **The branch's own tests were not run**, because the branch is not the
    artefact under review (F01).

## Summary

The change itself is good and I have nothing substantive against it. It is
small, the compatibility guarantee (no tracker selected means every tracker) is
the right default and is pinned by a test that is green on both sides, the
migration is justified in the dossier and is identical in shape to
`projects_webhooks` from the same feature, and the K-11 deactivation is
implemented where it belongs — as a `before_destroy` on `Tracker`, ordered ahead
of the HABTM join-row deletion so `tracker_ids` is still readable when it runs.
I reproduced the dossier's red-on-old-code claim for that callback by mutation
and got exactly the message it records.

**The blocker is not in the change, it is in which change the branch holds.**
`patch/webhook-tracker-filter` is still based on r24882 and does not contain
`app/models/tracker.rb` at all — so it has no K-11 deactivation, and no
`Webhook#tracker_ids=` either. The patch files and `7.0-stable-GEOxyz` are
byte-identical to each other on all four production files; the branch is the odd
one out. That is the same defect class as the `wiki-export-attachments` blocker
from round 2, on a different slug.

Two things follow from it and both are worth more than the finding itself.
`tools/check-patch-clean.sh` — the check that exists to make INV-9 mechanical,
and that was strengthened in round 2 *because of* `wiki-export-attachments` —
reports **PASS** here, because when it cannot apply the patch to the branch's own
base it downgrades to a warning instead of failing (F02). And `status.md` states
that the patch files "reproduce the branch exactly (checked in a throwaway
worktree)", which is not true (F03).

**Counts:** blocker 1 · major 1 · minor 1 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

## Suite

Both sides run today, in `/home/user/wt/wtf-patched` (r25037 + both patch files)
and `/home/user/wt/wtf-trunk` (pristine r25037), PostgreSQL 16, Ruby 3.3.6.

| What | Result |
|---|---|
| touched suites in one process (`webhook_test`, `webhooks_controller_test`, `tracker_test`) | `66 runs, 213 assertions, 0 failures, 0 errors, 0 skips` |
| `test:all` with the patch | `5989 runs, 31400 assertions, 48 failures, 82 errors, 92 skips` |
| `test:all` on pristine trunk, same `Gemfile.lock` | `5977 runs, 31358 assertions, 48 failures, 82 errors, 92 skips` |
| delta | **12 runs — exactly the 12 new tests** (`grep -c '^+  test "'` on the feature patch gives 12) |
| failing names | **130 on both sides, `comm` empty in both directions** |
| RuboCop on the six changed `.rb` files | `6 files inspected, no offenses detected` |
| `tools/check-patch-clean.sh webhook-tracker-filter --submit` | PASS — but see **F02**, it could not run its most important check |

**Why those figures are 48/82 and not the usual 27/2, and why that is not the
patch.** A fresh `bundle install` now resolves **json 3.0.0**, and everything
that goes through `ActiveSupport::JSON.decode` raises
`ArgumentError: wrong number of arguments (given 2, expected 1)` — the whole
`Redmine::ApiTest::*` family, `Redmine::Views::Builders::JsonTest`,
`AutoCompletesControllerTest`, the `QueriesControllerTest` filter tests. I did
not assume this: the same error occurs on **pristine trunk r25037**, which is
what the second row above measures. `Gemfile.lock` is gitignored
(`.gitignore:44`), so two worktrees can resolve different gems; I copied the
lock from the patched side to the trunk side before bundling, which is the only
reason the two rows are comparable at all. Written up in `docs/traps.md`,
because it makes every suite figure recorded before today non-comparable with
one measured in a new worktree.

**Red on old code, reproduced by mutation.** The dossier verifies each new test
by removing its production hunk. I re-ran the one that matters most, since it is
precisely what the branch lacks:

```
# before_destroy :check_integrity, :deactivate_webhooks  ->  :check_integrity
$ ruby -Itest test/unit/webhook_test.rb -n "/deactivate_a_hook_whose_only_tracker/"
Expected true to be nil or false
1 runs, 1 assertions, 1 failures, 0 errors, 0 skips

# restored
2 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

That is the message the dossier records, word for word.

**Hypotheses driven and cleared:**

| Hypothesis | Outcome |
|---|---|
| the migration's shape is wrong — it has an `id` column and no unique index, unlike `custom_fields_trackers` | clean, and already answered. `projects_webhooks`, created by `CreateWebhooks` for this same feature, has exactly the same shape (`db/schema.rb:454`). The patch matches its neighbour, and the dossier's objections table already says so |
| `deactivate_webhooks` runs after the HABTM join rows are deleted, so `tracker_ids` would already be empty | clean — `before_destroy` is declared on line 31, `has_and_belongs_to_many :webhooks` on line 35, so the callback runs first. The ordering is load-bearing but a test covers it |
| INV-10: GEOxyz has drifted from the patch | clean, and the opposite of what I expected: GEOxyz `88d597548` is **byte-identical** to the patched trunk on `tracker.rb`, `webhook.rb`, `webhooks_controller.rb` and `_form.html.erb` |
| the 130 failures are the patch's | clean — identical on pristine trunk with the same lock |

---

### F01 — the branch holds an older design than the patch files: no K-11, no `tracker_ids=`

- **Status:** open
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** conventions (patch hygiene)
- **Where:** `origin/patch/webhook-tracker-filter` at `90d3f6775` (base `2563fa6a5` = r24882) versus `patches/webhook-tracker-filter/2026-09-05-r25037-*.patch`
- **Invariant touched:** INV-9, and INV-2's "standalone" half

**What is wrong**

The patch files touch twelve files. The branch touches eleven. The missing one
is `app/models/tracker.rb`, which is the entire K-11 implementation:

```
$ comm -23 <files in the patch files> <files on the branch>
   app/models/tracker.rb
```

`Webhook#tracker_ids=` is missing from the branch too — `grep` for it on
`origin/patch/webhook-tracker-filter:app/models/webhook.rb` returns nothing,
while both the patch file and `7.0-stable-GEOxyz` have it. So the branch is the
design as it stood before Jan decided K-11 (option C, 2026-09-05) and before the
round-2 hardening, and it never moved.

**Why a committer would push back**

They would never see it — this one bites us, and the failure path is the
submission procedure written in our own `status.md`. It says to run
`check-patch-clean --submit` just before submitting and, if trunk has moved, to
refresh the patch first (g05). A session that does that starts from the branch,
regenerates from r24882 + the old design, and produces a patch **without the
tracker deactivation** — silently, because the one check that compares branch
against patch file cannot run (F02). The result would be a hook that keeps
firing for every tracker after its only selected tracker is deleted, which is
the exact behaviour K-11 was chosen to prevent.

The tiebreak is unambiguous: two of the three artefacts agree. The patch files
and GEOxyz are byte-identical on all four production files; only the branch
differs.

**How I verified it**

Applied both patch files to a fresh `origin/master` worktree, then compared file
by file against the branch and against `origin/7.0-stable-GEOxyz`. Compared the
file lists with `comm`. Compared the branch's own diff against its base with the
patch file's diff, added/removed lines only, which shows `tracker_ids=`, the
`hooks_for` line split and eight tests present in the patch and absent on the
branch. Read `origin/patch/webhook-tracker-filter:app/models/webhook.rb`
directly to confirm `tracker_ids=` is not there.

**Suggested direction**

Rebuild the branch from current `origin/master` as one commit carrying the
design the patch files hold, exactly as round 2 did for
`wiki-export-attachments` and as this round did for `revision-branches`, and
keep the old tip under `archive/` so `90d3f6775` stays resolvable. The patch
files are the chosen design and should not be regenerated from the branch.

**Resolution:**

---

### F02 — `check-patch-clean.sh` reports PASS when it cannot perform the branch-versus-file comparison

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** conventions (tooling)
- **Where:** `tools/check-patch-clean.sh:207` and `:211`
- **Invariant touched:** INV-9 — this is the check that is supposed to make it mechanical
- **Note on ownership:** `tools/**` belongs to a session Jan explicitly asks for
  a framework change, so this is reported rather than fixed.

**What is wrong**

The drift check applies the patch to the branch's own merge base and compares
the result with the branch. When that apply fails, the script does:

```sh
else
  warn "cannot compare with $BRANCH: the patch does not apply to its own base ${base:0:9}"
```

`warn` prints a note and does not increment `fails`, so the script exits 0 and
prints `PASS — safe to submit`. The sibling branch at `:211`
("could not create a worktree") does the same. So the check silently opts out of
its most important comparison in exactly the circumstance that makes drift
likely: a branch that has fallen behind the patch files.

**Why a committer would push back**

Not a committer — us. Concrete: on this slug the script prints

```
  ok    applies to a pristine origin/master (r25037) checkout
  note  cannot compare with origin/patch/webhook-tracker-filter: the patch does
        not apply to its own base 2563fa6a5
PASS — safe to submit
```

and F01 walks straight through it. This is the check that round 2 added *because*
`wiki-export-attachments` had branch/file drift; the hole means it catches drift
only when the branch is fresh enough for the comparison to be possible, which is
the case where drift is least likely.

**How I verified it**

Read `tools/check-patch-clean.sh:190-212`, then ran
`tools/check-patch-clean.sh webhook-tracker-filter --submit` and observed the
`note` plus `PASS` with a real, material drift present.

**Suggested direction**

Make an impossible comparison fail rather than pass — the gate should say "I
could not verify this" and stop, not "safe to submit". Whether that is `fail`
outright or a `--submit`-only failure is Jan's call, but the current behaviour
means G6 can pass without ever checking G6's main claim. Fixing it needs Jan's
authorisation for `tools/**`.

**Resolution:**

---

### F03 — `status.md` claims an equivalence check that does not hold

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/webhook-tracker-filter/status.md:106-108`
- **Invariant touched:** INV-8

**What is wrong**

The evidence block says:

> Beide patchbestanden appliceren met `git am` los op een verse
> `origin/master`-checkout van r25037, en samen reproduceren ze de branch exact
> (gecontroleerd in een wegwerp-worktree).

The first half is true and I reproduced it. The second half is not: the patch
files reproduce a change the branch does not contain (F01). Whatever was checked
in that throwaway worktree, it cannot have been this.

**Why a committer would push back**

They do not read this file. It matters because it is the sentence a later
session would rely on to skip re-checking, and it is the same failure mode as
the stale K-06 line in `imap-oauth/status.md` and the guessed explanation
recorded in `docs/traps.md`: a claim written as measured that was not.

**How I verified it**

Read the file, then performed the comparison it describes: the patch files
applied to a fresh r25037 worktree differ from the branch in four of five
production and test files, and the branch is missing `app/models/tracker.rb`
entirely.

**Suggested direction**

Replace it with what is actually true once F01 is fixed — and state which of the
three artefacts was compared with which, since "reproduces the branch" is only
meaningful when the branch is the chosen design.

**Resolution:**
