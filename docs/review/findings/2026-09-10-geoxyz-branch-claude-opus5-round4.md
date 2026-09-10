# Review run — 2026-09-10 — claude-opus5-round4

- **Reviewer:** Claude Code (Opus 5), round 4 (Deel A of `docs/review/prompt-round4.md`)
- **Reviewed:** `origin/7.0-stable-GEOxyz` at `43246a900` as an integrated branch, against `origin/7.0-stable`. This is the onderdeel that is not a feature: what the other fifteen runs cannot see is what happens where two of them meet.
- **Dossier read:** all nine feature dossiers were read across today's runs; none of them is this onderdeel's
- **Status read:** yes, all of them, over the course of the day
- **Ran the test suite:** yes — the **full** `test:all` on this branch tip, today, after the `version-subprojects` fix landed on it.
- **Scope covered:** the branch's merge state and own-commit accounting; **every file in the branch diff traced back to an own commit, and every own commit's file traced forward into the diff**, which is the file-level counterpart of K-21's commit-level check; the files more than one feature touches, and whether the combined result is coherent; INV-10 for all nine features at once; the lint measurement, which I re-established after fixing the gate; the full suite.
- **Scope NOT covered:** no browser. I did not re-read the nine features' code here — that was the other fifteen runs — only what they do to each other.

## Summary

**One finding, a nit, and it is the only kind of thing this onderdeel can
produce that the others cannot.**

The accounting is clean in both directions. All 90 files in the branch diff are
touched by an own commit, and the two files that own commits touch without
appearing in the diff are both deliberate reversals with a visible reason:
`lib/redmine/acts/webhookable.rb` was changed by `7d85538f3` and put back by
`465d326aa` when the `issue.closed` timestamp mapping moved into the
issue-specific concern, and `lib/tasks/disable_mail_ldap_users.rake` was added
by `2ac1de3c6` and deleted by `bc7314a62` when the LDAP task was replaced by
the reversible one. Neither is residue.

The files several features share are where I looked hardest.
`app/models/query.rb` carries `assignee-nobody` and `version-subprojects`;
`test/unit/webhook_test.rb` carries both webhook features;
`config/settings.yml` carries `mypage-query-blocks` and `revision-branches`;
`config/application.rb` carries `ar-sessions` and `geoxyz-hosts`. In every case
the two changes are in different methods or different keys and cannot see each
other — except one, and that is the finding.

**And the lint number for this branch is now a real number.** The G8 gate used
to report "1 offence (baseline 1)" for it; that was the gate, not the branch,
and it is fixed today at Jan's request. The branch's honest figure is **8 and
8** — the same eight `Rails/StrongParametersExpect` and `Style/DirectiveScope`
offences on upstream's own lines, on both sides. The branch adds none.

**Counts:** blocker 0 · major 0 · minor 0 · nit 1 · question 0

**Lines in the diff not strictly required by the features:** 0 that I can name
at branch level.

## Evidence I re-measured

| Claim | What I measured | Same? |
|---|---|---|
| the full suite is green here | **6165 runs, 32522 assertions, 0 failures, 0 errors, 39 skips**, on this tip, today | yes |
| `tools/check-geoxyz-branch.sh`: PASS | **PASS** — nothing to merge, no AI traces in 49 own commits, no AI identity in author or committer, all 47 recorded shas present, every own non-merge commit recorded against a feature, locales within the five | yes |
| lint adds nothing | **8 on the branch, 8 on `origin/7.0-stable`, added 0** — measured with a lockfile in both worktrees. The gate printed 1 and 1 until today | conclusion yes, numbers no |
| `tools/check-symmetry.sh --all`: PASS | **PASS** for all nine, with the one allowed divergence on `wiki-export-attachments` (the `itcpdf` inflection) | yes |
| every changed file belongs to a feature | **confirmed both ways**: 90 files in the diff, all touched by an own commit; 92 files touched by own commits, the two extra being the reversals above | yes |

## What I attacked and what held

1. **`app/models/query.rb` with two features in it.** `assignee-nobody` adds
   `match_null` inside `sql_for_field` and a value to `assigned_to_values`;
   `version-subprojects` rewrites `fixed_version_values`. Different methods.
   They do compose in one place — `fixed_version_id` is a
   `list_optional_with_history` filter, so on this branch a hand-written URL
   can ask for "no target version, or version X" while the value list also
   offers the subprojects' versions — and the composition is coherent, because
   `match_null` operates on the submitted values and `fixed_version_values`
   only builds the offered list.
2. **`config/application.rb` with `ar-sessions` and `geoxyz-hosts` in it.** The
   session store block and `config.hosts` are unrelated lines in different
   environments' configuration.
3. **`config/settings.yml` with two features' settings.** Four keys from
   `revision-branches`, one from `mypage-query-blocks`, no overlap, and both
   sets sit next to their thematic neighbours.
4. **The branch having tests of its own.** It has none: its test suite is
   exactly the union of the nine features' tests. That is what makes finding
   F01 possible.

