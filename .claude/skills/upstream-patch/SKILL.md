---
name: upstream-patch
description: Turn one GEOxyz Redmine customisation into a Redmine core patch against trunk, and apply the same design to the GEOxyz branch. Use when asked to work on a named feature from the register, to make an upstream patch of an existing GEOxyz change, or to continue the next feature in docs/STATE.md.
---

# Making one upstream patch

One feature per invocation. Finish it, then stop — CLAUDE.md's cadence rule.

## 0. Establish what and where

Feature slug from Jan, or the next row in `docs/STATE.md`'s register.

Target defaults to **both, upstream-shaped**. Ask only in the two ambiguous
cases CLAUDE.md names. If it is local-only, there is no patch: one commit on
`7.0-stable-GEOxyz`, one line in the register, done.

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

Copy `docs/features/TEMPLATE.md` to `docs/features/<slug>.md` and fill in the
problem, the design, the rejected alternatives and the anticipated objections
*first*. If you cannot write the "why core and not a plugin" paragraph, the
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

## 6. Export and verify the patch — G6

    tools/check-patch-clean.sh patch/<slug>

The script checks descent from trunk, that no framework or GEOxyz-local path is
touched, that locales stay inside en/nl/fr/de/es, that no AI trace is in the
commit messages, and that the patch applies to a pristine trunk checkout. All
must pass.

Then export the two files (5b), each from the same branch:

    git format-patch origin/master --stdout -- . ':!config/locales/nl.yml' \
      ':!config/locales/fr.yml' ':!config/locales/de.yml' ':!config/locales/es.yml' \
      > patches/<slug>/<date>-r<rev>-feature.patch

    git format-patch origin/master --stdout -- config/locales/nl.yml \
      config/locales/fr.yml config/locales/de.yml config/locales/es.yml \
      > patches/<slug>/<date>-r<rev>-locales.patch

Verify each applies to a pristine trunk checkout on its own, and that the two
together reproduce the branch. Commit both next to the dossier.

## 7. Apply the same design to GEOxyz

    git worktree add /home/user/wt/geoxyz 7.0-stable-GEOxyz   # if not present

Same behaviour, adapted only where 7.0-stable differs mechanically from trunk.
Run the suites again there — a green trunk patch can still fail on 7.0-stable.
Any behavioural difference is INV-10: record it in the dossier with its reason
and the fact that it is a permanent private patch.

The same five locale files as the patch — the GEOxyz branch and upstream carry
identical translations (INV-10).

## 8. Close out

- register row in `docs/STATE.md`: status, patch branch, patch file, issue
  number once Jan has one
- `docs/DECISIONS.md`: Class A one-liners, Class B under "Open — keuze voor Jan"
- anything found but deliberately not fixed: report it, do not fix it
- the Dutch session report from CLAUDE.md

Then stop. Do not start the next feature.
