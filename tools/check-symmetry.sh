#!/usr/bin/env bash
# INV-10, mechanically: does 7.0-stable-GEOxyz carry the same change as
# patch/<slug>?
#
#   tools/check-symmetry.sh <slug> [<slug> ...]
#   tools/check-symmetry.sh --all
#   tools/check-symmetry.sh --self-test <slug>|--all
#
# check-geoxyz-branch.sh answers "is the branch healthy" and cannot see a fix
# that landed on one side only: on 2026-09-09 it reported PASS while
# patch/version-subprojects carried a scope narrowing that GEOxyz did not, and
# status.md claimed both sides were the same change (Codex round 2, blockers
# version-subprojects F01 and geoxyz-branch F02).
#
# Two comparisons, because code and translations fail differently.
#
# **Code** is compared line by line, deliberately crudely, because that is what
# makes it mechanical. For every substantive line the patch's diff touches, the
# question is presence, not position: is the line in the file on the patch
# branch and absent from the same file on GEOxyz, or the reverse? It cannot
# judge whether two implementations are equivalent, and it does not try — it
# catches the case that actually happened, a hunk on one side only, and it
# narrows what has to be read by hand rather than replacing it.
#
# **In both directions since 2026-09-10.** Until then the set of lines examined
# was the patch's own diff, so a line GEOxyz has and the patch never mentions
# was not in the set at all and could not be seen — a hotfix applied to
# production and never carried back, which is the divergence this branch will
# actually produce next. Adding an unrelated guard to GEOxyz alone passed with a
# global INV-10 PASS (round 4, tools F04).
#
# The reverse direction has to be scoped or it is unusable: GEOxyz carries
# thirteen features at once, so every line of the other twelve would read as a
# divergence of this one. It is scoped **by content**, which needs no bookkeeping
# to be right: a line GEOxyz added to one of this patch's files, and this patch
# does not have, is this slug's divergence unless some other patch branch has
# it — in which case it belongs to that feature. It cannot be upstream's own
# line either, since this patch branch is upstream plus one feature and the line
# is absent there.
#
# Two scopings were tried first and both are worse. Reading the feature's own
# geoxyz_commit list out of status.md can only see divergences somebody already
# wrote down, which is the opposite of the case worth catching. Treating every
# unrecorded commit as this feature's produced 45 false failures in one run,
# because five real commits are recorded against no feature at all and one of
# them shares a test file with another slug.
#
# **Locale files** are compared by value, per key, with a real YAML parser.
# They used to be skipped here, on the stated grounds that they were "compared
# as whole keys elsewhere". That was wrong, and it was a claim made without
# checking: check-patch-clean.sh and check-geoxyz-branch.sh only constrain
# *which* locale filenames may be touched (INV-5), and neither reads a value.
# So a translation broken on one side alone passed this gate with a global
# INV-10 PASS — reproduced, then fixed (Codex round 3, geoxyz-branch F01). A
# line comparison would not do: trunk and 7.0-stable order and neighbour the
# keys differently, so only the keys this patch itself adds or changes are
# compared, which leaves unrelated upstream locale drift out of it.
#
# Legitimate divergences go in docs/features/<slug>/symmetry-allow.txt: one
# fixed string per line, matched as a substring of the line body or of the
# locale key path, '#' for a reason. A missing file means nothing may differ. A
# divergence that is not listed there is a defect; one that is listed is a
# claim the dossier has to back (INV-10).
#
# That substring direction is what the file always said and not what it did
# until 2026-09-10: `grep -F "$body" allowfile` asks whether an allow LINE
# contains the whole body, the opposite, so a short distinguishing fragment —
# the documented thing to write — suppressed nothing, and the 8-character guard
# below was inert because no body is ever short enough to be excused by it
# (round 4, tools F09).
#
# --self-test proves the gate still bites. It builds three synthetic defects on
# a copy of GEOxyz — a broken translation, a missing code line, an extra code
# line — and requires this script to fail on each. Three, because until
# 2026-09-10 it only ever broke a translation: the code half, which is the older
# and larger one and the reason the gate exists at all, had no self-test, and a
# run that found nothing to break still printed a global PASS (round 4, tools
# F10). It now fails if it ran no probe. It creates no branch and touches no
# worktree: every tree is assembled in a temporary index and committed with
# commit-tree, leaving unreferenced objects.
#
# Exit 0 = symmetric. Exit 1 = a divergence that is not allowed.

