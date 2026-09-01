# geoxyz/framework

**This branch contains no Redmine code.** It is an orphan branch: the working
method, the per-feature dossiers, the patches submitted to redmine.org, and the
review findings. Nothing here may ever appear in a patch.

Its purpose is to get the GEOxyz Redmine customisations accepted into Redmine
core, so they stop being a private fork to maintain.

## Start here

    Lees CLAUDE.md en docs/STATE.md. Doe verder.

`CLAUDE.md` holds the rules. `docs/STATE.md` holds the register of features and
where each one stands.

## Layout

    CLAUDE.md                     the rules: invariants, gates, cadence
    .claude/skills/
      upstream-patch/             feature -> trunk patch + dossier
      patch-review/               the review lens of a core committer
    docs/
      STATE.md                    current position + feature register
      DECISIONS.md                append-only decision log
      runbook.md                  how to get a working test environment
      features/<slug>.md          submission dossier per feature
      review/findings/            one file per review run
    patches/<slug>/               exactly what was attached to which issue
    tools/check-patch-clean.sh    refuses to let a bad patch out
    tools/check-geoxyz-branch.sh  health of the branch GEOxyz runs

## Branches

| Branch | What |
|---|---|
| `geoxyz/framework` | this |
| `7.0-stable-GEOxyz` | what GEOxyz runs |
| `patch/<slug>` | one upstream patch, from `origin/master` |
| `origin/master` | Redmine trunk mirror — the patch target |

Work happens in worktrees beside this branch, never on it.

## Before submitting anything

    tools/check-patch-clean.sh patch/<slug>

Checks descent from trunk, that no framework or local path is touched, that
locales stay within en/nl/fr/de/es, that no AI traces are in the commit
messages, and that the patch applies to a pristine trunk checkout. Exit 0 means
safe to submit.

And for the branch that actually runs:

    tools/check-geoxyz-branch.sh

Is it current with upstream `7.0-stable`, does it still merge, is its lint
clean, what does it carry. `REF=<local-ref>` to check work before pushing. The
test suite is the other half and has to be run separately.
