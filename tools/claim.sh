#!/usr/bin/env bash
# Claim a feature before working on it, so two parallel sessions cannot build
# the same one.
#
#   tools/claim.sh <slug>            # take it, or find out you cannot
#   tools/claim.sh <slug> --release  # give it back untouched
#   tools/claim.sh --list            # who holds what
#   tools/claim.sh <slug> --force    # take over a claim whose session is gone
#
# The lock is a file per session: docs/claims/<slug>--<session>. Two sessions
# claiming the same slug write two DIFFERENT paths, so the pushes never
# conflict — they both land, and then the tie is broken the same way by both
# sides: earliest date wins, and the lexicographically smaller session id breaks
# a same-day tie. The loser deletes its own file and takes another row.
#
# A same-path lock (a line in status.md, or one CLAIM file) would collide on the
# replay instead of producing a winner, which is how this was written the first
# time and why it is not written that way now.

set -uo pipefail

REPO="${REPO:-/home/user/redmine}"
cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

ME="${CLAUDE_CODE_REMOTE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-$(hostname)-$$}}"
ME=$(printf '%s' "$ME" | tr -c 'A-Za-z0-9_.-' '-')
TODAY=$(date -u +%Y-%m-%d)
DIR=docs/claims

# Both this script and tools/append-note.sh replay onto origin/geoxyz/framework,
# and neither checked which branch was actually checked out. The execution
# environment mints a fresh branch per session, so a session that ran this
# before doing the checkout in docs/STATE.md rebased that branch onto the
# framework branch and got an exit code with no explanation (round 4, tools
# F14).
on_framework_branch() {
  local here; here=$(git rev-parse --abbrev-ref HEAD)
  [ "$here" = geoxyz/framework ] && return 0
  cat >&2 <<TXT
FAIL  HEAD is '$here', not geoxyz/framework, and this tool replays onto the
      framework branch. Do the checkout from docs/STATE.md first:

          git fetch origin geoxyz/framework
          git checkout geoxyz/framework && git merge --ff-only origin/geoxyz/framework
TXT
  exit 2
}

holders() { ls "$DIR/$1--"* 2>/dev/null; }

# Both sides must agree on the winner without talking to each other: sort the
# claim files by the date inside them, then by session id.
winner() {
  local slug="$1" f
  for f in $(holders "$slug"); do
    printf '%s %s\n' "$(sed -n 's/^date: *//p' "$f" | head -1)" "$f"
  done | LC_ALL=C sort | head -1 | awk '{print $2}'
}

on_framework_branch
git fetch -q origin geoxyz/framework 2>/dev/null

if [ "${1:-}" = "--list" ]; then
  git rebase -q origin/geoxyz/framework 2>/dev/null
  if [ -z "$(ls "$DIR" 2>/dev/null | grep -v '^README' || true)" ]; then
    echo "no open claims"
    exit 0
  fi
  printf '%-28s %-12s %s\n' SLUG SINCE SESSION
  for f in "$DIR"/*--*; do
    [ -f "$f" ] || continue
    slug=${f#"$DIR"/}; slug=${slug%%--*}
    printf '%-28s %-12s %s\n' "$slug" \
      "$(sed -n 's/^date: *//p' "$f" | head -1)" \
      "$(sed -n 's/^session: *//p' "$f" | head -1)"
  done
  exit 0
fi

SLUG="${1:?usage: $0 <slug> [--release|--force] | --list}"
case "$SLUG" in */*|-*) echo "FAIL  '$SLUG' is not a slug" >&2; exit 2 ;; esac
MINE="$DIR/$SLUG--$ME"

git rebase -q origin/geoxyz/framework 2>/dev/null || {
  echo "FAIL  could not replay on origin/geoxyz/framework — resolve that first" >&2
  exit 1
}

# docs/REGISTER.md carries a "Nu in behandeling" section generated from these
# files, and nothing regenerated it — so a released claim stayed advertised on
# the branch, and check-ownership.sh's freshness check only looks when the
# register is itself part of the push, which is exactly when it is not stale.
# On 2026-09-10 the branch had claimed version-subprojects to a session that
# gave it back the day before (round 4, tools F05).
stage_register() {
  tools/register.sh --write >/dev/null 2>&1 || {
    echo "FAIL  could not regenerate docs/REGISTER.md — fix that before changing a claim" >&2
    exit 1
  }
  git add docs/REGISTER.md
}

if [ "${2:-}" = "--release" ]; then
  [ -f "$MINE" ] || { echo "note  this session holds no claim on $SLUG"; exit 0; }
  git rm -q "$MINE"
  stage_register
  git commit -q -m "$SLUG: claim released"
  exec tools/session-push.sh geoxyz/framework
fi

if [ "${2:-}" = "--force" ]; then
  for f in $(holders "$SLUG"); do [ "$f" = "$MINE" ] || git rm -q "$f"; done
fi

mkdir -p "$DIR"
{
  printf 'slug: %s\n' "$SLUG"
  printf 'date: %s\n' "$TODAY"
  printf 'session: %s\n' "$ME"
} > "$MINE"

git add "$MINE"
stage_register
if ! git diff --cached --quiet; then
  git commit -q -m "$SLUG: claimed"
  tools/session-push.sh geoxyz/framework >/dev/null || exit 1
fi

# Everything anyone claimed is now on the branch. Same rule on both sides.
win=$(winner "$SLUG")
if [ "$win" = "$MINE" ]; then
  others=$(holders "$SLUG" | grep -v -x "$MINE" || true)
  [ -n "$others" ] && echo "note  another session also claimed $SLUG and will stand down"
  echo "PASS  $SLUG is yours"
  exit 0
fi

echo "note  $SLUG went to $(sed -n 's/^session: *//p' "$win" | head -1) — standing down"
git rm -q "$MINE"
stage_register
git commit -q -m "$SLUG: claim withdrawn, another session got there first"
tools/session-push.sh geoxyz/framework >/dev/null || exit 1
echo "FAIL  $SLUG is taken. Take a different row from docs/REGISTER.md." >&2
exit 1
