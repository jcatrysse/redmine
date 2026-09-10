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
#   4. with --submit: origin/master really is current trunk (K-20)
#   5. it applies to a pristine origin/master checkout
#   6. branch and patch file are the same change (no drift)
#   7. no AI identity in the author or committer of the branch's own commits
#
# Check 6 is Jan's K-16 (2026-09-09, option B). Until then nothing covered this
# on a patch branch at all: `git format-patch` writes only the author into the
# file, so check 3 is structurally blind to the committer, and
# check-geoxyz-branch.sh cannot be pointed here because it computes own commits
# as origin/7.0-stable..ref, which for a trunk branch is thousands of them.
# patch/mypage-query-blocks carried `Claude <noreply@anthropic.com>` as its
# committer from 2026-09-03 to 2026-09-09 with every gate reporting PASS.
#
# Check 4 is Jan's K-20 (2026-09-10, option B) and runs only with --submit.
# origin/master is a mirror only Jan writes (K-19 option A), so "applies to
# origin/master" is a statement about the mirror unless somebody checks. On
# 2026-09-09 nobody did: the mirror sat six days and 18 commits behind real
# trunk, this gate reported PASS for all nine patches, and one of them did not
# apply to the trunk it gets submitted to. The fetch is read-only — it lands in
# FETCH_HEAD and never writes origin/master, so K-19's rule that only Jan syncs
# the mirror is untouched, and patch/<slug> stays branched from origin/master.
#
# Check 5 is a WARNING by default and a FAILURE with --submit. A patch that
# stopped applying because trunk moved 88 commits is not defective, it is
# stale; all nine branches failed the old permanent version of this rule for
# exactly that reason and it measured decay rather than quality (g13.1).
# Refreshing is the last step before submitting (g05), which is where --submit
# belongs.
#
# Exit 0 = safe. Exit 1 = do not submit.

set -uo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/inv4-identity.sh"

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
FILES=()

if [ -f "$SUBJECT" ]; then
  FILES=("$SUBJECT")
  SLUG=$(printf '%s' "$SUBJECT" | sed -n 's|^patches/\([^/]*\)/.*|\1|p')
elif [ -d "patches/$SUBJECT" ]; then
  SLUG="$SUBJECT"
  mapfile -t FILES < <(find "patches/$SLUG" -maxdepth 1 -name '*.patch' | sort)
  [ "${#FILES[@]}" -gt 0 ] || { echo "FAIL  no .patch file in patches/$SLUG" >&2; exit 2; }
