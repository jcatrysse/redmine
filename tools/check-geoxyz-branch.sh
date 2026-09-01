#!/usr/bin/env bash
# Health of the branch GEOxyz actually runs.
#
#   tools/check-geoxyz-branch.sh [/path/to/redmine/repo]
#
# Checks origin/7.0-stable-GEOxyz by default. To check work in progress before
# pushing it, point REF at a local ref (the remote fetch is then skipped):
#
#   REF=7.0-stable-GEOxyz tools/check-geoxyz-branch.sh
#
# Fast checks only — the test suite is G8's other half and has to be run
# separately (see docs/runbook.md). This answers: is the branch current, does it
# still merge with upstream, is its lint clean, and what does it carry?
#
# Exit 0 = healthy. Exit 1 = something needs attention.

set -uo pipefail

REPO="${1:-/home/user/redmine}"
BRANCH=7.0-stable-GEOxyz
UPSTREAM=origin/7.0-stable
RUBOCOP="${RUBOCOP:-/opt/rbenv/versions/3.3.6/bin/rubocop}"

cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

fails=0
pass() { printf '  ok    %s\n' "$1"; }
warn() { printf '  note  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

echo "check-geoxyz-branch: $BRANCH  (repo $REPO)"

if [ -n "${REF:-}" ]; then
  ref="$REF"
  git fetch -q origin 7.0-stable 2>/dev/null || warn "could not fetch upstream"
  warn "checking local ref $ref instead of origin/$BRANCH"
else
  git fetch -q origin 7.0-stable "$BRANCH" 2>/dev/null ||
    warn "could not fetch; using the refs already present"
  ref="origin/$BRANCH"
fi
git rev-parse --verify --quiet "$ref" >/dev/null || {
  echo "FAIL  no such branch: $ref" >&2
  exit 2
}

# --- 1. is it current with upstream 7.0-stable? ----------------------------
behind=$(git rev-list --count "$ref..$UPSTREAM")
if [ "$behind" -eq 0 ]; then
  pass "current with $UPSTREAM"
else
  fail "$behind commit(s) behind $UPSTREAM — merge upstream in before starting a feature (never rebase)"
fi

# --- 2. own commits, and do they merge cleanly? ----------------------------
own=$(git rev-list --count "$UPSTREAM..$ref")
if [ "$own" -eq 0 ]; then
  warn "no own commits yet — nothing of GEOxyz is on 7.0 so far"
else
  pass "$own own commit(s):"
  git log --format='          %h  %s' "$UPSTREAM..$ref" | sed 's/(#[0-9]*)//'
fi

# A worktree checked out at $ref. Needed for both the merge test and the lint:
# rubocop reads the working tree, so linting from the repo root would silently
# skip files that exist only on this branch and report a false "clean".
tmp=$(mktemp -d)
cleanup() { git worktree remove --force "$tmp/m" >/dev/null 2>&1; rm -rf "$tmp"; }
trap cleanup EXIT

wt=""
if git worktree add --detach -q "$tmp/m" "$ref" 2>/dev/null; then
  wt="$tmp/m"
else
  fail "could not create a worktree at $ref — merge and lint checks skipped"
fi

if [ -z "$wt" ]; then
  :
elif [ "$behind" -eq 0 ]; then
  pass "nothing to merge — already current"
elif git -C "$wt" merge --no-commit --no-ff "$UPSTREAM" >/dev/null 2>&1; then
  pass "merges cleanly with $UPSTREAM"
  git -C "$wt" merge --abort >/dev/null 2>&1
else
  conflicts=$(git -C "$wt" diff --name-only --diff-filter=U 2>/dev/null | head -8)
  fail "does NOT merge cleanly with $UPSTREAM:"
  printf '%s\n' "$conflicts" | sed 's/^/          /'
  git -C "$wt" merge --abort >/dev/null 2>&1
fi

# --- 3. AI traces in own commit messages -----------------------------------
# INV-4 applies here too: these commits are the source of a future patch.
if [ "$own" -gt 0 ]; then
  traces=$(git log --format='%B' "$UPSTREAM..$ref" |
           grep -inE 'co-authored-by:.*(cursor|claude|copilot|codex|chatgpt)|generated (with|by)|claude-(opus|sonnet|haiku|fable)|(claude|chatgpt|cursor)[-.]?session|claude\.ai/code' || true)
  if [ -n "$traces" ]; then
    fail "own commit messages contain AI traces (INV-4):"
    printf '%s\n' "$traces" | sed 's/^/          /'
  else
    pass "no AI traces in own commit messages"
  fi
fi

# --- 4. lint on what the branch changes -----------------------------------
if [ "$own" -eq 0 ]; then
  pass "lint: nothing changed to lint"
elif [ ! -x "$RUBOCOP" ]; then
  warn "rubocop not found at $RUBOCOP — set RUBOCOP= to check lint"
elif [ -z "$wt" ]; then
  warn "lint skipped — no worktree"
else
  files=$(git diff --name-only "$UPSTREAM...$ref" | grep -E '\.(rb|rake)$' || true)
  if [ -z "$files" ]; then
    pass "lint: no Ruby files changed"
  else
    # Run inside the worktree, and count from JSON: the human-readable summary
    # is ambiguous to parse.
    n=$(cd "$wt" && "$RUBOCOP" --force-exclusion --format json $files 2>/dev/null |
        grep -o '"cop_name"' | wc -l | tr -d ' ')
    n=${n:-0}
    if [ "$n" -eq 0 ]; then
      pass "lint: 0 offences on $(printf '%s\n' "$files" | wc -l | tr -d ' ') changed Ruby file(s)"
    else
      fail "lint: $n offence(s) on the changed Ruby files — Redmine's CI runs rubocop"
    fi
  fi
fi

# --- 5. locales stay inside the five ---------------------------------------
if [ "$own" -gt 0 ]; then
  bad=$(git diff --name-only "$UPSTREAM...$ref" |
        grep -E '^config/locales/' | grep -v -E '^config/locales/(en|nl|fr|de|es)\.yml$' || true)
  if [ -n "$bad" ]; then
    fail "locales outside en/nl/fr/de/es (INV-5):"
    printf '%s\n' "$bad" | sed 's/^/          /'
  else
    pass "locales within en/nl/fr/de/es"
  fi
fi

echo
echo "Not covered here (G8's other half): the test suite. Run it — see docs/runbook.md."
echo
if [ "$fails" -eq 0 ]; then
  echo "PASS"
  exit 0
fi
echo "$fails check(s) need attention"
exit 1
