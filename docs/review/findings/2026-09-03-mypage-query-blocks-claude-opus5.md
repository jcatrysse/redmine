# Review run — 2026-09-03 — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `patch/mypage-query-blocks` at `ec6466159` against `origin/master` `bee32a926` (branch point `2563fa6a5` = r24882)
- **Dossier read:** `docs/features/mypage-query-blocks/dossier.md` — yes
- **Status read:** `docs/features/mypage-query-blocks/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes — touched suites only, in a throwaway PostgreSQL worktree of `ec6466159`. Not the full suite (tens of minutes, and the dossier's own trunk-baseline comparison is credible: the 29 failures it names are all `svn`/`hg`/`bzr`/`cvs` suites that this container cannot run).
  - `my_controller_test` + `setting_test` + `settings_controller_test` + `i18n_test`, one process → **126 runs, 1325 assertions, 0 failures, 0 errors, 0 skips** (exactly the dossier's figure)
  - the same four plus `user_preference_test` → **140 runs, 1353 assertions, 0 failures, 0 errors, 0 skips**
  - RuboCop (`--force-exclusion`) on `lib/redmine/my_page.rb` + `test/functional/my_controller_test.rb` → **2 files inspected, no offenses detected**
- **Scope covered:** minimality; feature scope; settings surface (name, tab, validation, 0/negative/huge/non-integer inputs, measured); conventions of the touched files against real trunk code; backward compatibility incl. the lowered-limit / data-loss question (verified by experiment); authorization; page-load cost (measured independently); i18n (all 15 locale citations checked line by line); test quality (four separate mutation experiments); test pollution; patch hygiene (both files applied against pristine trunk); screenshots (opened and compared, not just listed); GEOxyz commit vs patch diff; INV-4.
- **Scope NOT covered:** the full test suite; database portability (no SQL is added, so nothing to check); SCM symmetry (not applicable); escaping (no new user-controlled value reaches a view); no live browser session of my own — I inspected the committed screenshots instead; the dossier's absolute SQL-query numbers could not be reproduced because they were measured on `tools/dev-seed.rb` data and I measured on Redmine's test fixtures (see F04).

## Summary

The code is very good and very small: two changed lines and one new nine-line
method, no migration, no route, no permission, one setting on the tab where
Redmine already keeps its display limits. I checked the two claims the whole
submission rests on. The first — the default really is still 3 — **holds, and is
genuinely locked by a test**: I changed the default in `config/settings.yml` from
3 to 5 and `test_page_should_disable_issuequery_option_at_the_default_maximum`
failed, so the guard is not decoration. The second — that lowering the setting
below what a user already has costs them nothing — **also holds**: rendering
never consults `max_occurs`, so existing blocks keep rendering; I confirmed this
both in the code path and by driving `GET /my/page` with three blocks and the
limit at 0. No data loss. Authorization is untouched: every block still goes
through `IssueQuery.visible` and `Issue.visible`, so a raised limit exposes
nothing new.

Three things would send this back, none of them deep. (1) The patch **no longer
applies to trunk**: `origin/master` has moved ~90 commits since the branch point
and the "French translation update (#44323)" commit rewrote the tail of
`fr.yml`, so the locales patch fails `git apply` there — a committer's first
action bounces. (2) The dossier and `status.md` both instruct Jan to tell
Jean-Philippe Lang that `before-select-at-default-maximum.png` and
`select-at-default-maximum.png` are *the same image*. **They are not** — they
differ in bytes and, worse, the "after" one has a stray "Delete" tooltip
floating over the select. Telling the lead developer "this is the same picture"
and handing him two visibly different pictures is the one mistake this note
cannot afford. (3) The clamp to a minimum of 1 is defended, in the dossier *and
in the commit message*, with a reason that is factually wrong — "a zero must not
disable a block a user already has". Zero does not disable anything a user
already has; I removed the clamp and proved it. The clamp's only real effect is
to take away the one setting value that answers note-5 most directly ("no new
custom query blocks at all"), while still storing and redisplaying 0 and -2 in
the admin form as if they meant something.

What surprised me positively: the mutation experiments. Reverting only
`lib/redmine/my_page.rb` while leaving the setting in place makes three of the
six new tests fail on behaviour, and removing only the clamp makes a fourth
fail. That is real discriminating power, and it is stronger evidence than the
dossier's own "five tests raise `There's no setting named …`" claim. Only one of
the six tests turns out not to discriminate anything (F05).

**Counts:** blocker 1 · major 2 · minor 4 · nit 2 · question 1

