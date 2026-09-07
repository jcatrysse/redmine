#!/usr/bin/env bash
# Verify what actually gets attached to a redmine.org issue: the patch FILE.
#
#   tools/check-patch-clean.sh <slug>                    every patches/<slug>/*.patch
#   tools/check-patch-clean.sh patches/<slug>/x.patch    one file
#   tools/check-patch-clean.sh patch/<slug>              a branch, exported first
#   tools/check-patch-clean.sh <slug> --submit           the pre-submission gate
#
# Until 2026-09-05 this checked the BRANCH. That let the two drift apart
# unseen: patch/wiki-export-attachments carried the design Jan rejected while
# patches/wiki-export-attachments/*.patch carried the one he chose, and a
# branch-only check called it clean (round-1 finding wiki-export-attachments
# F01). The file is what a committer downloads, so the file is the subject.
#
# Checks, in order:
#   1. the patch touches no framework path and no GEOxyz-local path (INV-9)
#   2. locales stay inside en/nl/fr/de/es (INV-5)
#   3. no AI trace in the From: line or the commit message (INV-4)
#   4. it applies to a pristine origin/master checkout
#   5. branch and patch file are the same change (no drift)
#
# Check 4 is a WARNING by default and a FAILURE with --submit. A patch that
# stopped applying because trunk moved 88 commits is not defective, it is
# stale; all nine branches failed the old permanent version of this rule for
# exactly that reason and it measured decay rather than quality (g13.1).
# Refreshing is the last step before submitting (g05), which is where --submit
# belongs.
#
# Exit 0 = safe. Exit 1 = do not submit.

set -uo pipefail

SUBJECT=""
SUBMIT=0
REPO="${REPO:-/home/user/redmine}"

for arg in "$@"; do
  case "$arg" in
    --submit) SUBMIT=1 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) if [ -z "$SUBJECT" ]; then SUBJECT="$arg"; else REPO="$arg"; fi ;;
  esac
done

if [ -z "$SUBJECT" ]; then
  echo "usage: $0 <slug>|<patch-file>|patch/<slug> [--submit] [repo-path]" >&2
  exit 2
fi

cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

