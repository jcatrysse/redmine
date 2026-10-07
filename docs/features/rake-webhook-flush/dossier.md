# rake-webhook-flush — webhooks gaan niet meer verloren in de mail-rake-taken

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** wie mail binnenhaalt met
  `rake redmine:email:read`, `receive_imap` of `receive_pop3` en geen aparte
  job-backend draait, verloor de webhooks van de issues die die mails aanmaakten:
  het rake-proces stopte voor de webhook-jobs liepen. Nu worden die webhooks in
  het rake-proces zelf verstuurd, net zoals Redmine dat sinds 2014 al doet voor
  de notificatiemails in precies diezelfde taken.
- **Waar het vandaan komt:** geen 5.1-commit. Jans opdracht van 2026-10-07 (keuze
  core-q4, optie A), na de meting van de issue_recurring-sessie (4 issues, 3
  webhooks) en de 30-secondenwacht in de cron van redmine_ai_triage.
- **Doel:** upstream + GEOxyz.
- **Afwijking GEOxyz ↔ upstream:** geen. Dezelfde commit, schoon toegepast.
- **Kans dat Redmine dit aanneemt:** redelijk tot goed. Het is vier regels in een
  bestaande helper die precies voor dit probleem bestaat, en #36393 legde in 2022
  al vast dat die helper altijd inline werkt, zonder slimmigheid. Het bezwaar dat
  je kan verwachten is #36395 (die helper is niet thread-safe); dat geldt al
  voor de bestaande regel en wordt hier niet erger in een rake-proces.
- **Wat jij nog moet doen:** een issue aanmaken op redmine.org (er bestaat er nog
  geen, zie G1) met de tekst vanaf "The problem" en
  `patches/rake-webhook-flush/2026-10-07-r25136-feature.patch` erbij; en de
  Class B-keuze K-24 in `docs/DECISIONS.md` bevestigen of omgooien.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** mirror `origin/master` = `e3962939c`, r25136 van
  2026-09-25. Echte trunk op 2026-10-07 = `713d29813`, r25215: de mirror loopt
  **41 commits achter**. Geen van die 41 raakt `app/models/mailer.rb`,
  `test/unit/mailer_test.rb`, `app/jobs/`, `app/models/webhook.rb` of
  `lib/tasks/email.rake` (`git diff --stat` leeg), en de patch applyt op r25215
  (`git apply --check`, gemeten 2026-10-07). De mirror bijwerken blijft van Jan
  (K-19 optie A).
