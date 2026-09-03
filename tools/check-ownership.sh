#!/usr/bin/env bash
# Verify a session only writes the framework files its own feature owns.
#
#   tools/check-ownership.sh <slug>
#
# Parallel sessions stay out of each other's way because they touch disjoint
# files, not because they remember to. This is the check that makes that
# mechanical, the same way tools/check-patch-clean.sh makes INV-9 mechanical.
#
# Run it before every push on geoxyz/framework.
#
# A feature session owns:
#     docs/features/<slug>/**        status, dossier, decisions, shots
#     patches/<slug>/**
#     verify/<slug>.mjs
#     docs/claims/<slug>--*
#     docs/review/findings/*<slug>*
#     docs/REGISTER.md               generated — regenerate, never merge
#
# Shared, and only ever appended through tools/append-note.sh:
#     docs/traps.md  docs/DECISIONS.md  docs/redmine-requirements.md
#
# Nobody else's: CLAUDE.md, docs/STATE.md, docs/runbook.md, tools/**,
# .claude/**, and every other slug's directory. Those belong to a session Jan
# explicitly asked to change the framework.

set -uo pipefail

REPO="${REPO:-/home/user/redmine}"
cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

SLUG="${1:?usage: $0 <slug>}"
BASE="${BASE:-origin/geoxyz/framework}"

fails=0
pass() { printf '  ok    %s\n' "$1"; }
warn() { printf '  note  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

echo "check-ownership: $SLUG  (against $BASE)"

git fetch -q origin geoxyz/framework 2>/dev/null || warn "could not fetch; using the ref already present"

# Everything this session would push: committed but unpushed, plus the working
# tree. Both matter — a stray edit is a stray edit whether it is committed yet.
changed=$( { git diff --name-only "$BASE...HEAD" 2>/dev/null
             git status --porcelain | awk '{print $NF}'; } | sort -u | grep . || true)

if [ -z "$changed" ]; then
  pass "nothing to push"
  echo
  echo "PASS"
  exit 0
fi

OWNED="^(docs/features/$SLUG/|patches/$SLUG/|verify/$SLUG\.mjs$|docs/claims/$SLUG--|docs/review/findings/[^/]*$SLUG[^/]*$|docs/REGISTER\.md$)"
SHARED='^(docs/traps\.md|docs/DECISIONS\.md|docs/redmine-requirements\.md)$'

owned=$(printf '%s\n' "$changed" | grep -E "$OWNED" || true)
shared=$(printf '%s\n' "$changed" | grep -E "$SHARED" || true)
foreign=$(printf '%s\n' "$changed" | grep -v -E "$OWNED" | grep -v -E "$SHARED" | grep . || true)

[ -n "$owned" ] && pass "$(printf '%s\n' "$owned" | wc -l | tr -d ' ') file(s) this feature owns"

if [ -n "$shared" ]; then
  warn "shared file(s) — push these with tools/append-note.sh, not in your own commit:"
  printf '%s\n' "$shared" | sed 's/^/          /'
fi

if [ -n "$foreign" ]; then
  fail "file(s) this session does not own:"
  printf '%s\n' "$foreign" | sed 's/^/          /'
  echo "          Another slug's directory, the framework itself, or the tools." >&2
  echo "          If Jan asked for a framework change, say so and skip this check." >&2
fi

# A generated file that was hand-edited is worse than a conflict, because it
# looks authoritative and the next regeneration silently reverts it.
if printf '%s\n' "$changed" | grep -qx 'docs/REGISTER\.md'; then
  if tools/register.sh > /tmp/register-check.$$ 2>/dev/null &&
     ! diff -q /tmp/register-check.$$ docs/REGISTER.md >/dev/null; then
    fail "docs/REGISTER.md does not match tools/register.sh — run 'tools/register.sh --write'"
  else
    pass "docs/REGISTER.md matches its generator"
  fi
  rm -f /tmp/register-check.$$
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS"
  exit 0
fi
echo "$fails check(s) failed"
exit 1