elif git rev-parse --verify --quiet "$SUBJECT" >/dev/null ||
     git rev-parse --verify --quiet "origin/$SUBJECT" >/dev/null; then
  SLUG=${SUBJECT#patch/}
  BRANCH="$SUBJECT"
  git rev-parse --verify --quiet "$BRANCH" >/dev/null || BRANCH="origin/$SUBJECT"
  base=$(git merge-base origin/master "$BRANCH")
  git format-patch "$base..$BRANCH" --stdout > "$tmp/branch.patch" 2>/dev/null
  [ -s "$tmp/branch.patch" ] || { echo "FAIL  $BRANCH changes nothing since $base" >&2; exit 2; }
  FILES=("$tmp/branch.patch")
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
for i in "${!FILES[@]}"; do
  case "${FILES[$i]}" in /*) ;; *) FILES[$i]="$REPO/${FILES[$i]}" ;; esac
done

trunk_rev=$(git log -1 --format='%B' origin/master | sed -n 's|.*/trunk@\([0-9]*\) .*|\1|p')
echo "check-patch-clean: ${SLUG:-$SUBJECT}  (trunk r${trunk_rev:-?}, repo $REPO)"
printf '  file  %s\n' "${FILES[@]}"

# --- 1 + 2. the paths the patch touches ------------------------------------
changed=$(grep -h '^diff --git ' "${FILES[@]}" | sed 's|^diff --git a/\(.*\) b/.*|\1|' | sort -u)

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
    for f in "${FILES[@]}"; do
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
# Only the part before each hunk: a diff body may legitimately contain the word
# "generated" (Redmine generates plenty of things).
#
# The header of EVERY message in EVERY file, which is not what this did until
# 2026-09-10. It was `awk '/^diff --git /{exit}'`, and awk's `exit` ends the
# whole program rather than the current file, so with more than one .patch file
# only the first one's header was ever read — while the check printed "ok". Five
# of the nine slugs ship two files, mypage-query-blocks among them, which is the
# slug K-16 was written for (round 4, tools F01). The same truncation hid the
# second and later commit messages of a multi-commit branch export, since git
# format-patch writes those after the first diff.
headers=$(awk '
  FNR == 1 || /^From [0-9a-f]+ / { inhdr = 1; msgs++ }
  /^diff --git / { inhdr = 0 }
  inhdr { print FILENAME ": " $0 }
  END { print "@@scanned " msgs+0 }
' "${FILES[@]}")
scanned=${headers##*@@scanned }
headers=${headers%@@scanned *}

# A file that starts with `diff --git` is a plain diff and not a format-patch
# export, so it carries no commit message at all: there is nothing to scan and
# nothing that could carry a trace. `members-pagination` is the only slug in
# that shape — its two files are Takenori TAKAKI's, attached to #43355, and no
# branch of ours exports them. "There was no message" is not the same claim as
# "the message is clean", so it is a note and not an ok.
fmtfiles=0
for f in "${FILES[@]}"; do
  IFS= read -r first < "$f" || first=""
  case "$first" in
    "From "*) fmtfiles=$((fmtfiles + 1)) ;;
  esac
done

# An empty header set means the extraction broke, not that the patch is clean.
# A grep over nothing reports nothing, and that is the shape of every gate
# defect this framework has found so far.
if [ "$fmtfiles" -eq 0 ]; then
  warn "no commit message to scan: ${#FILES[@]} file(s) are plain diffs, not format-patch exports"
elif [ "${scanned:-0}" -lt 1 ] || [ -z "$headers" ]; then
  fail "could not read a single message header from ${#FILES[@]} file(s) — this check would pass without testing anything"
else
  traces=$(printf '%s\n' "$headers" |
           grep -inE 'co-authored-by:.*(cursor|claude|copilot|codex|chatgpt|ai\b)|generated (with|by)|claude-(opus|sonnet|haiku|fable)|(claude|chatgpt|cursor)[-.]?session|claude\.ai/code|claude|anthropic|copilot|codex|openai|noreply@' || true)
  if [ -n "$traces" ]; then
    fail "AI trace in the patch header or commit message (INV-4):"
    printf '%s\n' "$traces" | sed 's/^/          /'
  else
    pass "no AI trace in $scanned message header(s) across ${#FILES[@]} file(s)"
  fi
fi

# --- 4. is origin/master really trunk? (K-20, --submit only) ---------------
UPSTREAM_TRUNK="${UPSTREAM_TRUNK:-https://github.com/redmine/redmine.git}"
if [ "$SUBMIT" -eq 1 ]; then
  if git fetch -q "$UPSTREAM_TRUNK" master 2>"$tmp/trunkerr"; then
    gap=$(git rev-list --count origin/master..FETCH_HEAD 2>/dev/null)
    if [ "${gap:-}" = 0 ]; then
      pass "origin/master is current with $UPSTREAM_TRUNK"
    elif [ -z "${gap:-}" ]; then
      fail "could not compare origin/master with $UPSTREAM_TRUNK — one of the two refs does not resolve"
    else
      fail "origin/master is $gap commit(s) behind real trunk, so this answer would be about the mirror (K-19, K-20):"
      printf '          %s\n' \
        "$(git log -1 --format='mirror     %h  %ad  %s' --date=short origin/master)" \
        "$(git log -1 --format='real trunk %h  %ad  %s' --date=short FETCH_HEAD)" \
        "Jan syncs the mirror — the three commands are in docs/runbook.md." \
        "Re-run --submit after the sync; the evidence numbers are re-measured with it (g05)."
    fi
  else
    fail "could not reach $UPSTREAM_TRUNK — a --submit that cannot ask whether the mirror is current may not answer yes (K-20):"
    sed 's/^/          /' "$tmp/trunkerr" 2>/dev/null | head -3
  fi
fi

# --- 5. applies to a pristine trunk checkout -------------------------------
if git worktree add --detach -q "$tmp/trunk" origin/master 2>/dev/null; then
  if git -C "$tmp/trunk" apply --check "${FILES[@]}" 2>"$tmp/err"; then
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

# --- 6. branch and file are the same change --------------------------------
if [ -n "$BRANCH" ] && [ "${FILES[0]}" != "$tmp/branch.patch" ]; then
  base=$(git merge-base origin/master "$BRANCH")
  if git worktree add --detach -q "$tmp/drift" "$base" 2>/dev/null; then
    if git -C "$tmp/drift" apply "${FILES[@]}" 2>"$tmp/drifterr"; then
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

# --- 7. AI identity in the branch's own commits (INV-4) --------------------
# Pattern and range guard both live in tools/inv4-identity.sh, so the mandatory
# guard in session-push.sh can never be looser than this one (round 4, F03).
if [ -n "$BRANCH" ]; then
  ibase=$(git merge-base origin/master "$BRANCH")
  own=$(git rev-list --count "$ibase..$BRANCH")
  identities=$(inv4_identities "$ibase" "$BRANCH") || exit 2
  if [ -n "$identities" ]; then
    fail "an AI identity in the author or committer of $BRANCH (INV-4):"
    printf '%s\n' "$identities" | sed 's/^/          /'
    printf '          The author reaches the patch file; the committer reaches every clone.\n'
    printf '          A patch branch may be rewritten — nobody checks it out — so:\n'
    printf '            git -c user.name="Jan Catrysse" -c user.email="jan.catrysse@geoxyz.eu" \\\n'
    printf '              commit --amend --no-edit\n'
    printf '            git push --force-with-lease=%s:<old sha>\n' "${BRANCH#origin/}"
    printf '          Then re-export the patch file so its From: sha matches.\n'
  else
    pass "no AI identity in the author or committer of $BRANCH ($own own commit(s))"
  fi
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
