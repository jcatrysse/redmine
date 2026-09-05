---
name: upstream-patch
description: Turn one GEOxyz Redmine customisation into a Redmine core patch against trunk, and apply the same design to the GEOxyz branch. Use when asked to work on a named feature from the register, to make an upstream patch of an existing GEOxyz change, or to continue the next feature in docs/STATE.md.
---

# Making one upstream patch

One feature per invocation. Finish it, then stop — CLAUDE.md's cadence rule.

## 0. Claim it, then establish what and where

Sessions run in parallel. Before anything else:

    git fetch origin geoxyz/framework
    git checkout geoxyz/framework && git merge --ff-only origin/geoxyz/framework
    cat docs/REGISTER.md
    tools/claim.sh <slug>

Feature slug from Jan, or the top `todo` row in `docs/REGISTER.md`. The claim is
not optional: it is the only thing that stops a parallel session building the
same feature. If it refuses, take another row.

Then read `docs/features/<slug>/status.md` — the memory of this feature,
including the section on what is already settled. A decision recorded there is
not yours to re-open.

Target defaults to **both, upstream-shaped**. Ask only in the two ambiguous
cases CLAUDE.md names. If it is local-only, there is no patch: one commit on
`7.0-stable-GEOxyz`, `status.md` updated, done.

## 1. Trunk check — G1, before anything else

    git fetch origin master
    git log origin/master -1 --format='%h %ad %s' --date=short

Read the current trunk implementation of whatever the feature touches. Ask:
does trunk already do this, or does it do something adjacent that changes the
design? One GEOxyz feature (`default_users_auto_watch_on`) landed upstream on
its own between 5.1 and 7.0. Record the answer in the dossier even when it is
"no" — a reviewer wants to know you looked.

Note that the fork's `origin/master` mirror lags the real SVN trunk. Record the
mirror's date and revision; a patch is submitted against a named revision.

## 2. Read the history, build on neither

Three sources, all reference material:

| Source | What to take from it |
|---|---|
| the original 5.1 commit | the intent, and the operational need behind it |
| `origin/ansifi/learn-and-test-7.0` | the 7.0 API adaptations it got right |
| current trunk | the conventions and seams the patch must fit |

Do not branch from either GEOxyz branch. Read them, then design fresh.

Assume nothing in the original is correct. Every one of the nine functional
defects in this codebase's history came from the original 5.1 commits and
survived a port because the porter only checked "does it still work". Check
"is this right" instead: operators the filter offers but does not handle,
sharing semantics, asset loading, per-row subprocesses.

## 3. Design, and write the dossier before the code

Copy `docs/features/TEMPLATE.md` to `docs/features/<slug>/dossier.md` and fill
in the problem, the design, the rejected alternatives and the anticipated
objections *first*. If you cannot write the "why core and not a plugin" paragraph, the
patch is not ready to build.

Design for what upstream accepts, not for what GEOxyz asked for. Where those
differ, that is Class B: pick the upstream-likely option, build it, log the
choice.

Settings are the usual trap. Every new setting is permanent API surface and
translation burden for Redmine. Four settings for one display feature will not
pass. Ask what the feature is without them.

## 4. Build in a worktree off trunk

    git worktree add -b patch/<slug> /home/user/wt/patch-<slug> origin/master

Match the file you are editing: its hash syntax, its naming, its comment
density (usually zero). Minimal diff — INV-1. Tests with the change, not
after.

## 5. Prove it — G2..G5

Start the full suite early; it takes tens of minutes and G3 wants all of it, not
only the touched files. Do the translations and the browser verification while
it runs.

Environment setup, once per session (PostgreSQL, gems, and the SCM fixtures if
the feature touches repositories) is in `docs/runbook.md`.

Run, and keep the output:

- the suites covering every file you touched, plus the suites of anything that
  consumes them
- `rubocop` on the changed files, **and on the same files at the merge base**,
  so the baseline is on record
- for each new test: confirm it fails on the old code, and say how you know

Write the counts into the dossier. INV-8: no numbers, not green.

Then re-read your own diff as if you wanted to reject it. Anything that is not
strictly needed comes out.

## 5b. Translations — derived, never invented

Every user-visible string gets `en`, `nl`, `fr`, `de`, `es` (INV-5).

For each new key, in each file: find the **closest existing key** and match its
terminology, register and capitalisation. Redmine's files disagree on basic
vocabulary — `issues` is *issues* in Dutch, *demandes* in French, *Tickets* in
German, *peticiones* in Spanish — so a translation composed from the English
reads plausible and uses the wrong word.

    git show origin/master:config/locales/de.yml | grep -E '^  setting_search'

Record each one in the dossier's locale table with the key you patterned it on.
That is what makes it checkable in seconds, by Jan or by a committer.

