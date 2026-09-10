# Review run — 2026-09-10 — claude-opus5-round4

- **Reviewer:** Claude Code (Opus 5), round 4 (Deel A of `docs/review/prompt-round4.md`)
- **Reviewed:** `patch/webhook-tracker-filter` at `cb4972a5c` against its base `bee32a926` (r25037), and against real trunk `167e487ee` (r25065) for applicability
- **Dossier read:** `docs/features/webhook-tracker-filter/dossier.md` — yes
- **Status read:** `docs/features/webhook-tracker-filter/status.md` — yes
- **Ran the test suite:** partly — `webhook_test.rb`, `webhooks_controller_test.rb` and `tracker_test.rb` in one process, after migrating the test database for the new join table. Not `test:all`; the r25037 baseline this dossier quotes is the one I measured today for `imap-oauth` on the same revision.
- **Scope covered:** the whole production diff; **the migration compared against Redmine's own join-table conventions, both the 2009 one and the 2025 one this feature sits next to**; the `tracker_ids=` override and the empty-selection path the form actually submits; `Tracker#deactivate_webhooks` and its interaction with `check_integrity` and with HABTM's own join-row cleanup; `matches_tracker?` for an object with no tracker; INV-5 across all five locales with the cited keys looked up by hand; INV-6 for the migration; RuboCop; INV-10 through `tools/check-symmetry.sh`; the twelve new tests read as coverage; the dossier read as a submission.
- **Scope NOT covered:** no `test:all`, no `7.0-stable-GEOxyz` suite for this feature, and no browser. I did not verify the N+1 claim by counting queries; I read the `preload(:trackers)` that removes it.

## Summary

**No findings.** I attacked four things and every one of them was already
answered, in two cases better than I would have answered it.

The migration was my main lead: `create_table :trackers_webhooks` gives a
HABTM join table a surplus `id` column and no composite unique index, which is
not how Redmine's `projects_trackers` was built in 2009 (`:id => false`, plus a
unique index added later). Then I looked at the join table this feature
actually sits beside — `projects_webhooks`, created by trunk's own
`20251007073256_create_webhooks.rb` — and it is `create_table` with a default
`id` and two `index: true` columns, character for character the same shape as
the new one. Copying the migration next door rather than the one from 2009 is
INV-1 read correctly, and it is the answer a committer would want.

The second was the empty selection. The form posts a hidden `''` alongside the
checked ids, so unchecking everything submits `['']`; `tracker_ids=` turns that
into `Tracker.where(id: [nil])`, which selects nothing, which is what "no
tracker selected means every tracker" needs. There is a test for it ("should
clear the trackers of a webhook") and one for the override's other purpose
("should ignore a tracker id that does not exist").

The third was `Tracker#deactivate_webhooks`. It runs after `check_integrity`,
so it only fires for a tracker that can actually be deleted, and it deactivates
exactly the hooks whose selection was that one tracker — because otherwise
HABTM's own join-row cleanup would leave those hooks with an empty selection,
which means *every* tracker, so a hook would widen instead of stopping. That is
Jan's K-11 option C and both directions have a test.

The fourth was the untranslated Dutch and Spanish neighbours: `webhook_url_info`
and `webhook_secret_info_html` are still English in `nl.yml` and `es.yml`, so
this patch's translated hint lands between two English ones. The dossier says
so, in a paragraph headed "Honest note on `nl` and `es`", and its per-word
derivation table takes the vocabulary from mail-notification keys instead of
from the English siblings. The Spanish row is the strongest INV-5 argument I
have read in this register: in `es.yml` a tracker is a **tipo**
(`label_tracker: Tipo`, `label_tracker_plural: Tipos de peticiones`), which I
verified, so a sentence composed from the English would have said "trackers"
and clashed with the fieldset legend printed directly above it.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0. The migration is
the one thing INV-6 puts a burden of proof on, and a many-to-many between two
existing tables cannot be expressed without one.

## Evidence I re-measured

| Claim | What I measured | Same? |
|---|---|---|
| RuboCop on the six changed files: 0 | **0** (rubocop 1.90.0) | yes |
| touched suites green | **66 runs, 213 assertions, 0 failures, 0 errors** (`webhook_test`, `webhooks_controller_test`, `tracker_test`), after `db:migrate` created `trackers_webhooks` | yes |
| `tools/check-symmetry.sh webhook-tracker-filter`: PASS | **PASS**, and its 5 locale keys read the same on both branches | yes |
| `tools/check-patch-clean.sh webhook-tracker-filter --submit`: PASS | **PASS** against real trunk r25065 | yes |
| the migration follows core | **confirmed**: identical in shape to `projects_webhooks` in `20251007073256_create_webhooks.rb` | yes |
| `es.yml` calls a tracker a *tipo* | **confirmed**: `label_tracker: Tipo`, `label_tracker_plural: Tipos de peticiones`, `label_tracker_all: Todos los tipos` | yes |
| `nl.yml`/`es.yml` webhook siblings are untranslated | **confirmed**, and the dossier says so; `fr.yml` and `de.yml` are translated | yes |
| twelve new tests | **twelve** `test "…" do` blocks, in the style `webhook_test.rb` already uses | yes |

## What I attacked and what held

Recorded because a zero-finding review is only worth reading if it says what it
tried.

1. **The join table.** Surplus `id`, no composite unique index, no foreign
   keys — all true, and all true of `projects_webhooks` next to it, which trunk
   itself added ten months ago. Matching the neighbour beats matching the 2009
   table.
2. **A duplicate join row defeating `deactivate_webhooks`.** `hook.tracker_ids
   == [id]` would be false for `[id, id]`, so a hook with a duplicated row
   would not deactivate. Reachable only by direct SQL: `tracker_ids=` assigns
   from `Tracker.where(id: ids)`, which cannot yield duplicates, and the
   surplus-`id` table has no unique constraint to lean on. Same exposure as
   `projects_webhooks`; not this patch's to fix.
3. **The hook left with an empty selection after its last tracker is deleted.**
   It is deactivated, so it does not fire; if an administrator reactivates it,
   it fires for every tracker. That is inherent to "empty means all" and is
   what K-11 option C decided.
4. **An object with no tracker.** `matches_tracker?` short-circuits on
   `!object.respond_to?(:tracker_id)`, and there is a test using `news.created`.

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks.

**Nothing.** This is the second feature in a row where the thing I went looking
for was already answered in the submitted text, and in both cases the answer
was better than my question. Worth naming the pattern the other features could
copy: this dossier derives each translation **word by word**, names the key
each word came from, and flags where it deliberately did *not* copy an existing
string — `fr.yml`'s `text_issues_destroy_confirmation` has *selectionnée*
missing its accent, and the table says so and follows the correctly accented
`text_user_mail_option` instead. Compare `wiki-export-attachments`, where I
filed a nit because the Spanish value cannot be reconstructed from the two keys
its table cites. The difference is not care about Spanish; it is whether the
table records a derivation or a justification.

**One thing I would have raised if the dossier had not.** The "Honest note on
`nl` and `es`" paragraph is exactly the disclosure that stops a reviewer from
reporting a mixed-language form as a defect. It also quietly strengthens the
patch's own offer to let a committer take the feature patch and leave the
locales to the language teams, which is the argument the separate `-locales`
patch file exists for.

**Nothing in `docs/DECISIONS.md` looks wrong to me.** K-11 option C is the only
one of the three options that cannot silently widen a hook's reach, and the
test named after it proves the other direction too.