set -uo pipefail

REPO="${REPO:-/home/user/redmine}"
GEOXYZ="${GEOXYZ:-origin/7.0-stable-GEOxyz}"
GEOBASE="${GEOBASE:-origin/7.0-stable}"
BASE="${BASE:-origin/master}"
RUBY="${RUBY:-/opt/rbenv/versions/3.3.6/bin/ruby}"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
LOCALES='^config/locales/(en|nl|fr|de|es)\.yml$'

cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

fails=0
pass() { printf '  ok    %s\n' "$1"; }
# Is this divergence one the dossier already accounts for? The pattern is a
# fragment of the line body or of the key path, matched literally.
allowed() {
  local subject="$1" pattern
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    case "$subject" in *"$pattern"*) return 0 ;; esac
  done < "$allowfile"
  return 1
}

# One trimmed copy per (ref, path) for the whole run. A feature adds a few
# hundred lines and every one of them is looked up on up to nine branches, so a
# git show per lookup turns 30 seconds into half an hour.
CACHE=$(mktemp -d)
trap 'rm -rf "$CACHE"' EXIT
trimmed() {
  local key; key=$(printf '%s:%s' "$1" "$2" | tr -c 'A-Za-z0-9.' '_')
  [ -f "$CACHE/$key" ] ||
    git show "$1:$2" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' > "$CACHE/$key"
  printf '%s' "$CACHE/$key"
}

