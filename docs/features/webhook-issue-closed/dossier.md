# webhook-issue-closed — een apart `issue.closed`-event op de webhook

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** een webhook kan nu aanvinken dat hij alleen
  wil horen wanneer een issue **gesloten** wordt. Vandaag moet een ontvanger op
  "issue gewijzigd" abonneren en daarna zelf uit de journaalregels opmaken of
  dit de sluiting was, dus hij krijgt elke andere wijziging in het project ook
  binnen en gooit die weg.
- **Waar het vandaan komt:** 5.1-commit `25220b45d` ("Feature: webhook"), de
  andere helft daarvan; de eerste helft was `webhook-tracker-filter`. De hele
  webhookfunctie zelf zit inmiddels in Redmine core (#29664), dus van die
  commit blijft alleen dit event over.
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen. De diff op `7.0-stable-GEOxyz` is
  regel voor regel dezelfde als de patch (gecontroleerd, zie "GEOxyz").
- **Kans dat Redmine dit aanneemt:** goed. In **note 36** van #29664 somt Jan
  zijn zes uitbreidingen op en punt 2 is letterlijk *"An option to only trigger
  on issue close."*; **note 37** van Holger Just vraagt om precies dat: die
  monolithische patch opsplitsen in losse, tegen trunk gerebaseerde stukken met
  per stuk de reden erbij. Dit is punt 2, los, tegen r25037. Buiten de tests
  zijn het dertien toegevoegde en twee verwijderde regels over drie bestanden,
  en er komt geen instelling, migratie, gem, route of permissie bij. De patch
  raakt **geen enkel bestand onder `lib/redmine/`**: alles wat issuespecifiek
  is staat in `Issue::Webhookable`.
- **Wat jij nog moet doen:** een nieuw issue op redmine.org aanmaken als
  follow-up van #29664 en de patch eraan hangen. Er staat één keuze voor je
  open (**K-09**, over de vertalingen) die het indienen niet blokkeert.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `bee32a926` = **r25037** van **2026-09-03**. Dat
  is de stand van de mirror in deze fork; Redmine's bron is SVN en de mirror
  loopt achter op de echte trunk. De patch is tegen r25037 gemaakt en dat hoort
  in het issue vermeld te worden. (De eerste versie stond op r24882; op
  2026-09-05 opnieuw op r25037 gezet, 88 commits verder, zonder conflict.)
- **Lost trunk dit al op?** Nee. `Webhook` in trunk kent per model precies drie
  events. `Redmine::Acts::Webhookable#acts_as_webhookable` staat standaard op
  `%w(created updated deleted)` en alle vijf de modellen die het gebruiken
  (`Issue`, `News`, `WikiPage`, `TimeEntry`, `Version`) nemen die standaard
  over. `grep -i closed` op `app/models/webhook*.rb`,
  `lib/redmine/acts/webhookable.rb`, `app/views/webhooks/` en de webhooktests
  geeft **nul** treffers. Er is dus geen enkele manier om alleen op een
  sluiting te abonneren.
- **Bestaand issue op redmine.org?** Niets over dit onderwerp. Gezocht op
  `webhook` (22 issues) en op `webhook event` (10 issues). Wat er wel is:
  - [#29664](https://www.redmine.org/issues/29664) — de webhookfunctie zelf,
    gesloten, target version 7.0.0. Note 36 punt 2 is dit voorstel; note 37 is
    het verzoek om het los in te dienen. Dit issue is de plek om naar te
    verwijzen, maar er kan geen note meer bij die opgepikt wordt: het is
    gesloten en uitgeleverd.
  - [#43889](https://www.redmine.org/issues/43889) — "Webhook is not triggered
    when attachment is deleted via AJAX UI", gesloten. Dat is de reden dat
    `Issue#attachment_removed` in trunk zelf `Webhook.trigger` aanroept, buiten
    `acts_as_webhookable` om. Dat is het precedent waar deze patch op leunt.
  - [#44337](https://www.redmine.org/issues/44337) — "Add an administration
    page listing all webhooks", open. Punt 4 van note 36, een aparte feature.
- **Verandert iets in trunk het ontwerp?** Ja, één ding, en het maakt de patch
  veel kleiner. `acts_as_webhookable` (`d43437161`, 2026-02-22) heeft de
  webhooklaag generiek gemaakt over vijf modeltypes. De 5.1-code hing een
  `trigger_issue_webhooks`-methode met vier eigen `after_*_commit`-callbacks in
  `Issue`; daarvan is niets meer nodig. Wat overblijft is: het event
  registreren en het op één plek afvuren.

---

# The problem

A webhook can subscribe to `issue.created`, `issue.updated` and
`issue.deleted`. There is no way to subscribe to an issue being **closed**,
which is the single transition most receivers are built around: hand the job
back to the ERP, release the invoice, notify the customer, close the ticket in
the other tracker.

To hear about a closing today, a receiver has to subscribe to `issue.updated`
and reconstruct the transition itself. That means:

- **Receiving everything.** Every note, every assignee change, every
  spent-time edit, every attachment added or removed in every subscribed
  project is delivered, and the receiver discards nearly all of it. On a busy
  project that is two orders of magnitude more deliveries than the receiver
  cares about — each one a POST, a retry on failure, and a log line.
- **Reimplementing "closed" outside Redmine.** The payload's journal carries
  `prop_key: "status_id"` with an old and a new value, both numeric ids. To
  decide whether that transition was a closing, the receiver needs to know
  which `IssueStatus` rows have `is_closed` set — which is not in the payload.
  So it has to call the REST API for `/issue_statuses.json`, cache it, and
  invalidate that cache whenever an administrator edits a status. Every
  receiver reimplements the same lookup, and each one gets to be wrong in its
  own way about the cases below.
- **Getting the edge cases wrong.** A closing is not simply "the new status is
  closed". `Closed` → `Rejected` is not a second closing. Reopening and closing
  again is a second closing. An issue created directly in a closed status is a
  closing. A note added to an already-closed issue is not one. Redmine knows
  all of this — `Issue#closing?` is right there — and a receiver outside
  Redmine has to guess it.

# Why this belongs in core

The decision "was this save a closing?" is core's, not a receiver's. Redmine
already answers it internally: `Issue#closing?` and the `update_closed_on`
callback exist so that `closed_on` records the moment of the last closing. The
information needed to answer it — the previous status row and its `is_closed`
flag — is available in core for free and is not in the payload at all.

A plugin cannot add this cleanly. `WebhookPayload.events` is a class-level
registry filled by `acts_as_webhookable` at class-definition time, so a plugin
would have to re-declare `Issue.acts_as_webhookable` after Redmine has already
declared it, which re-registers the model and re-installs the three existing
lifecycle callbacks — the payload test in trunk does exactly this to
`News` and leaves the registry mutated for the rest of the process. It would
also have to add its own commit callback to `Issue`. That is a plugin patching
core's callback chain to add one string to a core list, which is the shape this
patch exists to avoid.

# Proposed change

`Issue` registers a fourth webhook event, `closed`, and fires it once per
closing. Nothing else changes: hooks that do not tick the new box behave
exactly as before, and the other four webhookable models are untouched.

The trigger condition is `saved_change_to_closed_on?`. `closed_on` is written
by exactly one place in core — the `update_closed_on` callback, `if closing?` —
and it is not a safe attribute, so no request can set it. So "this save wrote
`closed_on`" and "this save closed the issue" are the same statement, and the
patch does not need a second definition of closing, an extra query for the
previous status, or an instance variable carried from `before_save` into
`after_commit`.

| File | Change |
|---|---|
| `app/models/issue.rb` | `acts_as_webhookable %w(created updated closed deleted)` — registers the event so it appears on the form and passes `Webhook`'s event validation |
| `app/models/concerns/issue/webhookable.rb` | an `after_save_commit` that triggers `issue.closed` when the save wrote `closed_on`; the existing journal enrichment now also applies to `closed`; `webhook_payload_timestamp` is overridden to map `closed` onto `updated_on` |
| `config/locales/en.yml` | `webhook_event_closed`, next to the three keys it belongs with |
| `test/unit/webhook_test.rb` | eight tests for the transitions, one of them end to end through `WebhookJob` |
| `test/unit/webhook_payload_test.rb` | two tests for the payload |

Outside the tests: **13 insertions, 2 deletions** across three files, one of the
insertions being the locale string and two being comments.

**Nothing under `lib/redmine/` changes.** `closed` is an event only `Issue` can
fire, so the generic layer never learns its name: `Issue::Webhookable` both
triggers it and maps its payload timestamp. That keeps the whole feature inside
the file that exists for issue-specific webhook behaviour.

`Issue` passes the event list explicitly — `acts_as_webhookable %w(created
updated closed deleted)` — where the other four webhookable models take the
`%w(created updated deleted)` default. The trade-off is deliberate and worth
naming: if a later change adds a generic action to that default, `Issue` will
not inherit it. Expressing it as an addition instead would mean exposing the
default from `Redmine::Acts::Webhookable`, which is a change to the generic
layer this patch otherwise leaves alone.

**New setting / migration / gem / route / permission:** none. The event list is
a serialized column that already exists; an existing hook simply does not
contain the new value.

**Translations:** `en.yml` only, and that is deliberate — see the locale
section below.

**Backward compatibility:** nothing changes for an existing installation until
somebody ticks the new box.

- Existing hooks have `events` arrays that do not contain `issue.closed`, so
  `Webhook.hooks_for('issue.closed', issue)` returns none of them and no
  extra delivery is made. There is a test that closes an issue with only
  `issue.closed` subscribed and asserts exactly one job; the mirror case is
  the existing `should validate events` test, which now also round-trips the
  new value.
- `issue.updated` still fires on a closing, unchanged. A receiver that has
  been reconstructing closings from `issue.updated` keeps working and can
  migrate when it wants to.
- The order in which the two events reach the queue is not guaranteed and no
  receiver should depend on it. `after_` callbacks run in inverse
  registration order (the comment above `add_auto_watcher` in `issue.rb` says
  so), so `issue.closed` is currently enqueued first, and delivery is
  asynchronous anyway. **Worth saying out loud for one pair:** on an issue
  created directly in a closed status the queue receives `issue.closed` before
  `issue.created` (measured), so a receiver that creates its local record on
  `issue.created` must tolerate a closing for an issue it has not seen yet.
  For the `issue.updated` / `issue.closed` pair either order is harmless.
- The event is derived from the **last** save in a transaction. If the same
  issue is closed by one save and then saved again inside the same enclosing
  transaction, `after_save_commit` sees only the second save's dirty state, so
  `issue.closed` is not produced while `issue.updated` still is. No path in
  core does this — a single save wrapped in `Issue.transaction` fires both
  events normally, measured — but
  `IssuesController#save_issue_with_child_records` calls
  `controller_issues_edit_after_save` **inside** its `Issue.transaction`, so a
  plugin that re-saves the issue from that hook would lose the closing.
  Carrying the fact across in per-instance state survives it, at the cost of a
  second callback and state to reset; see *Alternatives considered*.

## Which transitions fire, and which do not

Verified case by case, in a test and again in a browser against a running
instance:

| What happens to the issue | `issue.closed` |
|---|---|
| created with an open status | no |
| created directly with a closed status | **yes** |
| open status → closed status | **yes** |
| closed status → a different closed status (`Closed` → `Rejected`) | no |
| closed status → open status (reopened) | no |
| reopened, then closed again | **yes**, a second time |
| note or field edited while closed, status unchanged | no |
| deleted | no |
| copied with "keep status" from a closed issue | **yes**, alongside `issue.created` |
| closed while another issue duplicates it | **yes**, once for each — the duplicate is closed too |

The two rows that are easy to get wrong are rows 4 and 7, and they are the two
that a receiver reconstructing this from `issue.updated` gets wrong first.
"Created directly with a closed status" follows Redmine's own definition:
`Issue#closing?` returns `closed?` for a new record, and `update_closed_on`
therefore stamps `closed_on` on such a create.

The last two rows are the ones a receiver author most wants told in advance,
and both are inherited behaviour rather than anything this patch decides. A
copy taken with "keep status" is a new record in a closed status, so it is a
closing by the same definition as row 2. `Issue#close_duplicates` closes every
duplicate through `update_attribute :status`, which runs callbacks, so **one**
status change in the UI delivers `issue.closed` for N+1 issues — measured:
closing an issue with one duplicate enqueues two `issue.closed` and two
`issue.updated` jobs. `issue.updated` already behaves the same way on both
paths, so neither is a new surprise; they are simply not obvious from the
first eight rows.

# Alternatives considered

**Naming `closed` anywhere in `lib/redmine/acts/webhookable.rb`.** Two places
invited it and both are refused, for one reason: `closed` is not a lifecycle
event, it is a state transition, and the predicate that recognises it exists
only on `Issue`.

The first is the `case` that maps an action name onto a Rails lifecycle
callback — `created`/`updated`/`deleted` onto `after_create_commit`/
`after_update_commit`/`after_destroy_commit`. A `when 'closed'` branch there
would break for any other model that registered `closed` without defining the
predicate. The `case` has no `else`, and trunk's own payload test (`should
generate payload for custom event`, which registers `news.commented`) relies on
that: registering an event without a generic callback is a supported thing to
do. So the event is registered generically and fired from `Issue::Webhookable`,
which is the file that exists for issue-specific webhook behaviour and where
the journal enrichment already lives. `Issue#attachment_removed` in trunk calls
`Webhook.trigger` directly for the same kind of reason — the commit that added
it is "Trigger issue webhook when attachment is deleted via AJAX UI (#43889,
#29664)".

The second is `webhook_payload_timestamp`, whose `case` maps an action name
onto a timestamp and *does* have a working `else`. Adding `when 'updated',
'closed'` there is a one-word change and it works, which is what the first
version of this patch did. It is still the wrong file: it would leave the
generic layer carrying the name of an action only `Issue` can ever fire, and
carrying it for a single fallback — `Issue::Webhookable#webhook_payload`
overwrites the timestamp with the journal's whenever there is one, so the
generic branch is reached only for a closing with no visible journal, i.e. an
issue created directly in a closed status. `Issue::Webhookable` overrides the
method instead. It costs two lines more and leaves `lib/redmine/` untouched.

**Deriving the transition from `status_id` instead of `closed_on`.** The 5.1
implementation did this: `saved_change_to_status_id?`, then
`IssueStatus.find_by(id: saved_change_to_status_id.first)` to see whether the
previous status was closed. It gives the same answer for every row of the table
above, but it costs one extra query per status change into a closed status, it
restates a definition core already has, and it uses a safe-navigation chain on
`status`, which is validated as present. `closed_on` is the value core writes
*because* the issue was closed, so reading it is reading core's own answer.

**Capturing `closing?` in a `before_save` instance variable.** `Issue#closing?`
is the exact predicate, but it reads the dirty state before the save and is
false by the time `after_save_commit` runs. Carrying it across in an ivar works
and is a pattern this model already uses for `@current_journal`, but it is an
extra callback and an extra piece of per-instance state to express something
already recorded in a column.

**A setting to switch the event on.** Rejected on INV-6 grounds and because it
would be a setting for something a check box on the hook already expresses.
Webhooks as a whole are already behind `Setting.webhooks_enabled?`, and that
switch is verified to suppress this event too (screenshot below).

**Leaving it to the receiver.** This is the status quo and it is defensible for
one receiver. It stops being defensible once every receiver has to ship the
same `/issue_statuses.json` cache and the same four edge cases.

**Adding `closed` to `Version` as well.** `Version` has a `closed` status and
could carry the same event. It is not what this patch is for, no GEOxyz use
case asks for it, and it would double the surface under review. If a committer
wants it, the design above generalises: `Version::Webhookable` gains the same
three lines with its own predicate.

# Tests

| Test | What it proves |
|---|---|
| `webhook_test: should enqueue a job for a hook subscribed to issue closed when an issue is closed` | end to end: a hook subscribed **only** to `issue.closed` gets exactly one `WebhookJob`, for the right hook, with `type: issue.closed`, the right issue and the closing note. This is the whole feature in one test |
| `webhook_test: should not trigger issue closed webhook when an issue is created with an open status` | the ordinary create does not fire it. Deliberately pinned rather than left to the end-to-end test's reading of the queue |
| `webhook_test: should trigger issue closed webhook when an issue is created with a closed status` | the create path fires it, matching `Issue#closing?` |
| `webhook_test: should not trigger issue closed webhook when a closed issue moves to another closed status` | `Closed` → `Rejected` is not a second closing, and `issue.updated` still fires |
| `webhook_test: should not trigger issue closed webhook when a closed issue is reopened` | reopening is not a closing |
| `webhook_test: should trigger issue closed webhook again when a reopened issue is closed` | it is not a once-per-issue event |
| `webhook_test: should not trigger issue closed webhook when a closed issue is updated` | editing a closed issue does not re-fire it. This is the regression a naive implementation ships |
| `webhook_test: should not trigger issue closed webhook when a note is added to a closed issue` | the other half of the same row: a note on an already-closed issue is not a closing either. Named in *The problem* as one of the cases receivers get wrong |
| `webhook_payload_test: issue closed payload should contain journal` | the payload carries the closing journal, its notes and its author, and the timestamp is the journal's |
| `webhook_payload_test: issue closed payload should use the issue timestamp when there is no journal` | pins the `webhook_payload_timestamp` override; without it this case returns `Time.now` from the generic `else` |
| `webhook_payload_test: issue closed payload should be correct` | not written here — trunk's existing parametrised loop over `WebhookPayload.events` picks the new event up by itself |
| `webhook_test: should validate events` (existing, unchanged) | the new value round-trips through `Webhook`'s event validation |

**Which rows of the transition table are pinned, and which are not.** Eight of
the ten new tests are transition tests, and they cover seven of the eight rows —
row 7 twice, once for a field edit and once for a note. **One** row has no
dedicated test:

- **"deleted → no"**, and deliberately: the trigger is an `after_save_commit`,
  so a destroy cannot reach it. A test there would assert a property of Rails,
  not of this patch.

Row 1, "created with an open status", has its own test rather than the
incidental coverage it used to have. It was previously caught only as a side
effect of how the end-to-end test read the job queue, which is not a property
worth relying on.

The two rows added to the table for copies and duplicates are inherited
`update_attribute`/`copy_from` behaviour rather than anything the guard
decides, and they are measured in the dossier rather than pinned in a test.

**Evidence (INV-8 — figures, not claims):** all re-run on 2026-09-05 against
trunk **r25037** (`bee32a926`), the revision the patch is now made against.

- **full** suite with the patch:
  `tools/test-env.sh /home/user/wt/patch-webhook-issue-closed bundle exec ruby bin/rails test:all`
  → **5988 runs, 31747 assertions, 27 failures, 2 errors, 92 skips**
- **full** suite on a pristine trunk worktree at the same revision (same
  command, `wt/base`) → **5977 runs, 31708 assertions, 27 failures, 2 errors,
  92 skips**. The eleven extra runs are the ten new tests plus the one the
  existing parametrised payload loop generates for the new event.
- **Failure names compared, not counts, and this time the two sets are
  identical.** Both runs fail the same **29** tests, name for name — the
  `comm` of the two sorted sets is empty in both directions.
  They break down as `RepositoriesControllerTest` (14),
  `Redmine::ApiTest::RepositoriesTest` (8), `SysControllerTest` (5),
  `UserTest#test_destroy_should_nullify_changesets` and
  `Redmine::ApiTest::IssuesTest#test_GET_/issues/:id.xml_should_not_disclose_associated_changesets_from_projects_the_user_has_no_access_to`
  — every one of them needs an SCM binary this container does not have
  (`svn`, `hg`, `bzr`, `cvs` are all absent; only `git` is present). So **the
  patch introduces no failure**, and unlike the r24882 measurement there is no
  flake on either side to explain away.
- webhook suites in one process (`webhook_test`, `webhook_payload_test`,
  `webhooks_controller_test`): **71 runs, 262 assertions, 0 failures, 0
  errors, 0 skips**.
- On `7.0-stable-GEOxyz`, the same three plus Redmine's own locale consistency
  test (`test/unit/lib/redmine/i18n_test.rb`): **110 runs, 1104 assertions,
  0 failures, 0 errors**.
- RuboCop on the changed Ruby files: **0** offences (four files; `en.yml` is
  not Ruby). Baseline on the same four files at the merge base, measured in a
  worktree with the same `Gemfile.lock` so the same cops run: **0**.
- **Red on the old code:** the two test files were copied onto a pristine
  trunk worktree at r25037 and run there — **62 runs, 218 assertions,
  2 failures, 3 errors**. So **5 of the 10 new tests fail** on old code:
  - `issue closed payload should contain journal` and
    `issue closed payload should use the issue timestamp when there is no journal`
    → `ArgumentError: invalid event: issue.closed` (2 of the 3 errors)
  - `should enqueue a job for a hook subscribed to issue closed when an issue is closed`
    → `ActiveRecord::RecordInvalid: Validation failed: Events is invalid`
    (the third error)
  - `should trigger issue closed webhook when an issue is created with a closed status`
    and `should trigger issue closed webhook again when a reopened issue is closed`
    → `expected exactly once, invoked never: Webhook.trigger("issue.closed", …)`
    (the 2 failures)
- **The other five are guards, and they are not idle either.** They are the
  `.never` expectations — created with an open status, closed → another closed
  status, reopened, a field edited while closed, a note added while closed —
  and they are green on old code because the event does not exist there. What
  proves they are load-bearing is a mutation: delete the
  `if saved_change_to_closed_on?` condition and run `webhook_test` →
  **36 runs, 127 assertions, 5 failures, 0 errors**, all five of them. Said
  plainly so nobody mistakes the two halves: five tests prove the new
  behaviour, five protect it.
- **The measurements the dossier's own claims rest on**, taken with a probe in
  the patch worktree that counts `sql.active_record` statements and reads the
  types of the enqueued `WebhookJob`s:
  - queries touching `webhooks` around one `Issue#save`, with zero hooks in the
    table: enabled `closing 2 / non-closing 1`, disabled `0 / 0`
  - one save inside `Issue.transaction` → `["issue.closed", "issue.updated"]`;
    two saves of the same issue inside one transaction →
    `["issue.updated"]`, with `closed_on` set
  - `copy_from(keep_status: true)` of a closed issue →
    `["issue.closed", "issue.created"]`; without `keep_status` →
    `["issue.created"]`, status `New`
  - closing an issue that has one duplicate → two `issue.closed` and two
    `issue.updated`
  - created directly in a closed status → `["issue.closed", "issue.created"]`,
    in that queue order
- patch applies to pristine `origin/master` r25037: **yes** —
  `tools/check-patch-clean.sh webhook-issue-closed --submit` applies it in a
  throwaway checkout and confirms the patch file and the branch are the same
  change.
- `tools/check-patch-clean.sh --submit`: **PASS** (5 Redmine files, locales
  `en.yml` only, no AI trace in header or message, applies to a pristine
  r25037 checkout, file and branch agree)

# Locales — why `en.yml` only

This is the one place where the patch deliberately does less than the framework
usually asks for, and the reason is a fact about Redmine's own files.

All figures below are counted on the revision this patch is made against,
**r25037 (`bee32a926`)**, so they can be re-checked and so they do not silently
age: they moved once already between r24882 and r25037.

The new key's three siblings — `webhook_event_created`, `_updated` and
`_deleted` — are present in **all 49** non-English locale files, and in **42**
of them the value is still the verbatim English string. They got there because
`rake locales:update` ("Updates language files based on en.yml content") appends
every `en` key a language file is missing, **with the English value**. That is
Redmine's mechanism for this, not a feature patch's job.

Seven languages have since had a translator go through that group: `bg`, `cs`,
`fr`, `gl`, `hu`, `ja` and `zh-TW`. `fr` joined them between r24882 and r25037.
`nl`, `de` and `es` are not among them — in those three the keys still read
`"%{object_name} created"` and so on, `de.yml` included, which is otherwise the
best translated of the four languages this framework ships. So the pattern in
this exact group of keys is: the key ships in English, and each language team
translates the group when it gets to it.

So there are three options and none of them is "translate it":

1. **`en.yml` only.** `config.i18n.fallbacks = true` in `config/application.rb`,
   so a locale without the key renders the English string — which is character
   for character what hand-copying the English into four files would produce.
   And the form passes `:default => name.gsub('.', ' ').humanize`, so even
   without any key at all the label reads "Issue closed".
2. **Copy the English into `nl`, `fr`, `de`, `es`.** Four changed files, zero
   changed pixels, and an obvious question from a reviewer: why those four of
   the forty-nine.
3. **Actually translate it.** In `nl`, `de` and `es` the fieldset would then
   read *Issue created / Issue updated / Ticket geschlossen / Issue deleted*,
   because `_form.html.erb` interpolates `:object_name => type.to_s.humanize` —
   an English class name — and the three siblings stay English. One translated
   label out of four is worse than four English ones. The seven languages that
   did translate the group translated all three at once, which is the right
   unit of work.

   **French is now the exception, and it cuts the other way.** Since r25037 a
   French administrator sees *Création de… / Mise à jour de… / Suppression
   de…* plus an English "Issue closed" — exactly the half-and-half outcome the
   argument above is built to avoid, arrived at by taking option 1. That is
   one file, and it is the fact Jan should have in front of him when he answers
   **K-09**; it does not change what the other three languages need.

Option 1 is what is built. There is a real thing to fix here, but it is the
whole `webhook_event_*` group in `nl`, `fr`, `de` and `es` together, plus the
unlocalised `object_name`, and that is its own patch. It is logged as **K-09**
for Jan.

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`, with a real HTTP receiver catching the outgoing POSTs.
**Re-run on 2026-09-05 against the rebuilt patch** (r25037, with the timestamp
mapping moved into `Issue::Webhookable`), so the "after" shots are of the code
that is actually being submitted; the "before" shots are the unpatched
instance and are unchanged.
Both modes drive the **same seven changes** to one issue through the web UI —
create, plain note, status change to another open status, close, move to a
second closed status, reopen, close again — and the only difference is what
arrives. The receiver serves what it received as a page, and that page is what
is photographed, so the delivery tables are real POSTs from the running
application rather than an assertion about them.

Screenshots in `docs/features/webhook-issue-closed/shots/`.

| Function | Screenshot | What it shows |
|---|---|---|
| The events fieldset | `before-webhook-form.png` | the whole form before the change: the Issues fieldset offers created, updated, deleted |
| | `webhook-form.png` | the same form with the change: created, updated, **closed**, deleted |
| The one changed pixel region | `before-issue-events.png` | just the Issues fieldset before — three check boxes |
| | `issue-events.png` | just the Issues fieldset after — four, with "Issue closed" between updated and deleted |
| The selection round-trips | `webhook-form-edit-selected.png` | the saved hook re-opened: only "Issue closed" is ticked, so the next editor does not silently drop it |
| **The deliveries** — the feature itself | `before-deliveries.png` | unpatched, hook on `issue.updated`: the seven changes produced **six** POSTs, every one carrying `status_id` and no way to tell which two were closings |
| | `deliveries.png` | patched, hook on `issue.closed` only: the same seven changes produced **two** POSTs, both `type: issue.closed`, both with status `Closed`, each carrying the closing note |
| The issue that produced them | `before-issue-history.png` / `issue-history.png` | the full journal of the issue in each run, so every delivery above can be matched to the change that caused it |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| `Closed` → `Rejected` (closed to closed) | `deliveries.png` row absent | no delivery | no delivery — journal #4 in `issue-history.png` has no matching row |
| reopened (`Rejected` → `In Progress`) | `deliveries.png` row absent | no delivery | no delivery — journal #5 has no matching row |
| a note with no status change | `deliveries.png` row absent | no delivery | no delivery — journal #1 has no matching row |
| "Enable webhooks" turned off, then reopen and close again | `deliveries-webhooks-disabled.png` | nothing at all | "0 POST request(s) received. No delivery received." — journals #7 and #8 in `issue-history.png` are that reopen and that closing |

Screenshots read, not just generated: **yes**, and read again after the
2026-09-05 re-run. What was looked for, and found: the two cropped fieldsets
counted (three boxes vs four) and the new label read in place — `issue-events.png`
shows *Issue created / Issue updated / Issue closed / Issue deleted*; the tick
in the reopened edit form confirmed to be on "Issue closed" and on nothing
else; both delivery tables read row by row against the journal in the matching
`issue-history` shot. That last reading is what makes the "no delivery" rows
conclusions rather than absences: the issue's journal has **eight** entries —
a plain note, `New` → `In Progress`, `In Progress` → `Closed`, `Closed` →
`Rejected`, `Rejected` → `In Progress`, `In Progress` → `Closed`, then a reopen
and a close with webhooks off — and the receiver page lists exactly **two**
deliveries, both `issue.closed`, carrying the notes of journals 3 and 6.
The disabled-setting page reads "0 POST request(s) received" and "No delivery
received" rather than merely showing an empty table.

One thing the screenshots show that is **not** this patch, mentioned so nobody
reads it as a defect introduced here: `/webhooks/new` has no "Wiki pages"
fieldset in either run. `WebhookPayload.events` is a class-level registry
filled by `acts_as_webhookable` when the model class loads, and
`config.eager_load = false` in development, so a model Zeitwerk has not touched
yet is simply missing from the form. It is there in production, where
`eager_load` is true. Reproducible on pristine trunk and worth its own bug
report.

# Anticipated objections

| Objection | Answer |
|---|---|
| Why `closed_on` and not the status change? | `closed_on` is written by exactly one place in core, `update_closed_on`, `if closing?`, and it is not a safe attribute. So reading it is reading core's own answer to "was this a closing", with no extra query and no second definition to keep in step. The status-based version is in "Alternatives considered" with what it costs. |
| `closed` is in the `acts_as_webhookable` array but the `case` in that method has no branch for it. Is that not a bug? | No, it is the seam, and it is the reason `lib/redmine/acts/webhookable.rb` is not in this patch at all. Registering an event without a generic lifecycle callback is supported and trunk's own payload test does it (`should generate payload for custom event`, registering `news.commented`). "Closed" is not a lifecycle callback, so it is fired from `Issue::Webhookable` instead, next to the journal enrichment that is also issue-specific — and the payload timestamp for it is overridden in that same file rather than added to the generic mapping. `Issue#attachment_removed` calls `Webhook.trigger` directly for the same reason. |
| This should be `after_update_commit`, not `after_save_commit`. | `after_save_commit` also covers an issue created directly in a closed status, which is a closing by Redmine's own definition (`Issue#closing?` returns `closed?` for a new record, and `update_closed_on` stamps `closed_on` on that create). Restricting it to updates would make the event silently miss that case. There is a test for it. |
| What does this cost on `Issue#save` in an installation with webhooks off, which is the default? | One in-memory boolean, and **zero** queries. The condition is written `Webhook.trigger(...) if saved_change_to_closed_on?`, so the guard is evaluated first and `Setting.webhooks_enabled?` is not even read unless the save actually closed the issue. That is cheaper than the three callbacks `acts_as_webhookable` already installs, which call `Webhook.trigger` unconditionally on every create, update and destroy. Measured by counting `sql.active_record` around one `Issue#save`: with webhooks off the `webhooks` table is not touched on any save path, closing or not. |
| And with webhooks on? | One extra `hooks_for` query, on the save that actually closes the issue and only there. Measured, with webhooks enabled and no hooks at all in the table: a closing save queries `webhooks` **twice** where trunk queries it once, a non-closing save queries it **once**, which is trunk's number. That is one additional indexed `SELECT` on a state transition; every other save path is unchanged. |
| Does an existing installation start getting extra deliveries? | No. Existing hooks' `events` arrays do not contain `issue.closed`, so `hooks_for` never returns them for it. Nothing changes until somebody ticks the box. |
| Then a receiver gets two deliveries for one closing, `issue.updated` and `issue.closed`. | Only if it subscribes to both, which it no longer needs to. The point of the event is that a receiver interested only in closings ticks one box and gets one delivery per closing — six deliveries down to two in the browser verification above. |
| Two closed statuses in a row (`Closed` → `Rejected`) — surely that is a closing too? | It is a change between two closed states, and `closed_on` is deliberately left alone by core in that case, so the issue's recorded closing time does not move. Firing again would tell a receiver "this was closed now" about an issue that was already closed. There is a test. |
| An administrator ticks "Issue closed" on an existing status. Does every issue in that status now POST to the hook? | No. `IssueStatus#handle_is_closed_change` backfills `closed_on` on those issues with two `Issue.where(...).update_all(...)` statements, and `update_all` runs no callbacks — so neither `issue.closed` nor the existing `issue.updated` fires. Which is right: the issues were not closed, the definition of closed changed. Deleting such a status is not a route in either: `IssueStatus#check_integrity` refuses while any issue still uses it. |
| Why not add it to `Version` too, which also has a closed status? | Out of scope for this patch and it would double what has to be reviewed. The design generalises: `Version::Webhookable` gains the same three lines with its own predicate. Happy to add it if wanted. |
| The other translations are missing. | On purpose, and the reasoning is in "Locales — why `en.yml` only": at r25037, in 42 of the 49 non-English locale files the three sibling keys are still the verbatim English string, `i18n.fallbacks` is on, and `rake locales:update` is Redmine's mechanism for propagating a new `en` key with its English value. The seven languages that did translate the group translated all three together — that is the unit of work, and a language team will pick the fourth up the same way. |
| Thirteen added lines of production code and ten tests is a lot of test for a little code. | The code is small because the condition is exactly right; the tests are what establish that. Eight of the ten are transition tests, covering seven of the eight rows of the table above, and that table is the specification of the feature; the other two pin the payload's journal and its timestamp. The one row without a test is named in *Tests*, with why. |

---

## Submission

- **Issue:** <redmine.org nummer + link, zodra Jan het heeft aangemaakt>
- **Patches attached:** `patches/webhook-issue-closed/2026-09-05-r25037-feature.patch` (code + `en.yml`, one file — there is no locales patch, see the locale section)
- **Made against:** `origin/master` r`25037` (2026-09-03)
- **Status:** nog niet ingediend
- **Feedback en wat ermee gebeurde:** —
- **Twee losse issues, en ze bijten elkaar niet.** Deze patch en die van
  `webhook-tracker-filter` gaan als twee aparte redmine.org-issues de deur uit.
  Ze raken elkaar alleen in `test/unit/webhook_test.rb` en zijn op een schoon
  r25037-checkout **in beide volgordes** achter elkaar toegepast zonder
  conflict. Eén zin daarover in het issue dat als tweede binnenkomt bespaart de
  committer het uitzoekwerk.
- **Eén zin over `json` 3.0.0, zolang die gem is wat een verse `bundle install`
  oplevert.** `json` 3.0.0 breekt `ActiveSupport::JSON.decode` met
  `ArgumentError: wrong number of arguments (given 2, expected 1)` — dat is een
  Rails/gem-probleem, niet van deze patch, en het is gemeten op **kaal** trunk
  r25037, waar het ongeveer honderd kerntests raakt. Eén daarvan is de nieuwe
  test op `webhook_test.rb:250`, en dat is precies het bestand dat een reviewer
  van deze patch draait. De patch zelf blijft ongewijzigd: `ActiveSupport::JSON.decode`
  is wat **20** kerntestbestanden gebruiken tegen 3 voor `JSON.parse`, dus hier
  afwijken om een tijdelijke gembug te ontwijken laat een inconsistentie achter
  die de bug overleeft. Is `json` gepind of de Rails-kant gerepareerd tegen de
  tijd dat het issue de deur uit gaat, dan vervalt deze zin vanzelf.

## GEOxyz

- **Commits op `7.0-stable-GEOxyz`:** `827e9e7d5` (2026-09-03, de feature) en
  `7e92b5596` (2026-09-05, het ronde-2 ontwerp: de tijdstempelmapping terug uit
  `lib/redmine/acts/webhookable.rb` naar `Issue::Webhookable`, de regel waarom
  boven de bewaking, en de twee testwijzigingen). **Twee** commits en geen
  herschreven historie: een force push op de branch die GEOxyz draait maakt elke
  checkout daar ongeldig. Dezelfde afweging als bij `ldap-mail-prefs`, en het
  registerveld wijst naar de laatste.
- **Identiek aan de patch (INV-10):** ja, mechanisch nagegaan — de drie
  productiebestanden (`app/models/issue.rb`,
  `app/models/concerns/issue/webhookable.rb`, `lib/redmine/acts/webhookable.rb`)
  zijn **byte-identiek** tussen de patch-worktree en de GEOxyz-worktree.
  `en.yml` en `webhook_test.rb` verschillen, maar alleen doordat de GEOxyz-tak
  ook andere features draagt; de hunks van deze feature zijn regel voor regel
  dezelfde.
- **Suites daar groen:** ja — volledige suite op de branchtip `7e92b5596`:
  **6121 runs, 32338 assertions, 0 failures, 0 errors, 39 skips**, in één run,
  zonder gelijktijdige andere suite en dus zonder flake om weg te redeneren.
  Dat is de boom die GEOxyz draait. Webhooksuites plus Redmine's eigen
  locale-consistentietest daar: **110 runs, 1104 assertions, 0 failures**.
  RuboCop in die worktree op de vijf gewijzigde bestanden: **0**.
- **`nl.yml` toegevoegd:** nee — zie de localesectie; `en.yml` alleen, aan
  beide kanten identiek, dus geen INV-10-afwijking
- **`tools/check-geoxyz-branch.sh`:** **PASS** (merge met upstream
  `7.0-stable`: niets te mergen, al current; lint 1 offence op 66 gewijzigde
  Ruby-bestanden, en die ene staat al op een regel van upstream zelf — baseline
  1, dus de branch voegt er nul toe; locales binnen en/nl/fr/de/es; 33 eigen
  commits, kloppend met het register)
- **Wanneer kan deze commit vervallen?** Trunk staat op `7.0.0 devel` en
  Redmine backportt geen features naar een stable branch, dus een geaccepteerde
  patch komt in **7.1 of later**. De GEOxyz-commits blijven nodig tot GEOxyz
  zelf naar die release gaat.
