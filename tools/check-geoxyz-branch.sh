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
AI_TRACE_RE='co-authored-by:.*(cursor|claude|copilot|codex|chatgpt)|generated (with|by)|claude-(opus|sonnet|haiku|fable)|(claude|chatgpt|cursor)[-.]?session|claude\.ai/code'
# Deliberately narrow: the tool names only. A broad pattern such as \bai\b
# would fire on a contributor genuinely named Ai, and a gate with false
# positives on real names is a gate somebody switches off.
AI_IDENTITY_RE='claude|anthropic|copilot|codex|chatgpt|cursor\.(sh|com)'
if [ "$own" -gt 0 ]; then
  traces=$(git log --format='%B' "$UPSTREAM..$ref" | grep -inE "$AI_TRACE_RE" || true)
  if [ -n "$traces" ]; then
    fail "own commit messages contain AI traces (INV-4):"
    printf '%s\n' "$traces" | sed 's/^/          /'
  else
    pass "no AI traces in own commit messages"
  fi

  [ -n "${AI_TRACE_RE:-}" ] && [ -n "${AI_IDENTITY_RE:-}" ] ||
    { echo "FAIL  AI pattern is empty — this check would pass without testing anything" >&2; exit 2; }
  identities=$(git log --format='%h  author=%an <%ae>  committer=%cn <%ce>' "$UPSTREAM..$ref" |
               grep -iE "$AI_IDENTITY_RE" || true)
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

# --- 4. lint on what the branch changes -----------------------------------
# Measured against a baseline: the same files at $UPSTREAM, linted with
# upstream's own config. An offence upstream already has on its own line is
# upstream's (INV-1 says leave it); only an offence this branch adds fails.
# Without the baseline this check failed on wiki_controller.rb:369
# (Rails/StrongParametersExpect, an upstream line) for every branch that
# touched the file (2026-09-05).
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
    nfiles=$(printf '%s\n' "$files" | wc -l | tr -d ' ')
    base_files=""
    for f in $files; do
      git cat-file -e "$UPSTREAM:$f" 2>/dev/null && base_files="$base_files $f"
    done
    branch_json=$(cd "$wt" && "$RUBOCOP" --force-exclusion --format json $files 2>/dev/null)
    base_json='{"files":[]}'
    if [ -n "$base_files" ] && git worktree add --detach -q "$tmp/u" "$UPSTREAM" 2>/dev/null; then
      base_json=$(cd "$tmp/u" && "$RUBOCOP" --force-exclusion --format json $base_files 2>/dev/null)
      git worktree remove --force "$tmp/u" >/dev/null 2>&1
    fi
    # Per file and cop, count offences on both sides; what the branch has more
    # of than upstream is what the branch added.
    verdict=$(python3 - "$branch_json" "$base_json" <<'PY'
import json, sys
def tally(raw):
    t = {}
    try:
        for f in json.loads(raw or '{}').get('files', []):
            for o in f.get('offenses', []):
                k = (f['path'], o['cop_name'])
                t[k] = t.get(k, 0) + 1
    except json.JSONDecodeError:
        pass
    return t
b, u = tally(sys.argv[1]), tally(sys.argv[2])
added = {k: n - u.get(k, 0) for k, n in b.items() if n > u.get(k, 0)}
print(sum(b.values()), sum(u.values()), sum(added.values()))
for (path, cop), n in sorted(added.items()):
    print("%s  %s x%d" % (path, cop, n))
PY
)
    read -r n base_n added_n <<< "$(printf '%s\n' "$verdict" | head -1)"
    if [ "${added_n:-0}" -eq 0 ] && [ "${n:-0}" -eq 0 ]; then
      pass "lint: 0 offences on $nfiles changed Ruby file(s)"
    elif [ "${added_n:-0}" -eq 0 ]; then
      pass "lint: $n offence(s) on $nfiles changed Ruby file(s), all already on $UPSTREAM's own lines (baseline $base_n) — upstream's, not this branch's"
    else
      fail "lint: $added_n offence(s) added by this branch ($n on the files, baseline $base_n on $UPSTREAM) — Redmine's CI runs rubocop:"
      printf '%s\n' "$verdict" | tail -n +2 | sed 's/^/          /'
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
