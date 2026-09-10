# Review run — 2026-09-10 — claude-opus5-round4

- **Reviewer:** Claude Code (Opus 5), round 4 (Deel A of `docs/review/prompt-round4.md`)
- **Reviewed:** `patch/search-token-limit` at `587d9a11b` against its base `bee32a926` (r25037), and against real trunk `167e487ee` (r25065) for applicability
- **Dossier read:** `docs/features/search-token-limit/dossier.md` — yes
- **Status read:** `docs/features/search-token-limit/status.md` — yes
- **Ran the test suite:** partly — the five touched files in one process. Not `test:all` for this feature; the r25037 baseline this dossier quotes (5977 runs) is the one I measured today for `imap-oauth` on the same revision, and it matches.
- **Scope covered:** the whole production diff line by line; `Hash#delete` with a block as the default mechanism; every caller of `Redmine::Search::Tokenizer` in the tree; the round-trip property of `tokens_to_question` worked out by hand against the tokenizer's regex, including tokens containing a quote character, which the tests do not cover; the eight new tests read as coverage; RuboCop; INV-10 through `tools/check-symmetry.sh`; the dossier read as a submission, including its performance table; the screenshots opened.
- **Scope NOT covered:** I did not reproduce the PostgreSQL benchmark in the objections table (1 000 tokens, 10.9 s). I did not run `test:all` or the `7.0-stable-GEOxyz` suite for this feature, and I did not re-drive the browser.

## Summary

This is the cleanest patch of the four I have read. It is a bug fix pretending
to be nothing more, the diff outside tests is fourteen lines, and the mechanism
is the smallest one that works: `Hash#delete(:token_limit) {5}` keeps the old
default for every existing caller and lets exactly one caller lift it. I
checked the two things that could have gone wrong — whether any other code
depends on the tokenizer's cap, and whether `tokens_to_question` really
round-trips through the tokenizer — and both are fine. The round-trip holds
even for the case the tests miss, a token containing a quote character, because
the tokenizer's alternation cannot produce a token that would re-parse
differently.

The performance objection I had drafted before opening the dossier was already
there, answered with `EXPLAIN ANALYZE` numbers at 1, 5, 50, 200 and 1 000
tokens, split by `AND` versus `OR` operators, and with the core precedent
(`Principal.like`, uncapped since forever) named. That is the standard the
other dossiers should be held to.

I have one finding and it is a nit: the backward-compatibility paragraph
reasons about plugins that build a `Fetcher`, and not about plugins that call
`Redmine::Search::Tokenizer` directly, whose behaviour this patch changes.

**Counts:** blocker 0 · major 0 · minor 0 · nit 1 · question 0

**Lines in the diff not strictly required by the feature:** 0.

## Evidence I re-measured

| Claim | What I measured | Same? |
|---|---|---|
| pristine trunk r25037: 5977 runs | **5977 runs** (measured today on the same revision, matched lock) | yes |
| delta +8 runs, the eight new tests | the five test files add **8** `def test_` methods | yes |
| RuboCop on the 8 changed files: 0, baseline 0 | **0** on all eight (rubocop 1.90.0) | yes |
| touched suites green | **351 runs, 1183 assertions, 0 failures, 0 errors, 2 skips** | yes |
| `tools/check-symmetry.sh search-token-limit`: PASS | **PASS** | yes |
| `tools/check-patch-clean.sh search-token-limit --submit`: PASS | **PASS** against real trunk r25065 | yes |
| "`grep -rn Tokenizer app lib` returns three hits" | **confirmed**: the class, `Fetcher#initialize`, and `Query#sql_contains` at `query.rb:1519` | yes |
| the before shots show the defect | **yes** — `before-filter-contains.png` is `Subject contains "pump alignment survey report northern zzz"` returning one issue whose subject contains no `zzz`. That single image is the whole bug | yes |

---

### F01 — the backward-compatibility paragraph covers plugins that build a `Fetcher`, not plugins that call the tokenizer

- **Status:** fixed
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** backward-compat
- **Where:** `lib/redmine/search.rb:148`; "Backward compatibility" in `dossier.md`
- **Invariant touched:** none

**What is wrong**

`Redmine::Search::Tokenizer#tokens` used to return at most five tokens and now
returns all of them. The dossier's backward-compatibility paragraph says
"`Redmine::Search::Fetcher.new` keeps its old default, so a plugin that builds
one is unaffected", which is true, and it enumerates core's callers of the
tokenizer, which is also true. Neither covers a plugin that calls the tokenizer
itself — `Redmine::Search::Tokenizer.new(params[:q]).tokens` is two words of
public API in `lib/redmine/`, it is the obvious way for a plugin to split a
search box the way Redmine does, and after this patch it hands that plugin an
unbounded list where it used to hand back five.

**Why a committer would push back**

Not over the change, which is right. Over the completeness of the sentence,
and only if they think of it. The concrete case is the one this patch's own
objections table quantifies: a plugin that loops the tokens into `OR`-combined
`LIKE` conditions goes from five conditions to as many words as the user
pasted, and the table's own measurement for that shape is 10.9 seconds at
1 000 tokens.

**How I verified it**

`grep -rn Tokenizer app lib` gives the three core hits the dossier names, so
nothing in core is affected. The class is public, is not marked internal, and
`Fetcher` is the only place the new default lives — read-only; I did not write
a plugin to demonstrate it.

**Suggested direction**

One clause in the backward-compatibility paragraph: the cap now lives in
`Fetcher`, so a plugin that builds a `Fetcher` is unaffected and a plugin that
calls `Tokenizer` directly now receives every token and should pass its own
`first(n)` if it wants the old behaviour. Nothing in the code needs to change.

**Resolution:** fixed, 2026-09-10, in the dossier. The backward-compatibility paragraph now
distinguishes the two kinds of plugin: one that builds a `Fetcher` keeps the old
default and is unaffected, one that calls `Redmine::Search::Tokenizer` directly
now receives every token and should apply its own `first(n)`. No code change —
the tokenizer's new behaviour is the fix, not a side effect.

---

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks.

**I disagree with nothing here, and that is worth stating rather than skipping.**
Rounds 1 and 3 and the two Codex rounds between them left this patch with one
new helper, fourteen production lines and a performance table measured on real
data. The one thing I would have raised on my own — unbounded tokens in a
filter — is answered better in the dossier than I would have asked it, because
it separates the `AND` operators (cost flat in token count) from the `OR`
operators (cost linear in tokens × rows) instead of giving a single number.

**One thing I checked because a test does not.** `tokens_to_question` is tested
for the phrase round-trip but not for a token containing a `"`, which the
tokenizer can produce: `foo"bar` matches the `[^\p{Zs}]+` branch, survives the
quote-stripping gsub, and re-parses to itself, so the round-trip holds. I am
not filing that as a coverage finding — the property is real and the helper is
three lines — but the reasoning is here in case a later change to the regex
makes it false.

**The one screenshot other features should copy.**
`before-filter-contains.png` shows a filter reading "contains pump alignment
survey report northern zzz" and one result whose subject has no `zzz` in it.
No caption is needed; the picture is the bug. Several other features'
before shots are HTTP 500 pages, which prove only that a URL raises.

**Nothing in `docs/DECISIONS.md` looks wrong to me.** K-04 option A — drop the
setting, keep the global search at five, make this a bug fix — is what turns
this from a feature request into something a committer can take in one reading,
and the diff shows it.
