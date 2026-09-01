#!/usr/bin/env bash
# Verify a patch branch is safe to export to redmine.org.
#
#   tools/check-patch-clean.sh patch/<slug> [/path/to/redmine/repo]
#
# Three checks, all must pass:
#   1. the branch descends from origin/master (so no framework commit is in range)
#   2. the diff touches no framework path and no GEOxyz-local path
#   3. the exported patch applies to a pristine origin/master checkout
#
# Exit 0 = safe to submit. Exit 1 = do not submit.

set -uo pipefail

BRANCH="${1:-}"
REPO="${2:-/home/user/redmine}"

if [ -z "$BRANCH" ]; then
  echo "usage: $0 patch/<slug> [repo-path]" >&2
  exit 2
fi

cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

fails=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

echo "check-patch-clean: $BRANCH  (repo $REPO)"

git rev-parse --verify --quiet "$BRANCH" >/dev/null || {
  echo "FAIL  no such branch: $BRANCH" >&2
  exit 2
}

git fetch -q origin master 2>/dev/null || echo "  note  could not fetch; using the origin/master already present"

# --- 1. descent from trunk -------------------------------------------------
if git merge-base --is-ancestor origin/master "$BRANCH"; then
  pass "descends from origin/master"
else
  base=$(git merge-base origin/master "$BRANCH" 2>/dev/null || echo unknown)
  fail "does NOT descend from current origin/master (merge base ${base:0:9}) — recreate the branch from trunk"
fi

# --- 2. no framework or GEOxyz-local path ----------------------------------
# Anything on the framework branch, plus files that exist only in a GEOxyz
# deployment and must never be proposed to Redmine.
FORBIDDEN_PATHS='^(CLAUDE\.md|\.claude/|docs/(STATE|DECISIONS)\.md|docs/(features|review)/|patches/|tools/check-patch-clean\.sh|config/database\.yml|config/additional_environment\.rb)'

changed=$(git diff --name-only origin/master..."$BRANCH")
if [ -z "$changed" ]; then
  fail "the branch changes nothing relative to origin/master"
else
  leaked=$(printf '%s\n' "$changed" | grep -E "$FORBIDDEN_PATHS" || true)
  if [ -n "$leaked" ]; then
    fail "patch touches paths that must never be submitted:"
    printf '%s\n' "$leaked" | sed 's/^/          /'
  else
    pass "touches only Redmine paths ($(printf '%s\n' "$changed" | wc -l | tr -d ' ') files)"
  fi

  # INV-5: en.yml, plus only a language Jan vouches for personally.
  # Redmine falls back to English for a missing key, so an absent translation
  # costs nothing; an unverifiable one costs the patch its credibility.
  ALLOWED_LOCALES='^config/locales/(en|nl)\.yml$'

  locales=$(printf '%s\n' "$changed" | grep -E '^config/locales/' || true)
  bad_locales=$(printf '%s\n' "$locales" | grep -v -E "$ALLOWED_LOCALES" | grep . || true)
  if [ -n "$bad_locales" ]; then
    fail "patch touches locales beyond en.yml/nl.yml (INV-5) — leave these to Redmine's translators:"
    printf '%s\n' "$bad_locales" | sed 's/^/          /'
  elif [ -n "$locales" ]; then
    pass "locales: $(printf '%s\n' "$locales" | xargs -n1 basename | paste -sd, -)"
  else
    pass "locales: none touched"
  fi
fi

# --- 3. AI traces in the commit messages -----------------------------------
traces=$(git log --format='%B' origin/master.."$BRANCH" |
         grep -inE 'co-authored-by:.*(cursor|claude|copilot|codex|chatgpt|ai\b)|generated (with|by)|claude-(opus|sonnet|haiku|fable)' || true)
if [ -n "$traces" ]; then
  fail "commit messages contain AI traces (INV-4):"
  printf '%s\n' "$traces" | sed 's/^/          /'
else
  pass "no AI traces in commit messages"
fi

# --- 4. applies to a pristine trunk checkout -------------------------------
tmp=$(mktemp -d)
cleanup() { git worktree remove --force "$tmp/trunk" >/dev/null 2>&1; rm -rf "$tmp"; }
trap cleanup EXIT

if git worktree add --detach -q "$tmp/trunk" origin/master 2>/dev/null; then
  if git format-patch origin/master.."$BRANCH" --stdout > "$tmp/p.patch" 2>/dev/null &&
     [ -s "$tmp/p.patch" ] &&
     git -C "$tmp/trunk" apply --check "$tmp/p.patch" 2>"$tmp/err"; then
    pass "applies cleanly to a pristine origin/master checkout"
  else
    fail "does NOT apply to a pristine origin/master checkout:"
    sed 's/^/          /' "$tmp/err" 2>/dev/null | head -5
  fi
else
  fail "could not create a trunk worktree to test against"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS — safe to submit"
  exit 0
fi
echo "$fails check(s) failed — do NOT submit"
exit 1