- **Lost trunk dit al op?** Deels, en dat bepaalt het ontwerp. Trunk heeft
  `Mailer.with_synched_deliveries` (`app/models/mailer.rb`), met de Rails-guide
  in het commentaar: "Using the asynchronous queue from a Rake task will
  generally not work because Rake will likely end […] before any/all of the
  .deliver_later emails are processed". Alle drie de taken die mail ontvangen
  (`email:read`, `receive_imap`, `receive_pop3` in `lib/tasks/email.rake`) en
  `redmine:send_reminders` draaien al in dat blok. Maar het blok zet alleen
  `ActionMailer::MailDeliveryJob` op inline. `WebhookJob` (sinds r24093,
  #29664, 2025-10-07) gebruikt `perform_later` op de standaardadapter en valt
  erbuiten.
- **Bestaand issue op redmine.org?** Geen issue over webhooks die in rake-taken
  verloren gaan. Gezocht via de API op onderwerp: `webhook` (12 issues, alle
  gelezen), `WebhookJob`, `webhook rake`, `webhook async`,
  `with_synched_deliveries`. Relevant voor de bezwaren:
  - **#36393** (gesloten, 5.0.0): de helper detecteerde alleen de Async-adapter;
    Felix Schäfers patch maakt hem onvoorwaardelijk inline, "without trying to
    be clever about it". Dat is de conventie waar deze patch op leunt.
  - **#36395** (New sinds 2022): de helper zet globale toestand en is dus niet
    thread-safe. Geldt voor de bestaande regel; zie de bezwaren.
  - **#44465** (New, doel 7.1.0): webhooks op een eigen queue, omdat één
    onbereikbaar endpoint 60 s per levering kost. Raakt deze patch niet (zie de
    bezwaren), maar het is dezelfde 60 s.
  - **#44454** (New): de lijst webhook-events is leeg na het starten in
    development. Kwam ik tegen in het G9-script, staat los van deze patch.
- **Verandert iets in trunk het ontwerp?** Ja, in de goede richting: de helper
  bestaat al en wordt al door de juiste taken gebruikt, dus de fix is één plek en
  geen nieuwe taak, instelling of sleep.

---

# The problem

Since webhooks were introduced (#29664), an issue created or updated by an
incoming email triggers `WebhookJob.perform_later`. On an installation that has
not configured an Active Job backend — the default `:async` adapter, which runs
jobs on a thread pool inside the current process — those jobs are lost when the
email is received by one of the rake tasks: `redmine:email:read`,
`redmine:email:receive_imap` or `redmine:email:receive_pop3`. The task finishes,
the process exits, and the thread pool is discarded with the jobs still in it.

Redmine already solved exactly this for notification emails in 2014 (#16784):
those three tasks wrap their work in `Mailer.with_synched_deliveries`, which
switches `ActionMailer::MailDeliveryJob` to the inline adapter for the duration
of the block. The notification email for an issue created by mail therefore
arrives; the webhook call for the same issue does not.

Reproduced on trunk r25136 in development (default `:async` adapter), with one
webhook subscribed to `issue.created` and four separate
`rake redmine:email:read project=...` runs, one email each, as an MTA pipe would
run them: **4 issues created, 0 webhook calls received.** The development log
shows all four `Enqueued WebhookJob ... to Async(default)` lines and no
`Performing WebhookJob` line. When several emails are processed in one run the
loss is partial instead of total — the jobs for the earlier emails get time to
run while the later ones are being processed — which makes it easy to miss: an
installation that receives four emails per run may see three webhook calls.

# Why this belongs in core

The jobs are enqueued by core (`Webhook.trigger`) from core rake tasks, and the
fix belongs in the helper core already uses to make those tasks reliable. A
plugin cannot fix this for the core tasks without patching `Mailer` or wrapping
the core rake tasks. The workaround available today is to install and run a
separate job backend just so that webhook calls from a cron job are not
dropped, or to add a sleep after the rake task, which is a guess.

# Proposed change

`Mailer.with_synched_deliveries` also switches `ActiveJob::Base` to the inline
adapter for the duration of the block, and restores it afterwards. Every job
enqueued inside the block that has no adapter of its own — `WebhookJob`, and any
job a plugin enqueues while an email is processed — then runs before the block
returns, exactly like the notification emails.

| File | Change |
|---|---|
| `app/models/mailer.rb` | two lines to swap `ActiveJob::Base.queue_adapter`, two to restore it; the method comment names webhook calls |
| `test/unit/mailer_test.rb` | one test: a `WebhookJob` enqueued inside the block is performed, not left in the queue, and the adapter is restored |

**New setting / migration / gem / route / permission:** none.

**Translations:** none — no user-visible string.

**Backward compatibility:** outside the three email tasks and
`redmine:send_reminders` nothing changes; the helper is not called anywhere
else in core. Inside them, jobs that used to be lost now run. On an installation
with a real backend (Sidekiq, Resque, ...) webhook calls from these tasks now
run inline in the rake process instead of being handed to the backend — the
same trade-off #36393 made deliberately for emails in 2022. Webhook calls cannot
fail the task: `Webhook#call` rescues every error and logs it, and that is
verified below with an unreachable endpoint.

Why `ActiveJob::Base` and not `WebhookJob`: Active Job stores the adapter in a
`class_attribute`. Assigning `WebhookJob.queue_adapter` and then "restoring" it
assigns the inherited value to `WebhookJob` itself, so `WebhookJob` stops
following `ActiveJob::Base` afterwards. In the test suite that is visible at
once: built that way, `test/unit/mailer_test.rb` and `test/unit/webhook_test.rb`
run together (as `rake test` does) gave 8 failures, because `WebhookTest`
switches `ActiveJob::Base` to `:test` in its setup and `WebhookJob` no longer
followed. `ActiveJob::Base` is the root of that inheritance, so restoring it is
exact and leaves nothing pinned. The existing `MailDeliveryJob` lines are left
as they are (INV-1), so an installation that gave `MailDeliveryJob` an adapter
of its own keeps today's behaviour for emails.

# Alternatives considered

**Swap only `WebhookJob.queue_adapter`.** Narrowest in intent, and the first
version built. Rejected for the `class_attribute` pinning described above: the
suite turns order-dependent, and undoing the pin needs Rails internals
(`singleton_class` introspection, which is what `ActiveJob::TestHelper` itself
uses).

**Wait for the Async adapter to drain at the end of the block.** Keeps the jobs
asynchronous while the emails are processed, then waits. Rejected: it needs a
timeout (a guess, the same guess as a sleep after the task), it reaches into the
adapter's private scheduler, and it does nothing for a real backend — where
nothing is lost in the first place, but where #36393 decided this helper should
be inline anyway.

**Only switch when the adapter is `:async`.** Rejected because that is the
exact check #36393 removed from this helper; reintroducing it for jobs while the
emails stay unconditional would make the helper inconsistent with itself. Noted
as an open choice for the GEOxyz side (K-24).

**A sleep or a wait in each rake task.** Ruled out by the brief and by design:
one place, not one per task.

**A separate job backend for the whole installation.** Out of scope on purpose;
whether Redmine (or GEOxyz) should run one is a separate decision. This patch
makes the default configuration correct without one.

# Tests

| Test | What it proves |
|---|---|
| `MailerTest#test_with_synched_deliveries_should_perform_other_jobs_inline` | with `ActiveJob::Base` on a queueing adapter, a `WebhookJob` enqueued inside the block is performed exactly once and nothing is left in the queue; after the block the original adapter is back |

**Evidence (INV-8 — figures, not claims):**

- **full** suite with the patch, `bin/rails test:all` (system tests included):
  `6101 runs, 32301 assertions, 27 failures, 2 errors, 82 skips`.
- pristine trunk r25136, same command:
  `6100 runs, 32296 assertions, 27 failures, 2 errors, 82 skips` — the same 29
  failing test names on both runs (27 of them repository and SCM tests, plus
  one `UserTest` and one API issues test, all failing on pristine trunk in this
  environment), so the patch adds one passing test and changes nothing else.
- RuboCop on `app/models/mailer.rb` and `test/unit/mailer_test.rb`: **0**
  offences with the patch, **0** at the merge base.
- the new test is red on the old code: with `app/models/mailer.rb` stashed it
  fails on `assert_empty WebhookJob.queue_adapter.enqueued_jobs` — the job was
  queued, not performed (`2 runs, 5 assertions, 1 failures`). With the patch:
  `2 runs, 7 assertions, 0 failures`.
- test pollution: `mailer_test.rb`, `webhook_test.rb` and
  `mail_handler_test.rb` in one process, seeds 1–4: `233 runs, 1335 assertions,
  0 failures, 0 errors` each time.
- patch applies to pristine `origin/master` r25136: yes; to real trunk r25215
  (`713d29813`): yes.
- `tools/check-patch-clean.sh`: PASS.

# Live verification (G9)

Exercised in a real Redmine at `http://127.0.0.1:3000` (development, default
`:async` adapter), seeded by `tools/dev-seed.rb`, by `verify/rake-webhook-flush.mjs`.
There is no screen for this feature, so the evidence is the issue list in
Redmine next to the page of a real webhook receiver the script starts. Every run
is four separate `rake redmine:email:read project=geoxyz-verify` processes, one
email each, against a webhook subscribed to `issue.created`. The script asserts
the counts it screenshots and exits non-zero when they disagree. Screenshots in
`docs/features/rake-webhook-flush/shots/`.

| Function | Screenshot | What it shows |
|---|---|---|
| the webhook used | `before-webhook-config.png` | one active hook, `issue.created`, project GEOxyz verification |
| trunk, issues | `before-issues.png` | 4 issues created by the 4 rake runs |
| trunk, webhooks | `before-receiver.png` | **0 of 4** webhook calls received |
| patched, issues | `after-issues.png` | 4 issues created by the 4 rake runs |
| patched, webhooks | `after-receiver.png` | **4 of 4** received, one per issue, ~3 s apart (one rake run each) |
| patched, the webhook used | `after-webhook-config.png` | the same hook |
| `7.0-stable-GEOxyz`, issues | `geoxyz-issues.png` | 4 issues on a Redmine 7.0 instance (port 3001) |
| `7.0-stable-GEOxyz`, webhooks | `geoxyz-receiver.png` | 4 of 4 received |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| endpoint unreachable (closed port) | `after-unreachable-issues.png`, `after-unreachable-receiver.png` | issues still created, rake exits 0, nothing received | 4 issues, 4 × exit 0 in ~3.1 s each, 0 received; the log has `Webhook Error: Could not connect to any IP (SocketError)` |
| webhooks disabled in the settings | `after-disabled-issues.png`, `after-disabled-receiver.png` | issues created, no job at all | 4 issues, 0 received, no `WebhookJob` line in the log for those issues |

Each inline delivery took 7–11 ms (`Performed WebhookJob ... from Inline(default)`
in the development log); a rake run took ~3 s with or without the patch.

Screenshots read, not just generated: yes — the receiver pages for the count
and the issue ids, the issue lists for the four subjects of that run, the
webhook page for URL, event and project.

**A trap in the verification itself, caught and fixed.** The first version of
the script ran rake with `spawnSync`, which blocks Node's event loop, so the
receiver in that same process could not answer: each delivery then took
Redmine's 60 s read timeout and was still counted once the rake run had ended.
The figures above are from the corrected script (asynchronous spawn), and the
before run was repeated with it.

# Anticipated objections

| Objection | Answer |
|---|---|
| "This changes the adapter for *all* jobs, not just webhooks." | Only inside this block, which only the four email/reminder rake tasks call, and only for jobs without an adapter of their own. In those processes every such job enqueued on `:async` is lost today, so running it is the fix rather than a side effect; a plugin that enqueues a job when an issue is created by mail gets the same repair. Swapping only `WebhookJob` was built first and broke the suite through `class_attribute` pinning (see "Proposed change"). |
| "With Sidekiq, webhook calls now run inline instead of going to the backend." | True, and the same trade-off #36393 accepted for emails: this helper is "always inline without trying to be clever about it". In these processes an email is being received, so the delay is bounded by `Webhook::Executor`'s timeouts. An `:async`-only condition is possible (see Alternatives) but brings back the check #36393 removed. |
| "An unreachable endpoint now blocks the mail fetch for 60 s per call." (cf. #44465) | Only when the host accepts the connection and then never answers; a refused connection fails in milliseconds (verified: unreachable endpoint, 3.1 s per run, same as without a hook). The emails in the same block already work that way with an SMTP timeout. And the alternative today is not a faster delivery but no delivery. #44465's dedicated queue is independent of this change: it governs where a backend runs webhook jobs, this governs whether a short-lived process runs them at all. |
| "`with_synched_deliveries` is not thread-safe (#36395)." | Correct, and true of the existing `MailDeliveryJob` line since 2018. Core calls it only from rake tasks, which are single-threaded. A thread-local rewrite would fix both lines and is #36395's subject, not this patch's. |
| "A webhook call can now raise inside mail processing." | `Webhook#call` rescues every error and logs it; `WebhookJob#perform` only looks up the hook and its user. `Redmine::JobWrapper#keep_current_user` (an `around_enqueue`) restores `User.current`, which `WebhookJob` changes to the hook's user — under the inline adapter the job runs inside that `around_enqueue`. Verified with an unreachable endpoint: issues created, exit 0. |
| "Why not rename the helper, it is not only about mail any more?" | Renaming a public method that plugins call is not worth it for a fix; the comment says what it now covers. |

---

## Submission

- **Issue:** nog aan te maken door Jan
- **Patches attached:** `patches/rake-webhook-flush/2026-10-07-r25136-feature.patch` (code + test; geen locales, dus geen tweede bestand)
- **Made against:** `origin/master` r25136 (2026-09-25); applyt ook op echte trunk r25215 (2026-10-07)
- **Status:** klaar om in te dienen
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `e1e759c47` (dezelfde wijziging als de patch, schoon toegepast; `tools/check-symmetry.sh` PASS)
- **Suites daar groen:** `test:all` op `e1e759c47`: `6194 runs, 32668 assertions, 0 failures, 0 errors, 28 skips`
- **`nl.yml` toegevoegd:** n.v.t., geen vertalingen
- **`tools/check-geoxyz-branch.sh`:** ok voor deze commit; zie `status.md` voor de drie commits van parallelle sessies die de run op 2026-10-07 deden falen
- **Wanneer kan deze commit vervallen?** Pas als GEOxyz naar de Redmine-release
  gaat die de patch bevat (op zijn vroegst 7.1). Tot dan blijven ook de
  wachtlussen in de crons van issue_recurring en redmine_ai_triage gewoon
  staan (Jans beslissing bij issue_recurring). Een wachtlus na een van de drie
  core-mailtaken is met deze commit overbodig; een wachtlus na een eigen
  rake-taak van een plugin niet, want die draait niet in dit blok — tenzij de
  plugin zijn taak zelf in `Mailer.with_synched_deliveries` zet, wat met deze
  commit een werkende optie wordt. Welke van de twee de crons van die plugins
  zijn, is in deze sessie niet nagekeken (hun code staat niet in deze repo).
