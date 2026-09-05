# Review run — 2026-09-03 — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `patch/webhook-tracker-filter` at `90d3f6775` against `origin/master` `bee32a926` (merge base `2563fa6a5`)
- **Dossier read:** `docs/features/webhook-tracker-filter/dossier.md` — yes
- **Status read:** `docs/features/webhook-tracker-filter/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes — `test/unit` + `test/functional` on the patch branch in a throwaway PostgreSQL worktree: **4882 runs, 24637 assertions, 19 failures, 1 error, 84 skips**. The 20 named failures/errors are byte-identical to a pristine `origin/master` baseline run of the same three files (`RepositoriesControllerTest`, `SysControllerTest`, `UserTest#test_destroy_should_nullify_changesets` — all need `svn`/`hg`, which this image does not have). The webhook suites alone: **66 runs, 245 assertions, 0 failures**. RuboCop on the five changed/added Ruby files: **0 offences**.
- **Scope covered:** minimality; scope; settings surface; conventions of the touched files; backward compatibility (empty / nil / string-vs-integer ids, verified by experiment); DB portability of the migration (schema compared column by column against `projects_webhooks` in a real PostgreSQL database); performance of `hooks_for` (query counting with and without the `preload`); authorization of the controller and the tracker list; escaping in the form; i18n (every derivation in the dossier's table checked against the real key in the real file, on both the merge base and current trunk); tests as code (four mutation experiments); test pollution (whole `test/unit` + `test/functional` in one process); patch application (`git am`, `git am -3`, `patch -p1`) onto current trunk; the G9 screenshots (read, not just counted).
- **Scope NOT covered:** system tests (`test/system`) were not run — no Chrome in this reviewer's setup and the patch adds no JavaScript. `test/integration` and `test/api` were not run. MySQL and SQLite were not exercised; only PostgreSQL. The GEOxyz branch (`7.0-stable-GEOxyz`, G8) was not reviewed — I looked only at the trunk patch. I did not re-run the live verification (`verify/webhook-tracker-filter.mjs`); I read the committed screenshots instead.

## Summary

This is a good patch and most of it would survive a committer's reading unchanged. The feature is one idea, the code is one predicate and one association, the migration is byte-for-byte the shape of the join table the webhook feature already created, and the form fieldset is very nearly a copy of `custom_fields/_visibility_by_tracker_selector`. The central backward-compatibility claim — "no tracker selected means every tracker" — is not just asserted, it is genuinely nailed down: when I deleted the `tracker_ids.blank? ||` guard, **seven** tests went red, six of them pre-existing trunk tests, which is much stronger evidence than the dossier itself claims. Every clause of `matches_tracker?` is load-bearing under mutation, and only `Issue` responds to `tracker_id` among the five webhookable models, exactly as the dossier says. Query counting confirms the N+1 is real (20 hooks: 21 queries without the preload, 2 with it).

Two things would send it back. First, the patch is made against a trunk revision that is now about a month and eighty commits old, and **neither patch file applies to current `origin/master` with `git am`** — the feature patch collides with #44386, which the dossier explicitly claims it does not collide with, and the locales patch collides with the French translation update #44323. `patch -p1` still applies it with fuzz, so a committer would probably get there, but the dossier's own claim is now false and that is the sort of thing that costs credibility on an issue tracker. Second, `Tracker` does not get the inverse `has_and_belongs_to_many :webhooks` that `Project` has on trunk, so deleting a tracker leaves its join rows behind and silently turns a hook that was restricted to that one tracker into a hook that fires for **every** tracker — the opposite of what the feature exists to do. I confirmed both by experiment.

Everything else is small: a handful of dossier statements that no longer match trunk, two behaviours (clearing a selection, the edit form pre-checking) that the screenshots cover but the suite does not, and one design consequence — an issue that moves out of a selected tracker produces no update event, so the receiver's copy goes quietly stale — that deserves a sentence in the issue text rather than a code change.

**Counts:** blocker 0 · major 2 · minor 5 · nit 2 · question 2

**Lines in the diff not strictly required by the feature:** 1 — the `preload(:trackers)` line in `hooks_for`. I would not remove it: the feature itself is what introduces the N+1, so fixing it in the same patch is the defensible choice, and the dossier argues that well. Everything else in the 76 added lines is the feature, its tests, or the one new locale key.

---

### F01 — Neither patch file applies to current trunk; the dossier's "#44386 does not conflict" claim is false

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `patches/webhook-tracker-filter/2026-09-03-r24882-feature.patch`, `patches/webhook-tracker-filter/2026-09-03-r24882-locales.patch`; the hunk at `app/models/webhook.rb:118`
- **Invariant touched:** INV-2 (every patch applies standalone to a fresh `origin/master`), G6
- **Resolution:** fixed 2026-09-05 (g05) — branch recreated from `origin/master` r25037 and both files re-exported; `git am` applies each on its own, and the dossier's "#44386 does not conflict" claim is replaced by what actually happened

**What is wrong**

The branch was cut from `2563fa6a5` (r24882, 2026-08-03). `origin/master` in this repository is now `bee32a926`, eighty-odd commits later, and two of those commits are `790b2de58` and `219546baa` — the two halves of #44386 — which rewrote `Webhook#setable_projects` and the `before_validation` lambda. The dossier says (Trunk check, point 2, and again under Anticipated objections): *"This patch does not touch either, so it rebases without conflict."* That reasoning is right about *which lines the patch changes* and wrong about *which lines the patch quotes*: the new `matches_tracker?` method is inserted immediately above `def setable_projects`, so `setable_projects`' old body sits in the hunk's three lines of trailing context. On current trunk that context no longer matches. Separately, the locales patch quotes the English `webhook_url_info` / `webhook_secret_info_html` block in `fr.yml`, which the French team translated in `890812e49` (#44323), so that file's hunk fails too.

**Why a committer would push back**

A committer downloads the two attachments and applies them. With git tooling they get, verbatim:

```
$ git am 2026-09-03-r24882-feature.patch
error: patch failed: app/models/webhook.rb:118
error: app/models/webhook.rb: patch does not apply
$ git am 2026-09-03-r24882-locales.patch
error: patch failed: config/locales/fr.yml:1508
error: config/locales/fr.yml: patch does not apply
```

They will get it in eventually — `patch -p1` succeeds ("Hunk #2 succeeded at 122 with fuzz 1 (offset 3 lines)") and `git am -3` succeeds — but the issue text will be claiming, in writing, that a specific recent commit by the very committer likely to read it does not conflict, while their tool says otherwise. That is a bad first impression for a patch whose whole pitch is "I did the rebase Holger Just asked for".

**How I verified it**

Throwaway worktree at `bee32a926`, four runs:

- `git am <feature>` → fails at `app/models/webhook.rb:118` (exit 128)
- `git am <locales>` → fails at `config/locales/fr.yml:1508` (exit 128)
- `git am -3 <feature>` → succeeds (falls back to a three-way merge of `app/models/webhook.rb` and `config/locales/en.yml`)
- `patch -p1 --dry-run --verbose <feature>` → all hunks succeed, one with fuzz 1

and `git diff 2563fa6a5..origin/master -- app/models/webhook.rb` shows exactly the `setable_projects` rewrite that breaks the context. I also confirmed the two webhook patches do **not** stack badly on each other: with `git am -3`, `webhook-tracker-filter` followed by `webhook-issue-closed` applies cleanly, even though both touch `config/locales/en.yml` within three lines of each other and both touch `test/unit/webhook_test.rb`.

**Suggested direction**

Recreate the branch from a freshly fetched `origin/master` and re-export, then re-run the gates on the new base — the framework already prescribes exactly this (`git fetch origin master` before `git worktree add`). While re-basing, the French half of the dossier's translation argument needs revisiting too (see F03 and F04). Whatever revision is finally used, the dossier's "Made against" line and the `#44386` objection row should be rewritten against it rather than left describing r24882.

**Resolution:** fixed, 2026-09-05, per g05. The branch was recreated from a
freshly fetched `origin/master` (`bee32a926`, r25037, 2026-09-03 — 88 commits on
from the old base) and both patch files were re-exported against it, so `git am`
now applies each of them on its own onto a pristine trunk checkout. The two
collisions this finding named are gone with it: r25011 (#44386) is in the base,
and the French half of the locales patch is written against the translated
`fr.yml` from `890812e49` (#44323) instead of the English block it replaced. The
dossier's Trunk-check point 2 no longer claims "does not conflict"; it states
plainly that the old claim was about the lines the patch *changes* while `git am`
reads the lines it *quotes*, and that `matches_tracker?` is inserted directly
above `def setable_projects`, whose old body sat in the trailing context. Every
evidence figure was re-run against the new base in the same pass (g10).

---

### F02 — `Tracker` never gets the inverse association, so deleting a tracker silently un-restricts every hook that used it

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/models/webhook.rb:93` (the new `has_and_belongs_to_many :trackers`); the missing counterpart in `app/models/tracker.rb`
- **Invariant touched:** none (but it breaks the symmetry the dossier's whole design argument rests on)
- **Resolution:** fixed 2026-09-05 (Jan g07) — `Tracker` gets the mirror `has_and_belongs_to_many :webhooks`, with a test that the join rows go and the surviving restriction stays; that a hook left with no tracker is back to "every tracker" is now written into the dossier, and is K-11 for Jan

**What is wrong**

Trunk's `Project` declares `has_and_belongs_to_many :webhooks` (`app/models/project.rb:63`). That declaration is what makes Rails delete a project's `projects_webhooks` rows when the project is destroyed. The patch adds `has_and_belongs_to_many :trackers` on `Webhook` but does not add the mirror-image `has_and_belongs_to_many :webhooks` on `Tracker`, so a destroyed tracker leaves its `trackers_webhooks` rows behind. The rows themselves are only litter; the behaviour change is not. `tracker_ids` reads through an inner join to `trackers`, so a hook whose only selected tracker has been deleted reports an **empty** selection — and empty means "every tracker".

**Why a committer would push back**

Concrete path, all of it inside one Redmine installation:

1. An admin creates a tracker `Integration`, and a user restricts a webhook to it so that only those issues leave the installation.
2. The tracker turns out not to be needed and, because no issue uses it, `Tracker#check_integrity` permits it and the admin deletes it in Administration → Trackers.
3. The hook now has an orphan row, `tracker_ids == []`, and fires for **every** issue in its projects. Every issue's subject, description, journal notes and custom fields now go to that endpoint.

The form gives no warning: it shows nothing checked, and the new hint says in so many words that nothing checked means every tracker. So the UI is telling the truth about a state the user never chose. The dossier's stated reason for the feature is precisely that "the endpoint sees issue data it has no reason to see", which makes a path that silently re-widens the endpoint the worst possible failure mode for it, and it is the first thing a reviewer who knows this codebase will check, because `Project` already does it right two lines up.

**How I verified it**

In a patched worktree against a real PostgreSQL database:

```
before destroy: tracker_ids=[6]
join rows=1
tracker destroyed=true
orphan join rows remaining=1
after destroy: tracker_ids=[] matches(issue1)=true
hooks_for issue.created issue1 => [54]   (the hook, which had been restricted to the deleted tracker)
Project reflects webhooks? #<...HasAndBelongsToManyReflection ... @name=:webhooks ...>
Tracker reflects webhooks? nil
```

and the mirror experiment on pristine trunk, to show the project side does clean up:

```
join rows before project destroy: 1
project destroyed=true
join rows after project destroy: 0
```

**Suggested direction**

Whatever is done should make tracker deletion and project deletion behave the same way, since "it mirrors `projects_webhooks` exactly" is the argument the migration and the whole design lean on. The design question the fixing session owns is whether "tracker deleted" should mean the hook keeps its remaining restrictions (with the row gone), or whether a hook left with an empty selection after a deletion is itself something to surface. Whichever is chosen, a test that destroys a tracker and then asserts what `hooks_for` returns is what pins it, and one sentence in the dossier makes it a considered position rather than an oversight.

**Resolution:** fixed, 2026-09-05, per Jan's g07. `Tracker` now declares
`has_and_belongs_to_many :webhooks`, the mirror of the line `Project` carries at
`app/models/project.rb:63`, so a destroyed tracker takes its `trackers_webhooks`
rows with it instead of leaving them behind.
`WebhookTest#test_should_drop_the_reference_to_a_tracker_that_is_destroyed`
pins it: it selects two trackers on a hook, destroys one, and asserts both that
`SELECT 1 FROM trackers_webhooks WHERE tracker_id = <destroyed>` comes back
`nil` and that the hook still fires for the surviving tracker and not for the
other one. Without the new line the test fails with `Expected 1 to be nil`,
which is the orphan row this finding describes.

What that does **not** change, stated plainly because the finding's headline is
wider than the fix: a hook whose *only* tracker is destroyed is left with an
empty selection, and an empty selection still means every tracker. The
association removes the litter, not that rule. It is written into the dossier
twice now — in the behaviour list under "Proposed change" and as its own row in
the objections table — with the reasoning: no issue can carry the destroyed
tracker any more, so what widens is the rest of the project's issues, and
blocking the deletion while a hook still points at the tracker belongs in
`Tracker#check_integrity` as a separate change. Whether to go that far is
**K-11** in `docs/DECISIONS.md`; we shipped the documented behaviour because it
is the one a committer will read as consistent.

---

### F03 — The French "one word could not be derived" caveat is factually wrong

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** i18n
- **Where:** `docs/features/webhook-tracker-filter/dossier.md`, the `fr` row of the translation table; `docs/features/webhook-tracker-filter/decisions.md`
- **Invariant touched:** INV-5 (the rule that every term names an existing key in the same file)
- **Resolution:** fixed 2026-09-05 — the `fr` row derives *événements* from `label_webhook_events` and from the translated `webhook_url_info` on the same form; the wrong bullet in `decisions.md` is marked withdrawn rather than deleted

**What is wrong**

The dossier says, in bold: *"**One word is not derived:** `fr.yml` contains no occurrence of *événement* anywhere, so there is nothing to pattern it on."* `fr.yml` contains it in at least two keys at the very revision the patch was made against, and in four on current trunk. The translated string itself is fine — this is a wrong justification for a right sentence, not a wrong sentence.

**Why a committer would push back**

A committer will not read this dossier; Jan will, and so will the next session. INV-5's entire safety mechanism is "name the key so anyone can check it in seconds". A cited-but-false exception is worse than no exception, because it teaches the next reader that the table's other rows were checked with the same care. Concretely: the table's own claimed gap can be closed by `label_user_mail_option_all` (fr: *"Pour tous les événements de tous mes projets"*), which was present at `2563fa6a5`, and on current trunk by `label_webhook_events: Événements` and the now-translated `webhook_url_info` (*"un des événements sélectionnés"*) — a source key sitting on the same screen as the new hint, which is the strongest possible derivation.

**How I verified it**

```
$ git show 2563fa6a5:config/locales/fr.yml | grep -n "événement"
866:  label_user_mail_option_all: "Pour tous les événements de tous mes projets"
867:  label_user_mail_option_selected: "Pour tous les événements des projets sélectionnés..."
$ git show origin/master:config/locales/fr.yml | grep -n "webhook"
1497:  label_webhook_events: Événements
1498:  webhook_url_info: Redmine enverra une requête POST à cette URL chaque fois qu'un des
       événements sélectionnés se produit dans un des projets sélectionnés.
```

For the record, every other derivation in the table does check out against the real file. I verified each cited key exists and says what the dossier says it says: `nl` `field_is_for_all`, `label_user_mail_option_all`, `text_select_mail_notifications`, `text_user_mail_option`, and the claim that `nl.yml` has no "aanvinken"/"vinkje" (true); `fr` `label_issue: Demande`, `label_tracker_all: Tous les trackers`, `error_no_tracker_allowed_for_new_issue_in_project`, and the missing accent in `text_issues_destroy_confirmation` (true); `de` `label_issue: Ticket`, `label_tracker_plural: Tracker`, `field_is_for_all`; `es` `label_issue_plural: Peticiones`, `label_tracker: Tipo`, `label_tracker_plural: Tipos de peticiones`, `label_tracker_all: Todos los tipos`, `label_none: ninguno`, `notice_email_sent`. The Spanish *tipo*/*tracker* point is real and `shots/hint-es.png` shows the legend "Tipos de peticiones" over a hint that says "los tipos", which is exactly the agreement the dossier claims.

**Suggested direction**

Correct the row to name the key, and drop the "one word is not derived" framing along with the matching bullet in `decisions.md`.

**Resolution:** fixed, 2026-09-05. The claim was simply false and it is gone.
The `fr` row of the translation table now derives *événements* from
`label_webhook_events: Événements` and from the French `webhook_url_info`
("chaque fois qu'un des événements sélectionnés se produit"), both translated in
#44323 and both printed on the very form this hint sits on — as this finding
points out, the strongest derivation available. The matching bullet in
`decisions.md` is marked withdrawn rather than deleted, with the two keys named,
so the next reader sees the correction and not a silently improved table. The
sentence about `text_issues_destroy_confirmation`'s missing accent was checked
again and kept; that part was right.

---

### F04 — The dossier's "the sibling hints are still English" note, and the K-08 rationale, are out of date for French

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/webhook-tracker-filter/dossier.md`, the "Honest note on `nl`, `fr` and `es`" paragraph and the last row of the objections table
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the note now covers `nl` and `es` only, says `fr` is fully translated since #44323, and `shots/webhook-form-fr.png` was retaken against r25037

**What is wrong**

The dossier tells a reviewer that on `nl`, `fr` and `es` the new hint will sit next to two untranslated English hints, and offers that as the honest cost of shipping four translations. On current trunk this is true for `nl` and `es` and **false for `fr`**: `890812e49` (#44323, the French translation update) translated `webhook_url_info`, `webhook_secret_info_html`, `label_webhook_events` and the three `webhook_event_*` keys. `shots/webhook-form-fr.png` therefore no longer shows what trunk would show.

**Why a committer would push back**

This one actually helps the patch, which is why it is worth fixing rather than leaving: the French hint now lands in a fully French block, which removes the only stated objection to including it, and the newly translated `webhook_url_info` is a better derivation source than anything the table cites. Left as it is, the dossier under-sells its own strongest locale and shows a screenshot a reviewer could contradict by opening trunk.

**How I verified it**

`git show origin/master:config/locales/fr.yml | grep -n webhook` (output quoted under F03) against `git show 2563fa6a5:config/locales/fr.yml | grep -n webhook`, which shows the same keys still in English at the merge base. The same grep on `nl.yml` and `es.yml` confirms both are still English on current trunk, so the note remains correct for those two.

**Suggested direction**

Re-read the three locale files at whatever revision the patch is finally rebased onto, redo the affected screenshot, and narrow the note to the locales it still applies to.

**Resolution:** fixed, 2026-09-05. The paragraph now reads "Honest note on `nl`
and `es`" and says that `de.yml` and, since #44323 (`890812e49`), `fr.yml` carry
the whole webhook block translated, so in those two the new hint lands in a
fully translated fieldset — French being the strongest locale of the four rather
than one of the weak ones. Re-checked at r25037: `nl.yml` and `es.yml` still
have `webhook_url_info` and `webhook_secret_info_html` in English, so the note
is true for exactly those two. `shots/webhook-form-fr.png` was retaken against
r25037 in the G9 re-run, so the screenshot shows the French page a reviewer
would actually see.

---

### F05 — The N+1 figures in the dossier do not reproduce, and the preload costs one query in the common case

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** performance
- **Where:** `docs/features/webhook-tracker-filter/dossier.md`, the N+1 measurement table; `app/models/webhook.rb:129`
- **Invariant touched:** INV-8 (figures, not claims)
- **Resolution:** fixed 2026-09-05 — the table is replaced by numbers taken on the rebased tree (1/5/20 hooks: 4 queries with the preload, 4/8/23 without), and the row where the preload costs a query instead of saving one is now in the objections table

**What is wrong**

The dossier's table reads: 5 matching hooks → 5 queries with the preload and 8 without; 20 → 5 and 23. Those numbers are not self-consistent (8 − 5 = 3 extra queries for 5 hooks is not "one per hook") and I could not reproduce them. Counting `sql.active_record` notifications around a warmed `Webhook.hooks_for` call, the real shape is one extra query per *matching* hook, and the preload flattens it to a constant. The conclusion the dossier draws is correct; the arithmetic behind it is not, and the framework treats the numbers themselves as the evidence.

**Why a committer would push back**

They would not — no committer will see this table. It matters because INV-8 exists to stop a later session from trusting a figure that was never really measured, and because the honest numbers are *better* than the printed ones for the low-hook case and slightly worse for one case the dossier does not mention: when hooks exist in the project but none of them subscribes to the event being fired, the preload runs anyway and costs one query that the old code did not spend (measured: 2 queries with the preload, 1 without, for 20 hooks all subscribed to `news.created` while an `issue.created` event fires). Since a real installation usually has one or two hooks per project, that case is not rare. It is still clearly the right trade — a single fixed query against an unbounded one-per-hook — but the objections table's "One extra query in total, not one per hook" is only the good half of the story.

**How I verified it**

Patched worktree, real database, `ActiveSupport::Notifications` on `sql.active_record` with schema and transaction statements filtered out, caches warmed by an identical call first:

| matching hooks | with `preload(:trackers)` | without |
|---|---|---|
| 1 | 2 | 2 |
| 5 | 2 | 6 |
| 20 | 2 | 21 |
| 20, each with a tracker selected | 3 | 21 |
| 20 subscribed to `news.created`, firing `issue.created` | 2 | 1 |

The "without" column was produced by deleting only the `.preload(:trackers)` line from the same tree and re-running the same script.

**Suggested direction**

Replace the table with numbers that were actually taken, and add the "no hook subscribes to this event" row so the trade-off is stated in full rather than only where it wins.

**Resolution:** fixed, 2026-09-05. The printed table was replaced by numbers
taken on the rebased tree, by counting `sql.active_record` notifications around
a warmed `Webhook.hooks_for` with `SCHEMA`/`TRANSACTION` filtered out, and the
"without" column by deleting only the `.preload(:trackers)` line from the same
tree and re-running the same script:

| matching hooks | with `preload(:trackers)` | without |
|---|---|---|
| 1 | 4 | 4 |
| 5 | 4 | 8 |
| 20 | 4 | 23 |
| 20, each with a tracker selected | 5 | 23 |
| 20 subscribed to `news.created`, firing `issue.created` | 2 | 1 |

These are self-consistent in a way the old ones were not: three queries are the
constant part (the hook query plus the `visible?` and `allowed_to?` lookups),
the preload adds exactly one — two when there is anything in the join table to
load — and without it the association costs one per *matching* hook. The counts
are three higher than the ones in this finding because that measurement filtered
more aggressively; the differences are identical.

The last row is the one the finding asked to have stated, and it is now in the
dossier's objections row for performance rather than only in the evidence
block: where hooks exist but none subscribes to the event being fired, the
`select` block short-circuits on the event list, nothing ever asks for the
trackers, and the preload has spent a query trunk did not. That is the price of
a fixed query instead of an unbounded one.

---

### F06 — Nothing tests that unchecking every tracker clears the selection, or that the edit form pre-checks it

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/functional/webhooks_controller_test.rb:74-90`; `app/views/webhooks/_form.html.erb:48` (the blank `hidden_field_tag`)
- **Resolution:** fixed 2026-09-05 — three functional tests: the edit form's checked boxes and the blank sentinel, clearing a selection through the sentinel, and a forged id; deleting the `hidden_field_tag` now reddens one test where it used to stay green

**What is wrong**

Two behaviours the feature depends on are covered only by screenshots. The first is the blank `hidden_field_tag('webhook[tracker_ids][]', '', :id => nil)`: without it, a form on which the user unchecks every tracker submits no `tracker_ids` key at all, `webhook_params` therefore contains none, and `update` leaves the previous selection in place — the user's "send this for every tracker again" is silently ignored. The second is that the edit form checks the boxes for the trackers already stored. The two controller tests that exist cover creation with trackers and the presence of three check boxes on `new`.

**Why a committer would push back**

They probably would not comment on it, but the framework's own G3 is about the suite proving the feature rather than the author's memory of it, and this is exactly the sort of one-line view element that a later refactor removes without noticing. `webhook-form-edit-none.png` proves it works today; nothing prevents it from breaking tomorrow.

**How I verified it**

Deleted the `hidden_field_tag` line for `tracker_ids` from `_form.html.erb` and ran both webhook test files together: **42 runs, 151 assertions, 0 failures, 0 errors** — fully green with the sentinel gone. For contrast, the four mutations of the model and controller code are all caught: removing `hook.matches_tracker?(object)` from `hooks_for` reddens 2 tests; removing the `tracker_ids.blank? ||` guard reddens 7 (including six pre-existing trunk tests); removing the `!object.respond_to?(:tracker_id) ||` guard errors the News test; removing `tracker_ids: []` from the strong parameters reddens the create test. So the gap is specifically in the form's round-trip, not in the logic.

A smaller point in the same area: the three tracker tests rely on issue 1 and issue 2 having different trackers (they are 1 and 2 — I checked) without saying so. If a fixture change ever made them equal, `test_should_not_find_hook_for_issue_of_a_tracker_that_is_not_selected` would fail loudly, which is the safe direction, so this is a readability nit rather than a hole.

**Suggested direction**

A functional test that updates a hook which has trackers, posting the blank sentinel and nothing else, and asserts the selection came back empty, would pin both the sentinel and "empty means all" at the HTTP level. An `assert_select` on `edit` for the checked box would pin the round-trip.

**Resolution:** fixed, 2026-09-05. Three functional tests close the gap:

- `test_edit_should_check_the_boxes_of_the_selected_trackers` asserts the stored
  tracker comes back checked, the others do not, and — the sentinel — that
  `input[type=hidden][name="webhook[tracker_ids][]"][value=""]` is on the page.
  Running this finding's own mutation (deleting the `hidden_field_tag` line from
  `_form.html.erb`) now gives **1 failure** where it gave a green run before:
  `Expected at least 1 element matching "input[type=hidden]…", found 0`.
- `test_should_clear_the_trackers_of_a_webhook` posts the sentinel and nothing
  else to a hook that has a tracker and asserts the selection comes back empty,
  which pins the controller half at the HTTP level.
- `test_should_ignore_a_tracker_id_that_does_not_exist` came out of g16d and
  covers the same round trip with a forged value.

The readability point about issues 1 and 2 having different trackers was left
as it is, for the reason this finding gives: if a fixture change made them
equal, the test fails loudly.

---

### F07 — The Trackers fieldset is offered on hooks that subscribe to no issue event, where it does nothing

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** ui
- **Where:** `app/views/webhooks/_form.html.erb:43-50`
- **Resolution:** answered 2026-09-05 — the fieldset stays unconditional and the trade-off (JavaScript, or a server-side condition that is stale between saves) is a row in the objections table

**What is wrong**

The fieldset renders unconditionally. A hook that subscribes only to `news.created` and `version.updated` still gets a Trackers box with a check box per tracker, and any selection made there has no effect whatsoever — `matches_tracker?` returns `true` for every object that does not respond to `tracker_id`, which is the correct behaviour and the reason the box is inert.

**Why a committer would push back**

The patch-review checklist's SCM rule states the general principle: the UI must not offer a control where it does nothing. A user who ticks Bug on a news-only hook has expressed an intention the system will not honour and will not warn about. The hint underneath does say "Issue events are only sent for the selected trackers", which is the mitigation, and it is placed where the user will read it — so this is a discussion point rather than a defect.

**How I verified it**

Read `_form.html.erb` (no condition around the fieldset) and confirmed against `shots/webhook-form.png`: the New webhook form shows the Trackers box with no event checked at all. The inertness itself is proven by `test_should_find_hook_for_object_without_a_tracker_when_trackers_are_selected` and by my own probe showing only `Issue` responds to `tracker_id` among the five webhookable models.

**Suggested direction**

The honest options are: leave it and say so in the issue text (hiding it needs JavaScript, which the patch deliberately avoids everywhere else); or make the fieldset's presence depend on the hook's stored events, which is server-side only and therefore stale between saves. Both are defensible; what is not defensible is having no position when a reviewer asks. This belongs in the anticipated-objections table either way.

**Resolution:** answered, not changed, 2026-09-05. The fieldset stays
unconditional and the position is now written down where a reviewer will meet
it, as its own row in the objections table: hiding it needs JavaScript, which
this patch avoids everywhere else, and deriving it server-side from the stored
events is stale between saves — a user who ticks an issue event would have to
save twice to be offered the trackers. The hint under the fieldset already says
the box applies to issue events. The row ends by naming the alternative and its
size ("a view-only change"), so a committer who wants it conditional can ask for
it without re-deriving the trade-off. Also recorded as a Class A decision in
`decisions.md`.

---

### F08 — The tracker list is not scoped to the user, while the projects list next to it is

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** security
- **Where:** `app/views/webhooks/_form.html.erb:45`
- **Resolution:** answered 2026-09-05 — `Tracker.sorted` stays; the dossier now carries the precedent (`ProjectsController` on a non-admin screen) and the reason it is harmless (the filter only narrows)

**What is wrong**

The projects fieldset renders `@webhook.setable_projects`, which trunk scopes to `Project.allowed_to(user, :use_webhooks)`. The tracker fieldset renders `Tracker.sorted` — every tracker in the installation. `Tracker.visible(user)` exists in core for exactly this kind of scoping. This is not an admin screen: `WebhooksController` requires `:use_webhooks` granted through any role, and the patch's own test renders the form as `dlopper`, a plain developer.

**Why a committer would push back**

Weakly, if at all, which is why this is a nit rather than a finding with teeth. Tracker names are low-sensitivity, the six views the dossier cites as precedent do the same thing, and — the part that really settles it — `ProjectsController` already hands `Tracker.sorted.to_a` to the project settings screen, which any project manager can reach without being an admin. So the precedent for an unscoped tracker list on a non-admin screen exists in trunk today. Storing a tracker the user cannot see is harmless: the filter only ever narrows, so an unreachable tracker simply never matches.

**How I verified it**

`git grep "Tracker.sorted\|Tracker.visible" origin/master -- app lib` for the precedent list; read `WebhooksController#authorize` (`User.current.allowed_to?(:use_webhooks, nil, global: true)`) and the controller test's `setup`, which grants `:use_webhooks` to the Developer role and signs in as `dlopper`.

**Suggested direction**

If it is left as it is — which I would recommend — the reason is worth one line in the dossier, because "why `Tracker.sorted` and not `Tracker.visible`" is a fair question and the answer (existing non-admin precedent, and the filter can only narrow) is a good one.

**Resolution:** answered, not changed, 2026-09-05, along the line this finding
recommends. `Tracker.sorted` stays, and the dossier now carries the "why not
`Tracker.visible(user)`" row: `ProjectsController` already hands
`Tracker.sorted.to_a` to the project settings screen, which a project manager
reaches without being an admin, five other core tracker check-box lists do the
same, and storing an unreachable tracker is harmless here because the filter
only narrows — a tracker out of reach simply never matches.

---

### F09 — The four-clause condition in `hooks_for` is now a 152-character line

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `app/models/webhook.rb:133`
- **Resolution:** fixed 2026-09-05 — the condition is two lines, cheap checks first, longest line down from 152 to 90 characters; RuboCop unchanged at 0

**What is wrong**

Inserting `hook.matches_tracker?(object) &&` into the existing `select` block puts four independent conditions on one 152-character line.

**Why a committer would push back**

They may not — `_form.html.erb` in the same feature has a 187-character line, RuboCop's `Layout/LineLength` is configured not to complain, and the line was already long before this patch. But the diff makes the line harder to read than it was, and reading order now matters (the dossier argues, correctly, that `matches_tracker?` must come before `object.visible?` so a non-matching tracker skips the visibility lookup), which is precisely the sort of intent that a wrapped condition makes visible and a long line hides.

**How I verified it**

`awk 'length($0)>120'` over the changed files; `rubocop --force-exclusion` on the five Ruby files reports **0 offences**, so this is taste, not a rule.

**Resolution:** fixed, 2026-09-05. The condition is now two lines instead of one
of 152 characters, split so that the ordering the dossier argues for is visible:
the two cheap checks (`events.include?`, `matches_tracker?`) on the first line,
the two that hit the database (`visible?`, `allowed_to?`) on the second. Longest
line in the changed files is now 90 characters. RuboCop is unchanged at 0
offences, as it was before — this was taste, and the split makes the diff read
the way the code runs.

---

### F10 — An issue that moves out of a selected tracker produces no event, so the receiver goes stale

- **Status:** resolved
- **Severity:** question
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/models/webhook.rb:140` (`matches_tracker?` reads the object's current `tracker_id`)
- **Resolution:** named 2026-09-05 (Jan g16f) — a row in the objections table says an issue leaving a selected tracker stops producing events, exactly as an issue leaving a selected project already does; no code change

**What is wrong**

`matches_tracker?` sees only the object as it is now. A hook restricted to Bug is told about an issue while it is a Bug; the moment someone changes that issue's tracker to Feature, the `issue.updated` event no longer matches and no delivery is made. The receiving system keeps a Bug record that Redmine no longer has, and nothing ever tells it otherwise. The same is true in the other direction — an issue that becomes a Bug arrives as `issue.updated` for a system that has never seen it created.

**Why this is a question and not a defect**

Any per-object filter has this property, the project filter that already exists has it too (moving an issue between projects does the same thing), and the alternative — sending an event to a hook that does not want the new tracker so it can learn about a deletion — is a design decision well beyond this patch. So this is not something to fix. It is something to *say*, in the issue text, so that a committer sees it was considered. I raise it as a question because the dossier is otherwise unusually thorough about edge cases and this is the one it does not name.

**How I verified it**

Patched worktree, real database: a hook on `issue.created`/`issue.updated` restricted to tracker 1, and issue 1 (tracker 1):

```
issue 1 tracker=1; hook trackers=[1]
issue.updated before tracker change -> 1 hook(s)
issue tracker now 2
issue.updated after tracker change -> 0 hook(s)
```

**Suggested direction**

For Jan: decide whether one sentence goes into the "Proposed change" section — something to the effect that an issue leaving a selected tracker stops producing events for that hook, exactly as an issue leaving a selected project already does. No code change implied.

**Resolution:** named, not fixed, 2026-09-05, per Jan's g16f. There is a row in
the objections table now: a hook limited to Bug hears about an issue while it is
a Bug and hears nothing once it becomes a Feature, so a receiver's copy can go
stale; the project filter that already exists behaves the same way when an issue
is moved between projects; and fixing it would mean delivering events to a hook
for a tracker its owner deliberately excluded, which is the opposite of the
feature. Inherent to a per-object filter, so it is stated rather than repaired
— which is what this finding asked for.

---

### F11 — A forged `tracker_ids` value produces a 500, not a validation error (settled)

- **Status:** resolved
- **Severity:** question
- **Confidence:** confirmed
- **Category:** security
- **Where:** `app/controllers/webhooks_controller.rb:67`
- **Resolution:** fixed 2026-09-05 (Jan g16d, overturning the settled position) — `Webhook#tracker_ids=` drops unknown ids, so a forged POST no longer 500s; `project_ids` still raises on trunk and the asymmetry is stated in the dossier

**What is wrong**

Nothing new. Rails' `tracker_ids=` writer calls `Tracker.find(ids)`, so an id that does not exist raises `ActiveRecord::RecordNotFound`, and `ApplicationController` has no global rescue for it on this path — the user gets an Internal Server Error. Arbitrary ids therefore **cannot** be stored, which was the question worth asking; the cost is that a hand-crafted POST yields a 500 rather than a form error.

**Why this is a question and not a defect**

`status.md` records this under "Gevonden, bewust niet gerepareerd", with the reasoning that `project_ids` on pristine trunk behaves identically and that closing it only on the new field would be asymmetric. I checked that reasoning and it holds: `hook.project_ids = [999999]` raises the same way on trunk. Per the review rules a settled decision is not a finding, so I am recording it only so the next reader does not re-derive it, and flagging one thing the dossier does not currently say: the *submitted* issue text says nothing about it, so if a committer tries a forged id and gets a 500 they will attribute it to this patch. Half a sentence in the issue ("this mirrors the existing behaviour of `project_ids`") pre-empts that.

**How I verified it**

`hook.tracker_ids = [999999]` in a patched worktree → `ActiveRecord::RecordNotFound: Couldn't find Tracker with 'id'=999999`. I did not re-verify the trunk `project_ids` half; the dossier reports it and it follows from the same Rails writer.

**Resolution:** fixed, 2026-09-05, and the settled position was overturned by
Jan (g16d) rather than left alone. `Webhook#tracker_ids=` now drops ids that do
not exist, so a hand-written POST gets an empty or partial selection instead of
an internal error. Measured on the rebased tree, before and after:
`hook.tracker_ids = [999999]` gave `ActiveRecord::RecordNotFound` and now gives
`[]`, and `WebhooksControllerTest#test_should_ignore_a_tracker_id_that_does_not_exist`
errors with that same exception when the writer is removed.

Overriding an `_ids=` writer to sanitise what it is handed is how core already
takes this kind of input (`Member#role_ids=`, `User#notified_project_ids=`), so
the three lines are idiomatic rather than novel. The asymmetry this finding
warned about is real and is now stated in the dossier instead of avoided:
`hook.project_ids = [999999]` still raises on trunk today — re-measured, it does
— which makes the two fieldsets behave differently until that pre-existing
defect is fixed. Unknown ids are dropped silently rather than reported as a
validation error; the reasoning is in `decisions.md`.

---

## What I checked and found nothing wrong with

Recorded so the fixing session does not spend time re-checking, and so the gaps above are read as gaps rather than as everything I looked at.

- **"Empty means all", for real.** `tracker_ids` on a hook with no rows is `[]`, `blank?` is true, `matches_tracker?` returns `true`, and `hooks_for` returns the hook for issues of every tracker. It cannot be `nil` for a `has_and_belongs_to_many`, and `blank?` covers it anyway. **String versus integer ids do not bite**: Rails' `ids_writer` resolves `['1']` through `Tracker.find` and the reader returns `[1]` as `Integer`, both before and after save, so `include?(object.tracker_id)` compares like with like. Verified by probe on both an unsaved and a reloaded hook.
- **The backward-compatibility test is not vacuous.** `test_should_find_hook_for_issue_of_any_tracker_when_no_tracker_is_selected` passes unchanged on pristine trunk (I copied the four new unit tests onto a clean `origin/master` worktree: three error with `ActiveModel::UnknownAttributeError: unknown attribute 'trackers'`, that one passes). And it is load-bearing: deleting the `tracker_ids.blank? ||` guard turns it red along with six pre-existing trunk tests.
- **The preload does not break on hooks with no trackers** — 20 such hooks, 2 queries, all 20 returned, no error.
- **`respond_to?(:tracker_id)` is the right test.** Of the five `acts_as_webhookable` models, only `Issue` responds to it (`News`, `WikiPage`, `TimeEntry`, `Version` do not, and have no such column) — the dossier's claim, verified.
- **The migration.** `trackers_webhooks` comes out of PostgreSQL with exactly the columns, types, null constraints, implicit `bigint` primary key and two single-column indexes that `projects_webhooks` has. Version `[8.1]` matches the four most recent migrations in trunk. No `frozen_string_literal` comment, matching `CreateWebhooks` and the RuboCop exclusion for `db/**/*.rb`. `db/schema.rb` is gitignored, so its absence from the diff is correct.
- **Escaping.** `tracker.name` goes through `<%= %>`, so it is escaped; nothing new is marked `html_safe`; the one `raw` on the form is pre-existing (`webhook_secret_info_html`).
- **The form follows the closest existing precedent closely** — `custom_fields/_visibility_by_tracker_selector.html.erb` uses the same `fieldset.box`, the same `id="<model>_tracker_ids"`, the same `toggle_checkboxes_link` selector, the same `label_tracker_plural` legend and the same blank `hidden_field_tag`. Inline check boxes on one line match that precedent too, so the layout in `shots/webhook-form.png` is not an oversight.
- **No new setting, route, permission or gem**, and the comment added to `matches_tracker?` documents a non-obvious contract rather than restating code — which is what the two existing method comments in this same file do.
- **Test pollution:** running the whole of `test/unit` and `test/functional` in one process produces the same 20 failures as pristine trunk and no others. (My first run showed a phantom `WebhookTest` failure; it was caused by rows my own N+1 probe had committed to the test database outside a transaction, and it disappeared once I cleaned up. Worth knowing: `rails runner` against the test database leaves `Webhook` rows behind, because webhooks have no fixtures and nothing truncates that table.)
- **The G9 evidence is genuine.** I opened the screenshots. `deliveries-tracker-selected.png` is a real receiver page showing one `issue.created` POST with tracker Bug and a timestamped subject; `hint-es.png` shows the Spanish hint's "los tipos" sitting under Redmine's own "Tipos de peticiones" legend, which is the specific claim the dossier makes about it.
