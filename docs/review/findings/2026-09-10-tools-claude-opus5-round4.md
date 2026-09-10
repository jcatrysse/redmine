# Review run — 2026-09-10 — claude-opus5 (ronde 4, onderdeel `tools`)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `tools/**` on `geoxyz/framework` at `902df6e` — the quality gates as code, not any patch
- **Dossier read:** n.v.t. — this onderdeel has no feature dossier
- **Status read:** `CLAUDE.md`, `docs/STATE.md` — yes. `docs/DECISIONS.md` skimmed for K-01/K-13/K-16/K-19 and g13 only
- **Ran the test suite:** no — Redmine's suite is not what this onderdeel tests. What I did run is listed below, and it is the point of the round
- **Scope covered:** read line by line: `check-patch-clean.sh`, `check-geoxyz-branch.sh`, `check-symmetry.sh`, `check-ownership.sh`, `session-push.sh`, `register.sh`, `findings.sh`, `claim.sh`, `append-note.sh`, `test-env.sh`, `verify-lib.mjs`, `dev-server.sh`. Executed: `check-geoxyz-branch.sh`; `check-patch-clean.sh <slug> --submit` for all nine slugs; `check-symmetry.sh --all` and `--self-test --all`; `check-ownership.sh` with a planted foreign file; `register.sh`; `findings.sh` and `findings.sh --open`. Built three synthetic defects and asked the gates to find them (two they missed).
- **Scope NOT covered:** `tools/dev-seed.rb` (skimmed, not audited); `dev-server.sh` audited by reading, never executed (no Redmine worktree in this session); **no lint measurement of any kind is possible in this image — rubocop is not installed anywhere**, which is itself F02; the other fifteen onderdelen (the nine patches, the five company-local features, `geoxyz-branch`); ronde-4 points 2 (re-measuring a feature's `status.md` numbers), 3 (opening the screenshots) and 4 (reading the dossiers as submissions) belong to the feature onderdelen and I did not do them.
- **Findings read first?** No. `docs/review/findings/**` was left unread until this file was written, per the prompt. One unavoidable leak: running `tools/findings.sh` to test it printed the summary table, so I saw finding titles and a handful of `Resolution:` strings. I did not open any findings file.

## Summary

The tools are the only code in this repository nobody had reviewed, and they
turned out to hold the same class of defect they were built to catch: a gate
that prints `ok` over something it never looked at.

Two are blockers. First, the check that keeps AI attribution out of a submitted
patch (`check-patch-clean.sh`, check 3) reads **only the first `.patch` file**
of a slug. Five of the nine slugs ship two files, so half of what gets attached
to a redmine.org issue is never scanned for the very thing INV-4 exists to
prevent — and the gate says "ok no AI trace" while doing it. I planted a
`Co-authored-by: Claude` line in a copy of the second file and the gate's own
pipeline came back empty. Second, `check-geoxyz-branch.sh` prints **PASS** when
rubocop is missing, and rubocop is missing from this image. So the run I did
today reports a healthy branch having never measured lint at all. Its sister
script `check-symmetry.sh` refuses to run without Ruby for exactly this reason,
with a comment saying so; this one shrugs and continues.

The four majors are of the same family. `check-symmetry.sh` only ever asks
"is each line of the patch also on GEOxyz?" — never the reverse — so I added an
unrelated `raise Unauthorized unless User.current.admin?` to GEOxyz alone and
the gate reported a global INV-10 PASS. `session-push.sh` is the only mandatory
chokepoint in the whole framework, and its AI-identity pattern is the weakest of
the three in the repository: a Cursor, Copilot, Codex or `@claude.ai` identity
walks straight through a guard that the audit gates would catch, and on the
first push of a new `patch/*` branch the guard compares against a ref that has
not been fetched, which makes it pass without testing anything.
`docs/REGISTER.md` on the branch is wrong today — it advertises an open claim on
`version-subprojects` that was released on 2026-09-09 — because nothing
regenerates it when a claim changes, and the freshness check only fires when the
register is itself being pushed. And `check-ownership.sh` reports
"matches its generator" whenever the generator *crashes*.

What is genuinely good: `check-patch-clean.sh`'s drift check (check 5) and its
K-16 identity check both do what they claim, and all nine patch files apply to
real trunk today — I fetched redmine.org's own master and the mirror gap is
**zero** (r25065), so today's `--submit` PASS is a statement about trunk, not
about the mirror. `check-symmetry.sh`'s code half caught a synthetic one-sided
removal on the first try, and its `--self-test` really does bite on the five
slugs that have locale keys. The claim-race design in `claim.sh` is sound.

**Counts:** blocker 2 · major 4 · minor 5 · nit 2 · question 1

**Lines in the diff not strictly required by the feature:** n.v.t. — this
onderdeel is not a patch.

---

### F01 — the AI-trace check reads only the first patch file, and five of nine slugs ship two

- **Status:** fixed
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `tools/check-patch-clean.sh:170`
- **Invariant touched:** INV-4

**What is wrong**

Check 3 builds the header text with
`headers=$(awk '/^diff --git /{exit} {print}' $FILES)`. In awk, `exit`
terminates the **whole program**, not the current input file. With more than one
file in `$FILES`, everything from the first `diff --git` line onwards — which
includes the entire second, third, … `.patch` file, header and all — is never
read. The grep that follows then finds nothing and the gate prints
`ok  no AI trace in the header or the commit message`.

The same truncation applies to the branch-export path: `git format-patch` on a
multi-commit branch writes commit two's `From:` and message *after* commit one's
diff, so only the first commit's message is ever scanned. Every patch branch
happens to have exactly one commit today, so that half is latent; the multi-file
half is live.

**Why a committer would push back**

`patches/mypage-query-blocks/`, `revision-branches/`, `webhook-tracker-filter/`,
`wiki-export-attachments/` and `members-pagination/` each hold two `.patch`
files. If the translations file were exported by a session whose git identity
had not been overridden — the default state, per INV-4's own text — its `From:`
line carries `Claude <noreply@anthropic.com>`, it gets attached to a
redmine.org issue, and the gate that exists to stop precisely that reports PASS.
This is the K-16 failure repeated one layer out: a check whose subject is
narrower than the thing it is trusted to cover.

**How I verified it**

Copied the two real `wiki-export-attachments` patch files to a scratch
directory (the repository was not touched), inserted
`Co-authored-by: Claude <noreply@anthropic.com>` at line 3 of the *second*
copy, and ran the gate's check-3 pipeline verbatim over both:

```
planted trace present in file 2:
3:Co-authored-by: Claude <noreply@anthropic.com>
--- gate's check-3 pipeline, verbatim ---
GATE SEES NOTHING -> prints 'ok no AI trace'
```

The reduced case is decisive on its own:
`awk '/^diff --git /{exit} {print}' f1.patch f2.patch` prints f1's header and
stops.

**Suggested direction**

Scan every file's header, not the concatenation's first one — a per-file loop,
or an awk that resets on `FNR==1` instead of exiting. For the branch-export
path the subject is every commit message in the range, which `git log` already
gives without parsing the patch at all. Whatever the shape, the gate should
print how many headers it scanned, so "ok" carries its own denominator.

- **Resolution:** fixed 2026-09-10 — `check-patch-clean.sh` check 3 now reads the header of **every message in every file**: `awk 'FNR == 1 || /^From [0-9a-f]+ / { inhdr = 1; msgs++ } /^diff --git / { inhdr = 0 } inhdr { print FILENAME ": " $0 }'`, which re-enters the header on each new `From <sha>` line and so also covers the second and later commits of a multi-commit branch export. The `ok` line now carries its own denominator — `no AI trace in 2 message header(s) across 2 file(s)` — because an "ok" that does not say how much it read is how this hid for a week. **Driven red first, on the finding's own route:** the two real `wiki-export-attachments` patch files copied into a scratch `patches/zz-inv4-red/`, `Co-authored-by: Claude <noreply@anthropic.com>` inserted at line 3 of the **second** one, and the gate run against the directory — `FAIL  AI trace in the patch header or commit message (INV-4)`, exit 1. Removing the line gives `ok  no AI trace in 2 message header(s) across 2 file(s)`, and the scratch directory was deleted. The old code over the same input printed nothing at all. One more thing this check now refuses to do: if the extraction reads zero headers it fails instead of passing, because a grep over an empty string is what the whole defect was. All nine slugs pass `--submit`.

---

### F02 — `check-geoxyz-branch.sh` prints PASS with the lint check not run, and that is the state of this image

- **Status:** fixed
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `tools/check-geoxyz-branch.sh:170-173` and `:184-215`
- **Invariant touched:** INV-8

**What is wrong**

Two independent ways for G8's lint half to not happen while the script still
exits 0 and prints `PASS`:

1. `elif [ ! -x "$RUBOCOP" ]; then warn "rubocop not found …"`. A `warn` does not
   increment `fails`. The hardcoded path is
   `/opt/rbenv/versions/3.3.6/bin/rubocop`, and there is **no rubocop anywhere
   in this image** (`find / -name rubocop -type f` returns nothing).
2. If rubocop *is* present but produces no JSON — a config error, a bundler
   mismatch, a crash — `2>/dev/null` discards the reason, `tally()` catches
   `json.JSONDecodeError` and returns `{}`, and the script prints
   `ok  lint: 0 offences on N changed Ruby file(s)`. "Clean" and "did not run"
   are the same output.

`tools/check-symmetry.sh:72-73` takes the opposite position for its own
interpreter and says why: *"skipping it is how this gate went blind once
already"*. Both scripts were written by the same framework; only one of them
acted on the lesson.

**Why a committer would push back**

This is not hypothetical drift — it is the current state. My run today:

```
  ok    no AI identity in the author or committer of 48 own commit(s)
  ok    all 41 recorded geoxyz_commit sha(s) are on origin/7.0-stable-GEOxyz
  note  rubocop not found at /opt/rbenv/versions/3.3.6/bin/rubocop — set RUBOCOP= to check lint
  ok    locales within en/nl/fr/de/es
…
PASS
```

Any session that quotes "`check-geoxyz-branch.sh` PASS" as G8 evidence — and
STATE.md tells them to — is quoting a run in which lint was never measured. The
final `PASS` does not mention the skip; only the scrolled-past `note` does.

**How I verified it**

Ran `tools/check-geoxyz-branch.sh` (exit 0, output above). Searched for a
rubocop binary: none. Fed the embedded Python tally an empty `branch_json`:
it prints `0 0 0`, which is the "0 offences" branch.

**Suggested direction**

A gate that cannot measure should not pass. Exit 2 with "lint not measured" the
way `check-symmetry.sh` does for Ruby, and treat empty or unparseable rubocop
output as a hard failure rather than as zero offences. If the tool must remain
runnable without rubocop, the verdict line has to say `PASS (lint not measured)`
so the words a session pastes into a dossier carry the gap with them.

- **Resolution:** fixed 2026-09-10, and the second half of the finding then happened for real. `check-geoxyz-branch.sh` gained a third outcome next to `ok` and `FAIL`: `????` for a check that could not run, counted separately, and a run with any `????` ends in `INCOMPLETE — n check(s) could not be measured, so this is not a PASS` and exits 1. Missing rubocop is now `????`, not a `note`; and the embedded tally no longer catches `JSONDecodeError` — unparseable output is reported as `UNMEASURED`, never as zero. **Three outcomes driven by hand:** no rubocop → `INCOMPLETE`, exit 1; a stub rubocop that writes to stderr and exits 1 → `lint NOT MEASURED — rubocop gave no parseable JSON for the branch worktree`, exit 1; a stub that prints `{"files":[]}` → `ok  lint: 0 offences`, `PASS`, exit 0. **Then the finding paid for itself.** I installed rubocop 1.90 to get a real measurement, and the gate said `NOT MEASURED` rather than green — because Redmine's `.rubocop.yml` loads `rubocop-performance` and `rubocop-rails` as plugins, and without them rubocop dies with `cannot load such file` and writes nothing to stdout. The old code would have printed `lint: 0 offences` on that machine. After `gem install rubocop-performance rubocop-rails` the branch measures for the first time in this session: **1 offence on 67 changed Ruby files, baseline 1 on `origin/7.0-stable`, 0 added — `PASS`, exit 0.** The trap is written up in `docs/traps.md`. Note the version caveat: rubocop 1.90 is what was available, not necessarily what Redmine's CI pins, so the *number* is worth less than the fact that it is now a number at all.

---

### F03 — the only mandatory guard, `session-push.sh`, has the weakest AI-identity pattern and fails open on an unfetched range

- **Status:** fixed
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `tools/session-push.sh:96-106`
- **Invariant touched:** INV-4

**What is wrong**

Three scripts test the same thing with three different patterns:

| Script | Pattern |
|---|---|
| `session-push.sh:106` | `anthropic\|(^\| )claude( \|<)` |
| `check-patch-clean.sh:242` | `claude\|anthropic\|copilot\|codex\|chatgpt\|cursor\.(sh\|com)` |
| `check-geoxyz-branch.sh:105` | same as check-patch-clean |

`session-push.sh` is the *preventive* one — its own header says catching it at
push time "is what stops it from accumulating unnoticed for sixteen commits
again" — and it is the narrowest of the three.

Second defect, same block: when `origin/$BRANCH` does not yet exist, the range
falls back to `origin/master..HEAD` (or `origin/7.0-stable..HEAD`). The retry
loop only ever fetches `$BRANCH` (line 48), so on the first push of a new
`patch/<slug>` in a clone without `origin/master`, `git log` fails, `traced` is
empty, and the guard passes without examining a single commit. Neither of the
audit gates has this hole, and both explicitly assert their pattern is non-empty
— but none of the three asserts that the *range* resolved.

**Why a committer would push back**

Measured, with `%h %an <%ae> / %cn <%ce>` lines fed to both patterns:

```
Cursor Agent <cursoragent@cursor.com> / Cursor Agent …   passes session-push   flagged by check-patch-clean
Jan <jan@x.eu> / GitHub Copilot <copilot@github.com>     passes session-push   flagged by check-patch-clean
Jan <jan@x.eu> / codex <codex@openai.com>                passes session-push   flagged by check-patch-clean
Jan <noreply@claude.ai> / Jan <noreply@claude.ai>        passes session-push   flagged by check-patch-clean
Claude <noreply@anthropic.com> / x <y@z>                 BLOCKED               flagged by check-patch-clean
```

Four of five get onto `7.0-stable-GEOxyz` or `patch/*` unopposed. The
`@claude.ai` row is the sharp one: it is an Anthropic identity that the
Anthropic-aware guard does not recognise. And ansifi's PR #1 carries
`Co-authored-by: Cursor <cursoragent@cursor.com>` on two commits, so the Cursor
row is not an invented threat either — it is the identity of the work this
repository forward-ports.

**How I verified it**

Ran both greps over five synthetic identity lines (table above). Confirmed the
range fail-open directly:

```
$ traced=$(git log --format='…' "origin/nosuchref..HEAD" 2>/dev/null | grep -iE 'anthropic|(^| )claude( |<)')
traced=[]  -> guard: passes, nothing tested
```

**Suggested direction**

One pattern, defined once, shared by all three scripts — a `tools/lib` sourced
file or an exported variable — so the preventive guard can never be looser than
the audit. And before using a range, verify both endpoints resolve; a range that
does not is a hard failure, exactly as an empty pattern already is.

- **Resolution:** fixed 2026-09-10 — one pattern in one place. New `tools/inv4-identity.sh`, sourced (never executed) by all three gates, holds `AI_IDENTITY_RE`, `AI_TRACE_RE` and `inv4_identities <from> <to>`; the three local copies are gone, so the mandatory guard cannot be looser than the audits again. The range hole is closed in the same function: it verifies both endpoints resolve and **returns 2** rather than reporting clean, and `session-push.sh` additionally fetches the fallback ref before asking. **Driven red end to end in a throwaway clone with a local bare `origin`** — nothing was pushed anywhere real: a `patch/zz-probe` commit with committer `Cursor Agent <cursoragent@cursor.com>` and a clean author. The old pattern matches it 0 times; the new guard prints `FAIL INV-4: an AI identity on commits bound for patch/zz-probe`, exit 1. **A mistake worth recording, because it is the same class as the finding:** the first version of `inv4_identities` called `exit 2` on an unresolvable range, and `exit` inside `$( )` leaves only the subshell — so the guard printed FAIL and the parent pushed anyway, which the throwaway remote proved. It returns 2 now and every call site is `... || exit 2`; re-tested, the push is refused with exit 2 and the bare repo receives no ref. The audit gates were re-run afterwards: nine `--submit` PASS, `check-geoxyz-branch.sh` PASS.

---

### F04 — `check-symmetry.sh` never looks at what GEOxyz has and the patch does not

- **Status:** fixed
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `tools/check-symmetry.sh:212-231` (code) and `:105-112` (locales)
- **Invariant touched:** INV-10

**What is wrong**

The set of lines the gate examines is `git diff -U0 $mb $patch_ref -- $f` — the
patch's own diff. For each such line it asks whether it is present on one side
and absent on the other. A line that GEOxyz carries and the patch never mentions
is not in that set at all, so it is invisible. The locale half is the same
shape: `patch.each do |key, value|` iterates the patch's keys only, so a key
added or changed on GEOxyz alone is never compared.

The script's header claims otherwise: *"is the line in the file on the patch
branch and absent from the same file on GEOxyz, **or the reverse**?"* The
reverse it actually implements is "removed by the patch, still on GEOxyz" —
which is still a line the patch's diff contains. The genuine reverse direction
is not covered, and the documented limits (line 205-208: "a change whose every
line already occurs somewhere else in the file is invisible") do not name it.

**Why a committer would push back**

This is the direction that will actually happen next. GEOxyz runs the branch in
production; a hotfix applied there under time pressure and not carried back to
`patch/<slug>` is the obvious future divergence, and INV-10 is the rule that is
supposed to make it impossible to claim symmetry without proving it. Built the
case and ran the gate:

```
+    raise Unauthorized unless User.current.admin?     # on GEOxyz only, in a file the patch touches
$ GEOXYZ=<synthetic> tools/check-symmetry.sh version-subprojects
  ok    version-subprojects: every substantive line of the patch is on both sides (no locale key of its own)
PASS  no unexplained divergence between the patches and …
```

The `ok` line is literally true and completely misleading — and it is the
sentence a session would paste into `status.md` as the INV-10 evidence.

For contrast, the direction the gate *does* cover works: deleting
`q.build_from_params(params.slice(:f, :op, :v))` from GEOxyz's
`app/controllers/queries_controller.rb` was caught on the first try, exit 1.

**How I verified it**

Two synthetic `7.0-stable-GEOxyz` commits built through a temporary index (no
branch, no worktree written), then `GEOXYZ=<sha> tools/check-symmetry.sh
version-subprojects`. Removal → FAIL. Addition → PASS.

**Suggested direction**

The honest fix is to compare the same *region* on both sides rather than a line
set drawn from one of them: for each file the patch touches, diff the patch's
version of it against GEOxyz's and report every hunk that is not explained by
upstream drift or by `symmetry-allow.txt`. If that is too noisy to be
mechanical, then the header and CLAUDE.md's G8 row must stop saying "or the
reverse" and state the one direction the gate covers, so nobody reads the `ok`
line as more than it is.

- **Resolution:** fixed 2026-09-10 — `check-symmetry.sh` now looks in both directions, and the scoping took three attempts. For every file the patch touches it also walks GEOxyz's own added lines and reports any that this patch does not carry. **Scoped by content, which needs no bookkeeping to be right:** such a line is this slug's divergence unless some other `patch/*` branch has it, in which case it belongs to that feature; it cannot be upstream's own line, because this patch branch is upstream plus one feature and the line is absent there. Locale files are handled by key presence, not by line, so a differing value stays the forward check's finding and is not reported twice. **The two scopings I tried first are recorded in the script's header because both are instructive.** Reading the feature's `geoxyz_commit` list out of `status.md` reproduces nothing: my own synthetic hotfix passed, because a hotfix is exactly the commit nobody wrote down. Treating every unrecorded commit as this feature's produced **45 false failures in one run** — five real GEOxyz commits are recorded against no feature at all (`1fd3343ff`, `2ac1de3c6`, `8612a76f4`, `7d85538f3`, `c077d96df`) and one of them shares `test/unit/webhook_test.rb` with another slug. **Red then green on the finding's own case:** the same `raise Unauthorized unless User.current.admin?` added to GEOxyz alone now gives `FAIL version-subprojects: app/controllers/queries_controller.rb — on GEOxyz, on no patch branch, absent here`, exit 1; a locale key added on GEOxyz alone gives `FAIL … key label_geoxyz_only_key is on GEOxyz and on no patch`. `--all` against the real branches is PASS for all nine with zero false positives, in 48 seconds. **One thing this does not fix, and it is worth someone's attention:** those five unattributed commits mean the register's `geoxyz_commit` fields are incomplete. `check-geoxyz-branch.sh` check 3b only verifies recorded → branch, never branch → recorded, so nothing notices. That is a finding for a future round rather than something a tools session should quietly rewrite in twelve `status.md` files it does not own.

---

### F05 — nothing regenerates the register when a claim changes, and the committed register is wrong today

- **Status:** fixed
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `tools/claim.sh:69-105`, `tools/check-ownership.sh:82-96`
- **Invariant touched:** none

**What is wrong**

`docs/REGISTER.md` embeds a "Nu in behandeling" section generated from
`docs/claims/*`. `claim.sh` writes and deletes those claim files and pushes
them, but never runs `tools/register.sh --write`. `check-ownership.sh`'s
`check_generated` would notice the staleness, but it returns early
(`printf … | grep -qxF "$path" || return 0`) unless `docs/REGISTER.md` is itself
among the files being pushed — which is exactly when it is *not* stale.

**Why a committer would push back**

The register is the coordination artefact. STATE.md step 2 tells a new session
to take a row from it, and CLAUDE.md says the same. Today it lies:

```
$ tools/register.sh > /tmp/r.md; diff /tmp/r.md docs/REGISTER.md
32a33,36
> ## Nu in behandeling
>
> - `version-subprojects` — cse_01VUeLQwkYYqqVPhKzx3M4qu sinds 2026-09-09
```

`docs/claims/` holds only `README.md`; the claim was released in `d409852c2`
("version-subprojects: claim released") on 2026-09-09. So the branch has
advertised a phantom claim for a day. A parallel session reading the register
would skip `version-subprojects` believing another session holds it — the exact
coordination failure the claim mechanism exists to prevent, produced by the
mechanism's own bookkeeping.

**How I verified it**

`tools/register.sh` versus the committed file (diff above); `ls docs/claims/`;
`git log --oneline -- docs/claims/`.

**Suggested direction**

Either `claim.sh` regenerates and pushes the register in the same commit as the
claim change, or the claims section comes out of the generated register and the
live answer becomes `tools/claim.sh --list`, which reads the directory and
cannot go stale. The second is smaller and removes a whole class of drift. Do
not leave it to `check_generated`, which by construction only looks when
somebody is already touching the file.

- **Resolution:** fixed 2026-09-10, and the stale entry is gone. `claim.sh` now runs `tools/register.sh --write` and stages `docs/REGISTER.md` in the same commit as every claim, release and withdrawal, and refuses the claim outright if the register cannot be regenerated. The branch's own staleness was corrected in this commit: `docs/REGISTER.md` no longer advertises `version-subprojects` as held by `cse_01VUeLQwkYYqqVPhKzx3M4qu`, a claim released in `d409852c2` on 2026-09-09. `tools/register.sh` and the committed file now match byte for byte, which `check-ownership.sh` confirms. The finding's other half — that `check_generated` only looks when the register is part of the push — is unchanged and now harmless, since the only thing that made the register stale was the claim path.

---

### F06 — `check_generated` prints "matches its generator" when the generator fails

- **Status:** fixed
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `tools/check-ownership.sh:87-91`
- **Invariant touched:** none

**What is wrong**

```sh
if "$generator" > "$tmp" 2>/dev/null && ! diff -q "$tmp" "$path" >/dev/null; then
  fail …
else
  pass "$path matches its generator"
fi
```

A non-zero exit from the generator short-circuits the `&&`, so control lands in
the `else` — the branch whose message asserts the file *does* match. `2>/dev/null`
removes the only remaining trace. The stated purpose of the check ("a generated
file that was hand-edited is worse than a conflict, because it looks
authoritative") is inverted: a broken generator makes any edit look
authoritative.

**Why a committer would push back**

`register.sh` shells out to Python over every `status.md`; `findings.sh` parses
every findings file. A malformed front matter block or a bad encoding is enough
to make either exit non-zero, and then a hand-edited `docs/REGISTER.md` gets a
green tick on its way onto the branch.

**How I verified it**

```
$ printf '#!/bin/sh\nexit 3\n' > brokengen.sh; chmod +x brokengen.sh
$ if ./brokengen.sh > "$tmp" 2>/dev/null && ! diff -q "$tmp" target.md >/dev/null; then echo FAIL; else echo PASS; fi
PASS branch -> 'ok target.md matches its generator'
```

**Suggested direction**

Split the two conditions: run the generator, fail loudly (with its stderr) if it
exits non-zero, and only then compare. Same rule as F02 — a check that could not
run is not a check that passed.

- **Resolution:** fixed 2026-09-10 — the two conditions are separate statements instead of an `&&` chain, so a generator that exits non-zero now fails with its stderr attached (`$generator failed, so nothing is known about $path`) instead of falling into the branch that announces a match. The temp file is a `mktemp` rather than `/tmp/generated-check.$$`. **Driven red** with a stub generator that writes to stderr and exits 4: the old shape prints `ok  docs/REGISTER.md matches its generator`, the new one prints `FAIL  … failed, so nothing is known about docs/REGISTER.md` followed by `generator exploded`.

---

### F07 — the ownership rule is documented as mechanical, and nothing invokes it

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `CLAUDE.md` ("`tools/check-ownership.sh <slug>` enforces it"), `docs/STATE.md` ("maakt dat mechanisch"), `tools/session-push.sh`
- **Invariant touched:** none

**What is wrong**

`session-push.sh` is the one gate a session cannot route around, and it runs the
INV-4 identity check only. `grep -rn check-ownership tools/ .claude/` finds two
prose references in skill files and nothing executable; there are no git hooks.
So ownership is a discipline, like the ones the framework replaced with tools,
while two documents describe it as mechanical.

**Why a committer would push back**

The check itself is sound — I planted `docs/features/imap-oauth/…tmp` while
claiming `version-subprojects` and it failed correctly, naming the file. The
defect is only that nothing calls it, which is invisible until two sessions
actually run in parallel — and STATE.md records that they never yet have.

**How I verified it**

`grep -rn "check-ownership" tools/ .claude/`; `ls .git/hooks | grep -v sample`
(empty); ran the check with a planted foreign file (FAIL, exit 1, correct file
named).

**Suggested direction**

Have `session-push.sh` run it when the branch is `geoxyz/framework` and a slug
can be inferred (or is passed), with an explicit `--no-ownership` escape for the
framework sessions Jan asks for. Alternatively soften the two documents to say
"run it before every push" rather than "enforces". The first is better; the
second is at least honest.

- **Resolution:** fixed 2026-09-10 — it is mechanical now, so the documents that said so are true. `check-ownership.sh` gained `--infer`, which works the slug out from the changed paths (`docs/features/X/`, `patches/X/`, `verify/X.mjs`, `docs/claims/X--`), fails when the changes span more than one feature, and falls back to a shared-and-generated-files-only rule when no slug is implied — a findings file cannot name its own slug, since `<date>-<slug>-<reviewer>` is dashed on both sides, so those are checked against `OWNED` once a slug is known. `session-push.sh` runs it on every push to `geoxyz/framework`. The one legitimate exception is a framework change, which now has to be *stated*: `FRAMEWORK_CHANGE=1`, and the tool prints `say in the report that Jan asked for this`. **Verified both ways:** on this session's own tree `--infer` correctly finds no slug and fails naming `tools/check-patch-clean.sh`, `tools/check-symmetry.sh`, `tools/inv4-identity.sh`, `tools/session-push.sh`; a planted `docs/features/imap-oauth/…tmp` while claiming another slug fails naming that file. This very commit was pushed with `FRAMEWORK_CHANGE=1`, which is the honest use of it: Jan asked for these tool changes on 2026-09-10.

---

### F08 — `go()` accepts a 403 page and the static 500 page as a successful navigation

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `tools/verify-lib.mjs:40-46`
- **Invariant touched:** none (G9)

**What is wrong**

```js
const code = await page.evaluate(() => document.title);
if (/^(500|422|404|Error)/.test(code)) throw new Error(`${path} returned ${code}`);
```

The variable is called `code` but holds a title. Redmine's in-app error pages do
set the title from the status (`app/views/common/error.html.erb` ends with
`<% html_title @status %>`, and `html_title` joins to `"404 - Redmine"`), so
404, 422 and in-app 500 are caught. Two cases are not:

- **403.** `render_403` sets `:status => 403`, title `"403 - Redmine"` — not in
  the regex.
- **A genuine unhandled exception in production mode**, which Rails serves from
  `public/500.html`, whose title is `Redmine 500 error` — it starts with
  "Redmine", not "500".

`page.goto()` already returns the response, and `response.status()` is the
correct signal; several verify scripts use it directly for their own assertions,
so the helper is the only place still guessing from the DOM.

**Why a committer would push back**

G9 exists because the 2026 port shipped a link that was in the DOM and did
nothing. The failure paths G9 asks for by name — "the setting turned off, the
permission absent" — are precisely the ones that render 403. A verify script that
navigates to a permission-gated URL expecting content, gets 403, and screenshots
Redmine's error page produces a `before-*.png` / `after-*.png` pair that looks
like evidence. `verify/assignee-nobody.mjs:104` carries the comment *"go()
refuses an error page"* — a belief that is true for 404 and false for 403.

**How I verified it**

Read `public/404.html`, `public/500.html`, `app/views/common/error.html.erb`,
`app/helpers/application_helper.rb:905` and
`app/controllers/application_controller.rb:583` on `origin/master`. Read-only —
I did not bring up a Redmine instance, so I have not seen a 403 screenshot
happen; the reasoning is from the templates.

**Suggested direction**

Keep the response from `page.goto()` and refuse anything outside 2xx/3xx, with
the status in the message. The title test can stay as a second, cheaper signal;
it should not be the only one.

- **Resolution:** fixed 2026-09-10 — `go()` keeps the response from `page.goto()` and refuses anything outside 2xx/3xx, with the status and the page title in the message. The title test is gone rather than kept as a second signal: it was never the right question, and two signals where one is authoritative is how a reader ends up trusting the weaker one. **Honest about the verification:** this is read-only. There is no Redmine instance in this session — no worktree, no PostgreSQL — so the change is verified by `node --check` and by reading Redmine's own templates (`app/views/common/error.html.erb` ends with `html_title @status`, `public/500.html` has the title `Redmine 500 error`, `render_403` sets `:status => 403`), not by driving a browser. The first G9 run after this should confirm it, and should watch for the opposite risk: a verify script that deliberately navigates to a page which now throws. I checked the thirteen scripts in `verify/` for that and found none — `wiki-export-attachments.mjs` asserts a 403 but does its own `page.goto` and reads `resp.status()` itself, so it never went through `go()`.

---

### F09 — `symmetry-allow.txt` matching is the reverse of its own documentation, and the guard protecting it is inert

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `tools/check-symmetry.sh:36-38`, `:133-138`, `:174`, `:218`
- **Invariant touched:** INV-10

**What is wrong**

Header and `CLAUDE.md` both describe the allow file as *"one fixed string per
line, matched as a substring of the line body or of the locale key path"* — i.e.
the entry is a fragment of what it excuses. The code is
`grep -qF -- "$body" "$allowfile"`, which asks the opposite: does some allow
*line contain the whole body*. An operator writing the documented thing (a
short distinguishing fragment) gets no suppression at all and the gate keeps
failing.

Consequently the 8-character guard at `:133-138` — added so that a pattern like
`end` "would excuse whole files" — cannot fire on the case it describes: under
the implemented direction a short pattern excuses nothing, because every body is
at least 8 characters (`:216`). It is dead code justified by a threat model the
implementation does not have.

The one live allow file, `docs/features/wiki-export-attachments/symmetry-allow.txt`,
happens to contain the body verbatim, so it works by coincidence of being an
exact copy rather than a fragment.

**Why a committer would push back**

Failing closed is the safe direction, so this is not dangerous — it is a trap.
The next person to add a legitimate divergence will follow the documentation,
watch the gate fail anyway, and be one step from concluding the gate is broken
and skipping it.

**How I verified it**

Read the three call sites; read the one allow file and confirmed its single
entry is a byte-for-byte copy of the diff line body it excuses.

**Suggested direction**

Pick one direction and make the code, the header, `CLAUDE.md`'s G8 row and
`docs/STATE.md` agree. Substring-of-body (the documented one) is the useful
semantics and is what makes the 8-character guard meaningful; if instead exact
bodies are wanted, say "the full line, verbatim" and drop the guard.

- **Resolution:** fixed 2026-09-10 — the code now does what the file always said. A new `allowed()` helper walks the patterns and tests `case "$subject" in *"$pattern"*)`, so an allow entry is a **fragment of** the line body or the key path, which is the documented direction and the useful one. That also makes the 8-character guard load-bearing instead of inert. **Verified against the one live allow file**, `docs/features/wiki-export-attachments/symmetry-allow.txt`: its entry `'itcpdf' => 'ITCPDF',` still suppresses the exact line (it happened to work before only because it is a byte-for-byte copy), now also suppresses a longer line containing it, and does not suppress an unrelated line. `--all` stays PASS.

---

### F10 — `--self-test` reports a global PASS when it broke nothing, and never exercises the code half

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `tools/check-symmetry.sh:253-297`
- **Invariant touched:** none

**What is wrong**

The self-test finds a key with `grep -E '^\+  [a-z_]+:'` on the patch's locale
diff. When no key is found it prints a per-slug `note` and continues; `st_fails`
stays 0 and the script ends with
`PASS  self-test: a one-sided translation change fails the gate`. Run against a
single slug with no locale keys, that sentence is asserted having tested
nothing:

```
  note  version-subprojects: adds no locale key of its own, nothing to break
…
PASS  self-test: a one-sided translation change fails the gate
```

Four of nine slugs are in that position. Separately, the self-test only ever
breaks a *translation value*; the code half — the older, larger half, and the
one built for the `version-subprojects` incident — is not exercised at all. I
had to write that test by hand (see F04), and it passed, but nothing in the repo
would tell the next session if it stopped.

**Why a committer would push back**

The self-test is the framework's own answer to "how do you know the gate still
bites", and CLAUDE.md tells a session to run it after touching the script. A
verdict that can be reached without a single break is the same defect one layer
up.

**How I verified it**

Ran `tools/check-symmetry.sh --self-test --all`: five slugs `ok`, four `note`,
global PASS. Read the key extraction and the `st_fails` accounting.

**Suggested direction**

Fail when nothing was broken: if a run produced zero actual breaks, exit
non-zero and say so. Add a code-half break — delete one substantive line from
the synthetic GEOxyz tree and require a FAIL — using the same temporary-index
trick, which is already written.

- **Resolution:** fixed 2026-09-10 — `--self-test` now builds **three** synthetic defects per slug and requires the gate to fail on each: a translation that reads differently on GEOxyz (forward, locales), a line of the patch missing from GEOxyz (forward, code) and a line on GEOxyz that no patch branch carries (reverse, code). It fails if it ran no probe at all, so the sentence "a one-sided change fails the gate" can no longer be printed over nothing. Every tree is still assembled in a temporary index and committed with `commit-tree`: no branch, no worktree, no ref. **Result: `PASS self-test: all 23 probe(s) fail the gate, in both directions`**, in 3m08s — 9 slugs × 2 code probes plus 5 translation probes, with a `note` for the four slugs that add no locale key of their own. Where the old self-test tested 5 things it now tests 23, and the code half — the older and larger one — is covered for the first time. The zero-probe branch is defensive and was reasoned about rather than executed: I could not construct a slug that has a patch branch, passes the main gate, and offers nothing to break.

---

### F11 — the G9 and G3 helpers continue past their own failed setup steps

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `tools/test-env.sh:22-24`, `tools/dev-server.sh:88-96`
- **Invariant touched:** INV-8

**What is wrong**

`test-env.sh` prints `note  no Playwright Chromium found — system tests will
error` to stderr and then `exec`s the suite anyway. Its own header explains that
this produces "~260 errors that have nothing to do with the patch" and that such
a run "proves nothing (INV-8)" — and then it lets it happen.

`dev-server.sh` has the same shape twice: `redmine:load_default_data` and the
`dev-seed.rb` run both send output to `/dev/null` or through a pipe, and neither
exit status is checked. A failed seed leaves a server that answers 200 over an
empty database, and the script prints `PASS  http://127.0.0.1:3000` with the
project name it did not create.

**Why a committer would push back**

Both feed INV-8 numbers. A suite run whose 260 errors are environmental gets its
counts written into a dossier, and the sentence "27 failures, 2 errors" in the
runbook is exactly the kind of number that has to be reproducible to mean
anything. A verify run against an unseeded instance produces screenshots of an
empty Redmine.

**How I verified it**

Read both scripts. `dev-server.sh` was not executed in this session (no Redmine
worktree present), so the seed path is from reading only.

**Suggested direction**

Refuse rather than warn: no browser, no suite; a failed seed, no server. The
cost of stopping is a rerun, and the cost of continuing is a number in a dossier
that nobody can reproduce.

- **Resolution:** fixed 2026-09-10 — both refuse now. `test-env.sh` exits 2 when there is no Playwright Chromium, with the reason ("those counts are not suite evidence (INV-8)"), and `SYSTEM_TESTS_MAY_ERROR=1` is the stated escape for someone who wants the run anyway and knows not to quote the numbers. `dev-server.sh` checks the exit status of both `redmine:load_default_data` and `dev-seed.rb`, writes their output to `$LOGFILE.seed` instead of `/dev/null`, and stops with the last ten lines rather than presenting a server on an empty database. **Verified for `test-env.sh`:** with the real Chromium present it runs (exit 0); against a copy pointed at an empty browser directory it prints the FAIL and exits 2, and with `SYSTEM_TESTS_MAY_ERROR=1` it continues with a note (exit 0). **Not verified for `dev-server.sh`:** it needs PostgreSQL, a Redmine worktree and a bundle install, none of which exist in this session, so that half is a read-only change.

---

### F12 — `findings.sh` counts every `###` heading as a finding, and round 4 asks for one that is not

- **Status:** fixed
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `tools/findings.sh:56-69`
- **Invariant touched:** none

**What is wrong**

`re.split(r'^### ', text, flags=re.M)[1:]` treats every level-3 heading as a
finding block. A chunk without a `**Severity:**` line is silently filed as
`minor` (`:60`), and one without a `**Resolution:**` line lands on the `--open`
work list forever. Zero such chunks exist today — I checked all 63 files — so
this is latent, not live.

It becomes live this round: the round-4 prompt asks every reviewer to append a
section *"Where I disagree with the previous rounds"*. Written with `###`
sub-headings — the natural way to structure "F03 of round 2, and why I
disagree" — each one becomes a phantom open minor, and `tools/findings.sh
--open`, which STATE.md makes step 1 of every session, stops being empty.

**How I verified it**

Ran a script over `docs/review/findings/*.md` counting `###` chunks with no
`**Severity:**` line: 0. Read the split and the `sev if sev in RANK else
'minor'` fallback.

**Suggested direction**

Require a `**Severity:**` line before treating a chunk as a finding, and report
the skipped headings in a comment so a genuinely malformed finding is not
silently dropped instead.

- **Resolution:** fixed 2026-09-10 — `findings.sh` treats a level-3 heading as a finding only when the chunk has a `**Severity:**` line, and lists the rest in an HTML comment at the foot of `FINDINGS.md` so a genuinely malformed finding is reported rather than silently dropped. **Driven red:** a throwaway findings file containing `### Where I disagree with round 2` and no severity used to add a phantom open minor; with the fix the total stays at 186, `--open` stays at 14, and the heading appears under `level-3 headings with no Severity line, read as prose and not counted`. The file was deleted. **A second parser defect fell out of fixing this one, and it is the same class again:** `docs/review/findings/TEMPLATE.md` writes the line as `**Resolution:**` while every resolved finding writes `- **Resolution:**`, and `field()` required the dash — so a fixer who followed the template wrote a resolution the tool could not see and `--open` would have listed the finding forever. `field()` now accepts both. Fixing *that* produced a third one in passing, caught before it was committed: relaxing the regex with `\s*` made it match across newlines, so an empty `**Resolution:**` swallowed the blank line and captured the `---` separator as its value, reporting all fourteen open findings as resolved. It is `[ \t]*` now, and the counts are back to 186 total, 14 open.

---

### F13 — word-splitting and a predictable temp path across the shell tools

- **Status:** fixed
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `tools/check-patch-clean.sh:116,126,152,170,182`; `tools/check-symmetry.sh:144`; `tools/check-geoxyz-branch.sh:181,184`; `tools/check-ownership.sh:49,86`
- **Invariant touched:** none

**What is wrong**

File lists are carried in strings and expanded unquoted (`for f in $FILES`,
`$RUBOCOP … $files`), and `check-ownership.sh` derives paths with
`git status --porcelain | awk '{print $NF}'`, which returns only the last
whitespace-delimited token. A path containing a space is mis-parsed everywhere.
`check_generated` also writes to `/tmp/generated-check.$$`, a predictable name in
a world-writable directory.

**Why a committer would push back**

Every case I could construct fails safe — a mangled path does not match `OWNED`
and is reported as foreign, which is the correct verdict for the wrong reason:

```
  FAIL  file(s) this session does not own:
          docs/features/imap-oauth/SCRATCH-REVIEW-PROBE.tmp
          probe.tmp"
```

So this is hygiene, not a hole. It is listed because these scripts are the
framework's own quality bar and Redmine's tree does contain paths with spaces
under `test/fixtures`.

**How I verified it**

Created `docs/features/tools probe.tmp` and a foreign file, ran
`tools/check-ownership.sh version-subprojects` (output above), deleted both;
`git status --porcelain` is clean again.

**Suggested direction**

Arrays and `"${arr[@]}"` in the four scripts, `git status --porcelain -z` with a
null-delimited read, and `mktemp` for the comparison file.

- **Resolution:** fixed 2026-09-10 — `check-patch-clean.sh`, `check-geoxyz-branch.sh` and `check-symmetry.sh` carry their file lists in bash arrays (`mapfile -t` / `"${arr[@]}"`) instead of whitespace-split strings; `check-ownership.sh` reads `git status --porcelain -z` instead of `awk '{print $NF}'`; `check_generated` uses `mktemp` instead of `/tmp/generated-check.$$`. Two unquoted expansions are left on purpose and are safe: `$ALL_PATCHES` in `check-symmetry.sh` holds git ref names and `$inferred` in `check-ownership.sh` holds slugs, neither of which can contain a space. All gates re-run afterwards: nine `--submit` PASS, `check-symmetry.sh --all` PASS, `check-geoxyz-branch.sh` PASS.

---

### F14 — should `claim.sh` and `append-note.sh` refuse to run when HEAD is not `geoxyz/framework`?

- **Status:** fixed
- **Severity:** question
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `tools/claim.sh:44,64`, `tools/append-note.sh:48`
- **Invariant touched:** none

**What is wrong**

Both run `git rebase -q origin/geoxyz/framework` in `$REPO` without checking
which branch is checked out there. The execution environment mints a fresh
branch per session — this one started on
`claude/prompt-round4-review-ssd94p` — and CLAUDE.md tells a session to check
out `geoxyz/framework` instead. A session that runs `tools/claim.sh <slug>`
before doing that rebases the environment's branch onto the framework branch.
`session-push.sh` then refuses ("`geoxyz/framework` is not checked out here"),
so nothing is pushed and nothing is lost — but the local branch has been
rewritten and the session gets an exit code with no explanation of what
happened to its history.

**Why this is a question rather than a defect**

The blast radius is one unpushed local branch, and the failure is loud. It may
be judged not worth a guard. But the framework's own rule is that a session's
first act is to check out `geoxyz/framework`, and these two tools are the ones
most likely to be reached for before that has been done — `claim.sh` is step 3
of STATE.md's opening sequence.

**How I verified it**

Read both scripts; confirmed `session-push.sh:35-38` is the only branch check in
the chain. Not executed — I did not run `claim.sh` at all, since a review
session does not claim.

**Suggested direction**

Two lines at the top of each: if `git rev-parse --abbrev-ref HEAD` is not
`geoxyz/framework`, print the checkout command from STATE.md and exit 2.

- **Resolution:** fixed 2026-09-10 — answered yes rather than left as a question, because the guard is four lines and the alternative is a session losing its branch history to a tool it ran too early. `claim.sh` and `append-note.sh` share an `on_framework_branch` check that exits 2 with the two checkout commands from `docs/STATE.md` when HEAD is anything other than `geoxyz/framework`. Not executed as a red test: a review session does not claim, and running `claim.sh` for real would have written a claim file and pushed it. The guard is `git rev-parse --abbrev-ref HEAD` against a literal, which is as simple as it looks. Its usefulness was demonstrated by this session itself — it started on `claude/prompt-round4-review-ssd94p`, which is exactly the state the guard now refuses.

---

## What I checked and found sound

Not findings, but worth recording so the next round does not redo them.

- **`check-patch-clean.sh` check 5 (drift) works.** Pointed at one file of a
  two-file slug it correctly reported the branch and the file as different
  changes, exit 1. Pointed at the directory, all nine slugs pass.
- **K-16 (check 6) works.** It reads author *and* committer of the branch's own
  commits and reported them for all nine.
- **The mirror is current today, so `--submit` means what it says.**
  `git fetch https://github.com/redmine/redmine.git master` then
  `git rev-list --count origin/master..FETCH_HEAD` → **0**, both at `167e487ee`
  (r25065). All nine `tools/check-patch-clean.sh <slug> --submit` runs pass, and
  today that is a statement about real trunk, not about the mirror.
- **`check-symmetry.sh`'s code half bites** on a one-sided removal (verified,
  F04), and `--self-test` bites on a broken translation for all five slugs that
  have locale keys.
- **`check-geoxyz-branch.sh` check 3b works.** All 41 recorded `geoxyz_commit`
  shas resolve and are ancestors of `origin/7.0-stable-GEOxyz`.
- **`findings.sh --open` is genuinely empty:** 172 findings from 63 reviews, 0
  without a `Resolution:` line. `docs/review/FINDINGS.md` matches its generator
  byte for byte; `docs/REGISTER.md` does not (F05).
- **`claim.sh`'s race design is sound.** Per-session paths, a deterministic
  tie-break both sides compute identically, and the loser withdraws its own
  file.
- **`session-push.sh`'s pipeline exit is safe.** `git push … | tail -2` looks
  like it would swallow a failure, but `set -o pipefail` at line 29 preserves it.

---

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks. I read the two
`geoxyz-branch` Codex files in full, the two round-3 files that discuss the
gates (`gitignore-credentials`, `mypage-query-blocks`), and grepped all 63 for
every tool name. I did not read the other 59 in full.

**Nobody has ever read `check-ownership.sh`, `claim.sh`, `append-note.sh`,
`register.sh`, `findings.sh`, `verify-lib.mjs`, `dev-server.sh` or
`test-env.sh` as code.** A grep for each name across all 63 files returns only
three hits, and all three are a session *using* the tool, never reviewing it —
`tools/test-env.sh` quoted as the command that produced a suite count, twice.
So four of my findings (F05, F06, F07, F08) are not disagreements with anyone;
they are the first look at those files. That is the round-4 premise holding up.

**I disagree with `gitignore-credentials` round 3, F02, on what
`check-geoxyz-branch.sh` covers.** That finding says of G8's three claims: *"The
tool does the first two. It does not do the third."* The register half was
indeed missing and was added as check 3b — verified, all 41 shas resolve. But
the lint half is not done either: it is conditional on a hardcoded rubocop path,
and when the binary is absent the script prints a `note` and still exits `PASS`.
It is absent in this image, so the sentence "the tool does the first two" is
false on the very machine the framework runs on. The same finding's own argument
is the strongest thing I can cite against it — *"a gate that reports on a
narrower thing than its name suggests is worse than no gate, because the
evidence line it produces gets believed"* — and it applies unchanged, one line
further down in the same script. See my F02.

**I disagree with the K-16 resolution's account of what it closed.** The
`mypage-query-blocks` round-3 resolution presents the new check 6 next to the
line it was hiding behind, and quotes that line as the covered half: *"`FAIL an
AI identity …` directly under `ok no AI trace in the header or the commit
message` — the blind spot and its cover in one output."* The cover is itself
partly blind: check 3 reads only the first `.patch` file, and
`mypage-query-blocks` is one of the five slugs that ship two. So the very slug
that motivated K-16 has an unscanned patch file to this day. That is my F01, and
I think it is the more serious of the two, because the file is what a committer
downloads.

**I agree with Codex round 3, F01, and think its resolution stopped one step
short — twice.** The locale comparison is real work, correctly done with a YAML
parser rather than line-wise, and I reproduced its self-test passing on all five
slugs that have keys. But the resolution argues, rightly, that *"testing the
comparator would not have caught this defect, because the comparator was never
the problem, the `continue` above it was"* — and then leaves the code half with
no self-test at all, so the same class of regression is undetectable in the
older, larger half of the same script (my F10). And both halves ask only
"is the patch's line/key also on GEOxyz?", never the reverse, while the header
claims both directions; a hotfix applied to production and not carried back is
invisible (my F04). Neither is a criticism of the fix that was asked for. Both
are the same sentence Codex wrote, applied one level out.

**One resolution I find unconvincing as written, though not wrong.** The K-16
resolution closes with *"the emptied-pattern case exits 2 instead of reporting
ok"* — a guard that a *pattern* is non-empty. That guard is real and I verified
it exists in both scripts. But the failure mode it models is the rarer one. The
common way for a grep-based check to test nothing is an **empty input**, not an
empty pattern, and no script in `tools/` guards that: `session-push.sh` builds a
range from refs it never fetched (my F03), and `check-geoxyz-branch.sh` treats
empty rubocop output as zero offences (my F02). A pattern guard next to an
unguarded input reads as thoroughness and is not.

**One question for Jan, asked once and not re-litigated.** K-19 option A leaves
`origin/master` to Jan to sync by hand, on the reasoning that a gate measuring a
mirror should not silently pretend to measure trunk. Today that worked — the gap
is 0 and all nine patches apply to real trunk r25065. But the gate still cannot
tell the difference, and the check that would take two seconds is the one the
prompt itself hands every reviewer: fetch `redmine/redmine.git master` and count
`origin/master..FETCH_HEAD`. Would you want `check-patch-clean.sh --submit` to
do that fetch itself and refuse when the gap is not zero? It does not change who
syncs the mirror; it changes whether a PASS can be quoted without the reader
knowing to ask.
