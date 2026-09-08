# Review run — 2026-09-08 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** the `gitignore-credentials` change on `7.0-stable-GEOxyz`. There
  is no patch branch and there never will be — `upstream: nooit`.
- **Dossier read:** none exists, by design (a local-only item gets no dossier)
- **Status read:** `docs/features/gitignore-credentials/status.md`, including
  "wat er al bekend is" — yes
- **Round-1 findings read:** **no, deliberately.**
  `docs/review/findings/2026-09-03-gitignore-credentials-claude-opus5.md` was
  not opened.
- **Ran the test suite:** **no, and it would prove nothing.** The change is
  three lines in `.gitignore`. I checked that claim rather than accepting it:
  no test reads `.gitignore`, and `grep -rn "config/credentials\|Rails.application.credentials"`
  over `app lib config test Rakefile` returns only the commented-out line in
  `config/environments/production.rb`. What I did instead was create the six
  files on disk and ask git.
- **Scope covered:** the rule set itself, coverage of both Rails credential
  layouts, over-breadth, whether anything tracked is now hidden, whether
  `.github/` survived, the placement in the file, and the record of the change
  in `status.md` and `docs/REGISTER.md`.
- **Scope NOT covered:** whether GEOxyz's production checkout already contains
  a credentials file that predates the rule — that is on the server, not
  visible from here, and `git ls-files` can only speak for the repository.

## Summary

The change itself is right and I could not fault it. Every claim in
`status.md` reproduces exactly: all six credential paths are ignored, by the
line the status file names, the directory rule catches an environment nobody
has invented yet, nothing that is tracked has become hidden, and `.github/`
is still tracked, which was the deliberate departure from the 5.1 original.

The finding is not about the three lines. It is about the record of them, and
it is not confined to this slug: **the commit shas that `status.md` and
`docs/REGISTER.md` give for the GEOxyz branch are orphaned for 21 of the 32
entries across ten features**, this one included. The K-13 identity cleanup of
2026-09-06 rewrote `7.0-stable-GEOxyz`, every commit got a new sha, and the
status files written before that day were never updated. The objects still
exist in this clone, so `git show e2c0447b6` succeeds and prints a plausible
commit — the failure is silent here and only becomes loud in a fresh clone.

**Counts:** blocker 0 · major 1 · minor 1 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0. Three lines,
inserted in the file's existing alphabetical order.

## What I verified, with the files actually on disk

Created the six files in a worktree of `7.0-stable-GEOxyz` and asked git which
rule catches each:

```
config/master.key                         .gitignore:15:/config/master.key
config/credentials.yml.enc                .gitignore:11:/config/credentials.yml.enc
config/credentials/production.key         .gitignore:12:/config/credentials/
config/credentials/production.yml.enc     .gitignore:12:/config/credentials/
config/credentials/staging.key            .gitignore:12:/config/credentials/
config/credentials/some-new-env-2027.key  .gitignore:12:/config/credentials/
```

`git add -A --dry-run` with all six present stages **nothing**. `git ls-files -z
| git check-ignore -z --stdin -v` is empty, so no tracked file has been hidden.
`git check-ignore .github/workflows/tests.yml` reports nothing and `git ls-files
.github` still lists all three CI files, so the 5.1 commit's third line really
was left out.

**The one design choice I would have argued with is already Jan's, so it is not
a finding.** Ignoring `config/credentials.yml.enc` is the opposite of what Rails
intends — that file is encrypted precisely so it can be committed. `status.md`
records it as g16a with the price spelled out. Noted, not reopened.

**Hypotheses driven and cleared:**

| Hypothesis | Outcome |
|---|---|
| the directory rule is over-broad and hides something wanted | clean — nothing under `config/credentials/` is or should be tracked, and no tracked file anywhere matches an ignore rule |
| a key can still land outside these three paths | clean for the mechanism in use — `bin/rails credentials:edit` writes only under `config/`, in one of the two layouts both rules cover. `RAILS_MASTER_KEY` in the environment is not a file and is out of scope for `.gitignore` |
| the rules sit in the wrong place in the file | clean — inserted in the existing alphabetical block, between `configuration.yml` and `database.yml`, next to the `secrets.yml` rule they are the modern equivalent of |

