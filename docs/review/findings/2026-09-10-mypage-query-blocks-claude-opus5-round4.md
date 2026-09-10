# Review run — 2026-09-10 — claude-opus5-round4

- **Reviewer:** Claude Code (Opus 5), round 4 (Deel A of `docs/review/prompt-round4.md`)
- **Reviewed:** `patch/mypage-query-blocks` at `3fc86ca5b` against its base `bee32a926` (r25037), and against real trunk `167e487ee` (r25065) for applicability
- **Dossier read:** `docs/features/mypage-query-blocks/dossier.md` — yes
- **Status read:** `docs/features/mypage-query-blocks/status.md` — yes
- **Ran the test suite:** partly — the three touched test files in one process, and two wider combinations while trying to reproduce the "geraakte suites" figure. Not `test:all`; the r25037 baseline this dossier quotes (5977 runs) is the one I measured today for `imap-oauth` on the same revision, and it matches.
- **Scope covered:** the whole production diff; whether anything other than `block_options` reads `:max_occurs`, which decides whether the Symbol indirection can surprise a plugin; whether lowering the setting can break a user who is already over the limit, traced through `remove_block`, `order_blocks` and `add_block` rather than trusted to the commit message; the range validation including the non-numeric and blank paths; INV-5 across all five locales with every cited key looked up by hand; RuboCop both sides; INV-10 through `tools/check-symmetry.sh`; all fifteen screenshots listed and the identical-pair claim checked with `sha256sum`.
- **Scope NOT covered:** no `test:all` and no `7.0-stable-GEOxyz` suite for this feature. I did not reproduce the three mutation results ("alle productiebestanden terug naar trunk → 14 errors" and the two others), and I did not re-measure the query-count table in "What asynchronous loading would and would not fix".

## Summary

This one is in good shape and the design is the careful version. `:max_occurs`
now accepts either an Integer or a Symbol naming a setting, so a plugin that
declares `:max_occurs => 2` keeps working unchanged — and there is a test that
pins exactly that, which is the plugin-compatibility question the last two
features I reviewed left open. Nothing outside `block_options` reads
`:max_occurs`, so the indirection cannot leak anywhere else; I grepped for it
rather than assuming.

I spent most of the time on the claim that lowering the setting does not
disturb a user who already has more blocks than the new maximum, because that
is where this kind of change usually breaks. It holds, and not by luck:
`order_blocks` intersects with the blocks already in the layout and never calls
`valid_block?`, and `remove_block` does not either, so only `add_block` is
gated. Reordering and removing keep working at any setting value.

The i18n is exact. Every one of the five strings is composed from two or three
existing keys, the dossier cites each with file and line, and the four I
spot-checked read exactly as quoted — including the German, where "eigener
Abfragen" comes from `label_my_queries` ("Meine eigenen Abfragen") rather than
from the bare `label_query_plural` ("Abfragen"), which is the harder and the
right choice.

One number does not reproduce, and that is my only finding.

**Counts:** blocker 0 · major 0 · minor 0 · nit 1 · question 0

**Lines in the diff not strictly required by the feature:** 0.

## Evidence I re-measured

| Claim | What I measured | Same? |
|---|---|---|
| pristine trunk r25037: 5977 runs | **5977 runs** (measured today, same revision, matched lock) | yes |
| RuboCop on the five changed files: 0, baseline 0 | **0 and 0** (rubocop 1.90.0) | yes |
| touched suites: 135 runs, 1346 assertions, 0 failures, 0 errors | **92 runs, 506 assertions, 0 failures, 0 errors** for the three test files the patch changes; **108 runs, 547 assertions** adding `test/unit/setting_test.rb`. See F01 | no |
| `tools/check-symmetry.sh mypage-query-blocks`: PASS | **PASS**, and its 5 locale keys read the same on both branches | yes |
| `tools/check-patch-clean.sh mypage-query-blocks --submit`: PASS | **PASS** against real trunk r25065 | yes |
| the before/after pair at the default maximum is the same image | **confirmed** by `sha256sum`: `be9ced09…` for both `before-select-at-default-maximum.png` and `select-at-default-maximum.png` | yes |
| the cited locale sources exist and read as quoted | **confirmed** for `label_query_plural` and `label_my_page` in all five, and for `label_my_queries` (de.yml:651, "Meine eigenen Abfragen") | yes |
| "lowering it does not hide blocks a user already has" | **confirmed by reading the three call sites**: only `add_block` calls `valid_block?`; `order_blocks` intersects with the existing layout and `remove_block` does neither | yes |
| nothing else reads `:max_occurs` | **confirmed**: `grep -rn max_occurs app/ lib/` returns only the declaration, `block_options`, and the new method | yes |