**Lines in the diff not strictly required by the feature:** 1 — the
`# Maximum number of issue query blocks on My page` comment in
`config/settings.yml` (F07). Everything else in the 102 lines is load-bearing;
82 of them are tests.

---

### F01 — The locales patch does not apply to current `origin/master`

- **Status:** resolved
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** conventions (patch hygiene)
- **Where:** `patches/mypage-query-blocks/2026-09-03-r24882-locales.patch`, hunk `config/locales/fr.yml:1542`
- **Invariant touched:** INV-2 (and G6)
- **Resolution:** fixed 2026-09-05 — branch rebased onto `bee32a926` (r25037) and both patch files regenerated; `--submit` passes

**What is wrong**

The branch is based on `2563fa6a5` (r24882, 2026-08-03). The local trunk mirror
has since advanced to `bee32a926`, ~90 commits later, and one of those commits
is `890812e49 French translation update (#44323)`, which translated the
previously-English keys at the end of `fr.yml`. The locales patch's only `fr.yml`
hunk quotes those English lines as context, so it no longer applies. The feature
patch still applies cleanly; only the locales file breaks, and only for French.

**Why a committer would push back**

They will not read the patch at all. The first thing anyone does with an
attachment on redmine.org is apply it to a working copy; `git apply` on the
locales file fails outright, and even `git apply --3way` reports a conflict.
Concretely, in a pristine checkout of `bee32a926`:

    error: patch failed: config/locales/fr.yml:1542
    error: config/locales/fr.yml: patch does not apply

The dossier's claim "patch applies to pristine `origin/master` r24882: yes" is
true of the pinned revision and no longer true of trunk, and it is trunk that
the reviewer has.

**How I verified it**

Worktree at `origin/master` (`bee32a926`), then:

    git apply --check .../2026-09-03-r24882-feature.patch    # OK
    git apply --check .../2026-09-03-r24882-locales.patch    # fr.yml fails
    git apply --3way --check .../2026-09-03-r24882-locales.patch
      # de/es/nl clean, "Applied patch to 'config/locales/fr.yml' with conflicts"

Per-file `--include` runs confirmed `de`, `es` and `nl` are fine in isolation.

**Suggested direction**

Recreate the branch from a freshly fetched `origin/master` and regenerate both
files, then re-state the revision in the dossier and in the note. Two things to
re-check while doing it, both of which I already verified are still fine so they
should not cost time: the three French pattern keys the dossier cites
(`setting_gantt_items_limit`, `label_query_plural`, `label_my_page`) are
unchanged by #44323, and the `en.yml` insertion point next to
`setting_activity_days_default` still exists. Only the diff context has moved.

**Resolution:** fixed, 2026-09-05. The branch was rebased onto a freshly
fetched `origin/master` (`bee32a926` = r25037, 88 commits on from the old branch
point) and both patch files regenerated. The only conflict was the one this
finding names: `890812e49` translated the tail of `fr.yml`, so the French half
was resolved by keeping trunk's translations and re-appending the new key. The
three French pattern keys and the `en.yml` insertion point were re-checked and
are where the dossier says they are. `tools/check-patch-clean.sh
mypage-query-blocks --submit` now passes.

---

