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

  # INV-5: en plus the four languages GEOxyz ships (Jan, 2026-09-01).
  ALLOWED_LOCALES='^config/locales/(en|nl|fr|de|es)\.yml$'

  locales=$(printf '%s\n' "$changed" | grep -E '^config/locales/' || true)
  bad_locales=$(printf '%s\n' "$locales" | grep -v -E "$ALLOWED_LOCALES" | grep . || true)
  if [ -n "$bad_locales" ]; then
    fail "patch touches locales outside en/nl/fr/de/es (INV-5) — leave these to Redmine's translators:"
    printf '%s\n' "$bad_locales" | sed 's/^/          /'
  elif [ -n "$locales" ]; then
    pass "locales: $(printf '%s\n' "$locales" | xargs -n1 basename | paste -sd, -)"

    # A feature patch carrying translations is bigger and slower to review than
    # the same work as two files on one issue. Not a failure — Jan's call.
    code=$(printf '%s\n' "$changed" | grep -v -E '^config/locales/' | grep . || true)
    extra=$(printf '%s\n' "$locales" | grep -v -E '^config/locales/en\.yml$' | grep -c . || true)
    if [ -n "$code" ] && [ "$extra" -gt 0 ]; then
      printf '  note  this patch mixes code with %s translated locale file(s).\n' "$extra"
      printf '        Consider two files on the same issue: the feature (code + en.yml),\n'
      printf '        and the translations. Reviewers can take the first without the second.\n'
    fi
  else
    pass "locales: none touched"
  fi
fi

# --- 3. AI traces in the commit messages -----------------------------------
traces=$(git log --format='%B' origin/master.."$BRANCH" |
         grep -inE 'co-authored-by:.*(cursor|claude|copilot|codex|chatgpt|ai\b)|generated (with|by)|claude-(opus|sonnet|haiku|fable)|(claude|chatgpt|cursor)[-.]?session|claude\.ai/code' || true)
if [ -n "$traces" ]; then
  fail "commit messages contain AI traces (INV-4):"
  printf '%s\n' "$traces" | sed 's/^/          /'
else
  pass "no AI traces in commit messages"
fi

# --- 3b. AI identity in the commit authorship ------------------------------
# git format-patch writes the author into the "From:" line of the file that
# gets attached to the issue, so a tool identity there is as much an AI trace
# as one in the message. Found by exporting a patch and reading it.
authors=$(git log --format='%an <%ae>%n%cn <%ce>' origin/master.."$BRANCH" |
          grep -inE 'claude|anthropic|copilot|cursor|codex|chatgpt|openai|noreply@' || true)
if [ -n "$authors" ]; then
  fail "commit author or committer is a tool identity (INV-4):"
  printf '%s\n' "$authors" | sort -u | sed 's/^/          /'
else
  pass "no AI identity in commit authorship"
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
