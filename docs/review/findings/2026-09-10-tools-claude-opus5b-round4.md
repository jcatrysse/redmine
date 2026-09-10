# Review run — 2026-09-10 — claude-opus5b-round4

- **Reviewer:** Claude Code (Opus 5), round 4 (Deel A of `docs/review/prompt-round4.md`), second `tools` run
- **Reviewed:** `tools/check-geoxyz-branch.sh`, the lint half of G8. This is a second round-4 file on the `tools` onderdeel: the first (`2026-09-10-tools-claude-opus5-round4.md`) is another session's and its fourteen findings are all resolved. This one is a single defect found sideways, while reviewing `members-pagination`.
- **Dossier read:** n/a — `tools` has no dossier; `docs/STATE.md`, `docs/traps.md` and the script's own header read instead
- **Status read:** n/a
- **Ran the test suite:** no. The subject is a shell gate; I ran the gate and then reproduced its measurement by hand, twice, with the cache disabled.
- **Scope covered:** the lint check of `check-geoxyz-branch.sh`, from its file list to the number it prints, reproduced step by step; whether the branch actually adds a lint offence, measured independently on both sides; the root cause isolated by A/B in one worktree; the blast radius across the other gates.
- **Scope NOT covered:** the other four checks in that script, and the other gates. The finding was written before the fix: Jan asked for the gate to be repaired after reading it, so F01 carries a `Resolution:` and the rest of this file is left as it was written, unfixed-tense and all.

## Summary

`tools/check-geoxyz-branch.sh` reports **"lint: 1 offence(s) on 67 changed
Ruby file(s), all already on origin/7.0-stable's own lines (baseline 1)"**. The
honest number is **8 on the branch and 8 in the baseline**. The gate has never
measured a single version-gated `rubocop-rails` cop, on any branch, since it
was written.

The cause is that the gate lints inside a temporary worktree it creates with
`git worktree add`, and `Gemfile.lock` is gitignored, so that worktree never
has one. Without a lockfile, rubocop-rails' **version-gated** cops go quiet
even though `.rubocop.yml` sets `TargetRailsVersion: 8.1` explicitly. Not all
of them: `Rails/Output` fires either way, which is why this was never noticed —
the plugin is loaded and working, and only the cops that ask "which Rails is
this?" disappear. `Rails/StrongParametersExpect` is one of them, and it
accounts for all seven of the missing offences.

**The current PASS is still trustworthy, and I checked that rather than assume
it.** Both sides are measured the same way, so the *net* figure is right:
measuring branch and upstream by hand with a lockfile present gives 8 and 8, on
the same five files and the same cops, so `7.0-stable-GEOxyz` adds no lint
offence. What the gate cannot do is notice a `Rails/*` offence that the branch
*adds* — and Redmine's CI, which runs rubocop in a checkout that has a
lockfile, would. There is a live example of why that matters:
`patch/webhook-tracker-filter` adds
`has_and_belongs_to_many :trackers # rubocop:disable Rails/HasAndBelongsToMany`.
Remove that trailing comment and our gate stays green while Redmine's CI
does not.

This is the same family as round 4's `tools` F02 and the `docs/traps.md` entry
about the missing plugins, and the fix made then does not cover it. That fix
turned unparseable JSON into `NOT MEASURED`. Here the JSON parses perfectly;
the run is complete, correct and partial.

**Counts:** blocker 0 · major 1 · minor 0 · nit 0 · question 0

---

### F01 — the G8 lint check has never run a version-gated Rails cop, because it lints a worktree with no Gemfile.lock

- **Status:** fixed
- **Severity:** major
- **Confidence:** confirmed
- **Category:** scope
- **Where:** `tools/check-geoxyz-branch.sh:210-219` (the worktree at `$tmp/m`, and the baseline worktree at `$tmp/u`)
- **Invariant touched:** INV-8, G4, G8

**What is wrong**

The check builds its file list, then runs `$RUBOCOP --force-exclusion --format
json` inside `$wt`, a worktree created by `git worktree add --detach`. A fresh
worktree contains only tracked files, and `Gemfile.lock` is in `.gitignore`, so
it is never there. In that state rubocop-rails' version-gated cops produce no
offences. The same applies to the baseline worktree at `$tmp/u`, so both sides
under-report equally and the subtraction looks healthy.

**Why a committer would push back**

They will not see this file; the cost is ours. A gate that prints a number for
a measurement it did not make is what round 4's brief calls worse than no gate,
because it is what the next session points at instead of reading the files. And
the specific blind spot is the cop family Redmine's own CI is most likely to
fail on: `Rails/*` is where `HasAndBelongsToMany`, `StrongParametersExpect` and
`Output` live, and two of our nine patches touch code that trips the first two
and rely on an inline `rubocop:disable` to stay clean.

**How I verified it**

Reproducing the gate's own command, in one fresh worktree, with the RuboCop
cache off so the result cannot come from a previous run:

```
git worktree add --detach $T/m origin/7.0-stable-GEOxyz
files = git diff --name-only origin/7.0-stable...origin/7.0-stable-GEOxyz | grep '\.(rb|rake)$'   # 67

  A  no Gemfile.lock, --cache false   ->  1 offence
  B  Gemfile.lock copied in, same     ->  8 offences
```

The seven that appear in B are `Rails/StrongParametersExpect`:
`application_controller.rb` x3, `queries_controller.rb` x2,
`groups_controller.rb` x1, `wiki_controller.rb` x1. The one that appears in both
is `Style/DirectiveScope` on `query.rb`.