fails=0
stale=0
pass() { printf '  ok    %s\n' "$1"; }
warn() { printf '  note  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

tmp=$(mktemp -d)
cleanup() {
  git worktree remove --force "$tmp/trunk" >/dev/null 2>&1
  git worktree remove --force "$tmp/drift" >/dev/null 2>&1
  rm -rf "$tmp"
}
trap cleanup EXIT

git fetch -q origin master 2>/dev/null || warn "could not fetch; using the origin/master already present"

# --- what are we checking? -------------------------------------------------
SLUG=""
BRANCH=""
FILES=""

if [ -f "$SUBJECT" ]; then
  FILES="$SUBJECT"
  SLUG=$(printf '%s' "$SUBJECT" | sed -n 's|^patches/\([^/]*\)/.*|\1|p')
elif [ -d "patches/$SUBJECT" ]; then
  SLUG="$SUBJECT"
  FILES=$(find "patches/$SLUG" -maxdepth 1 -name '*.patch' | sort)
  [ -n "$FILES" ] || { echo "FAIL  no .patch file in patches/$SLUG" >&2; exit 2; }
elif git rev-parse --verify --quiet "$SUBJECT" >/dev/null ||
     git rev-parse --verify --quiet "origin/$SUBJECT" >/dev/null; then
  SLUG=${SUBJECT#patch/}
  BRANCH="$SUBJECT"
  git rev-parse --verify --quiet "$BRANCH" >/dev/null || BRANCH="origin/$SUBJECT"
  base=$(git merge-base origin/master "$BRANCH")
  git format-patch "$base..$BRANCH" --stdout > "$tmp/branch.patch" 2>/dev/null
  [ -s "$tmp/branch.patch" ] || { echo "FAIL  $BRANCH changes nothing since $base" >&2; exit 2; }
  FILES="$tmp/branch.patch"
  warn "checking an export of $BRANCH — the file under patches/$SLUG/ is what gets attached"
else
  echo "FAIL  '$SUBJECT' is neither a patch file, a patches/<slug> directory, nor a branch" >&2
  exit 2
fi

# A slug given as a directory: check the branch against it as well, if there
# is one. That comparison is the whole point of check 5.
if [ -z "$BRANCH" ] && [ -n "$SLUG" ]; then
  for cand in "patch/$SLUG" "origin/patch/$SLUG"; do
    git rev-parse --verify --quiet "$cand" >/dev/null && { BRANCH="$cand"; break; }
  done
fi

# git apply runs with -C inside a temporary worktree, so a relative path here
# would resolve against the wrong directory and report "no such file" as if the
# patch were stale.
abs=""
for f in $FILES; do
  case "$f" in /*) abs="$abs $f" ;; *) abs="$abs $REPO/$f" ;; esac
done
FILES="${abs# }"

trunk_rev=$(git log -1 --format='%B' origin/master | sed -n 's|.*/trunk@\([0-9]*\) .*|\1|p')
echo "check-patch-clean: ${SLUG:-$SUBJECT}  (trunk r${trunk_rev:-?}, repo $REPO)"
printf '  file  %s\n' $FILES

# --- 1 + 2. the paths the patch touches ------------------------------------
changed=$(grep -h '^diff --git ' $FILES | sed 's|^diff --git a/\(.*\) b/.*|\1|' | sort -u)

FORBIDDEN_PATHS='^(CLAUDE\.md|\.claude/|docs/|patches/|verify/|tools/|config/database\.yml|config/additional_environment\.rb)'
ALLOWED_LOCALES='^config/locales/(en|nl|fr|de|es)\.yml$'

if [ -z "$changed" ]; then
  fail "the patch changes nothing"
else
  leaked=$(printf '%s\n' "$changed" | grep -E "$FORBIDDEN_PATHS" || true)
  if [ -n "$leaked" ]; then
    fail "patch touches paths that must never be submitted (INV-9):"
    printf '%s\n' "$leaked" | sed 's/^/          /'
  else
    pass "touches only Redmine paths ($(printf '%s\n' "$changed" | wc -l | tr -d ' ') files)"
  fi

  locales=$(printf '%s\n' "$changed" | grep -E '^config/locales/' || true)
  bad_locales=$(printf '%s\n' "$locales" | grep -v -E "$ALLOWED_LOCALES" | grep . || true)
  if [ -n "$bad_locales" ]; then
    fail "patch touches locales outside en/nl/fr/de/es (INV-5) — leave these to Redmine's translators:"
    printf '%s\n' "$bad_locales" | sed 's/^/          /'
  elif [ -n "$locales" ]; then
    pass "locales: $(printf '%s\n' "$locales" | xargs -n1 basename | paste -sd, -)"

    # Per file, not over the set: a slug that already splits feature from
    # translations is doing exactly what this note asks for.
    for f in $FILES; do
      fc=$(grep -h '^diff --git ' "$f" | sed 's|^diff --git a/\(.*\) b/.*|\1|' | sort -u)
      code=$(printf '%s\n' "$fc" | grep -v -E '^config/locales/' | grep . || true)
      extra=$(printf '%s\n' "$fc" | grep -E '^config/locales/' | grep -v -E '^config/locales/en\.yml$' | grep -c . || true)
      if [ -n "$code" ] && [ "$extra" -gt 0 ]; then
        warn "$(basename "$f") mixes code with $extra translated locale file(s)."
        printf '        Consider two files on the same issue: the feature (code + en.yml),\n'
        printf '        and the translations. Reviewers can take the first without the second.\n'
      fi
    done
  else
    pass "locales: none touched"
  fi
fi

# --- 3. AI traces in the header and the commit message ---------------------
# Only the part before the first hunk: a diff body may legitimately contain the
# word "generated" (Redmine generates plenty of things).
headers=$(awk '/^diff --git /{exit} {print}' $FILES)
traces=$(printf '%s\n' "$headers" |
         grep -inE 'co-authored-by:.*(cursor|claude|copilot|codex|chatgpt|ai\b)|generated (with|by)|claude-(opus|sonnet|haiku|fable)|(claude|chatgpt|cursor)[-.]?session|claude\.ai/code|claude|anthropic|copilot|codex|openai|noreply@' || true)
if [ -n "$traces" ]; then
  fail "AI trace in the patch header or commit message (INV-4):"
  printf '%s\n' "$traces" | sed 's/^/          /'
else
  pass "no AI trace in the header or the commit message"
fi

# --- 4. applies to a pristine trunk checkout -------------------------------
if git worktree add --detach -q "$tmp/trunk" origin/master 2>/dev/null; then
  if git -C "$tmp/trunk" apply --check $FILES 2>"$tmp/err"; then
    pass "applies to a pristine origin/master (r${trunk_rev:-?}) checkout"
  elif [ "$SUBMIT" -eq 1 ]; then
    fail "does NOT apply to trunk r${trunk_rev:-?} — refresh it before submitting:"
    sed 's/^/          /' "$tmp/err" 2>/dev/null | head -5
  else
    stale=1
    warn "stale: does not apply to trunk r${trunk_rev:-?} any more"
    sed 's/^/        /' "$tmp/err" 2>/dev/null | head -5
    printf '        Not a defect — refresh against trunk as the last step before\n'
    printf '        submitting (g05) and re-run with --submit.\n'
  fi
else
  fail "could not create a trunk worktree to test against"
fi

# --- 5. branch and file are the same change --------------------------------
if [ -n "$BRANCH" ] && [ "$FILES" != "$tmp/branch.patch" ]; then
  base=$(git merge-base origin/master "$BRANCH")
  if git worktree add --detach -q "$tmp/drift" "$base" 2>/dev/null; then
    if git -C "$tmp/drift" apply $FILES 2>"$tmp/drifterr"; then
      # Stage first: git apply leaves a new file untracked, and an untracked
      # file is invisible to git diff — which would report "no drift" for a
      # patch that adds a file the branch does not have.
      git -C "$tmp/drift" add -A >/dev/null 2>&1
      diff=$(git -C "$tmp/drift" diff --cached --name-only "$BRANCH" 2>/dev/null || true)
      if [ -z "$diff" ]; then
        pass "$BRANCH and the patch file(s) are the same change"
      else
        fail "$BRANCH and the patch file(s) have DRIFTED apart — they differ in:"
        printf '%s\n' "$diff" | sed 's/^/          /'
        printf '          One of the two is the design that was chosen; rebuild the other.\n'
      fi
    else
      # Not being able to run this comparison is a failure, not a note. The
      # comparison applies the patch to the BRANCH's own base, so a branch that
      # is merely behind trunk still compares fine; it only breaks when the
      # patch file was rebuilt from a newer base than the branch — which is
      # drift, and is exactly what this check exists to catch. Warning here is
      # how webhook-tracker-filter kept a pre-K-11 branch while reporting PASS.
      fail "cannot compare with $BRANCH: the patch does not apply to its own base ${base:0:9}"
      sed 's/^/          /' "$tmp/drifterr" 2>/dev/null | head -3
      printf '          The patch file was almost certainly rebuilt against newer trunk
'
      printf '          while the branch stayed put. Rebuild the branch from the design
'
      printf '          the patch file holds; do not regenerate the patch from the branch.
'
    fi
  else
    fail "could not create a worktree at ${base:0:9} to compare with $BRANCH"
  fi
elif [ -z "$BRANCH" ]; then
  warn "no patch/$SLUG branch to compare against"
fi

echo
if [ "$fails" -eq 0 ] && [ "$stale" -eq 0 ]; then
  echo "PASS — safe to submit"
  exit 0
fi
if [ "$fails" -eq 0 ]; then
  echo "PASS with 1 stale warning — refresh against trunk, then re-run with --submit"
  exit 0
fi
echo "$fails check(s) failed — do NOT submit"
exit 1