### F02 — `before-select-at-default-maximum.png` and `select-at-default-maximum.png` are not the same image, and the "after" one has a stray "Delete" tooltip in it

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/mypage-query-blocks/shots/{before-,}select-at-default-maximum.png`; the claim is in `dossier.md` ("Anticipated objections", row 1: "are the same picture") and in `status.md` ("Wat Jan nog moet doen": "het voor/na-paar … is dezelfde afbeelding")
- **Invariant touched:** none (G9)
- **Resolution:** fixed 2026-09-05 — the pointer is parked before every select crop, and the run asserts the before/after pair by SHA-256

**What is wrong**

Both files are 146x171, but they are different files (7695 vs 8660 bytes,
different MD5). Opening them: the substance *is* identical — "Issues" is greyed
out in both, which is exactly the point being made — but the "after" image
additionally contains a native browser tooltip reading **"Delete"** floating over
the top-right of the listbox, left over from the mouse position after
`clearBlocks()`/`addBlock()` in `verify/mypage-query-blocks.mjs`. The before run
happened not to leave the cursor there.

**Why a committer would push back**

`status.md` tells Jan to write, in a note to Redmine's lead developer, that this
before/after pair is the same image. Jean-Philippe Lang can download both
attachments and see they are not: one has a "Delete" label in it that has
nothing to do with the change. The whole persuasive weight of the note is "look,
nothing is different at the default" — presenting two demonstrably different
pictures under that sentence undermines precisely the claim it is meant to prove,
and invites the reader to wonder what else in the note was checked as loosely.

**How I verified it**

    md5sum docs/features/mypage-query-blocks/shots/*.png
    # a6425069864132e6cbabed310a016100  before-select-at-default-maximum.png
    # cd3ace0ef82711522eb00c054cb3152e  select-at-default-maximum.png

and I opened both images. The before shot is byte-identical to
`before-select-raised-maximum.png` (same MD5), which is consistent with the
dossier; the after shot is the odd one out. Reading the images is also what
turned up the tooltip — the file sizes alone would only have told me they differ.

**Suggested direction**

Either make the pair genuinely byte-identical — move the pointer away (or use
`page.mouse.move`) before `shotSelect`, so the shot is deterministic in both
modes, and then assert in the verification script that the two files hash the
same, which turns the claim into something the script proves rather than
something a human asserts — or keep two images and reword the claim to what is
actually true. The first is much stronger for the note, and it costs one line in
`verify/mypage-query-blocks.mjs`.

**Resolution:** fixed, 2026-09-05, and by the first of the two routes the
finding suggests. `shotSelect` in `verify/mypage-query-blocks.mjs` now parks the
pointer with `page.mouse.move(0, 0)` before every crop, so no native tooltip can
land in the image, and the `after` run compares
`before-select-at-default-maximum.png` with its own shot by SHA-256 and fails if
they differ. The claim in the dossier and in `status.md` is now something the
script proves rather than something a human asserts.

---

### F03 — The clamp to a minimum of 1 is justified with a reason that is not true, and it removes the setting value that answers note-5 best

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/redmine/my_page.rb:71-73`; the justification is in `dossier.md` ("Proposed change", the input table's `0` row, and the "Anticipated objections" table) and in the commit message of `ec6466159`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the clamp is gone, `0` means no new blocks, and out-of-range is refused in the form (Jan g16b)

**What is wrong**

`max_occurs` clamps a configured value to at least 1:

    max_occurs.is_a?(Symbol) ? [Setting[max_occurs].to_i, 1].max : max_occurs

The stated reason, in the dossier ("a zero must not disable a block type a user
already has") and verbatim in the commit message that will be pasted into the
issue ("clamped to a minimum of one so that a blank or zero value cannot disable
a block type a user already has on the page"), does not hold. `max_occurs` is
read in exactly one place, `block_options`, which only decides whether *another*
block may be added; `MyHelper#render_blocks` never consults it. A value of 0
therefore cannot disable a block anybody already has — it only stops new ones.
"Blank" cannot occur at all: `Setting`'s `validates_numericality_of` refuses to
store an empty value, so the previous value survives.

What the clamp actually does is delete the one value that expresses "no new
custom query blocks on this installation" — which is the direction note-5 on
#27313 asks for, and which the dossier itself sells as the patch's second
selling point ("today an installation that is suffering from dashboard queries
cannot ask for fewer than three"). It also leaves the admin form lying: 0 and -2
are stored, redisplayed in the field on the next page load, and silently behave
as 1, with no validation error.

**Why a committer would push back**

An administrator who has been burned by dashboard load — note-5's installation —
sets the field to 0 to stop users adding query blocks. The form saves, reloads,
and shows `0`. Users can still each add one block. Nothing in the UI says
otherwise. Separately, a reviewer who reads the commit message and then reads
`block_options` sees that the sentence explaining the clamp is wrong about the
code it is explaining, which is worse than having no sentence.

**How I verified it**

Two experiments in a worktree of `ec6466159`.

1. Measured every input through the real `Setting` path (integration test,
   `Setting.my_page_max_issuequery_blocks = v` then
   `Redmine::MyPage.max_occurs('issuequery')`). Every row of the dossier's input
   table is accurate, and two rows it does not have:

       input=3        stored="3"        max_occurs=3
       input=""       stored="3"        max_occurs=3
       input="abc"    stored="3"        max_occurs=3
       input=0        stored="0"        max_occurs=1
       input=-2       stored="-2"       max_occurs=1
       input=2.9      stored=previous   max_occurs=previous   (rejected)
       input=999999   stored="999999"   max_occurs=999999

2. Removed the clamp, set the setting to 0, gave user 2 three `issuequery`
   blocks and requested `/my/page` as jsmith:

       status=200 max_occurs=0
       block-issuequery present=true
       block-issuequery__1 present=true
       block-issuequery__2 present=true
       issues option disabled="<option disabled=\"disabled\">Issues</option>"

   All three existing blocks render; only adding is blocked. So 0 is a coherent,
   useful value and the clamp's stated danger does not exist.

**Suggested direction**

Two defensible ends, and the choice is a real one. Either drop the clamp and let
0 mean "no new query blocks" (then the guard against nonsense belongs in
`Setting.validate_all_from_params`, where `default_issue_due_date_offset`
already rejects a negative with
`activerecord.errors.messages.greater_than_or_equal_to` — that is the existing
Redmine pattern for exactly this), or keep the clamp and reject anything below 1
in the form so the configuration the admin sees always matches what runs. What
must not survive either way is the current combination: silently accept, silently
redisplay, silently ignore — and a commit message that explains it with something
untrue.

**Resolution:** fixed, 2026-09-05, by the first of the two ends the finding
offers, combined with Jan's g16b. The clamp is gone: `MyPage.max_occurs` returns
`Setting[...].to_i` unchanged, so `0` means "no new custom query blocks", which
is what note-5 asks for. What used to be silently swallowed is now refused where
the administrator can see it: `Setting.validate_all_from_params` rejects
anything outside `0..Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS`, in the same place
and with the same messages `default_issue_due_date_offset` uses. The commit
message no longer explains a clamp that is not there. Pinned by three new tests
in `settings_controller_test.rb` and by
`test_add_issuequery_block_with_the_maximum_set_to_zero_should_error`.

---

### F04 — The asynchronous-loading measurement table is not reproducible as presented, and one sentence double-counts the baseline

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `dossier.md`, section "What asynchronous loading would and would not fix"
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — table re-measured on Redmine's own fixtures, with the conditions and the marginal cost stated

**What is wrong**

The table gives absolute SQL-query counts (0 blocks: 10; 1: 41; 3: 85; 6: 151)
without saying what data they were measured on. They were measured on a
`tools/dev-seed.rb` instance, and the per-block query cost of a My page block
depends almost entirely on that dataset — how many projects, versions,
categories, users and custom fields `available_filters` has to enumerate. I
measured the same thing on Redmine's own test fixtures and got a per-block cost
roughly seven times smaller. Separately, the prose says "Of the ~41 queries a
single block costs, 25 are `issue_count` plus `issues(:limit => 10)`" — but 41 is
the whole page including the 10-query baseline, so one block costs 31, not 41,
and the 25/7/6 breakdown sums to 38 against a figure that includes work the
block did not do.

**Why a committer would push back**

This table is the centrepiece of the answer to note-9, addressed to the person
who wrote note-9. If he reproduces it on his own instance and gets 3 extra
queries per block where the note says 22, he will not conclude that datasets
differ — he will conclude the note's numbers are not to be relied on, and the
rest of the note goes with them. The conclusions the table supports are, as far
as I can tell, all correct; it is only the presentation that is fragile.

**How I verified it**

Integration test on `ec6466159` in a fixtures database, counting
`sql.active_record` notifications with `SCHEMA` and `payload[:cached]` excluded,
six distinct public `IssueQuery` records (distinct `sort_criteria`, so no
identical SQL), one warm request before each measured one:

    blocks=0  queries=9        body=12.7KB
    blocks=1  queries=24 (+15) body=29.5KB
    blocks=2  queries=28 (+4)  body=46.5KB
    blocks=3  queries=31 (+3)  body=63.5KB
    blocks=6  queries=40 (+9)  body=114.5KB

Two of the dossier's claims come out of this **corroborated**: the response-body
column is almost exactly right (12.7 KB baseline vs its 13 KB; ~17 KB per block
vs its ~17.6 KB), and the cost genuinely does not scale with the number of rows —
re-running with a filter that matched no issues changed the per-block query delta
by at most one. The query counts themselves do not match, and I believe the
dataset is the whole explanation rather than an error by either of us.

One fact I found that the table is missing and that helps the argument: two blocks
pointing at the *same* saved query cost no extra SQL at all, because Rails'
per-request query cache absorbs the identical statements. With one query in six
blocks I measured 30 queries for one block and 30 for six.

**Suggested direction**

State the measurement conditions next to the table — Redmine revision, the seed
data, how the queries were counted, and that it is one *distinct* public query
per block — and give the marginal cost per block rather than only the totals, so a
reader who measures a different absolute number can still check the shape. The
"~41 queries a single block costs" sentence should be about the marginal 31. The
query-cache observation is worth one sentence: it is the honest form of "the
worst case needs six different queries".

**Resolution:** fixed, 2026-09-05. The table was re-measured on Redmine's own
test fixtures — the dataset a reviewer has — with the conditions stated next to
it: the revision, the fixture set, one distinct public `IssueQuery` per block,
`sql.active_record` counted with `SCHEMA` and cached statements excluded, and a
warm request before each measured one. It now gives the marginal cost per block
as well as the totals, so a reader whose absolute numbers differ can still check
the shape. The "~41 queries a single block costs" sentence is gone. The
query-cache observation is in the dossier too, because it is the honest form of
"the worst case needs six different queries".

---

### F05 — `test_page_should_render_issuequery_blocks_over_a_lowered_maximum` does not discriminate the change, but the dossier lists it as proof

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/functional/my_controller_test.rb:256-273`; the claim is in `dossier.md`'s "Tests" table and in the "Anticipated objections" row about lowered limits
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — labelled as a guard in the dossier, and the discriminating case added as a second test

**What is wrong**

The test sets the limit to 2, gives the user three blocks, and asserts that all
three still render and the "Issues" option is disabled. With
`lib/redmine/my_page.rb` at `origin/master` — the hardcoded 3 — and the setting
merely existing, the assertions all still hold: three blocks render (rendering
never consults the limit) and `3 >= 3` disables the option anyway. So the test
passes identically with and without the feature, and also with the clamp removed.
It is a guard against a future change that would drop blocks, which is a
worthwhile thing to have; it is not evidence that this patch behaves correctly
when the limit is lowered.

**Why a committer would push back**

Not a rejection on its own, but the dossier presents six tests as the proof of
six behaviours and says five of them are red on the old code. In fact this one is
green in every mutation I could construct, which makes the "lowered limit is
safe" row of the objections table rest on the screenshot alone. A test that
cannot fail is a claim, not a proof, and it is better to say so than to have a
reviewer discover it.

**How I verified it**

Four mutations of the worktree, each with the full new test file in place:

    all four production files reverted to origin/master
      -> 62 runs, 347 assertions, 0 failures, 5 errors
         (the dossier's figure exactly; all five errors are
          "RuntimeError: There's no setting named my_page_max_issuequery_blocks")
    only lib/redmine/my_page.rb reverted, setting + view + en.yml kept
      -> 62 runs, 369 assertions, 3 failures, 0 errors
         (enable_below_the_configured_maximum, add_over_the_configured_maximum,
          add_below_the_configured_maximum — all behavioural)
    only the clamp removed from max_occurs
      -> 62 runs, 370 assertions, 1 failure
         (add_..._maximum_set_to_zero_should_allow_one_block — so the clamp *is*
          covered)
    config/settings.yml default changed 3 -> 5
      -> the default guard fails:
         'Expected at least 1 element matching "option[disabled]", found 0'

`test_page_should_render_issuequery_blocks_over_a_lowered_maximum` survives all
four.

**Suggested direction**

Keep it, and label it in the dossier the way the default test is already labelled
— a deliberate guard, green on both sides, and say what change it would catch. If
a discriminating version is wanted as well, the case that separates old from new
is a lowered limit with *fewer* blocks than 3 in use (limit 2 with two blocks:
old code enables the option, new code disables it).

**Resolution:** fixed, 2026-09-05, both ways the finding suggests. The test is
kept and is now labelled in the dossier's test table as a deliberate guard,
green on both sides, with what it would catch; and the discriminating case the
finding describes was added as
`test_page_should_disable_issuequery_option_at_a_lowered_maximum` — limit 2 with
two blocks in use, which the old code leaves enabled. Verified red on the old
code by reverting only `lib/redmine/my_page.rb`.

---

### F06 — `MyPage.max_occurs` is new public API with no unit test, an unguarded `nil` dereference, and a silently changed return type on `MyPage.blocks`

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** backward-compat
- **Where:** `lib/redmine/my_page.rb:68-74`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the lookup is guarded and `test/unit/lib/redmine/my_page_test.rb` covers the five cases

**What is wrong**

Three small things in one method.

`max_occurs(block)` does `blocks[block][:max_occurs]` with no key check, so any
name that is not a block raises `NoMethodError: undefined method '[]' for nil`.
Inside core it is only ever called from `blocks.each`, so it cannot fire; but it
is a public module method now, and its immediate neighbour `find_block` guards
with `blocks.has_key?(name)` for the same lookup. The trap is specific: a caller
who passes a block *id* rather than a block name — `max_occurs('issuequery__1')`,
which is the shape `find_block` accepts — gets the `NoMethodError`.

The non-Symbol branch of the ternary is now unreachable from core: no core block
declares an integer `:max_occurs` any more, and plugin blocks discovered by
`additional_blocks` only ever get `:label` and `:partial`. So the branch exists
purely for a plugin that reopens `CORE_BLOCKS`, and nothing tests it.

Conversely, `Redmine::MyPage.blocks['issuequery'][:max_occurs]` now returns
`:my_page_max_issuequery_blocks` where it returned `3`. The dossier discloses
this, which is the right thing to have done; it is still a behaviour change in a
value plugins can read, and a plugin doing `occurs >= (… [:max_occurs] || 1)`
will raise `ArgumentError: comparison of Integer with Symbol` rather than
misbehave quietly.

**Why a committer would push back**

There is no `test/unit/lib/redmine/my_page_test.rb` in trunk and this patch does
not add one, so the module's one new method is only ever exercised through six
controller tests. A unit test covering integer, symbol, absent, clamped and
unknown-block would be three lines each and would pin the contract that the
"an integer still means what it did" objection-table row promises. It is also
where the `nil` guard question answers itself.

**How I verified it**

    Redmine::MyPage.max_occurs('news')       # => 1
    Redmine::MyPage.max_occurs('nope')       # => NoMethodError: undefined method `[]' for nil
    Redmine::MyPage.blocks['issuequery'][:max_occurs]  # => :my_page_max_issuequery_blocks

run as an integration test in the patch worktree; and
`git grep -l 'CORE_BLOCKS\|max_occurs' origin/master -- app lib test` returns
only `lib/redmine/my_page.rb`, confirming nothing else in core reads it.

**Suggested direction**

Decide whether `max_occurs` is public API or an implementation detail of
`block_options`. If it is public, guard the lookup the way `find_block` does and
add the unit test; if it is not, that is a defensible answer too, and then say so
rather than leaving a bare public `def self.`. Either way the integer branch
deserves the one assertion that proves the compatibility claim.

**Resolution:** fixed, 2026-09-05. `max_occurs` is public API and now behaves
like one: the lookup is `blocks.fetch(block, {})[:max_occurs] || 1`, so a block
id such as `issuequery__1` returns 1 instead of raising `NoMethodError`. The new
`test/unit/lib/redmine/my_page_test.rb` covers the five cases — default,
integer, setting-named, zero, unknown name — including the integer branch that
carries the plugin-compatibility claim. The changed return type of
`MyPage.blocks['issuequery'][:max_occurs]` stays disclosed in the dossier; it is
the price of the feature and there is no way to have both.

---

### F07 — The `config/settings.yml` comment restates the setting's own label

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** minimality
- **Where:** `config/settings.yml:92`
- **Invariant touched:** INV-3
- **Resolution:** fixed 2026-09-05 — the comment is dropped

**What is wrong**

`# Maximum number of issue query blocks on My page` says the same thing as the
key name below it and as `setting_my_page_max_issuequery_blocks` in `en.yml`. It
is the one line in the diff that the feature does not need.

**Why a committer would push back**

They would not, much — the file does carry comments elsewhere
(`# Maximum number of additional email addresses per user`), so this is not
against convention. But all four settings this one is placed among
(`issues_export_limit`, `activity_days_default`, `per_page_options`,
`feeds_limit`) have no comment, and INV-1's line count is easier to defend at
zero unnecessary lines than at one.

**How I verified it**

Read the file at `origin/master`: 32 comment lines, 16 of them the licence
header; the immediate neighbours are uncommented.

**Suggested direction**

Drop it, or keep it and stop counting it — this is a judgement call, not a defect.

**Resolution:** fixed, 2026-09-05 — the comment is dropped. It said what the
key name says, its four neighbours in that file carry none, and INV-1 is easier
to defend at zero unnecessary lines.

---

### F08 — One locale citation in the dossier is off by one line

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** i18n
- **Where:** `dossier.md`, translations table, `en` row
- **Invariant touched:** INV-5
- **Resolution:** fixed 2026-09-05 — the `en` row now cites `en.yml:500`; all fifteen citations re-read against r25037

**What is wrong**

The `en` row cites `setting_gantt_items_limit` at `en.yml:501`. Line 501 is
`setting_gantt_months_limit`; the cited key is at line 500. The quoted text is
correct, so the citation points at the right key by name and the wrong one by
number.

**Why a committer would push back**

They would never see it — this is for whoever re-checks INV-5 in ten minutes'
time. Worth recording only because I checked all 15 citations and this is the
single one that does not land, which is a good ratio and worth saying.

**How I verified it**

Read every cited line out of `git show origin/master:config/locales/<f>.yml`.
14 of 15 exact, including all four of the translated locales; the German pattern
(`setting_diff_max_lines_displayed`, `label_my_queries`, `label_my_page`) checks
out, and the straight double quotes around `"Meine Seite"` match existing de.yml
practice (`label_new_project_issue_tab_enabled: Tab "Neues Ticket" anzeigen`).
`config.i18n.fallbacks = true` in `config/application.rb:60`, so the ~45 locales
that do not get the key fall back to English rather than showing
"translation missing".

**Suggested direction**

Change 501 to 500 when the patch is regenerated for F01 anyway.

**Resolution:** fixed, 2026-09-05. The `en` row now cites `en.yml:500`. All
fifteen citations were re-read against `bee32a926` while the patch was being
refreshed; the other fourteen still land, and the four translated files are
unaffected because their keys are appended at the end.

---

### F09 — Every screenshot shows an *unconfigured* query block, so the feature's actual payload was never seen in a browser

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/mypage-query-blocks/shots/*.png`; `tools/dev-seed.rb`
- **Invariant touched:** none (G9)
- **Resolution:** fixed 2026-09-05 — the verification run creates a public query and points every block at it, so the shots show real issue lists

**What is wrong**

In `fourth-block.png` and `lowered-maximum.png` all four "Issues" blocks are the
`my/blocks/_issue_query_selection` form — a "Custom query" dropdown with nothing
selected and a Save button — not a rendered issue list. The dropdowns look empty,
which fits: `tools/dev-seed.rb` creates projects, users, groups, versions, issues
and wiki pages, but no saved queries at all (`grep -i query tools/dev-seed.rb`
returns nothing). So no run of `verify/mypage-query-blocks.mjs` could ever have
had a query to select.

**Why a committer would push back**

The screenshots do prove what they are captioned as proving — the option state,
the block count, the new field — and for those claims they are fine. But the
picture a reviewer of #27313 actually wants is six issue lists on one page, next
to the sentence about what that costs; and the load argument in the note is about
blocks that run queries, none of which any screenshot shows. It also means the
one visual check that would have caught a mistake in the performance table was
not available.

**How I verified it**

Opened `lowered-maximum.png`, `fourth-block.png`, `select-*.png` and
`before-*.png`; grepped `tools/dev-seed.rb` and `verify/mypage-query-blocks.mjs`
for query creation.

**Suggested direction**

Give the verification run a saved public `IssueQuery` (seeded, or created in the
script) and select it in at least the fourth block, so one "after" shot shows a
real list. That is also the shot worth attaching to the issue. Whether
`tools/dev-seed.rb` grows a query belongs to a framework session, not this one.

**Resolution:** fixed, 2026-09-05, within this feature's own files as the
finding suggests. `verify/mypage-query-blocks.mjs` now creates one public
`IssueQuery` through the UI and points every block at it, in both modes, so the
shots show rendered issue lists instead of empty selection forms. The
before/after pair stays comparable because both runs use the same dev database
and the query is created idempotently. `tools/dev-seed.rb` is unchanged — it is
a framework file, and a query in the seed is a framework session's call.

---

### F10 — No upper bound: 999999 is accepted, and the cost is linear in the number of blocks

- **Status:** resolved
- **Severity:** question
- **Confidence:** confirmed
- **Category:** settings-surface
- **Where:** `config/settings.yml:93-95`; `lib/redmine/my_page.rb:71-73`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — bounded to `0..Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS` (10) per Jan g16b; which number stays an open choice for Jan

**What is wrong — and this is a settled decision, so it is a question for Jan, not a finding against the patch**

`docs/DECISIONS.md` (2026-09-03) settles that the setting gets no upper bound,
with the reasoning that core does not cap `issues_export_limit`,
`gantt_items_limit` or `activity_days_default` either, and the dossier carries
that as an objection with the answer "it is one line in `MyPage.max_occurs` if
you want one". I am not re-litigating it. Two facts to have ready, because
#27313's own description asks for a cap ("certainly with some maximum") and
note-8's author is a core committer:

- the field accepts and stores `999999`, and `max_occurs` returns it, so a user
  can add blocks until they get bored; each block is a real marginal cost (F04:
  ~17 KB of HTML and, on a realistic dataset, tens of SQL queries)
- Redmine does cap this kind of thing elsewhere in exactly this file's
  neighbourhood: `MyHelper#render_timelog_block` clamps its per-block `days`
  setting with `days = 7 if days < 1 || days > 365`. A committer who sees the
  patch clamp the low end (F03) and not the high end may ask why one and not
  both.

**Why a committer would push back**

They may not. But if Go MAEDA or Jean-Philippe Lang asks for a cap, the answer
in the dossier is already the right one, and having the ``timelog`` precedent
to hand — Redmine clamping a My page block setting at both ends, in the same
helper — makes conceding the cap cheap rather than a redesign.

**How I verified it**

Measured input `999999` end to end (see F03's table); read
`app/helpers/my_helper.rb:render_timelog_block` on `origin/master`.

**Suggested direction**

No code change asked for. If Jan wants the note to pre-empt the question, one
sentence citing the `timelog` precedent and offering the one-line cap is stronger
than the current "we did not cap it because core does not cap other things",
because core does cap this one.

**Resolution:** fixed, 2026-09-05 — Jan reopened the settled decision himself
(g16b, 2026-09-04) and chose to bound the setting. It is now
`0..Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS` (10), refused in the form rather
than clamped, and the dossier leads with the `render_timelog_block` precedent
this finding supplied. The remaining judgement — whether 10 is the right ceiling
— is written up as an open choice for Jan in the dossier and in
`docs/DECISIONS.md`; it is one constant either way.

---

## What I checked and found clean

Recorded so an unstated gap is not read as clean, and so the fixing session does
not re-derive it.

- **The default is still 3, and it is locked.** `config/settings.yml` default 3;
  `Setting[...]` returns `"3"`; `max_occurs('issuequery')` returns 3. Changing
  the default to 5 makes
  `test_page_should_disable_issuequery_option_at_the_default_maximum` fail. An
  existing installation upgrades to identical behaviour.
- **No data loss when the limit is lowered.** `max_occurs` is read only by
  `block_options`, which only gates *adding*. `MyHelper#render_blocks`,
  `UserPreference#remove_block` and `UserPreference#order_blocks` never consult
  it, so a persisted `my_page_layout` with five blocks survives a drop to 2
  untouched. Verified in code and by request (F03's second experiment), and
  visible in `lowered-maximum.png` (four blocks, limit 1).
- **Authorization unchanged.** `render_issuequery_block` uses
  `IssueQuery.visible.find_by_id`, and `IssueQuery#base_scope` is
  `Issue.visible.joins(...)`. A raised limit multiplies blocks, not visibility;
  a block whose query stops being visible falls back to the selection form as
  before.
- **Settings tab.** `per_page_options`, `search_results_per_page`,
  `activity_days_default` and `feeds_limit` are all in
  `app/views/settings/_general.html.erb`; the display settings on the Display
  tab are formats and themes, not limits. General is the right tab, and the
  placement after `activity_days_default` mirrors `config/settings.yml`.
- **Input validation, as far as it goes.** `Setting`'s
  `validates_numericality_of :value, :only_integer => true` for `format: int`
  rejects `""`, `"abc"` and `2.9` and leaves the previous value in place. That
  the admin gets no error message for those is pre-existing Redmine behaviour
  for every `int` setting, not something this patch introduced. The 0/negative
  case is F03.
- **Test conventions.** `user.pref.my_page_layout = {...}; user.pref.save!`,
  `assert_select '#block-select'`, `assert_include ... User.find(2).pref[:my_page_layout]['top']`
  and `with_settings` all match what `my_controller_test.rb` already does on
  `origin/master`. No new fixtures, no records generated in a loop, no global
  state left behind, no `minitest/autorun`, no constants, nothing loaded outside
  the autoloader. The four touched suites run clean together in one process.
- **RuboCop.** 0 offences on the two changed Ruby files; `config/settings.yml`
  and the `.erb` are outside RuboCop's scope.
- **INV-4.** No attribution trailer, session link, model name or "generated by"
  in either commit or either patch file.
- **INV-10.** The production diff of `198cbfb63` (`7.0-stable-GEOxyz`) is
  identical to `ec6466159`'s, apart from commit metadata, an extra and
  appropriate paragraph in the GEOxyz commit message, and an `en.yml` hunk
  offset (465 vs 467). Verified by diffing the two `git show` outputs.
- **Feature scope.** One change, one number, one setting. Nothing reformatted,
  nothing renamed, no adjacent tidying. `app/views/settings/_general.html.erb`
  has a pre-existing unclosed `<p>` on the `search_results_per_page` line two
  lines above the insertion — correctly left alone (INV-1), and worth reporting
  here rather than fixing.
- **The split into two patch files** (code + `en.yml`, then `nl/fr/de/es`) is the
  practice `docs/redmine-requirements.md` already establishes and matches how
  trunk's history handles translations. Not a finding.
