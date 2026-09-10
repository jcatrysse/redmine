# Review run — 2026-09-10 — claude-opus5-round4

- **Reviewer:** Claude Code (Opus 5), round 4 (Deel A of `docs/review/prompt-round4.md`)
- **Reviewed:** `patch/webhook-issue-closed` at `f3234c1ec` against its base `bee32a926` (r25037), and against real trunk `167e487ee` (r25065) for applicability
- **Dossier read:** `docs/features/webhook-issue-closed/dossier.md` — yes
- **Status read:** `docs/features/webhook-issue-closed/status.md` — yes
- **Ran the test suite:** partly — the two touched test files in one process, plus a purpose-written probe that drives close → reopen → re-close twice, once with the clock frozen and once with it moving. Not `test:all`; the r25037 baseline this dossier quotes is the one I measured today for `imap-oauth` on the same revision.
- **Scope covered:** the whole production diff; `update_closed_on`, `closing?` and `reopening?` in `app/models/issue.rb`, to check the patch's central claim against the code it depends on rather than against the commit message; **the trigger predicate driven through the transitions, including a re-closing at an unchanged timestamp**; the payload and timestamp overrides; the eight new tests read as coverage; RuboCop; INV-10 through `tools/check-symmetry.sh`; the dossier read as a submission.
- **Scope NOT covered:** no `test:all`, no `7.0-stable-GEOxyz` suite for this feature, and no browser. I did not exercise a real delivery; the dossier's screenshot of live deliveries was read, not reproduced.

## Summary

The patch is small, the mechanism is the elegant one, and it is right about
almost every transition. `closed_on` really is written in exactly one place,
`update_closed_on`, `if closing?`, and Redmine really does preserve it across a
reopen — the comment at `issue.rb:2048` says so and `closing?` requires
`!was_closed?`, so a move between two closed statuses writes nothing. I checked
all of that against the code rather than against the commit message, and it
holds.

There is one exception to the identity the dossier rests its whole design
argument on, and I could only find it by running the transitions rather than
reading them. The dossier says: "'this save wrote `closed_on`' and 'this save
closed the issue' are the same statement." They are not, in one case: when a
re-closing lands on the same timestamp as the previous closing, `closed_on` is
assigned the value it already holds, `saved_change_to_closed_on?` is false, and
the closing produces **no `issue.closed` event**. Driven with the clock frozen,
the second closing is silent; with the clock two seconds ahead, it fires. On
PostgreSQL with microsecond precision this is unreachable in practice; on a
`datetime` column with second resolution, which is what an old MySQL `issues`
table has, it is a narrow race rather than an impossibility. Either way it is a
counter-example to a load-bearing sentence in the text that goes on
redmine.org, and it belongs in that text.

Everything else checks out. The payload change extends the journal enrichment
to `closed` without touching the other four webhookable models, the timestamp
override is confined to an Issue-only action, and the one error in the touched
suites is the patch's own end-to-end test hitting `ActiveSupport::JSON.decode`
under this image's json 3.0.2.

**Counts:** blocker 0 · major 0 · minor 1 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0.

## Evidence I re-measured

| Claim | What I measured | Same? |
|---|---|---|
| RuboCop on the four changed files: 0 | **0** (rubocop 1.90.0) | yes |
| touched suites green | **63 runs, 238 assertions, 0 failures, 1 error** — the one error is `ArgumentError: wrong number of arguments (given 2, expected 1)` at `webhook_test.rb:250`, which is `ActiveSupport::JSON.decode` under json 3.0.2, the documented image fault | yes, once the environment is subtracted |
| `tools/check-symmetry.sh webhook-issue-closed`: PASS | **PASS**, and its 1 locale key reads the same on both branches | yes |
| `tools/check-patch-clean.sh webhook-issue-closed --submit`: PASS | **PASS** against real trunk r25065 | yes |
| "closed_on is written by exactly one place, `if closing?`" | **confirmed** at `issue.rb:2050`, and `closing?` at `:1002` requires `status_id_changed? && closed? && !was_closed?` | yes |
| "preserved when the issue is reopened" | **confirmed** — core's own comment at `issue.rb:2048` says so, and my probe shows `closed_on` unchanged across a reopen | yes |
| a move between two closed statuses fires nothing | **confirmed** by reading `closing?`; not separately probed | yes |
| "fires once per closing" | **not quite** — see F01 | no |