---

### F01 — the two webhook features meet in one method on this branch and nothing exercises the combination

- **Status:** fixed
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `app/models/webhook.rb`, `Webhook.hooks_for`; `test/unit/webhook_test.rb`
- **Invariant touched:** none

**What is wrong**

`webhook-tracker-filter` adds `hook.matches_tracker?(object)` to the predicate
in `Webhook.hooks_for`, and `webhook-issue-closed` adds `issue.closed` to the
events that reach it. On the two patch branches those changes never meet:
each is branched from trunk on its own, which is exactly what INV-2 requires.
On `7.0-stable-GEOxyz` they are in the same method, and the fifteen tests
between them all hold the other feature at its default — the tracker tests use
`events: ['issue.created']`, and the closed tests set no tracker restriction.
No test asks whether a hook subscribed to `issue.closed` **and** restricted to
one tracker fires for closing an issue of that tracker and stays silent for
another.

**Why a committer would push back**

They will not: this combination cannot exist upstream until both patches are
accepted, and neither patch should carry a test for the other. The cost is
GEOxyz's. Reading the code, the composition is safe by construction — the
predicate is `hook.events.include?(event) && hook.matches_tracker?(object) &&
…`, two independent terms on the same object, and an Issue always has a
`tracker_id` so `matches_tracker?` never short-circuits on the
`respond_to?` branch. So this is coverage, not a suspected defect. What makes
it worth a line is that the branch has **no tests of its own at all**: its
suite is the union of the nine features' suites, so any interaction between two
features is by definition untested, and this is the only place in the branch
where two features actually meet in one expression.

**How I verified it**

Listed the tests in `test/unit/webhook_test.rb` on the branch: seven tracker
tests, eight `issue.closed` tests, no test naming both. Read `hooks_for` on the
branch to confirm the two conditions are independent `&&` terms.

**Suggested direction**

One test on the GEOxyz branch — a hook with `events: ['issue.closed']` and
`trackers: [<one tracker>]`, closing an issue of that tracker and then one of
another — and a line in whichever `status.md` owns it saying that the test
exists because the combination is GEOxyz-only. It must **not** go into either
patch branch: that would put one feature's subject into the other's diff and
break INV-1 and INV-2 both. Which of the two feature files records it is a
judgement for the owner; `webhook-tracker-filter` is the one whose predicate
grew.

**Resolution:** fixed, 2026-09-10, on `7.0-stable-GEOxyz` only, which is where the combination
exists. `should apply the tracker filter to the issue closed event as well`
puts a hook on `events: ['issue.closed']` **and** `trackers: [1]` and asserts it
is returned for closing an issue of tracker 1 and not for one of tracker 2:
1 run, 2 assertions, 0 failures. It is deliberately in neither patch — putting
it there would drag the other feature's subject into that diff and break INV-1
and INV-2 — and `docs/features/webhook-tracker-filter/symmetry-allow.txt` now
records every line of it with that reason, so INV-10 stays mechanical rather
than being waived.

Two things the fix taught, both recorded where the next session will meet them.
`check-symmetry.sh` strips lines beginning with `#` from an allowlist before
matching, so a **comment** in GEOxyz-only source can never be allowlisted and
would hold the gate red permanently; the test therefore carries no comment and
the reason lives in the allowlist, the commit message and `status.md`
(`fd2365dc3`). And that second commit exists at all because the first attempt
amended `1483f01e2` after it had been pushed — a rewrite of the production
branch, which CLAUDE.md forbids outright. It was caught before any force push:
`git reset --soft origin/7.0-stable-GEOxyz` put the pushed commit back and the
change went on top as an ordinary commit.

---

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks.

**K-21 checked commits against the register in both directions; nobody had
checked files.** The gate now answers "is every own commit recorded against a
feature" and "does every recorded sha exist", which is what made those five
unregistered commits visible. The file-level counterpart — is every file in the
branch diff attributable, and does every file an own commit touched still show
up — is a different question, and it is the one that would catch residue from a
reverted change rather than an unrecorded commit. I ran it by hand today and it
is clean, with two explained reversals. It is cheap enough to be worth adding to
the gate if anyone touches it again; I am not filing that as a finding because
the branch is clean and the gate already grew twice this week.

**The branch having no tests of its own is a deliberate consequence of the
whole design and it should stay that way, with one exception.** Every test on
this branch came in with the feature that needed it, which is what keeps
`check-symmetry.sh` able to say "every substantive line is on both sides". A
GEOxyz-only test breaks that symmetry by construction — which is precisely why
F01 has to name where it goes and why, rather than being dropped in.

**Nothing in `docs/DECISIONS.md` looks wrong to me.** K-13 (rewrite the AI
identities and force-push once) is the decision this branch would be least able
to recover from if it had been made later; done at 33 commits it cost one
afternoon, and the gate that now refuses such a push at source is the reason it
cannot recur.
