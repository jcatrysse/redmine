#!/usr/bin/env bash
# The one INV-4 identity pattern, and the one way to apply it.
#
# Sourced, never executed:
#     . "$(dirname "$0")/inv4-identity.sh"
#     offenders=$(inv4_identities origin/master patch/foo) || exit 2
#
# The `|| exit 2` is not decoration. inv4_identities runs inside a command
# substitution, so an `exit` of its own would leave only that subshell and the
# caller would sail on — which is exactly what happened while this file was
# being written, and the push it was supposed to block went through. It returns
# 2 instead, and every caller has to act on it.
#
# Until 2026-09-10 three scripts each carried their own pattern, and the only
# one that is mandatory carried the narrowest: tools/session-push.sh matched
# `anthropic|(^| )claude( |<)`, so a Cursor, Copilot or Codex identity — or
# `<noreply@claude.ai>`, which is Anthropic's own — walked through the push
# guard while both audit gates flagged it (round 4, tools F03). ansifi's PR #1
# carries `Co-authored-by: Cursor <cursoragent@cursor.com>` on two commits, so
# that row is not hypothetical.
#
# Deliberately narrow: tool names only. A broad pattern such as \bai\b fires on
# a contributor genuinely named Ai, and a gate with false positives on real
# names is a gate somebody switches off.
AI_IDENTITY_RE='claude|anthropic|copilot|codex|chatgpt|cursor\.(sh|com)'

# The same rule for a commit message. Narrower than the identity pattern on
# purpose: a message may legitimately quote a tool name, so only the shapes an
# attribution trailer actually takes are matched.
AI_TRACE_RE='co-authored-by:.*(cursor|claude|copilot|codex|chatgpt)|generated (with|by)|claude-(opus|sonnet|haiku|fable)|(claude|chatgpt|cursor)[-.]?session|claude\.ai/code'

# inv4_identities <from-ref> <to-ref>
#
# Prints one line per commit in <from>..<to> whose author or committer carries
# an AI identity, and nothing at all when there are none. Exits the calling
# script with 2 — rather than returning "clean" — when the pattern is empty or
# either ref does not resolve. Both of those make the grep report nothing, which
# is indistinguishable from a clean branch, and that is how session-push.sh
# could pass a first push of a new patch/* branch in a clone that had never
# fetched origin/master.
inv4_identities() {
  local from="$1" to="$2" ref
  [ -n "${AI_IDENTITY_RE:-}" ] ||
    { echo "FAIL  the AI identity pattern is empty — this check would pass without testing anything" >&2; return 2; }
  for ref in "$from" "$to"; do
    git rev-parse --verify --quiet "$ref^{commit}" >/dev/null ||
      { echo "FAIL  INV-4 cannot be checked: '$ref' does not resolve, so the range is empty and the check would report clean without reading a commit" >&2; return 2; }
  done
  git log --format='%h  author=%an <%ae>  committer=%cn <%ce>' "$from..$to" |
    grep -iE "$AI_IDENTITY_RE" || true
}