Two details worth recording because each one hid this:

- **With the RuboCop cache on, A and B both report 1.** The cache key does not
  cover whatever changes when the lockfile appears, so a second run in the same
  directory returns the first run's answer. My first A/B was wrong for exactly
  this reason and I only got the truth by adding `--cache false`.
- **`rubocop --show-cops Rails/StrongParametersExpect` prints an identical,
  `Enabled: pending` configuration with and without the lockfile.** So
  inspecting the configuration does not reveal it either; only running the cop
  does.

And the independent measurement that says the verdict survives: upstream
`origin/7.0-stable` in its own worktree, with a lockfile, over the 51 of those
files that exist there, gives **8** offences on the same five files and the same
cops. Branch 8, baseline 8, added 0.

**Suggested direction**

Two halves, and the second matters more than the first.

1. **Get a lockfile into both lint worktrees, or refuse to print a number.**
   `Gemfile.lock` cannot come from git, so it has to be copied from somewhere:
   an existing worktree that has had `bundle install`, or a path given in an
   environment variable. Both sides must get the *same* file, which keeps the
   comparison fair even if those gem versions are not exactly what a given
   branch resolves. If no lockfile can be found, the check should report `lint
   NOT MEASURED` with that reason and the remedy — the rule this framework
   already applies to a missing rubocop (round 4 `tools` F02) and to a stale
   trunk mirror (K-20).
2. **Make the gate prove the cops are live, not assume it.** The pattern is
   `tools/check-symmetry.sh --self-test`: put a file with a known `Rails/*`
   violation into the lint worktree and require that rubocop flags it before
   believing any count. Choose the probe carefully — `Rails/Output` fires with
   or without a lockfile, so it does *not* discriminate; the probe has to be a
   version-gated cop. Without such a self-test the fix in (1) is one more
   thing that is true until it silently is not.

Both are changes to `tools/**`, which `docs/STATE.md` reserves for a session
Jan asked for a framework change.

**Resolution:** fixed, 2026-09-10, after Jan chose option A and asked for the
gate to be repaired (so `FRAMEWORK_CHANGE=1`). Both halves are in, and the
second is the one that makes the first durable.

`find_gemfile_lock` takes `$GEMFILE_LOCK` if set, otherwise the first
`Gemfile.lock` in any worktree of the repo, and the same file is copied into
**both** lint worktrees so branch and baseline are measured against the same
gems. If no lockfile can be found the check reports `lint NOT MEASURED` with
that remedy rather than a number.

`rails_cops_live` then proves the cops are actually running before any count is
believed: it writes a probe controller containing
`Project.find(params[:id])` into the lint worktree, runs rubocop on it with
`--cache false`, and requires `Rails/StrongParametersExpect` in the output. That
cop needs Rails >= 8, so it is exactly the family that goes quiet. The probe
disables the cache because with it on the same directory returns the previous
run's answer either way, which is what made my own first A/B test wrong.

Measured after the fix, on `origin/7.0-stable-GEOxyz`:

```
  note  lint: Rails cops confirmed live, with /home/user/wt/geoxyz/Gemfile.lock in the worktrees
  ok    lint: 8 offence(s) on 67 changed Ruby file(s), all already on
        origin/7.0-stable's own lines (baseline 8) — upstream's, not this branch's
  PASS
```

8 and 8, which are the numbers I had measured by hand, against the 1 and 1 the
gate used to print. And the refusal path was driven red rather than reasoned
about: pointing `GEMFILE_LOCK` at a lockfile that pins no Rails gives

```
  ????  lint NOT MEASURED — the probe controller produced no
        Rails/StrongParametersExpect, ...
  INCOMPLETE — 1 check(s) could not be measured, so this is not a PASS.
```

with exit 1.

**What this does not fix, and it should be read before trusting an old
number.** Every "lint: 1 offence (baseline 1)" line already written into a
`status.md` as G8 evidence was produced by the blind version of this check. The
honest figure for that branch is 8 and 8. The *conclusion* those dossiers drew
is unchanged — both sides were blind in the same way, so "this branch adds no
lint offence" was true then and is true now — but the numbers are wrong and are
left as they are rather than rewritten across eight features' files. The trap
entry appended to `docs/traps.md` on 2026-09-10 says so.

---

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks.

**Round 4's first `tools` run fixed the neighbouring defect and stopped one
step short.** Its F02 was "RuboCop draait niet zonder rubocop-performance én
rubocop-rails ... de gate las dat als lege JSON en meldde `lint: 0 offences`",
and the fix was to treat unparseable JSON as `NOT MEASURED`. That is right and
it is in place — I read the code. But it addresses the case where rubocop fails
loudly. This is the case where rubocop succeeds quietly, and the same question
that produced F02 — "what can be wrong while this prints ok?" — has a second
answer that nobody asked for. The lesson I would draw is narrower than "check
the tools": a gate that shells out to another program has to establish that the
program did the *whole* job, and "it exited 0 and gave me JSON" is not that.

**`docs/traps.md` says to distrust a lint count of 0 "pas als de gate er ook
bij zegt hoeveel bestanden ze gelezen heeft".** The gate does say that — "on 67
changed Ruby file(s)" — and it was still wrong, because the missing dimension
was not files but cops. Worth adding to that entry.