---

### F01 — the GEOxyz commit shas in the register are orphaned, for this feature and nine others

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/gitignore-credentials/status.md` front matter
  (`geoxyz_commit: e2c0447b6 + 3f5eb3be2`) and body, and the same field in nine
  other `status.md` files, propagated into `docs/REGISTER.md`
- **Invariant touched:** none directly; it defeats the mapping CLAUDE.md asks
  the register to hold ("`docs/REGISTER.md` maps feature to commit")

**What is wrong**

Neither `e2c0447b6` nor `3f5eb3be2` is on `7.0-stable-GEOxyz`. Both are
reachable from no branch. The K-13 cleanup of 2026-09-06 force-pushed the branch
to strip `Claude <noreply@anthropic.com>` from the author and committer fields;
rewriting a commit changes its sha, and the status files were not updated. The
live commits carrying this change are **`af0af806d`** and **`737b0a549`**.

It is not this slug's mistake and not a small one. Across all features:

| slug | recorded | live | subject |
|---|---|---|---|
| `ar-sessions` | `8bf6dce3e` | `bc745ce73` | Verify the database session store at deploy time… |
| `assignee-nobody` | `9d28be94d` | `349fe1860` | Assigned to issuelist filter: added &lt;nobody&gt; value |
| `assignee-nobody` | `d8e0db501` | `9ad87a11b` | Keep the &lt;nobody&gt; filter condition self-contained |
| `gitignore-credentials` | `e2c0447b6` | `af0af806d` | Ignore the Rails credentials files… |
| `gitignore-credentials` | `3f5eb3be2` | `737b0a549` | Ignore the per-environment Rails credentials directory |
| `ldap-mail-prefs` | `113f32117` | `bc7314a62` | Replace the LDAP mail-muting task… |
| `mypage-query-blocks` | `198cbfb63` | `dc6dad120` | Make the maximum number of custom query blocks… |
| `mypage-query-blocks` | `47eec6f1d` | `dd063fa8b` | Bound the maximum number of custom query blocks… |
| `mypage-query-blocks` | `1b4a29a0b` | `f5ed23c8e` | Raise the upper bound of the custom query blocks setting |
| `revision-branches` | `115230bc2` | `ff0d23b62` | Show the Git branches that contain a revision |
| `revision-branches` | `8c1fa23fb` | `755d763a8` | Validate the branch exclusion pattern… |
| `search-token-limit` | `1c85728aa` | `6695461bd` | Text filters no longer ignore keywords after the fifth |
| `search-token-limit` | `f260958c6` | `1cd7091fd` | Lift the token limit for the any_searchable filter |
| `version-subprojects` | `20ed9e2d1` | `fd35bd2d1` | Target version filter offers the versions of the subprojects |
| `version-subprojects` | `d157934c0` | `157c171a5` | Assert the target version filter with subproject issues hidden |
| `version-subprojects` | `e2f060570` | `74f343d3d` | Send and consume only the filter parameters… |
| `webhook-issue-closed` | `7e92b5596` | `465d326aa` | Keep the issue.closed timestamp mapping… |
| `webhook-tracker-filter` | `f2242bd86` | `c6631e937` | Limit an outgoing webhook to the trackers selected on it |
| `webhook-tracker-filter` | `646008041` | `86647653e` | Translate the webhook tracker hint into Dutch, French and Spanish |
| `webhook-tracker-filter` | `0fbad7c17` | `72058fa43` | Drop a destroyed tracker from its webhooks… |
| `webhook-tracker-filter` | `72a3a8e22` | `8ac09f4ff` | Deactivate a webhook when the only tracker it is limited to… |

Twenty-one of thirty-two. The eleven that are correct are exactly the ones
written on or after 2026-09-06: `geoxyz-hosts`, `imap-oauth`,
`members-pagination`, `wiki-export-attachments`, and `revision-branches`' third
commit.

**Why a committer would push back**

Not a committer — this never leaves the repository. The cost lands on the next
session and on Jan. Two concrete paths:

1. *Silently wrong here.* `git show f2242bd86` succeeds in this clone, because
   the pre-rewrite objects are still in the object database and nothing has been
   garbage-collected. It prints a real commit with real content. Somebody
   checking "what does production actually run for the webhook tracker filter"
   gets an answer that looks right and is not on the branch.
2. *Loudly wrong elsewhere.* In a fresh clone the same command is
   `fatal: bad object`, and every one of these twenty-one lines is a dead end at
   the moment somebody needs it most — a deploy question, or an incident.

The register is the only feature-to-commit map there is. When more than half
its GEOxyz column is dead, it is not a map.

**How I verified it**

Resolved every `geoxyz_commit` value in every `status.md` against
`7.0-stable-GEOxyz` with `git merge-base --is-ancestor`, separating "unknown
sha" from "known object, not on the branch" — all twenty-one are the second.
Then matched each orphan's subject line against the branch's own 38 commits;
every one maps to exactly one live commit, no ambiguity, which is what makes
the table above safe to act on.

**Suggested direction**

Update the `geoxyz_commit` field in the ten affected `status.md` files from the
table, then regenerate `docs/REGISTER.md`. That is per-feature-owned work, so it
belongs to whichever session claims each slug; doing all ten in one framework
session Jan asks for would be quicker and is the same edit.

Worth considering separately, and Jan's call rather than mine: a rewrite of a
branch that the register points into will do this again. The cheap guard is to
make the check that already walks these commits verify them (F02).

**Resolution:**

---

### F02 — `check-geoxyz-branch.sh` cannot catch either failure it is credited with

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `tools/check-geoxyz-branch.sh:92-101`
- **Invariant touched:** INV-4 (the half of it that is about identities)

**What is wrong**

CLAUDE.md describes G8 as "merges cleanly with upstream `7.0-stable`, lint adds
nothing beyond upstream's own offences on the same files, **own commits match
the register**". The tool does the first two. It does not do the third — there
is no reference to the register anywhere in it, which is why F01 sat unnoticed
through every G8 run since 2026-09-06.

The AI-trace check has the same shape of gap. It greps commit **messages**:

```sh
grep -inE 'co-authored-by:.*(cursor|claude|copilot|codex|chatgpt)|generated (with|by)|…'
```

INV-4 says in terms that it "covers the author and committer fields, not just
the message", and names those fields as "the half that bites". The tool never
reads `%an`, `%ae`, `%cn` or `%ce`. `tools/session-push.sh` does check them
since K-13, so a *new* push is guarded, but a branch that already carries such a
commit passes `check-geoxyz-branch.sh` reporting "no AI traces in own commit
messages" — which is true, and reads as INV-4 being satisfied.

**Why a committer would push back**

Again, internal cost. The concrete path: `docs/features/gitignore-credentials/status.md`
cites a `check-geoxyz-branch.sh` **PASS** as its evidence line, and that PASS is
what made the stale shas invisible. A gate that reports on a narrower thing than
its name suggests is worse than no gate, because the evidence line it produces
gets believed.

There is also a live instance of the identity half, on a patch branch rather
than this one, which no gate covers at all: `patch/mypage-query-blocks` at
`6af3b35c4` has committer `Claude <noreply@anthropic.com>`. It is reported in
that slug's own round-3 file; it is mentioned here only because it is the same
blind spot.

**How I verified it**

Read the tool. Grepped it for `register`, `%an`, `%cn`, `author`, `committer` —
the only hits are in the message-grep block. Ran it and read its output: nine
`ok` lines, none about the register. Then checked all nine `patch/*` branches
and all 38 own commits of `7.0-stable-GEOxyz` for AI identities directly, which
is how the `mypage-query-blocks` one surfaced.

**Suggested direction**

Two additions to the same tool, both a few lines: resolve every `geoxyz_commit`
from the status files against the branch and fail on anything not an ancestor;
and extend the AI-trace check from the message to `%an <%ae>` and `%cn <%ce>`,
which is what INV-4 actually asks for. `tools/**` is framework-owned, so this
needs Jan to ask for it — a reviewer cannot and should not make the change.

**Resolution:**
