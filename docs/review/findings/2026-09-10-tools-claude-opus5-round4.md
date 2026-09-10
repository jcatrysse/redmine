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

- **Status:** open
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

**Resolution:**

---

### F02 — `check-geoxyz-branch.sh` prints PASS with the lint check not run, and that is the state of this image

- **Status:** open
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

**Resolution:**

---

### F03 — the only mandatory guard, `session-push.sh`, has the weakest AI-identity pattern and fails open on an unfetched range

- **Status:** open
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

**Resolution:**

---

### F04 — `check-symmetry.sh` never looks at what GEOxyz has and the patch does not

- **Status:** open
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

**Resolution:**

---

### F05 — nothing regenerates the register when a claim changes, and the committed register is wrong today

- **Status:** open
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

**Resolution:**

---

### F06 — `check_generated` prints "matches its generator" when the generator fails

- **Status:** open
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

**Resolution:**

---

### F07 — the ownership rule is documented as mechanical, and nothing invokes it

- **Status:** open
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

**Resolution:**

---

### F08 — `go()` accepts a 403 page and the static 500 page as a successful navigation

- **Status:** open
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

**Resolution:**

---

### F09 — `symmetry-allow.txt` matching is the reverse of its own documentation, and the guard protecting it is inert

- **Status:** open
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

**Resolution:**

---

### F10 — `--self-test` reports a global PASS when it broke nothing, and never exercises the code half

- **Status:** open
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

**Resolution:**

---

### F11 — the G9 and G3 helpers continue past their own failed setup steps

- **Status:** open
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

**Resolution:**

---

### F12 — `findings.sh` counts every `###` heading as a finding, and round 4 asks for one that is not

- **Status:** open
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

**Resolution:**

---

### F13 — word-splitting and a predictable temp path across the shell tools

- **Status:** open
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

**Resolution:**

---

### F14 — should `claim.sh` and `append-note.sh` refuse to run when HEAD is not `geoxyz/framework`?

- **Status:** open
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

**Resolution:**

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
