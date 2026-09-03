#!/usr/bin/env bash
# Append a block to a file that every session writes to, without ever
# conflicting with a parallel session.
#
#   tools/append-note.sh docs/traps.md <<'TXT'
#   - **A trap in one line.** Why it bites and what to do instead.
#   TXT
#
# Two sessions appending at the end of the same file is the one conflict this
# framework cannot design away — docs/traps.md and docs/DECISIONS.md are worth
# more as one readable list than as forty fragments. So the append happens
# AFTER the fetch and replay, inside the retry loop: whatever the other session
# added is already there, and this block goes underneath it. Nothing to merge.
#
# Never use this for a file one session owns (docs/features/<slug>/**) — just
# edit those.

set -uo pipefail

REPO="${REPO:-/home/user/redmine}"
cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

FILE="${1:?usage: $0 <file>   (block on stdin)}"
MSG="${2:-}"

case "$FILE" in
  docs/traps.md|docs/DECISIONS.md|docs/redmine-requirements.md) ;;
  *)
    echo "FAIL  $FILE is not a shared append-only file." >&2
    echo "      Shared: docs/traps.md, docs/DECISIONS.md, docs/redmine-requirements.md." >&2
    echo "      Anything under docs/features/<slug>/ is yours — edit it directly." >&2
    exit 2
    ;;
esac

BLOCK=$(cat)
[ -n "$BLOCK" ] || { echo "FAIL  nothing on stdin" >&2; exit 2; }

if [ -n "$(git status --porcelain -- "$FILE")" ]; then
  echo "FAIL  $FILE already has uncommitted changes — commit or discard them first" >&2
  exit 2
fi

delay=2
for attempt in 1 2 3 4 5; do
  git fetch -q origin geoxyz/framework 2>/dev/null
  git rebase -q origin/geoxyz/framework 2>/dev/null || {
    echo "FAIL  could not replay on origin/geoxyz/framework — resolve that first" >&2
    exit 1
  }

  [ -f "$FILE" ] || : > "$FILE"
  [ -s "$FILE" ] && [ -n "$(tail -c1 "$FILE")" ] && printf '\n' >> "$FILE"
  printf '%s\n' "$BLOCK" >> "$FILE"

  git add "$FILE"
  if git diff --cached --quiet; then
    echo "note  nothing to add — that block is already there"
    exit 0
  fi
  git commit -q -m "${MSG:-$(basename "$FILE" .md): $(printf '%s' "$BLOCK" | head -1 | cut -c1-60)}"

  if git push -q origin geoxyz/framework 2>/dev/null; then
    echo "PASS  appended to $FILE"
    exit 0
  fi

  # Undo only the commit this loop just made. Never reset to the remote — this
  # session may be holding other unpushed commits of its own.
  echo "note  attempt $attempt lost the race or the network, retrying in ${delay}s" >&2
  git reset -q --hard HEAD~1
  sleep "$delay"
  delay=$((delay * 2))
done

echo "FAIL  could not append to $FILE after 5 attempts" >&2
exit 1
