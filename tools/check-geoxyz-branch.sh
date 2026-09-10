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

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/inv4-identity.sh"

REPO="${1:-/home/user/redmine}"
BRANCH=7.0-stable-GEOxyz
UPSTREAM=origin/7.0-stable
RUBOCOP="${RUBOCOP:-/opt/rbenv/versions/3.3.6/bin/rubocop}"

cd "$REPO" || { echo "FAIL  repo not found: $REPO" >&2; exit 2; }

fails=0
unmeasured=0
pass() { printf '  ok    %s\n' "$1"; }
warn() { printf '  note  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# A check that could not run is not a check that passed. It is not a defect in
# the branch either, so it gets its own outcome rather than being counted as
# one — but it still costs the run its PASS, because the whole point of this
# script is that a session pastes its verdict into a dossier as G8 evidence
# (round 4, tools F02).
skip() { printf '  ????  %s\n' "$1"; unmeasured=$((unmeasured + 1)); }

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
# --- the lint measurement needs a Gemfile.lock, and has to prove it ---------
#
# Until 2026-09-10 this script linted a worktree made by `git worktree add`,
# which contains only tracked files — and Gemfile.lock is gitignored. Without
# it, rubocop-rails' **version-gated** cops produce nothing, while the plugin
# itself loads and Rails/Output still fires, so the run looked complete. On
# 7.0-stable-GEOxyz the gate reported "1 offence (baseline 1)" where the honest
# number is 8 and 8; the seven that vanished were all
# Rails/StrongParametersExpect (round 4, tools second run, F01).
#
# Two things hid it, and both are why the probe below exists rather than a
# comment saying "remember the lockfile":
#   * with RuboCop's cache on, the same directory returns the previous run's
#     answer whether or not a lockfile appeared, so the probe disables it;
#   * `rubocop --show-cops Rails/StrongParametersExpect` prints an identical
#     `Enabled: pending` config either way, so inspecting configuration proves
#     nothing. Only running the cop does.

# Where a Gemfile.lock can come from, in order: an explicit path, then any
# worktree of this repo that has had `bundle install`. It is copied into both
# lint worktrees, so branch and baseline are measured against the same gems.
find_gemfile_lock() {
  if [ -n "${GEMFILE_LOCK:-}" ] && [ -r "$GEMFILE_LOCK" ]; then
    printf '%s\n' "$GEMFILE_LOCK"
    return 0
  fi
  local d
  while read -r d; do
    [ -r "$d/Gemfile.lock" ] && { printf '%s\n' "$d/Gemfile.lock"; return 0; }
  done < <(git worktree list --porcelain | awk '/^worktree /{print $2}')
  return 1
}

# Proves the version-gated Rails cops are live in $1 by making one fire.
# Project.find(params[:id]) in a controller is what Rails/StrongParametersExpect
# is for, and that cop needs Rails >= 8, so it is exactly the family that goes
# quiet without a lockfile.
rails_cops_live() {
  local wtdir="$1" probe="$1/app/controllers/zzz_rails_cop_probe_controller.rb" out
  cat > "$probe" <<'PROBE'
# frozen_string_literal: true

class ZzzRailsCopProbeController < ApplicationController
  def show
    @object = Project.find(params[:id])
  end
end
PROBE
  out=$(cd "$wtdir" && "$RUBOCOP" --cache false --force-exclusion --format json \
          app/controllers/zzz_rails_cop_probe_controller.rb 2>/dev/null)
  rm -f "$probe"
  printf '%s' "$out" | grep -q 'Rails/StrongParametersExpect'
}

tmp=$(mktemp -d)
cleanup() { git worktree remove --force "$tmp/m" >/dev/null 2>&1; git worktree remove --force "$tmp/u" >/dev/null 2>&1; rm -rf "$tmp"; }
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

# --- 3. AI traces in own commits -------------------------------------------
# INV-4 applies here too: these commits are the source of a future patch. It
# covers the author and committer fields as well as the message, and those are
# the half that bites — a commit made without an explicit identity override
# carries the session's own, which is the AI's. Checking only the message is
# what let sixteen such commits reach this branch before K-13 (2026-09-06), and
# what let patch/mypage-query-blocks keep one until 2026-09-08: `git
# format-patch` writes the author into the .patch file but not the committer,
# so neither this check nor check-patch-clean.sh saw it.
# Both patterns come from tools/inv4-identity.sh, so the three gates cannot
# drift apart again (round 4, tools F03).
if [ "$own" -gt 0 ]; then
  traces=$(git log --format='%B' "$UPSTREAM..$ref" | grep -inE "$AI_TRACE_RE" || true)
  if [ -n "$traces" ]; then
    fail "own commit messages contain AI traces (INV-4):"
    printf '%s\n' "$traces" | sed 's/^/          /'
  else
    pass "no AI traces in own commit messages"
  fi

  [ -n "${AI_TRACE_RE:-}" ] ||
    { echo "FAIL  AI pattern is empty — this check would pass without testing anything" >&2; exit 2; }
  identities=$(inv4_identities "$UPSTREAM" "$ref") || exit 2
  if [ -n "$identities" ]; then
    fail "own commits carry an AI identity in author or committer (INV-4):"
    printf '%s\n' "$identities" | sed 's/^/          /'
    printf '          %s\n' "commit with the identity spelled out:" \
      "  git -c user.name=\"Jan Catrysse\" -c user.email=\"jan.catrysse@geoxyz.eu\" commit ..."
  else
    pass "no AI identity in the author or committer of $own own commit(s)"
  fi
fi

# --- 3b. the register points at commits that are actually on this branch ----
# G8 says "own commits match the register" and nothing implemented it. The
# K-13 rewrite of 2026-09-06 gave every commit a new sha and the status files
# were not updated, so 21 of 32 recorded shas pointed at commits reachable from
# no branch. The objects survive in a clone that has them, so `git show <old>`
# succeeds and prints a plausible commit — the failure is silent here and only
# becomes `fatal: bad object` in a fresh clone. Hence: resolve the field, do
# not trust it.
recorded=0; dead=''
known=$(mktemp)
for f in docs/features/*/status.md; do
  [ -f "$f" ] || continue
  gc=$(sed -n 's/^geoxyz_commit: *//p' "$f" | head -1)
  [ -z "$gc" ] && continue
  for c in $(printf '%s' "$gc" | tr -d ' ' | tr '+' ' '); do
    recorded=$((recorded + 1))
    if ! git rev-parse -q --verify "$c^{commit}" >/dev/null 2>&1; then
      dead="$dead$(printf '\n          %-11s %s  (unknown object)' "$c" "$f")"
    elif ! git merge-base --is-ancestor "$c" "$ref" 2>/dev/null; then
      subj=$(git log -1 --format=%s "$c" 2>/dev/null)
      dead="$dead$(printf '\n          %-11s %s  not on the branch: %s' "$c" "$f" "${subj:0:52}")"
    else
      git rev-parse "$c^{commit}" >> "$known"
    fi
  done
done
if [ "$recorded" -eq 0 ]; then
  warn "no geoxyz_commit recorded in any status.md — nothing to verify"
elif [ -n "$dead" ]; then
  fail "geoxyz_commit in the register does not resolve on $ref:$dead"
  printf '          %s\n' "match each subject against 'git log $UPSTREAM..$ref' and update status.md, then tools/register.sh --write"
else
  pass "all $recorded recorded geoxyz_commit sha(s) are on $ref"
fi

# --- 3c. and the other way round: is every own commit recorded? -------------
# 3b only ever asked "does what the register says exist on the branch". Nothing
# asked "does what is on the branch appear in the register", so five commits —
# the FIRST commit of five different features — sat on the production branch
# recorded nowhere, and the register read as complete (Jan's K-21, 2026-09-10).
# Merges are exempt: an upstream merge belongs to no feature.
if [ "$own" -gt 0 ]; then
  unrecorded=$(git rev-list --no-merges "$UPSTREAM..$ref" | grep -vxFf "$known" || true)
  if [ -n "$unrecorded" ]; then
    # Rendered first, printed after the FAIL line. A `| while read` subshell
    # flushes its own buffer independently, so piping straight to the terminal
    # printed the commit list above the line that explains it.
    listing=$(printf '%s\n' "$unrecorded" |
      while read -r c; do git log -1 --format='          %h  %ad  %s' --date=short "$c"; done)
    fail "own commit(s) on $ref that no status.md records as a geoxyz_commit:"
    printf '%s\n' "$listing"
    printf '          %s\n' \
      "Add each one to the geoxyz_commit line of the feature it belongs to," \
      "then tools/register.sh --write. A commit nobody records is a change" \
      "nobody is tracking against its patch (INV-10)."
  else
    pass "every own non-merge commit on $ref is recorded against a feature"
  fi
fi
rm -f "$known"

# --- 4. lint on what the branch changes -----------------------------------
# Measured against a baseline: the same files at $UPSTREAM, linted with
# upstream's own config. An offence upstream already has on its own line is
# upstream's (INV-1 says leave it); only an offence this branch adds fails.
# Without the baseline this check failed on wiki_controller.rb:369
# (Rails/StrongParametersExpect, an upstream line) for every branch that
# touched the file (2026-09-05).
#
# Both worktrees get a Gemfile.lock first, and the run refuses to print a number
# until a probe controller has made Rails/StrongParametersExpect fire — see
# find_gemfile_lock and rails_cops_live above. Without that, every version-gated
# rubocop-rails cop is silently off in a fresh worktree and this check reported
# 1 offence where the honest number was 8.
if [ "$own" -eq 0 ]; then
  pass "lint: nothing changed to lint"
elif [ ! -x "$RUBOCOP" ]; then
  skip "lint NOT MEASURED — no rubocop at $RUBOCOP. Install it, or point RUBOCOP= at one."
elif [ -z "$wt" ]; then
  skip "lint NOT MEASURED — no worktree to lint"
else
  mapfile -t files < <(git diff --name-only "$UPSTREAM...$ref" | grep -E '\.(rb|rake)$')
  if [ "${#files[@]}" -eq 0 ]; then
    pass "lint: no Ruby files changed"
  else
    nfiles=${#files[@]}
    base_files=()
    for f in "${files[@]}"; do
      git cat-file -e "$UPSTREAM:$f" 2>/dev/null && base_files+=("$f")
    done
    lock=$(find_gemfile_lock)
    if [ -z "$lock" ]; then
      skip "lint NOT MEASURED — no Gemfile.lock to put in the lint worktrees, so every"
      echo "      version-gated Rails cop would be silently off. Run bundle install in a" >&2
      echo "      worktree of this repo, or set GEMFILE_LOCK=/path/to/Gemfile.lock." >&2
      lint_measured=no
    else
      cp "$lock" "$wt/Gemfile.lock"
      if ! rails_cops_live "$wt"; then
        skip "lint NOT MEASURED — the probe controller produced no"
        echo "      Rails/StrongParametersExpect, so the version-gated Rails cops are not" >&2
        echo "      running even with $lock in place. Either the lockfile does not pin" >&2
        echo "      Rails, or rubocop-rails renamed the cop and rails_cops_live() in this" >&2
        echo "      script needs updating. Do not read a lint number until this passes." >&2
        lint_measured=no
      fi
    fi
    if [ "${lint_measured:-yes}" = no ]; then
      :
    else
    warn "lint: Rails cops confirmed live, with $lock in the worktrees"
    branch_json=$(cd "$wt" && "$RUBOCOP" --force-exclusion --format json "${files[@]}" 2>/dev/null)
    base_json='{"files":[]}'
    base_ok=yes
    if [ "${#base_files[@]}" -gt 0 ]; then
      if git worktree add --detach -q "$tmp/u" "$UPSTREAM" 2>/dev/null; then
        cp "$lock" "$tmp/u/Gemfile.lock"
        base_json=$(cd "$tmp/u" && "$RUBOCOP" --force-exclusion --format json "${base_files[@]}" 2>/dev/null)
        git worktree remove --force "$tmp/u" >/dev/null 2>&1
      else
        base_ok=no
      fi
    fi
    # Per file and cop, count offences on both sides; what the branch has more
    # of than upstream is what the branch added.
    #
    # Output that will not parse is reported as UNMEASURED, never as zero. Until
    # 2026-09-10 an empty $branch_json — a rubocop that crashed, a bad config, a
    # bundler mismatch, all of it swallowed by 2>/dev/null — was caught as a
    # JSONDecodeError and became "lint: 0 offences", so a rubocop that never ran
    # and a file with nothing wrong printed the same line (round 4, tools F02).
    verdict=$(python3 - "$branch_json" "$base_json" "$base_ok" <<'RUBOCOPTALLY'
import json, sys

# No try/except in here: output that will not parse is the thing the caller has
# to report, and swallowing it is the defect being fixed.
def tally(raw):
    t = {}
    for f in json.loads(raw)['files']:
        for o in f.get('offenses', []):
            k = (f['path'], o['cop_name'])
            t[k] = t.get(k, 0) + 1
    return t

try:
    b = tally(sys.argv[1])
except Exception as e:
    print('UNMEASURED rubocop gave no parseable JSON for the branch worktree (%s)' % e)
    raise SystemExit(0)
if sys.argv[3] != 'yes':
    print('UNMEASURED the upstream baseline worktree could not be created')
    raise SystemExit(0)
try:
    u = tally(sys.argv[2])
except Exception as e:
    print('UNMEASURED rubocop gave no parseable JSON for the upstream baseline (%s)' % e)
    raise SystemExit(0)

added = {k: n - u.get(k, 0) for k, n in b.items() if n > u.get(k, 0)}
print('OK %d %d %d' % (sum(b.values()), sum(u.values()), sum(added.values())))
for (path, cop), n in sorted(added.items()):
    print("%s  %s x%d" % (path, cop, n))
RUBOCOPTALLY
)
    read -r verdict_kind n base_n added_n <<< "$(printf '%s\n' "$verdict" | head -1)"
    if [ "$verdict_kind" != OK ]; then
      skip "lint NOT MEASURED — $(printf '%s\n' "$verdict" | head -1 | cut -d' ' -f2-)"
    elif [ "${added_n:-0}" -eq 0 ] && [ "${n:-0}" -eq 0 ]; then
      pass "lint: 0 offences on $nfiles changed Ruby file(s)"
    elif [ "${added_n:-0}" -eq 0 ]; then
      pass "lint: $n offence(s) on $nfiles changed Ruby file(s), all already on $UPSTREAM's own lines (baseline $base_n) — upstream's, not this branch's"
    else
      fail "lint: $added_n offence(s) added by this branch ($n on the files, baseline $base_n on $UPSTREAM) — Redmine's CI runs rubocop:"
      printf '%s\n' "$verdict" | tail -n +2 | sed 's/^/          /'
    fi
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
if [ "$fails" -eq 0 ] && [ "$unmeasured" -eq 0 ]; then
  echo "PASS"
  exit 0
fi
if [ "$fails" -eq 0 ]; then
  echo "INCOMPLETE — $unmeasured check(s) could not be measured, so this is not a PASS."
  echo "Nothing is known to be wrong with the branch; something is unknown about it."
  echo "Do not quote this run as G8 evidence while a ???? line is above."
  exit 1
fi
if [ "$unmeasured" -gt 0 ]; then
  echo "$fails check(s) need attention, and $unmeasured could not be measured"
else
  echo "$fails check(s) need attention"
fi
exit 1
