#!/usr/bin/env bash
# INV-10, mechanically: does 7.0-stable-GEOxyz carry the same change as
# patch/<slug>?
#
#   tools/check-symmetry.sh <slug> [<slug> ...]
#   tools/check-symmetry.sh --all
#
# check-geoxyz-branch.sh answers "is the branch healthy" and cannot see a fix
# that landed on one side only: on 2026-09-09 it reported PASS while
# patch/version-subprojects carried a scope narrowing that GEOxyz did not, and
# status.md claimed both sides were the same change (Codex round 2, blockers
# version-subprojects F01 and geoxyz-branch F02).
#
# The comparison is line-level and deliberately crude, because that is what
# makes it mechanical: every line the patch adds must appear somewhere in the
# same file on GEOxyz, and every line it removes must not. It cannot judge
# whether two implementations are equivalent — it catches the case that
# actually happened, a hunk present on one side only.
#
# Legitimate divergences go in docs/features/<slug>/symmetry-allow.txt, one
# regexp per line matching the diff line (with its +/- kept), '#' for a reason.
# An empty or absent file means nothing is allowed to differ. A divergence that
# is not listed there is a defect; one that is listed is a claim the dossier
# has to back (INV-10).
#
# Exit 0 = symmetric. Exit 1 = a divergence that is not allowed.

set -uo pipefail

REPO="${REPO:-/home/user/redmine}"
GEOXYZ="${GEOXYZ:-origin/7.0-stable-GEOxyz}"
BASE="${BASE:-origin/master}"

cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

fails=0
pass() { printf '  ok    %s\n' "$1"; }
warn() { printf '  note  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

if [ "${1:-}" = "--all" ]; then
  set -- $(git for-each-ref --format='%(refname:strip=4)' 'refs/remotes/origin/patch/*' | sort)
  [ $# -gt 0 ] || { echo "FAIL  no patch branches found under $BASE's remote" >&2; exit 2; }
fi
[ $# -gt 0 ] || { echo "usage: tools/check-symmetry.sh <slug> [<slug> ...] | --all" >&2; exit 2; }

git fetch -q origin master 7.0-stable-GEOxyz 'refs/heads/patch/*:refs/remotes/origin/patch/*' 2>/dev/null ||
  warn "could not fetch; using the refs already present"

for slug in "$@"; do
  echo "check-symmetry: $slug"
  patch_ref="origin/patch/$slug"
  git rev-parse -q --verify "$patch_ref" >/dev/null ||
    { fail "$patch_ref does not exist"; continue; }

  allow="docs/features/$slug/symmetry-allow.txt"
  # grep -f with an empty file matches nothing, which is the behaviour we want
  # for a slug that has no allowlist, so a missing file becomes an empty one.
  allowfile=$(mktemp); trap 'rm -f "$allowfile"' EXIT
  if [ -f "$allow" ]; then
    grep -v '^[[:space:]]*\(#\|$\)' "$allow" > "$allowfile"
    warn "$(wc -l < "$allowfile" | tr -d ' ') allowed divergence pattern(s) from $allow"
  else
    : > "$allowfile"
  fi

  mb=$(git merge-base "$BASE" "$patch_ref")
  files=$(git diff --name-only "$mb" "$patch_ref")
  [ -n "$files" ] || { fail "$patch_ref changes nothing against $BASE"; continue; }

  slug_fails=0
  for f in $files; do
    # Locale files are compared as whole keys elsewhere (INV-5); a line-level
    # comparison of them is noise, because trunk and 7.0-stable order and
    # neighbour the keys differently.
    case "$f" in config/locales/*) continue;; esac

    pat=$(mktemp); geo=$(mktemp)
    git show "$patch_ref:$f" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' > "$pat"
    if ! git show "$GEOXYZ:$f" > /dev/null 2>&1; then
      fail "$slug: $f exists on $patch_ref but not on $GEOXYZ"
      slug_fails=$((slug_fails + 1))
      rm -f "$pat" "$geo"
      continue
    fi
    git show "$GEOXYZ:$f" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' > "$geo"

    # Present on one side, absent on the other — not equal counts. Three
    # things make a count comparison useless here: a block the patch moves
    # shows up as both a removal and an addition; a line the patch edits one of
    # several times leaves the others in place; and GEOxyz carries every
    # feature at once, so a boilerplate line like `:settings => {` is there
    # thirteen times where one patch has it twelve.
    #
    # What is left is exactly the case that happened: a hunk on one side only.
    # The limit is the other side of the same coin — a change whose every line
    # already occurs somewhere else in the file is invisible to this check, so
    # it narrows what has to be read by hand, it does not replace it.
    while IFS= read -r body; do
      # A line that is only punctuation or a keyword carries no signal: 'end',
      # a bare brace, a blank. Counting those adds noise in both directions.
      stripped=$(printf '%s' "$body" | tr -d '[:space:]')
      [ ${#stripped} -ge 8 ] || continue

      grep -qF -- "$body" "$allowfile" 2>/dev/null && continue

      np=$(grep -cxF -- "$body" "$pat")
      ng=$(grep -cxF -- "$body" "$geo")
      if [ "$np" -gt 0 ] && [ "$ng" -eq 0 ]; then
        fail "$slug: $f — on the patch, absent on GEOxyz:  $body"
        slug_fails=$((slug_fails + 1))
      elif [ "$np" -eq 0 ] && [ "$ng" -gt 0 ]; then
        fail "$slug: $f — removed by the patch, still on GEOxyz ($ng x):  $body"
        slug_fails=$((slug_fails + 1))
      fi
    done < <(git diff -U0 "$mb" "$patch_ref" -- "$f" |
             grep -E '^[-+]' | grep -Ev '^(\+\+\+|---)' |
             sed 's/^.//; s/^[[:space:]]*//; s/[[:space:]]*$//' | sort -u)

    rm -f "$pat" "$geo"
  done

  [ "$slug_fails" -eq 0 ] && pass "$slug: every substantive line of the patch is on both sides"
  rm -f "$allowfile"; trap - EXIT
done

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  no unexplained divergence between the patches and $GEOXYZ"
  exit 0
fi
echo "FAIL  $fails divergence(s) — fix the side that is behind, or record it in symmetry-allow.txt with its reason (INV-10)"
exit 1