# Does this line, or this locale key, belong to one of the other features? Every
# feature that has a patch branch carries its own lines there, so a line absent
# from this patch and present on another one is that feature's, not a divergence
# of this one.
claimed_elsewhere() {
  local body="$1" file="$2" other
  for other in $ALL_PATCHES; do
    [ "$other" = "$patch_ref" ] && continue
    git cat-file -e "$other:$file" 2>/dev/null || continue
    grep -qxF -- "$body" "$(trimmed "$other" "$file")" && return 0
  done
  return 1
}
claimed_elsewhere_key() {
  local lkey="$1" file="$2" other
  for other in $ALL_PATCHES; do
    [ "$other" = "$patch_ref" ] && continue
    git cat-file -e "$other:$file" 2>/dev/null || continue
    grep -qE "^$lkey:" "$(trimmed "$other" "$file")" && return 0
  done
  return 1
}
warn() { printf '  note  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

SELF_TEST=no
if [ "${1:-}" = "--self-test" ]; then SELF_TEST=yes; shift; fi

if [ "${1:-}" = "--all" ]; then
  set -- $(git for-each-ref --format='%(refname:strip=4)' 'refs/remotes/origin/patch/*' | sort)
  [ $# -gt 0 ] || { echo "FAIL  no patch branches found under $BASE's remote" >&2; exit 2; }
fi
[ $# -gt 0 ] || { echo "usage: tools/check-symmetry.sh [--self-test] <slug> [<slug> ...] | --all" >&2; exit 2; }

command -v "$RUBY" >/dev/null 2>&1 ||
  { echo "FAIL  no ruby at $RUBY — the locale comparison needs a YAML parser, and skipping it is how this gate went blind once already" >&2; exit 2; }

git fetch -q origin master 7.0-stable 7.0-stable-GEOxyz 'refs/heads/patch/*:refs/remotes/origin/patch/*' 2>/dev/null ||
  warn "could not fetch; using the refs already present"

# Flattens both YAML trees to key -> value and reports, for every key this
# patch added or changed, one line per key whose value on GEOxyz differs.
locale_divergences() {
  local base_f="$1" patch_f="$2" geo_f="$3"
  "$RUBY" -e '
require "yaml"
require "date"

def flat(path)
  return {} unless File.exist?(path) && File.size(path) > 0
  tree = YAML.safe_load_file(path, :permitted_classes => [Date, Time, Symbol], :aliases => true)
  return {} unless tree.is_a?(Hash)
  out = {}
  walk = lambda do |node, prefix|
    case node
    when Hash  then node.each {|k, v| walk.call(v, prefix + [k.to_s])}
    when Array then node.each_with_index {|v, i| walk.call(v, prefix + [i.to_s])}
    else out[prefix.join(".")] = node.to_s
    end
  end
  # The locale root (en:, nl:, ...) differs per file by definition, so it is
  # dropped and the keys underneath are compared.
  tree.each_value {|v| walk.call(v, [])}
  out
end

base, patch, geo = ARGV.map {|p| flat(p)}
patch.each do |key, value|
  next if base[key] == value          # untouched by this patch
  if !geo.key?(key)
    puts "#{key}\tabsent on GEOxyz\t#{value}"
  elsif geo[key] != value
    puts "#{key}\t#{geo[key]}\t#{value}"
  end
end
' "$base_f" "$patch_f" "$geo_f"
}

ALL_PATCHES=$(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/patch/*')

for slug in "$@"; do
  echo "check-symmetry: $slug"
  patch_ref="origin/patch/$slug"
  git rev-parse -q --verify "$patch_ref" >/dev/null ||
    { fail "$patch_ref does not exist"; continue; }

  mb=$(git merge-base "$BASE" "$patch_ref")
  gmb=$(git merge-base "$GEOBASE" "$GEOXYZ" 2>/dev/null)
  [ -n "$gmb" ] || { fail "$slug: $GEOXYZ has no merge base with $GEOBASE, so the GEOxyz -> patch direction cannot be checked"; continue; }
  mapfile -t files < <(git diff --name-only "$mb" "$patch_ref")
  [ "${#files[@]}" -gt 0 ] || { fail "$patch_ref changes nothing against $BASE"; continue; }

  allow="docs/features/$slug/symmetry-allow.txt"
  allowfile=$(mktemp)
  if [ -f "$allow" ]; then
    grep -v '^[[:space:]]*\(#\|$\)' "$allow" > "$allowfile"
    # A short pattern is matched as a substring against every line, so `end`
    # would excuse most of the file and the check would report PASS having
    # tested almost nothing. Same threshold as the signal threshold below.
    short=$(awk '{ gsub(/[ \t]/, ""); if (length($0) < 8) print }' "$allowfile")
    if [ -n "$short" ]; then
      fail "$slug: $allow has a pattern under 8 non-blank characters, which would excuse whole files: $(printf '%s' "$short" | tr '\n' ' ')"
      rm -f "$allowfile"
      continue
    fi
    warn "$(wc -l < "$allowfile" | tr -d ' ') allowed divergence pattern(s) from $allow"
  fi

  slug_fails=0
  locale_keys=0
  for f in "${files[@]}"; do
    pat=$(mktemp); geo=$(mktemp); bas=$(mktemp)
    on_patch=no; on_geoxyz=no
    git cat-file -e "$patch_ref:$f" 2>/dev/null && on_patch=yes
    git cat-file -e "$GEOXYZ:$f" 2>/dev/null && on_geoxyz=yes

    # A patch that deletes a file is symmetric when GEOxyz has deleted it too,
    # and comparing the contents of two absent files says nothing either way.
    if [ "$on_patch" = no ]; then
      if [ "$on_geoxyz" = yes ]; then
        fail "$slug: $f deleted by the patch, still on $GEOXYZ"
        slug_fails=$((slug_fails + 1))
      fi
      rm -f "$pat" "$geo" "$bas"
      continue
    fi
    if [ "$on_geoxyz" = no ]; then
      fail "$slug: $f exists on $patch_ref but not on $GEOXYZ"
      slug_fails=$((slug_fails + 1))
      rm -f "$pat" "$geo" "$bas"
      continue
    fi

    if printf '%s' "$f" | grep -qE "$LOCALES"; then
      git show "$patch_ref:$f" > "$pat"
      git show "$GEOXYZ:$f" > "$geo"
      git show "$mb:$f" > "$bas" 2>/dev/null || : > "$bas"

      while IFS=$'\t' read -r key geo_value patch_value; do
        [ -n "$key" ] || continue
        allowed "$key" && continue
        fail "$slug: $f — key $key reads \"$patch_value\" on the patch and \"$geo_value\" on GEOxyz"
        slug_fails=$((slug_fails + 1))
      done < <(locale_divergences "$bas" "$pat" "$geo")

      locale_keys=$((locale_keys + $("$RUBY" -e '
require "yaml"; require "date"
def flat(p)
  return {} unless File.exist?(p) && File.size(p) > 0
  t = YAML.safe_load_file(p, :permitted_classes => [Date, Time, Symbol], :aliases => true)
  return {} unless t.is_a?(Hash)
  o = {}
  w = lambda {|n, pre| n.is_a?(Hash) ? n.each {|k, v| w.call(v, pre + [k.to_s])} : o[pre.join(".")] = n.to_s}
  t.each_value {|v| w.call(v, [])}
  o
end
b, p = flat(ARGV[0]), flat(ARGV[1])
puts p.count {|k, v| b[k] != v}
' "$bas" "$pat")))

      rm -f "$pat" "$geo" "$bas"
      continue
    fi

    # Code: present on one side, absent on the other — not equal counts. Three
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
    git show "$patch_ref:$f" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' > "$pat"
    git show "$GEOXYZ:$f"    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' > "$geo"

    while IFS= read -r body; do
      # A line that is only punctuation or a keyword carries no signal: 'end',
      # a bare brace, a blank. Counting those adds noise in both directions.
      stripped=$(printf '%s' "$body" | tr -d '[:space:]')
      [ ${#stripped} -ge 8 ] || continue

      allowed "$body" && continue

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

    rm -f "$pat" "$geo" "$bas"
  done

  # --- the other direction: what GEOxyz carries in these files that the patch
  # does not. See the header for why it is scoped by content.
  for f in "${files[@]}"; do
    git cat-file -e "$GEOXYZ:$f" 2>/dev/null || continue
    git cat-file -e "$patch_ref:$f" 2>/dev/null || continue

    while IFS= read -r body; do
      [ -n "$body" ] || continue
      stripped=$(printf '%s' "$body" | tr -d '[:space:]')
      [ ${#stripped} -ge 8 ] || continue
      allowed "$body" && continue

      if printf '%s' "$f" | grep -qE "$LOCALES"; then
        # Compared by key, not by line: a differing value is already the forward
        # check's finding, so the only question left here is whether the key
        # exists on the patch side at all. Key presence has none of the ordering
        # and neighbouring noise that made a line comparison useless for YAML.
        lkey=${body%%:*}
        case "$lkey" in *[!A-Za-z0-9_]*|'') continue ;; esac
        grep -qE "^$lkey:" "$(trimmed "$patch_ref" "$f")" && continue
        claimed_elsewhere_key "$lkey" "$f" && continue
        fail "$slug: $f — key $lkey is on GEOxyz and on no patch, so this feature's translation exists only in production"
        slug_fails=$((slug_fails + 1))
        continue
      fi

      grep -qxF -- "$body" "$(trimmed "$patch_ref" "$f")" && continue
      claimed_elsewhere "$body" "$f" && continue
      fail "$slug: $f — on GEOxyz, on no patch branch, absent here:  $body"
      slug_fails=$((slug_fails + 1))
    done < <(git diff -U0 "$gmb" "$GEOXYZ" -- "$f" |
             grep -E '^\+' | grep -Ev '^\+\+\+' |
             sed 's/^.//; s/^[[:space:]]*//; s/[[:space:]]*$//' | sort -u)
  done

  if [ "$slug_fails" -eq 0 ]; then
    if [ "$locale_keys" -gt 0 ]; then
      pass "$slug: every substantive line is on both sides in both directions, and its $locale_keys locale key(s) read the same"
    else
      pass "$slug: every substantive line is on both sides in both directions (no locale key of its own)"
    fi
  fi
  rm -f "$allowfile"
done

echo
if [ "$fails" -ne 0 ]; then
  echo "FAIL  $fails divergence(s) — fix the side that is behind, or record it in symmetry-allow.txt with its reason (INV-10)"
  exit 1
fi
echo "PASS  no unexplained divergence between the patches and $GEOXYZ"

if [ "$SELF_TEST" = yes ]; then
  echo
  echo "self-test: three synthetic defects per slug on a copy of $GEOXYZ"
  st_fails=0
  st_ran=0

  # A GEOxyz tree with one file replaced. No branch, no worktree, no ref.
  st_tree() {
    local path="$1" blob="$2" tmpidx tree
    tmpidx=$(mktemp -u)
    GIT_INDEX_FILE="$tmpidx" git read-tree "$GEOXYZ" 2>/dev/null || { rm -f "$tmpidx"; return 1; }
    GIT_INDEX_FILE="$tmpidx" git update-index --cacheinfo "100644,$blob,$path" || { rm -f "$tmpidx"; return 1; }
    tree=$(GIT_INDEX_FILE="$tmpidx" git write-tree); rm -f "$tmpidx"
    git commit-tree "$tree" -p "$(git rev-parse "$GEOXYZ")" -m 'check-symmetry self-test'
  }

  # The gate has to FAIL on the synthetic tree. Passing means it is blind again.
  st_probe() {
    local label="$1" broken="$2"
    st_ran=$((st_ran + 1))
    if GEOXYZ="$broken" "$SELF" "$slug" >/dev/null 2>&1; then
      printf '  FAIL  %s: %s — the gate passed with this on one side only, it is blind again\n' "$slug" "$label"
      st_fails=$((st_fails + 1))
    else
      printf '  ok    %s: %s\n' "$slug" "$label"
    fi
  }

  for slug in "$@"; do
    patch_ref="origin/patch/$slug"
    git rev-parse -q --verify "$patch_ref" >/dev/null || continue
    mb=$(git merge-base "$BASE" "$patch_ref") || continue

    # 1. a translation this patch adds, broken on GEOxyz only (forward, locales)
    key=''; lf=''
    for cand in $(git diff --name-only "$mb" "$patch_ref" | grep -E "$LOCALES"); do
      key=$(git diff -U0 "$mb" "$patch_ref" -- "$cand" |
            grep -E '^\+  [a-z_]+:' | head -1 | sed 's/^+  \([a-z_]*\):.*/\1/')
      [ -n "$key" ] && { lf="$cand"; break; }
    done
    if [ -n "$key" ]; then
      broken=$(st_tree "$lf" "$(git show "$GEOXYZ:$lf" |
               sed "s/^\(  $key:\) .*/\1 BROKEN TRANSLATION/" | git hash-object -w --stdin)") &&
        st_probe "$key in $(basename "$lf") reads differently on GEOxyz" "$broken"
    else
      printf '  note  %s: adds no locale key of its own, so no translation probe\n' "$slug"
    fi

    # a code file both sides have, and a substantive line the patch adds to it
    cf=''; body=''
    while IFS= read -r cand; do
      printf '%s' "$cand" | grep -qE "$LOCALES" && continue
      git cat-file -e "$GEOXYZ:$cand" 2>/dev/null || continue
      body=$(git diff -U0 "$mb" "$patch_ref" -- "$cand" |
             grep -E '^\+' | grep -Ev '^\+\+\+' |
             sed 's/^.//; s/^[[:space:]]*//; s/[[:space:]]*$//' |
             awk 'length($0) >= 20' |
             while IFS= read -r l; do
               git show "$GEOXYZ:$cand" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' |
                 grep -qxF -- "$l" && { printf '%s' "$l"; break; }
             done)
      [ -n "$body" ] && { cf="$cand"; break; }
    done < <(git diff --name-only "$mb" "$patch_ref")

    if [ -z "$cf" ]; then
      fail "$slug: no code file to probe — the code half of this gate is untested for this slug"
    else
      # 2. a line of the patch missing on GEOxyz (forward, code)
      broken=$(st_tree "$cf" "$(git show "$GEOXYZ:$cf" |
               awk -v b="$body" 'index($0, b) && !gone { gone = 1; next } { print }' |
               git hash-object -w --stdin)") &&
        st_probe "a line of the patch missing from $(basename "$cf") on GEOxyz" "$broken"

      # 3. a line on GEOxyz that no patch branch has (reverse, code)
      broken=$(st_tree "$cf" "$(git show "$GEOXYZ:$cf" |
               sed '1i\
# check-symmetry self-test: a line that exists in production and in no patch' |
               git hash-object -w --stdin)") &&
        st_probe "a line on GEOxyz that no patch branch carries" "$broken"
    fi
  done

  echo
  if [ "$st_ran" -eq 0 ]; then
    echo "FAIL  self-test: not a single probe ran, so this proves nothing"
    exit 1
  fi
  if [ "$st_fails" -ne 0 ]; then
    echo "FAIL  self-test: $st_fails of $st_ran probe(s) went unnoticed"
    exit 1
  fi
  echo "PASS  self-test: all $st_ran probe(s) fail the gate, in both directions"
fi
exit 0
