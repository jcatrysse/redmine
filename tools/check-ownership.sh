#!/usr/bin/env bash
# Verify a session only writes the framework files its own feature owns.
#
#   tools/check-ownership.sh <slug>
#   tools/check-ownership.sh --infer     work the slug out from the changed paths
#
# Parallel sessions stay out of each other's way because they touch disjoint
# files, not because they remember to. This is the check that makes that
# mechanical, the same way tools/check-patch-clean.sh makes INV-9 mechanical.
#
# tools/session-push.sh runs it with --infer on geoxyz/framework, so it is no
# longer a thing to remember. Until 2026-09-10 CLAUDE.md and docs/STATE.md both
# called it mechanical while nothing anywhere invoked it (round 4, tools F07).
# A session Jan asked for a framework change sets FRAMEWORK_CHANGE=1 to push
# past it — that is the one legitimate case, and it has to be stated rather than
# assumed.
#
# A feature session owns:
#     docs/features/<slug>/**        status, dossier, decisions, shots
#     patches/<slug>/**
#     verify/<slug>.mjs
#     docs/claims/<slug>--*
#     docs/review/findings/*<slug>*
#     docs/REGISTER.md               generated — regenerate, never merge
#     docs/review/FINDINGS.md        generated — regenerate, never merge
#
# Shared, and only ever appended through tools/append-note.sh:
#     docs/traps.md  docs/DECISIONS.md  docs/redmine-requirements.md
#     docs/exceptions.md
#
# Nobody else's: CLAUDE.md, docs/STATE.md, docs/runbook.md, tools/**,
# .claude/**, and every other slug's directory. Those belong to a session Jan
# explicitly asked to change the framework.

set -uo pipefail

REPO="${REPO:-/home/user/redmine}"
cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

SLUG="${1:?usage: $0 <slug>|--infer}"
BASE="${BASE:-origin/geoxyz/framework}"

fails=0
pass() { printf '  ok    %s\n' "$1"; }
warn() { printf '  note  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

git fetch -q origin geoxyz/framework 2>/dev/null || warn "could not fetch; using the ref already present"

# Everything this session would push: committed but unpushed, plus the working
# tree. Both matter — a stray edit is a stray edit whether it is committed yet.
# -z, because `awk '{print $NF}'` returned only the last whitespace-delimited
# token and mangled any path with a space in it (round 4, tools F13).
changed=$( { git diff --name-only "$BASE...HEAD" 2>/dev/null
             git status --porcelain -z | tr '\0' '\n' | sed -n 's/^..[ ]//p'
           } | sort -u | grep . || true)

if [ "$SLUG" = --infer ]; then
  # Which feature do these paths belong to? A findings file cannot say — its
  # name is <date>-<slug>-<reviewer> and both halves are dashed — so it is left
  # out here and checked against OWNED once a slug is known.
  inferred=$(printf '%s\n' "$changed" | sed -n \
      -e 's|^docs/features/\([^/]*\)/.*|\1|p' \
      -e 's|^patches/\([^/]*\)/.*|\1|p' \
      -e 's|^verify/\([^/]*\)\.mjs$|\1|p' \
      -e 's|^docs/claims/\(.*\)--.*|\1|p' | sort -u)
  case $(printf '%s' "$inferred" | grep -c .) in
    0) SLUG='' ;;
    1) SLUG="$inferred" ;;
    *) echo "check-ownership: --infer"
       echo "  FAIL  these changes span more than one feature, so no single session owns them:" >&2
       printf '          %s\n' $inferred >&2
       echo "          Split them into one commit per slug, or say which slug this is." >&2
       exit 1 ;;
  esac
fi

echo "check-ownership: ${SLUG:-no slug — shared and generated files only}  (against $BASE)"

if [ -z "$changed" ]; then
  pass "nothing to push"
  echo
  echo "PASS"
  exit 0
fi

if [ -n "$SLUG" ]; then
  OWNED="^(docs/features/$SLUG/|patches/$SLUG/|verify/$SLUG\.mjs$|docs/claims/$SLUG--|docs/review/findings/[^/]*$SLUG[^/]*$|docs/REGISTER\.md$|docs/review/FINDINGS\.md$)"
else
  OWNED='^(docs/review/findings/[^/]*$|docs/REGISTER\.md$|docs/review/FINDINGS\.md$)'
fi
SHARED='^(docs/traps\.md|docs/DECISIONS\.md|docs/redmine-requirements\.md|docs/exceptions\.md)$'

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
# looks authoritative and the next regeneration silently reverts it. There are
# two of them and both are owned by whoever pushes, so both are checked.
check_generated() {
  path="$1"; generator="$2"
  printf '%s\n' "$changed" | grep -qxF "$path" || return 0

  # Two conditions, separately. Chaining them with && sent a generator that
  # exited non-zero into the else branch, which announces that the file matches
  # — so a broken generator made any hand edit look authoritative, which is the
  # opposite of what this check is for (round 4, tools F06).
  tmp=$(mktemp)
  if ! "$generator" > "$tmp" 2>"$tmp.err"; then
    fail "$generator failed, so nothing is known about $path:"
    sed 's/^/          /' "$tmp.err" | tail -3
  elif ! diff -q "$tmp" "$path" >/dev/null; then
    fail "$path does not match $generator — run '$generator --write'"
  else
    pass "$path matches its generator"
  fi
  rm -f "$tmp" "$tmp.err"
}

check_generated 'docs/REGISTER.md'        tools/register.sh
check_generated 'docs/review/FINDINGS.md' tools/findings.sh

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS"
  exit 0
fi
echo "$fails check(s) failed"
exit 1
