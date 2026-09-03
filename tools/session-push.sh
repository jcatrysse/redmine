#!/usr/bin/env bash
# Push the current branch when other sessions may be pushing to it too.
#
#   tools/session-push.sh [branch]        # default: the current branch
#
# fetch, replay your own unpushed commits on top of the remote, push. Retries
# four times with backoff (2s, 4s, 8s, 16s), which covers both a network failure
# and losing the race to a parallel session. Never force-pushes.
#
# "Never rebase" in CLAUDE.md is about history that has been published — a
# rebase there invalidates every checkout GEOxyz has. Replaying a commit you
# have not pushed yet onto the branch tip is the opposite: nobody has it, and it
# is what keeps 7.0-stable-GEOxyz one linear commit per feature instead of a
# thicket of merge commits from parallel sessions.

set -uo pipefail

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
REPO="${REPO:-$(git rev-parse --show-toplevel)}"
cd "$REPO" || exit 2

if [ "$BRANCH" != "$(git rev-parse --abbrev-ref HEAD)" ]; then
  echo "FAIL  $BRANCH is not checked out here (HEAD is $(git rev-parse --abbrev-ref HEAD))" >&2
  exit 2
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "FAIL  working tree is dirty — commit first, then push" >&2
  git status --short >&2
  exit 2
fi

delay=2
for attempt in 1 2 3 4 5; do
  git fetch -q origin "$BRANCH" 2>/dev/null

  if git rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
    behind=$(git rev-list --count "HEAD..origin/$BRANCH")
    if [ "$behind" -gt 0 ]; then
      echo "==> $behind new commit(s) on origin/$BRANCH — replaying mine on top"
      if ! git rebase "origin/$BRANCH"; then
        cat >&2 <<'TXT'

FAIL  the replay hit a conflict. Resolve it and run this again.

      The one you should expect when two sessions each finished a feature:
      both appended a key at the end of config/locales/{nl,fr,de,es}.yml, or
      both appended a block at the end of docs/traps.md. Keep BOTH sides —
      there is nothing to choose. Then:

          git add <files> && git rebase --continue

      Anything else, read it properly before resolving.
TXT
        exit 1
      fi
    fi
  fi

  if git push -u origin "$BRANCH" 2>&1 | tail -2; then
    echo "PASS  pushed $BRANCH"
    exit 0
  fi

  echo "note  push attempt $attempt failed, retrying in ${delay}s" >&2
  sleep "$delay"
  delay=$((delay * 2))
done

echo "FAIL  could not push $BRANCH after 5 attempts" >&2
exit 1