---

### F01 — the "geraakte suites" figure does not reproduce, and the bullet does not say which suites it means

- **Status:** fixed
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/mypage-query-blocks/status.md`, the "Geraakte suites in één proces" bullet
- **Invariant touched:** INV-8

**What is wrong**

The bullet reads "Geraakte suites in één proces: **135 runs, 1346 assertions,
0 failures, 0 errors**" and names no files. The three test files this patch
changes hold 5 + 63 + 24 = 92 test methods between them, and running all three
in one process gives **92 runs, 506 assertions**. Adding the obvious companion
for the fourth changed production file, `test/unit/setting_test.rb`, gives
**108 runs, 547 assertions**. `test/system/my_page_test.rb` adds four more. I
could not construct a file set that gives 135 runs, and the assertion count is
further off than the run count is.

**Why a committer would push back**

They will not see this file. It matters under INV-8, which exists because a
number that was true once reads the same as a number that is true now. Every
other evidence bullet in this same block reproduces to the digit — the trunk
baseline, the RuboCop counts, even the SHA-256 identity of the two
screenshots — so this one stands out as the single figure a later session
cannot check.

**How I verified it**

```
my_page_test.rb + my_controller_test.rb + settings_controller_test.rb
  -> 92 runs, 506 assertions, 0 failures, 0 errors
  + test/unit/setting_test.rb
  -> 108 runs, 547 assertions, 0 failures, 0 errors
def test_ counts: 5, 63, 24 (+16 in setting_test.rb, +4 in test/system/my_page_test.rb)
```

**Suggested direction**

Name the files in the bullet and re-run it, the way
`docs/features/revision-branches/status.md` does. If the 135 turns out to come
from a larger set that made sense at the time, saying which set is enough; the
figure only has to be reconstructable.

**Resolution:** fixed, 2026-09-10, by re-measuring rather than by explaining. The bullet now
names all five files and says how they were run (`tools/test-env.sh`, so the
four system tests execute instead of erroring), and carries the number that run
produced: **112 runs, 570 assertions, 0 failures, 0 errors, 0 skips**. The old
`135 runs, 1346 assertions` was replaced rather than annotated, because no file
set I could construct reproduces it — the three changed test files alone give
92 runs, and adding the two obvious companions gives 112.

---

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks.

**The identical before/after pair is the best evidence idea in the register and
I want to say why, because at first glance it looks like the defect round 4
was told to hunt for.** The brief says "a screenshot that would look identical
with and without the change is not evidence, and one round already found a pair
that was the same image". Here the pair *is* the same image, deliberately, and
that is the whole argument: note 9 of Jean-Philippe Lang on #27313 asks that
the default not change for anyone, and two byte-identical screenshots at the
default setting are the strongest possible answer. The verification script
compares them with SHA-256 and fails if they ever differ, so the claim cannot
rot. I confirmed the hash myself. An identical pair is worthless when identity
is an accident and decisive when identity is the claim; the difference is
whether something asserts it.

**The `:max_occurs` Symbol indirection answers a question two other features in
this register leave open.** Both `assignee-nobody` and `search-token-limit`
change the meaning of something a plugin can reach — a filter value and a
tokenizer's output — and both reason about core's own callers only. This
feature does the same kind of thing to `:max_occurs` and ships
`test_max_occurs_should_return_an_integer_max_occurs`, which is exactly the
"a plugin that did it the old way still works" test the other two are missing.
Whoever fixes those two should copy this.

**Nothing in `docs/DECISIONS.md` looks wrong to me.** K-10 option C — an upper
bound of 20, described in the code comment as a typo guard rather than a
recommendation — is the right shape for a limit whose real cost (one query per
block) is explained in the same sentence.