Two patch files on one issue, unless Jan says otherwise:

1. the feature — code plus `en.yml`
2. the translations — `nl`, `fr`, `de`, `es` only, no code

A reviewer can take the first without waiting on the second, and the feature
patch stays small. This mirrors how Redmine's own history handles translations.
Generate both from the same branch, tagged in the filename:

    patches/<slug>/<date>-r<rev>-feature.patch
    patches/<slug>/<date>-r<rev>-locales.patch

## 5c. Live verification in a browser — G9

A green suite is not proof the feature works. Do this before exporting anything.

**Before shot first**, on the unpatched instance:

    tools/dev-server.sh /home/user/wt/patch-<slug>
    SHOT_DIR=docs/features/<slug>/shots PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers \
      node verify/<slug>.mjs

Name those `before-*.png`. Then apply the change, restart the server, and take
the after shots. Write `verify/<slug>.mjs` against `tools/verify-lib.mjs`:

    import { session, report } from '../tools/verify-lib.mjs';
    const s = await session(process.env.SHOT_DIR);
    await s.go('/projects/geoxyz-verify/wiki/index');
    await s.shot('wiki-index', 'Wiki index showing the TXT export link');
    report(s.shots);
    await s.browser.close();

One screenshot per function the feature claims, plus the failure paths: the
setting off, the permission absent, the empty state, the input that used to
raise. `report()` prints the dossier table rows.

Read the screenshots yourself — do not just check that the file exists. That is
how you catch a link that renders but does nothing.

## 6. Export and verify the patch — G6

Export first, then check the exported files: the file is what a committer
downloads, and a branch that has drifted away from its own `.patch` files is
exactly the defect this order catches.

Export the two files (5b), each from the same branch:

    git format-patch origin/master --stdout -- . ':!config/locales/nl.yml' \
      ':!config/locales/fr.yml' ':!config/locales/de.yml' ':!config/locales/es.yml' \
      > patches/<slug>/<date>-r<rev>-feature.patch

    git format-patch origin/master --stdout -- config/locales/nl.yml \
      config/locales/fr.yml config/locales/de.yml config/locales/es.yml \
      > patches/<slug>/<date>-r<rev>-locales.patch

Commit both next to the dossier, then:

    tools/check-patch-clean.sh <slug>

It reads `patches/<slug>/*.patch` and checks that no framework or GEOxyz-local
path is touched, that locales stay inside en/nl/fr/de/es, that no AI trace is
in the `From:` line or the commit message, that the patch applies to a pristine
trunk checkout, and that the files together reproduce `patch/<slug>` exactly.

"Does not apply to trunk any more" is a **warning** here, not a failure — trunk
moves, and that is decay rather than a defect (INV-2). Everything else must
pass. Just before Jan submits, refresh against current trunk, re-run the
evidence numbers, and re-run this with `--submit`, which turns that warning into
a failure.

## 7. Apply the same design to GEOxyz

    git worktree add /home/user/wt/geoxyz 7.0-stable-GEOxyz   # if not present

Same behaviour, adapted only where 7.0-stable differs mechanically from trunk.
Run the suites again there — a green trunk patch can still fail on 7.0-stable.
Any behavioural difference is INV-10: record it in the dossier with its reason
and the fact that it is a permanent private patch.

The same five locale files as the patch — the GEOxyz branch and upstream carry
identical translations (INV-10).

## 8. Close out

In this order, because the last two steps must not fail on a race:

1. **`docs/features/<slug>/status.md`** — front matter (`geoxyz`,
   `geoxyz_commit`, `upstream`, `patch`, `issue`) and every section, from
   `docs/features/STATUS-TEMPLATE.md`. This is the feature's memory: what
   stands, the figures, what Jan must do, and what a later session must not
   re-litigate.
2. **`docs/features/<slug>/decisions.md`** — the Class A one-liners for this
   feature. Class B goes to `docs/DECISIONS.md` under "Open — keuze voor Jan",
   through `tools/append-note.sh`.
3. **`tools/register.sh --write`** — regenerate `docs/REGISTER.md`.
4. **`tools/check-ownership.sh <slug>`** — must pass. If it names a file you do
   not own, you have written into another session's memory.
5. **`tools/session-push.sh geoxyz/framework`**, and the same for
   `7.0-stable-GEOxyz` from its worktree.
6. New traps you hit: `tools/append-note.sh docs/traps.md`. Never edit that file
   directly — a parallel session is appending to it too.
7. Anything found but deliberately not fixed: report it, do not fix it.
8. The Dutch session report from CLAUDE.md.

Then stop. Do not start the next feature — and if you are stopping unfinished,
`tools/claim.sh <slug> --release` so the row is free.