---

### F01 — a re-closing at an unchanged timestamp fires no event, and the dossier states the predicate as an identity

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/models/concerns/issue/webhookable.rb:24`; "Proposed change" and the `closed_on`-versus-status row of the objections table in `dossier.md`
- **Invariant touched:** none

**What is wrong**

The trigger is `after_save_commit ->{ ... if saved_change_to_closed_on? }`.
`update_closed_on` assigns `self.closed_on = updated_on` whenever `closing?`,
and Active Record reports no change when the assigned value equals the stored
one. So a closing whose `updated_on` happens to equal the `closed_on` left by a
previous closing writes nothing, `saved_change_to_closed_on?` is false, and no
`issue.closed` event is produced — even though the issue did just close.

The dossier states the underlying identity without qualification: "So 'this
save wrote `closed_on`' and 'this save closed the issue' are the same
statement", and the objections table repeats it as the reason for preferring
`closed_on` over the status transition. That reason is a good one and I would
keep the design; the sentence is what needs the exception.

**Why a committer would push back**

Because the sentence is checkable and there is a counter-example. Whether they
care about the window depends on the database: Rails reports the change from
the stored value, so the resolution of the `closed_on` column is what decides
how wide the window is. On PostgreSQL the column carries microseconds and no
human sequence of close, reopen and close can land inside one. On a MySQL
`datetime` column without fractional seconds — which is what an `issues` table
created by an older Redmine has — the window is a full second, and a script or
an API client that closes, reopens and re-closes is inside it. A receiver that
relies on `issue.closed` to drive a workflow then silently misses a closing,
which is precisely the failure mode this event exists to remove.

**How I verified it**

A probe against the patch tip that drives the three transitions with
`travel_to`, stubbing `Webhook.trigger` to record event names:

```
clock frozen at 12:00:00
  first closing   -> ["issue.closed", "issue.updated"]  closed_on=12:00:00
  reopen          -> ["issue.updated"]                  closed_on=12:00:00
  second closing  -> ["issue.updated"]                  closed_on=12:00:00   <-- no issue.closed

clock moving
  12:00:00 closing    -> ["issue.closed", "issue.updated"]  closed_on=12:00:00
  12:00:01 reopen     -> ["issue.updated"]                  closed_on=12:00:00
  12:00:02 re-closing -> ["issue.closed", "issue.updated"]  closed_on=12:00:02
```

The frozen clock is not an artificial condition: it is exactly how a column
with one-second resolution behaves for two events inside the same second.

**Suggested direction**

Two honest options and the owner picks. The cheap one is to qualify the
sentence: `closed_on` answers "was this a closing" except when the new
timestamp equals the old, so a re-closing inside the column's timestamp
resolution is missed — narrow enough to accept, and saying so is stronger than
being asked. The other is the `before_save` instance variable that
"Alternatives considered" already describes and rejects; it has no such gap,
and the rejection reasons ("an extra callback and an extra piece of
per-instance state") are weaker once the column-based version is known to be
lossy. Either way it wants a test: the frozen-clock sequence above is four
lines and is red on the current patch.

**Resolution:**

---

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks.

**The transition table is the right idea and it is what let me find F01.** The
dossier enumerates eight transitions and says which fire and which do not, with
seven of the eight tested and the eighth ("deleted") explained rather than
skipped. That table is why I went looking for a ninth row instead of re-reading
the seven: the sequence close → reopen → re-close is in it, and what is not in
it is *when* the re-close happens. A table that enumerates states invites the
question "what about the same state twice", and nobody asked it.

**I agree with the choice of `closed_on` over the status transition, and F01
does not change that.** Reading core's own answer beats keeping a second
definition of "closing" in step with core, and the alternatives section makes
that case properly. My finding is about one sentence and one missing test, not
about the mechanism.

**Nothing in `docs/DECISIONS.md` looks wrong to me.** K-09 (English only for
now) is still open and still does not block submission; the single `en.yml` key
sits next to the three it belongs with, which is what makes that defensible.
