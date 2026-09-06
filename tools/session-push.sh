#!/usr/bin/env bash
# Push the current branch when other sessions may be pushing to it too.
#
#   tools/session-push.sh [branch]        # default: the current branch
#
# fetch, replay your own unpushed commits on top of the remote, push. Retries
# four times with backoff (2s, 4s, 8s, 16s), which covers both a network failure
# and losing the race to a parallel session. Never force-pushes.
#
# Two things here exist because of K-13 (2026-09-06), where sixteen of the
# thirty-three own commits on 7.0-stable-GEOxyz turned out to carry
# `Claude <noreply@anthropic.com>` and had to be force-pushed away:
#
#   1. the replay preserves the committer instead of stamping whoever runs it;
#   2. a push to 7.0-stable-GEOxyz or patch/* is refused outright when a commit
#      carries an AI identity in its author or committer field (INV-4).
#
# (2) is the one that matters. The global git identity in a session is the AI's,
# so a commit made without an explicit override is already wrong before any
# replay — the replay was never the only cause. Catching it at push time is what
# stops it from accumulating unnoticed for sixteen commits again.
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

      # A plain `git rebase` stamps the committer of whoever runs it. Carry the
      # committer of the commits being replayed instead, so a replay changes
      # nothing but the parent. One identity is the normal case: these are the
      # commits of this session. More than one means the session committed under
      # different identities, and guessing which to keep would mislabel history,
      # so that case stops here rather than being papered over.
      mapfile -t replay_committers < <(
        git log --format='%cn|%ce' "origin/$BRANCH..HEAD" | sort -u)
      if [ "${#replay_committers[@]}" -gt 1 ]; then
        echo "FAIL  the commits to replay have ${#replay_committers[@]} different committers:" >&2
        printf '        %s\n' "${replay_committers[@]}" >&2
        echo "      Replaying would stamp one identity over all of them. Set them" >&2
        echo "      right first, then run this again." >&2
        exit 1
      fi
      GIT_COMMITTER_NAME="${replay_committers[0]%%|*}"
      GIT_COMMITTER_EMAIL="${replay_committers[0]##*|}"
      export GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

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

  # INV-4: nothing with an AI identity may reach the two branches that ship
  # Redmine code. geoxyz/framework is exempt — K-01 puts the attribution there
  # on purpose.
  case "$BRANCH" in
    7.0-stable-GEOxyz|patch/*)
      if git rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
        range="origin/$BRANCH..HEAD"
      elif [ "$BRANCH" = "7.0-stable-GEOxyz" ]; then
        range="origin/7.0-stable..HEAD"
      else
        range="origin/master..HEAD"
      fi
      traced=$(git log --format='%h %an <%ae> / %cn <%ce>' "$range" |
               grep -iE 'anthropic|(^| )claude( |<)' )
      if [ -n "$traced" ]; then
        echo "FAIL  INV-4: an AI identity on commits bound for $BRANCH" >&2
        printf '        %s\n' "$traced" >&2
        cat >&2 <<TXT

      The author reaches a patch — \`git format-patch\` carries it — and the
      committer reaches every clone. Neither belongs on this branch (K-01).
      These commits are not pushed yet, so rewriting them costs nothing:

          FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --env-filter '
            if [ "\$GIT_COMMITTER_EMAIL" = "noreply@anthropic.com" ]; then
              export GIT_COMMITTER_NAME="Jan Catrysse"
              export GIT_COMMITTER_EMAIL="jan.catrysse@geoxyz.eu"
            fi
            if [ "\$GIT_AUTHOR_EMAIL" = "noreply@anthropic.com" ]; then
              export GIT_AUTHOR_NAME="Jan Catrysse"
              export GIT_AUTHOR_EMAIL="jan.catrysse@geoxyz.eu"
            fi' -- $range

      Then run this again. To stop it happening at all, commit with the right
      identity in the first place — the session's global git identity is the
      AI's, so it has to be given explicitly:

          git -c user.name="Jan Catrysse" -c user.email="jan.catrysse@geoxyz.eu" commit ...

      Keep a third-party author (a contributor whose patch you applied) as it
      is: only the two fields above are wrong.
TXT
        exit 1
      fi
      ;;
  esac

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
