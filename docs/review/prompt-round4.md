# Prompt — ronde 4: hercontrole + vergelijking met PR #1 (ansifi)

Voor Jan: dit bestand heeft **twee delen**. Deel A is een grondige hercontrole
van ons eigen werk. Deel B vergelijkt ons werk met de forward-port die **ansifi**
in [PR #1](https://github.com/jcatrysse/redmine/pull/1) maakte, met een score.

Draai ze **apart**, en Deel B als laatste — een reviewer die eerst onze regels
leest, is al bevooroordeeld over ansifi's werk, en Deel B zegt expliciet wat
daaraan te doen. Deel A is per onderdeel (de lijst staat in de prompt); Deel B
kan in één run, of per feature als je meer diepte wil.

---
---

# DEEL A — ronde 4, hercontrole van ons eigen werk

Plak vanaf hier.

---

You are reviewing prepared patches for **Redmine core**, and the company branch
that runs the same code, the way a Redmine committer would. You are the **fifth**
reviewer on this work. Rounds 1–3 were Claude; rounds 1–3 of an independent pass
were ChatGPT Codex. All of them are in `docs/review/findings/`, and **every
finding now carries a `Resolution:` line** — 172 findings across 63 review runs,
none open.

That is exactly why this round is worth running, and it changes what you should
attack. Do not re-do a broad sweep for its own sake; the cheap findings are gone.
Go where nobody has looked.

## Where nobody has looked yet — spend your effort here

1. **The tools are unreviewed code, and they are where the last two blockers
   were.** `tools/*.sh` now carry the quality gates, and no review round has ever
   read them as code. Both of the last two blockers were *in a gate*, not in a
   patch: `check-symmetry.sh` skipped every locale file while printing a global
   INV-10 PASS (Codex round 3), and before that `check-patch-clean.sh` could not
   see an AI committer identity at all (K-16). A gate that reports PASS over
   something it does not test is worse than no gate, because it is what the next
   session points at instead of reading the files. Read all of
   `tools/check-patch-clean.sh`, `tools/check-geoxyz-branch.sh`,
   `tools/check-symmetry.sh`, `tools/check-ownership.sh`, `tools/session-push.sh`,
   `tools/register.sh`, `tools/findings.sh`. For each, ask the one question that
   matters: **what can be wrong while this prints ok?** Try to make one print ok
   over a real defect. `check-symmetry.sh --self-test` is the pattern to imitate;
   it is also fair game to attack.
2. **Reproduce evidence, do not read it.** INV-8 is the invariant this framework
   exists for, and the failure mode is a number that was true once. Pick at least
   two features and re-measure their `status.md` claims end to end: the full
   suite counts, the RuboCop baseline *and* after-count, and whether each test
   the dossier calls "red on the old code" actually is. Several dossiers label
   some tests "guards, green on both sides" — check that the labelling is honest
   in both directions, i.e. that no test called discriminating is in fact a guard.
   A number that does not reproduce is a finding whatever the code does.
3. **Open the screenshots.** G9 claims a before/after pair per function, and the
   dossiers have verification tables naming each image. Look at the images in
   `docs/features/*/shots/`. Does each one show what its caption says? Is the
   "before" genuinely the unpatched instance? A screenshot that would look
   identical with and without the change is not evidence, and one round already
   found a pair that was the same image.
4. **Read the dossiers as submissions, not as documentation.** From "The problem"
   onwards each one is what gets pasted onto redmine.org. Is the argument honest?
   Does the objections table answer the objection a committer would actually
   raise, or a softer one? Is any measurement quoted without its conditions? Is
   there a place where we describe a limitation in a way a reviewer would call
   burying it?
5. **The `.patch` files are the artefact.** A committer downloads those, not the
   branch. Check each file under `patches/<slug>/` applies to current real trunk
   and matches its branch — and note that our own gate measures against
   `origin/master`, which is a **mirror** Jan syncs by hand (K-19, option A). Fetch
   `https://github.com/redmine/redmine.git master` yourself and say whether the
   gate's answer is currently a statement about trunk or about the mirror.

## Where things are

Repository `jcatrysse/redmine`. Start on `geoxyz/framework` and read `CLAUDE.md`
first — ten invariants (INV-1..10), nine gates (G1..G9), a table of forbidden
constructs where every row is a real defect found in this codebase.

```sh
git fetch --unshallow origin geoxyz/framework   # the clone may be shallow with
                                                # two grafted roots
git checkout geoxyz/framework
git fetch origin 'refs/heads/patch/*:refs/remotes/origin/patch/*'
git fetch origin master 7.0-stable 7.0-stable-GEOxyz
```

| Branch | What it is |
|---|---|
| `geoxyz/framework` | orphan branch, **no Redmine code**: rules, dossiers, exported patches, findings |
| `patch/<slug>` | one prepared upstream patch, branched from `origin/master` |
| `7.0-stable-GEOxyz` | what the company runs: upstream 7.0-stable plus the same changes |
| `origin/master` | a mirror of Redmine trunk that nobody syncs automatically |

Current tips, so you can tell drift from a defect:

| Slug | Patch branch | Upstream |
|---|---|---|
| `assignee-nobody` | `d0243086d` | patch ready |
| `imap-oauth` | `45893a712` | patch ready |
| `mypage-query-blocks` | `3fc86ca5b` | patch ready |
| `revision-branches` | `53faa9a0f` | patch ready |
| `search-token-limit` | `587d9a11b` | patch ready |
| `version-subprojects` | `6ad109efe` | patch ready |
| `webhook-issue-closed` | `f3234c1ec` | patch ready |
| `webhook-tracker-filter` | `cb4972a5c` | patch ready |
| `wiki-export-attachments` | `eed205828` | patch ready |

`7.0-stable-GEOxyz` is at `32659b6f7`, current with upstream `7.0-stable`.
`ar-sessions`, `ldap-mail-prefs`, `members-pagination`, `geoxyz-hosts` and
`gitignore-credentials` are company-local (`upstream: nooit`) and live only there.

## What to read, and what deliberately not to read

**Read:** `CLAUDE.md`; `docs/features/<slug>/dossier.md`;
`docs/features/<slug>/status.md` **including its "wat er al bekend is" section**
(Dutch — settled trade-offs, so you do not spend effort reopening them);
`docs/DECISIONS.md` (Jan's decisions `g01`..`g18` and `K-01`..`K-19` — **do not
re-litigate these**; if you think one is wrong, say so once as a question in your
summary); `docs/redmine-requirements.md`; `docs/exceptions.md`; `docs/traps.md`;
`docs/runbook.md`.

**Do not read until you have written your findings:** `docs/review/findings/**`.
Form your own view first, then compare and tell us where you disagree. That
section is the most useful part of the deliverable.

## The onderdelen — pick one per run

The nine patches, the five company-local features, plus two subjects that are not
features:

`assignee-nobody`, `imap-oauth`, `mypage-query-blocks`, `revision-branches`,
`search-token-limit`, `version-subprojects`, `webhook-issue-closed`,
`webhook-tracker-filter`, `wiki-export-attachments`, `ar-sessions`,
`ldap-mail-prefs`, `members-pagination`, `geoxyz-hosts`,
`gitignore-credentials`, **`geoxyz-branch`** (the integrated branch as a whole),
**`tools`** (the gates as code — see point 1 above; this is the one I would run
first).

## The standard you are applying

**Would you commit this to trunk as it stands?** Concretely:

- **Minimality (INV-1).** Count the lines in the diff the feature does not
  require. If that number is not zero, say which — and check `docs/exceptions.md`
  before calling it a defect, because one such move is recorded there (g16c).
- **Correctness.** Name a concrete failure path: these inputs or this state
  produce this wrong outcome. If you cannot write that sentence, mark it
  speculative or a nit rather than inflating it.
- **Conventions.** Redmine's own comment density is 29% of methods carrying a
  comment line directly above them, and about one comment line per eighty lines
  *inside* method bodies. A short comment above a new method is normal; one
  restating a line inside a method is not.
- **Tests.** Are they discriminating? A test that passes on the unpatched code
  proves nothing. A test that reimplements the code it tests passes when both are
  wrong.
- **i18n (INV-5).** Only `en`, `nl`, `fr`, `de`, `es`, and every translation
  derived from the nearest existing key in that same file, with the key named in
  the dossier. Check the cited keys exist and say what is claimed.
- **The dossier.** Is the case honest? Does it hide a bad measurement?

## How to run things

`docs/runbook.md` is accurate and was established by running it. PostgreSQL 16,
Ruby 3.3.6, write `config/database.yml` yourself (gitignored, and the `Gemfile`
reads it to decide which database gems to load, so `bundle install` after). No
`rake` binstub — use `bundle exec ruby bin/rails <task>`.
`tools/test-env.sh <worktree> bundle exec ruby bin/rails test:all` makes the
system tests runnable; without it you get ~260 errors unrelated to any patch.
The full suite is about 15 minutes, so start it early and read code while it runs.

Extract the SCM fixtures or the repository tests skip **silently**:

```sh
mkdir -p tmp/test
gunzip < test/fixtures/repositories/git_repository.tar.gz | tar -x -C tmp/test
```

**Comparing two suite runs only means something if both sides have the same
`Gemfile.lock`.** The lock is not in git. Copy it from one worktree to the other
before running a baseline, or you are comparing two different Redmines.

## Two things already known, so you need not rediscover them

- **`origin/master` is a mirror Jan syncs by hand** (K-19, option A). A
  `--submit` PASS is a statement about the mirror unless you check the gap
  yourself: `git fetch https://github.com/redmine/redmine.git master` then
  `git rev-list --count origin/master..FETCH_HEAD`.
- **Suite baselines of `48 failures, 82 errors`** in older evidence are the
  json 3.0 gem, not a regression; trunk pinned it in `9a74cdf20` (#44428).
  Current baselines are `27 failures, 2 errors` on trunk (SCM tools absent from
  the image) and fully green on `7.0-stable-GEOxyz`.

## What you must not do

- **Do not change code, tests, or documents.** A reviewer never fixes; the fixing
  session owns the design. Propose a direction, not a patch.
- **Do not weaken, skip, or delete a test**, not even to demonstrate a point.
- **Do not claim verification you did not perform.** "Read-only, not executed" is
  a good answer and far more useful than an implied test run. An unstated gap
  reads as "clean", which is the one failure mode that matters here.

## Deliverable

One file per onderdeel at `docs/review/findings/<YYYY-MM-DD>-<slug>-<reviewer>-round4.md`,
copied from `docs/review/findings/TEMPLATE.md`: a header block saying what you
read and what you ran, a plain-language summary an intelligent non-specialist can
follow, a `**Counts:**` line, then one `### F01 —` block per finding with
`Status`, `Severity` (blocker/major/minor/nit/question), `Confidence`,
`Category`, `Where`, `Invariant touched`, and the four prose sections. Leave
`**Resolution:**` empty — the fixing session fills it in.

Severity means what it says. A **blocker** must not be submitted; a **major** is
something a committer would refuse over; a **minor** is worth fixing first; a
**nit** is one line of thought; a **question** is a judgement call for the owner.
Do not inflate: two real majors are worth more than twenty nits.

Then, and only then, read `docs/review/findings/**` and add a final section
**"Where I disagree with the previous rounds"** — anything they called clean that
you would not, anything they flagged that you think is a non-issue, and any
`Resolution:` you find unconvincing. Be specific about which resolution.

If you run out of time, say so in the header and report what you covered. An
honest partial review is useful; a complete-looking one with unstated gaps is not.

---
---

# DEEL B — vergelijking met PR #1 (ansifi), met score

Plak vanaf hier, in een aparte run.

---

You are comparing **two independent implementations of the same eighteen-item
list**, and scoring them. This is unusually clean as comparisons go: both sides
forward-ported the same GEOxyz 5.1 customisations to Redmine 7.0, from the same
starting point, without coordinating.

- **Side A — ansifi**, [PR #1](https://github.com/jcatrysse/redmine/pull/1)
  "GEOxyz 5.1 → 7.0: selective forward-port". Draft, open, 14 commits, 72 files,
  +2358/−57. Head `5693540cd`, authored 2026-07-29 to 2026-08-12. The PR body is
  a per-feature checklist with its own classification (obsolete / straightforward
  / deferred / complex) and a test plan — read it, it is the author's own account
  of what they did and why.
- **Side B — us**, nine `patch/<slug>` branches against trunk plus
  `7.0-stable-GEOxyz` at `32659b6f7`, with a dossier, a status file and review
  findings per feature.

**The fork point of both sides is `a7fe622f92`** (upstream 7.0-stable,
2026-07-26, pure upstream — no GEOxyz commits). From there ansifi has 14 own
commits and we have 90. Note that GitHub reports the PR's `base.sha` as
`88d5975489`, which is **not** the fork point — it is one of *our* later commits,
because the base branch moved under the PR. Diffing against it will mislead you.

```sh
git fetch origin 'refs/heads/patch/*:refs/remotes/origin/patch/*'
git fetch origin master 7.0-stable 7.0-stable-GEOxyz
git fetch origin refs/pull/1/head:refs/remotes/origin/pr-1   # ansifi's head
FORK=a7fe622f92
```

## Read the PR before you read our rulebook's opinion of it

This matters more than anything else in Part B, so it comes first.

`CLAUDE.md` has a table of "forbidden constructs" and says of it: *"Every row
below is a real defect found in the existing GEOxyz code or its 2026 port."* The
2026 port **is** this PR. Our own rulebook is therefore a document written partly
about ansifi's work, by the side you are scoring. Several of our documents also
cite it by way of specific accusations, among them:

- ~73 lint offences, "half of them trailing whitespace and missing final newline"
- a link that was in the DOM, passed `assert_select`, and did nothing when
  clicked because its JavaScript was never loaded on that page (cited as the
  reason G9 exists)
- a top-level `def` in a `.rake` file, defining private methods on `Object`
- `.html_safe` on text from user, SCM or mail input
- `sub(...)` where every occurrence had to go
- an instance variable assigned inside a view or partial

And the strongest one, because it is the claim that justified our starting over
rather than building on PR #1 — `docs/DECISIONS.md`, Jan's decision of
2026-09-01: *"zijn commits dragen de negen geërfde bugs en 73 lint-fouten"*
(his commits carry the nine inherited bugs and 73 lint errors). **Jan's decision
itself is settled and not to be reopened** — every feature had to be redesigned
for upstream anyway, so the restart cost nothing. But "nine inherited bugs" is a
checkable claim, and nowhere in our documents are those nine enumerated. Find
out whether they exist, and name them if they do.

**Verify each of those against `5693540cd` before you accept any of them**, and
report per claim: still true, was true and since fixed, or never true. Run
RuboCop yourself and give the number. If our characterisation of ansifi's work is
overstated, that is one of the most valuable findings you can produce, because it
is currently load-bearing in our own rules.

Conversely: our commits carry Jan's identity because INV-4 requires it, and two
of ansifi's commits carry `Co-authored-by: Cursor <cursoragent@cursor.com>`. Note
that as a fact under hygiene, relevant to what may be submitted upstream. **Do
not treat authoring tooling as a quality signal** — it says nothing about whether
the code is right.

## The feature map

Both sides cover the same list. Use this to line them up; verify it rather than
trusting it.

| Feature | ansifi commit | our upstream patch | our GEOxyz commits (from `docs/REGISTER.md`) |
|---|---|---|---|
| assignee `<<nobody>>` | `031bff8a1` | `patch/assignee-nobody` | `349fe1860 + 9ad87a11b` |
| target version + subprojects | `d8f19ff00` | `patch/version-subprojects` | `fd35bd2d1 + 157c171a5 + 74f343d3d + 73157aee5` |
| search token limit | `cd60c0b63` | `patch/search-token-limit` | `6695461bd + 1cd7091fd` |
| gitignore credentials | `9d0d8e937` | — (company-local) | `af0af806d + 737b0a549` |
| `*.geoxyz.eu` hosts | `f93620ba4` | — (company-local) | `075c86e8a + 363686456` |
| My page block limit | `256e7ff0d` | `patch/mypage-query-blocks` | `dc6dad120 + dd063fa8b + f5ed23c8e` |
| members/groups pagination | `b1a9fbb6e` | — (company-local) | `148faafb6 + 02ca8b044 + 22a4244c0 + 8fb5c8b8a` |
| LDAP mail preferences rake | `2f5d58d2f` | — (company-local) | `bc7314a62 + 5b4943570 + f00b41afd + ae2417a6e` |
| AR sessions | `70cd8113f` | — (company-local) | `bc745ce73 + 22daa7c96 + 5b04c5c15 + bf5b41a0d` |
| wiki export | `0832bb3d0` | `patch/wiki-export-attachments` | `6078281ff` |
| branches in views | `1e726250f + 1b8d5862c` | `patch/revision-branches` | `ff0d23b62 + 755d763a8 + 88d597548` |
| webhook extras | `798714bd7` | `patch/webhook-issue-closed` **and** `patch/webhook-tracker-filter` | `465d326aa` / `c6631e937 + 86647653e + 72058fa43 + 8ac09f4ff` |
| IMAP OAuth 2.0 | `5693540cd` | `patch/imap-oauth` | `1a6d462a8 + d92dff560 + 5c937ddbd + 75f355fa8 + 90afb7872` |
| net-imap CVE bump | skipped | — | — (we also dropped it) |
| auto-watch defaults | skipped | — | — (already upstream) |
| `database.yml` ERB | deferred | — | — (still `todo` for us too) |
| whole-wiki TXT export | **shipped** (`0832bb3d0`) | **dropped** | **none** — Jan's K-03 |

Compare **per feature against each side's own base**, never the two tips against
each other; the tips are five weeks apart in upstream terms and the diff would be
mostly drift:

```sh
git show <ansifi commit>                                        # side A
mb=$(git merge-base origin/master origin/patch/<slug>)
git diff $mb origin/patch/<slug>                                # side B, upstream
git show <each GEOxyz commit>                                   # side B, company
```

## Four differences I already know about — check them, then look for others

These are the ones visible from the two descriptions. They are starting points,
not the answer, and I may be wrong about any of them.

1. **`search-token-limit` — capability removed.** ansifi kept the 5.1 behaviour
   and made the limit a configurable admin setting, `0` meaning unlimited. We
   deliberately removed the setting and shipped it as a bugfix instead (Jan's
   K-04, option A: the global search keeps its five-token limit, text filters
   lose theirs). So if GEOxyz actually wanted the setting, **we removed something
   the company had.** Is that a loss in practice, or is the setting a thing nobody
   would have touched? Say which, and score GEOxyz fitness accordingly.
2. **IMAP OAuth — two very different shapes.** ansifi added a separate
   `receive_imap_oauth2` task, token files on disk, and two provider-specific
   documents (`doc/GMAIL_IMAP_OAUTH.md`, `doc/O365_IMAP_OAUTH.md`). We put two
   options on the existing `receive_imap`, cache no token, and have one generic
   authorization task that reads all provider specifics out of a credentials
   file. Ours is shaped for upstream; ansifi's ships operator documentation **in
   the repository**, which ours does not — our walkthrough lives in a dossier
   that is not on the company branch, so a GEOxyz operator has nothing in-repo.
   Which of those is the better deliverable *for GEOxyz*, as opposed to for
   redmine.org? Also: ansifi verified a **live Gmail OAuth fetch that created a
   real issue**. That is stronger evidence than anything we have on the one thing
   we could never test — weigh it as such.
3. **`ldap-mail-prefs` — different selection entirely.** ansifi ports the 5.1
   design: users belonging *only* to the holding group `ldap_sync_users`, with a
   `GROUP=` override. We rebuilt it on Jan's corrected goal (g01) as
   `auth_source_id IS NOT NULL`, with a dry run by default, a journal of previous
   values, and an undo. Check both against what the task is actually for, and
   note that ours is far larger for it.
4. **`ar-sessions` — session serializer.** Neither PR body nor commit message
   mentions a serializer on ansifi's side; ours is JSON with a custom
   `Redmine::SessionDataSerializer` plus a deploy-time check, because Marshal in
   `sessions.data` is deserialised before anything is verified. Confirm what
   ansifi's branch actually configures, and if it is Marshal, say what that costs
   and whether the one-off logout ours requires is worth it.

Then go looking for what I have not listed. Two questions in particular:

- **What does ansifi have that we do not?** Anything in PR #1, or in the 5.1
  branch it ports from, that our register does not cover at all — or covers as
  `vervallen` / `n.v.t.` where GEOxyz may still want the behaviour. The
  whole-wiki TXT export is the one I know of and it is Jan's own decision (K-03,
  not to be reopened), but say whether ansifi's implementation of it was any
  good, since if GEOxyz ever wants it back that is the starting point.
- **What did we get wrong that ansifi got right?** Not "differently" — wrong.
  A place where their reading of the 5.1 behaviour, of Redmine 7.0, or of what
  the feature is for beats ours.

## The score

Per feature, per side, score these six axes 0–5:

| Axis | What it measures |
|---|---|
| **Correctness** | edge cases, failure modes, wrong-answer paths |
| **Upstream acceptability** | would a Redmine committer take this to trunk |
| **GEOxyz fitness** | does it do what the company actually needs, operably |
| **Evidence** | tests that discriminate, numbers, live verification |
| **Maintenance cost** | divergence from upstream, private-patch surface (5 = least) |
| **Hygiene** | conventions, comment density, i18n, lint, minimality |

Anchors, so the numbers mean the same thing across features:

- **5** — a committer would take it as it stands; nothing to add
- **4** — accepted after a cosmetic change
- **3** — sound, but needs work a reviewer would name
- **2** — works, with a defect or gap that matters
- **1** — works in the happy path only
- **0** — wrong, or absent

**Every score needs one line of justification citing a `file:line`, a command you
ran, or a measured number.** A score you cannot cite is void — write `n/e` (no
evidence) instead of guessing, and count it as neither side's. Say plainly how
many cells ended up `n/e`; a comparison that is a third guesswork should say so.

Report:

1. a table per feature, twelve cells (six axes × two sides), plus a per-feature
   total out of 30 and a one-sentence verdict naming the winner or a draw;
2. per-axis totals across all features, per side — this is the part Jan can act
   on, because it says *where* one side is stronger rather than just that it is;
3. one headline number per side (percentage of available points), with the
   explicit caveat that the six axes are **not** equally important to Jan and the
   per-axis table is what to reweigh;
4. **"What we forgot"** — a plain list, most important first;
5. **"Where ansifi is better"** — required to be non-empty or to state
   explicitly that you looked and found nothing, with what you checked. A
   comparison written by the interested party that finds the interested party
   won on every axis is not a finding, it is a mirror.

Handle asymmetry explicitly: for a feature only one side implemented, score the
side that has it and mark the other `absent (0)` on Correctness and GEOxyz
fitness only — not on the other four, where absence is not a quality.

## What you must not do

Same as Part A: change nothing, weaken no test, claim no verification you did not
perform. Additionally: **do not review ansifi as a person.** The PR is a draft,
explicitly marked "Full branch review before marking Ready for merge" as its last
unchecked box, and it was never claimed to be finished. Judge the code at
`5693540cd` against what it set out to do, which its own PR body states.

## Deliverable

`docs/review/findings/<YYYY-MM-DD>-pr1-comparison-<reviewer>.md`. The findings
template does not fit a comparison, so use this shape instead: the same header
block (what you read, what you ran, scope covered, scope NOT covered), a
plain-language summary, then the four numbered reports above. Anything that is a
**defect in our work** also gets a normal `### F01 —` block, because that is what
the fixing session works from; a defect in ansifi's work does not need one, since
nobody here is going to fix it — describe it in the comparison and leave it.
