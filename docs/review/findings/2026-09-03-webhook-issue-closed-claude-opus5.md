# Review run — 2026-09-03 — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `patch/webhook-issue-closed` at `32a1b691d` against `origin/master` `bee32a926` (branch's own merge-base is `2563fa6a5` = r24882; trunk has moved 88 commits since)
- **Dossier read:** `docs/features/webhook-issue-closed/dossier.md` — yes
- **Status read:** `docs/features/webhook-issue-closed/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes — in a throwaway worktree at the patch tip, PostgreSQL 16, own database. Counts:
  - `webhook_test` + `webhook_payload_test` + `webhooks_controller_test` in one process: **69 runs, 258 assertions, 0 failures, 0 errors, 0 skips**
  - the same three plus `test/unit/lib/redmine/i18n_test.rb`: **96 runs, 1058 assertions, 0 failures, 0 errors**
  - `issue_test` + `webhook_test` + `webhook_payload_test` in one process: **355 runs, 1094 assertions, 0 failures, 0 errors**
  - `issues_controller_test` + `webhooks_controller_test`: **492 runs, 3093 assertions, 0 failures, 0 errors, 1 skip** (the skip needs ImageMagick's `convert`, absent here)
  - `webhook_test` + `webhook_payload_test` at seeds 1 / 4242 / 99991: **61 runs, 237–238 assertions, 0 failures** each — no order dependence
  - RuboCop (`--force-exclusion`) on the five changed files: **0 offences**; same five files at `origin/master`: **0 offences**
  - `git apply --check` of `patches/webhook-issue-closed/2026-09-03-r24882-feature.patch` against a pristine `origin/master` worktree at `bee32a926`: **clean** — it still applies 88 trunk commits after its stated base
  - I did **not** run the full `test:all`; I ran the suites the patch touches plus the two neighbours most likely to break.
- **Scope covered:** minimality; feature scope; conventions of the touched files; backward compatibility (measured, not read); the whole eight-row transition table (measured row by row); bulk edit / `update_all` / copy / duplicate-cascade paths; cost on `Issue#save` (SQL counted, webhooks on and off); reopen-then-reclose; test strength by mutation; test pollution across three multi-file runs; i18n key placement and the locale facts the dossier rests on; the exported patch file; INV-4 and INV-10 on both commits.
- **Scope NOT covered:** no full `test:all` run and therefore no independent confirmation of the dossier's 5929/5920 comparison; no live browser verification — I read the dossier's screenshot table but did not open a Redmine or look at the PNGs; no MySQL or SQLite run (the only portability-shaped risk I could think of, `closed_on` second-precision on MySQL, I reasoned through rather than measured — see the note under F02); no review of the `verify/webhook-issue-closed.mjs` receiver script; no check of the redmine.org issue history beyond what the dossier quotes.

## Summary

This is a good patch and I would expect a committer to take it. Eight lines of
production code, no setting, no migration, no permission, nothing reformatted,
and the one design decision it makes — trigger on "this save wrote
`closed_on`" rather than on "the status became a closed one" — is the right one
and is defended in the dossier with the alternatives priced. I checked the
central claim by experiment rather than by reading: a hook that subscribes only
to `issue.updated` still receives exactly `["issue.updated"]` when an issue is
closed, an empty `events` array means "nothing" both before and after (there is
no "empty means all" convention in this code to preserve), and a NULL `events`
column reads back as `[]` rather than raising. I then drove all eight rows of
the dossier's transition table through a running test process and counted the
events that actually reached the job queue: **all eight rows are exactly as
claimed**, including the two subtle ones (`Closed` → `Rejected` fires nothing,
an ordinary edit of a closed issue fires nothing). I also mutated the code —
deleting the `if saved_change_to_closed_on?` guard — and 4 of the 6 new
`webhook_test` tests went red, including the end-to-end one, so the tests are
not decorative.

The single biggest reason a committer would push back is not the code, it is
one sentence in the dossier: the answer to "what does this cost on
`Issue#save`?" ends with "No query is added on any path", and that is measurably
false. With webhooks enabled, a save that closes an issue now runs the
`hooks_for` query **twice** (once for `issue.updated`, once for `issue.closed`)
where trunk runs it once. The important half of the claim is true and I
verified it — with webhooks off, which is the default, the patch adds **zero**
queries on every save path — so the fix is to state the cost accurately rather
than to change the code. A reviewer who checks one claim and finds it
overstated reads the rest of the dossier differently, and this dossier does not
deserve that.

Two smaller things worth the fixing session's time. First, the claim that every
row of the transition table has a test: six of the eight rows have a dedicated
test, "created with an open status" and "deleted" do not, and row 7 is tested
for a field edit but not for the note-only case. Second, a robustness gap I
confirmed: if the same issue is saved **twice inside one enclosing
transaction** and the second save does not touch `closed_on`, the
`issue.closed` event is silently lost while `issue.updated` still fires. I
could not find a path in core that does this, so it is not a bug today — but
`IssuesController#save_issue_with_child_records` wraps the save in
`Issue.transaction` and then calls `controller_issues_edit_after_save` inside
that transaction, so a plugin that re-saves the issue there would lose closings
and never know.

What surprised me positively, beyond the transition table holding up: the
GEOxyz commit `827e9e7d5` is byte-for-byte the same diff as the patch (I
compared them with `index`/hunk lines filtered), neither commit carries any AI
trace, and the patch still applies cleanly to today's `origin/master` even
though trunk has moved 88 commits since its stated base — none of them touch
this patch's territory.

**Counts:** blocker 0 · major 0 · minor 5 · nit 4 · question 1

**Lines in the diff not strictly required by the feature:** 0 — the production
diff is 8 insertions and 3 deletions and every one of them is load-bearing. The
101 test lines are proportionate: six of the eight tests are one row of the
transition table each, and that table is the specification.

---

### F01 — The dossier's "No query is added on any path" is false: a closing save runs `hooks_for` twice when webhooks are enabled

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 (Jans g09) — de zin "No query is added on any path" is weg. De kostenrij in "Anticipated objections" noemt nu twee gemeten getallen in plaats van één claim: met webhooks **uit** wordt de `webhooks`-tabel op geen enkel savepad aangeraakt, sluitend of niet; met webhooks **aan** draait de save die het issue daadwerkelijk sluit `hooks_for` **twee** keer waar trunk hem één keer draait, en een niet-sluitende save één keer, wat trunks eigen getal is. Er staat een tweede rij bij die precies die vraag stelt, zodat een reviewer het antwoord niet uit de eerste rij hoeft te destilleren. Opnieuw gemeten op r25037 met een `sql.active_record`-teller rond één `Issue#save`, met nul hooks in de tabel: `ENABLED closing 2 / non-closing 1`, `DISABLED 0 / 0`. Zelfde uitkomst als de review, andere totalen (dat komt door een ander testscenario) — de `webhooks`-kolom is wat telt en die is identiek
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/webhook-issue-closed/dossier.md`, "Anticipated objections", the row *"What does this cost on `Issue#save` in an installation with webhooks off…"* — final sentence
- **Invariant touched:** none

**What is wrong**

The objection is posed about an installation with webhooks **off**, and for
that case the answer is correct and I verified it. But the answer closes with
the unqualified sentence "No query is added on any path", and that is not true
of the enabled path. `Webhook.trigger` calls `hooks_for`, which issues one
`SELECT … FROM webhooks INNER JOIN projects_webhooks … LEFT OUTER JOIN users`
per trigger. Trunk fires one trigger on a closing save (`issue.updated`); the
patch fires two, so the query runs twice — even when the installation has no
hooks at all and nothing will be delivered.

**Why a committer would push back**

The claim is the kind a reviewer spot-checks, and it is the one sentence in an
otherwise carefully hedged dossier that does not survive the check. Concretely:
with `webhooks_enabled = 1` and zero `Webhook` rows, closing one issue executes
2 queries against `webhooks`; editing the same issue without changing its
status executes 1. Nobody will reject the patch over one extra indexed SELECT
on a state transition, but an overstated cost claim invites a closer look at
every other claim, and it is also the sentence most likely to be quoted back if
someone later profiles a bulk close of a few thousand issues.

**How I verified it**

A probe in the patch worktree subscribed to `sql.active_record` and counted
statements around one `Issue#save`, filtering `SCHEMA`/`TRANSACTION` events:

```
ENABLED  closing save:     total=28  webhooks=2
ENABLED  non-closing save: total=4   webhooks=1
DISABLED closing save:     total=24  webhooks=0
DISABLED non-closing save: total=3   webhooks=0
```

The two "webhooks=…" rows for the enabled case are the whole finding: 2 on the
save that closes, 1 on the save that does not (which is trunk's number). The
DISABLED rows confirm the important half of the dossier's answer — `Setting`
is read from its cache and the `webhooks` table is not touched at all, on any
path.

**Suggested direction**

State the cost the way the rest of the dossier states things: zero added
queries when webhooks are off (the default, and the case the objection asks
about), and one additional `hooks_for` query on the save that actually closes
an issue when webhooks are on. Both numbers are defensible; only the
unqualified "no query on any path" is not.

**Resolution:** fixed 2026-09-05 (Jans g09) — de zin "No query is added on any path" is weg. De kostenrij in "Anticipated objections" noemt nu twee gemeten getallen in plaats van één claim: met webhooks **uit** wordt de `webhooks`-tabel op geen enkel savepad aangeraakt, sluitend of niet; met webhooks **aan** draait de save die het issue daadwerkelijk sluit `hooks_for` **twee** keer waar trunk hem één keer draait, en een niet-sluitende save één keer, wat trunks eigen getal is. Er staat een tweede rij bij die precies die vraag stelt, zodat een reviewer het antwoord niet uit de eerste rij hoeft te destilleren. Opnieuw gemeten op r25037 met een `sql.active_record`-teller rond één `Issue#save`, met nul hooks in de tabel: `ENABLED closing 2 / non-closing 1`, `DISABLED 0 / 0`. Zelfde uitkomst als de review, andere totalen (dat komt door een ander testscenario) — de `webhooks`-kolom is wat telt en die is identiek

---

### F02 — `issue.closed` is silently lost when the same issue is saved twice inside one transaction

- **Status:** resolved
- **Resolution:** beschreven, niet gerepareerd, 2026-09-05 — bewust, en de reden staat in `decisions.md` onder "Ronde 2". Het gedrag is opnieuw gemeten op de nieuwe code en klopt precies zoals gemeld: één save binnen `Issue.transaction` levert `["issue.closed", "issue.updated"]`, twee saves van hetzelfde issue binnen één transactie leveren `["issue.updated"]` met `closed_on` wél gezet. Repareren vraagt een tweede callback plus per-instance state die na commit én na rollback gereset moet worden; geen enkel pad in core doet dit, dus dat is meer machinerie dan het gemeten risico rechtvaardigt (INV-1). Het staat nu als eigen punt onder "Backward compatibility" in het dossier, mét de plugin-route via `controller_issues_edit_after_save` erbij, zodat het benoemd is in plaats van stil — precies wat de bevinding als minimum vroeg
- **Severity:** minor
- **Confidence:** confirmed (mechanism), speculative (that any real installation hits it)
- **Category:** correctness
- **Where:** `app/models/concerns/issue/webhookable.rb:24`
- **Invariant touched:** none

**What is wrong**

`after_save_commit` runs once per record per transaction, at commit, and
`saved_change_to_closed_on?` there reports the dirty state of the **last** save
only. So if an issue is closed by one `save` and then saved again inside the
same enclosing transaction, and that second save does not itself write
`closed_on` (it never will — `update_closed_on` only writes when `closing?`,
and by then the issue is already closed), the guard is false at commit time and
no `issue.closed` event is produced. The issue is closed in the database,
`closed_on` is set, `issue.updated` is delivered, and the new event simply does
not happen. Trunk's three existing triggers cannot suffer this because they are
unconditional; the conditional guard is what makes the event order-sensitive
with respect to the number of saves.

**Why a committer would push back**

I could not find a path in core that saves the same issue twice inside one
transaction, so I am not claiming a bug in stock Redmine — that is why this is
`minor` and not `major`. But the exposure is real and it is one hook away:
`IssuesController#save_issue_with_child_records` (`app/controllers/issues_controller.rb:670`)
opens `Issue.transaction`, saves the issue, and then calls
`call_hook(:controller_issues_edit_after_save, …)` **inside** that transaction.
A plugin that does the very ordinary thing of setting a field and re-saving the
issue in that hook turns "user closed the issue" into "receiver got
`issue.updated` and never got `issue.closed`" — a missing delivery, which is
the failure mode a webhook receiver is least able to detect. The same shape
applies to `controller_issues_bulk_edit_before_save`, and to any future core
code that adds a second save under an existing transaction.

**How I verified it**

Probe in the patch worktree, webhooks enabled, one hook subscribed to
`issue.created` / `issue.updated` / `issue.closed`, reading the types of the
`WebhookJob`s actually enqueued:

```
R3 single save inside Issue.transaction        -> ["issue.closed", "issue.updated"]
R2 two saves inside one Issue.transaction      -> ["issue.updated"]              closed_on=true
R1 same, with a reload between the two saves   -> ["issue.updated"]              closed_on=true
```

R1/R2 are the finding: `closed_on` is set in the database and the event is
gone. R3 is the control, showing that the transaction wrapper alone is harmless.

While I was here I also chased the neighbouring worry and cleared it: a
reopen-then-reclose does **not** depend on `closed_on`'s column precision.
`closed_on` is `:datetime` with no precision, so MySQL stores whole seconds,
but the dirty comparison happens in memory against a full-precision `Time`, so
the second closing is always seen as a change. The dedicated test for that row
is green and I do not consider it flaky.

**Suggested direction**

Either accept it and say so in the dossier (one line: the event is derived from
the last save in a transaction, so a second save of the same issue inside one
transaction drops it), or make the signal survive more than one save — the
dossier's own "Alternatives considered" already discusses carrying the fact
across in per-instance state, and it prices that alternative on cost rather
than on this. Deciding between those is the fixing session's call; what should
not happen is the current situation where the behaviour is neither tested nor
mentioned.

**Resolution:** beschreven, niet gerepareerd, 2026-09-05 — bewust, en de reden staat in `decisions.md` onder "Ronde 2". Het gedrag is opnieuw gemeten op de nieuwe code en klopt precies zoals gemeld: één save binnen `Issue.transaction` levert `["issue.closed", "issue.updated"]`, twee saves van hetzelfde issue binnen één transactie leveren `["issue.updated"]` met `closed_on` wél gezet. Repareren vraagt een tweede callback plus per-instance state die na commit én na rollback gereset moet worden; geen enkel pad in core doet dit, dus dat is meer machinerie dan het gemeten risico rechtvaardigt (INV-1). Het staat nu als eigen punt onder "Backward compatibility" in het dossier, mét de plugin-route via `controller_issues_edit_after_save` erbij, zodat het benoemd is in plaats van stil — precies wat de bevinding als minimum vroeg

---

### F03 — "Every row of the transition table has a test" is not true for two and a half of the eight rows

- **Status:** resolved
- **Resolution:** beide kanten bewogen, 2026-09-05 — twee tests erbij en de claim vervangen door een expliciete opsomming. De eerste is de notitie op een gesloten issue (`should not trigger issue closed webhook when a note is added to a closed issue`), het enige bij *The problem* met name genoemde geval zonder assertie. De tweede kwam er alsnog bij toen de F07-fix het effect ervan zichtbaar maakte: rij 1 ("created with an open status") was gedekt door precies het toeval dat F07 wegneemt, dus na die fix stond die rij helemaal zonder dekking. Nu heeft hij zijn eigen bewaker (`should not trigger issue closed webhook when an issue is created with an open status`), en met de bewaking weggemuteerd vallen **5** van de acht overgangstests om in plaats van 4. Het dossier zegt nu: acht van de tien nieuwe tests zijn overgangstests, ze dekken **zeven** van de acht rijen, rij 7 twee keer (veldwijziging én notitie), en de enige rij zonder eigen test is "deleted" — met de reden erbij, want een `after_save_commit` kan door een destroy niet bereikt worden. Ook `status.md` zegt niet langer "elke rij heeft een test"
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `docs/features/webhook-issue-closed/status.md` ("**De tabel met de acht overgangen** … Elke rij heeft een test") and `dossier.md` ("Six of the eight are one row of the transition table each")
- **Invariant touched:** none

**What is wrong**

The eight rows map onto six tests, not eight:

| Row | Dedicated test |
|---|---|
| created with an open status → no | **none** |
| created directly with a closed status → yes | yes |
| open → closed → yes | yes (the end-to-end test) |
| closed → other closed status → no | yes |
| closed → open (reopened) → no | yes |
| reopened, then closed again → yes | yes |
| note **or** field edited while closed → no | field edit only; the note-only case is untested |
| deleted → no | **none** |

"Created with an open status" is covered incidentally — the end-to-end test
creates an open issue before its assertion block, and if that create wrongly
fired `issue.closed` the later `assert_equal 'Done', payload.dig('data',
'journal', 'notes')` would read the wrong job and fail (I confirmed exactly
that when I mutated the guard away). But that is a side effect of how the test
reads the queue (see F07), not an assertion about the row. "Deleted" has
nothing at all, though `after_save_commit` makes it structurally impossible for
a destroy to fire the event.

**Why a committer would push back**

Not for the missing tests themselves — the row that matters most, "deleted", is
unreachable by construction and a test for it would be near-worthless. The push
back is on the claim: the dossier presents the table as the specification and
says each row is pinned, and a reviewer who opens `webhook_test.rb` and counts
six new tests against eight rows finds a small discrepancy in the one document
that is supposed to make counting unnecessary. The note-only case is the one
genuinely worth closing: "a note added to an already-closed issue is not a
closing" is named in *The problem* as one of the edge cases receivers get
wrong, and it is the only such named case with no assertion behind it. I
verified it behaves correctly (`["issue.updated"]` only), so this is about
protecting behaviour that already works.

**How I verified it**

I drove all eight rows through one test process with a hook subscribed to all
four issue events and printed the types that reached the queue:

```
created open            -> ["issue.created"]
created closed          -> ["issue.closed", "issue.created"]
open->closed            -> ["issue.closed", "issue.updated"]
closed->closed2         -> ["issue.updated"]
closed->open            -> ["issue.updated"]
reopened->closed        -> ["issue.closed", "issue.updated"]
edit while closed       -> ["issue.updated"]
note only while closed  -> ["issue.updated"]
destroy closed          -> ["issue.deleted"]
```

Every row of the dossier's table is correct, including the note-only case that
the table folds into row 7. Then I read the six new tests in
`test/unit/webhook_test.rb` against the table to produce the mapping above.

**Suggested direction**

Either add the one assertion that is worth having (note-only on a closed issue)
and reword the claim to say which rows are covered by which test, or leave the
tests alone and make the claim match reality. The claim and the tests
disagreeing is the whole finding; which side moves is the fixing session's
choice.

**Resolution:** beide kanten bewogen, 2026-09-05 — twee tests erbij en de claim vervangen door een expliciete opsomming. De eerste is de notitie op een gesloten issue (`should not trigger issue closed webhook when a note is added to a closed issue`), het enige bij *The problem* met name genoemde geval zonder assertie. De tweede kwam er alsnog bij toen de F07-fix het effect ervan zichtbaar maakte: rij 1 ("created with an open status") was gedekt door precies het toeval dat F07 wegneemt, dus na die fix stond die rij helemaal zonder dekking. Nu heeft hij zijn eigen bewaker (`should not trigger issue closed webhook when an issue is created with an open status`), en met de bewaking weggemuteerd vallen **5** van de acht overgangstests om in plaats van 4. Het dossier zegt nu: acht van de tien nieuwe tests zijn overgangstests, ze dekken **zeven** van de acht rijen, rij 7 twee keer (veldwijziging én notitie), en de enige rij zonder eigen test is "deleted" — met de reden erbij, want een `after_save_commit` kan door een destroy niet bereikt worden. Ook `status.md` zegt niet langer "elke rij heeft een test"

---

### F04 — The locale argument has gone stale: `fr.yml` in current trunk has the sibling keys translated

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 (Jans g05 + g10) — de patch staat nu op r25037 en de localecijfers zijn op diezelfde revisie opnieuw geteld, met de revisie erbij vermeld zodat ze niet nog een keer stil kunnen verlopen: **49** niet-Engelse bestanden dragen de groep, **42** nog letterlijk Engels, **zeven** vertaald (`bg cs fr gl hu ja zh-TW`). `fr` is er tussen r24882 en r25037 bij gekomen; `nl`, `de` en `es` niet. De consequentie staat er expliciet bij en niet verstopt: een Franse beheerder ziet sinds r25037 drie vertaalde labels plus een Engels "Issue closed" — precies de half-Engelse uitkomst waartegen optie 3 argumenteerde, bereikt door optie 1 te nemen. Dat is een feit voor Jan bij **K-09**; de keuze zelf is niet heropend
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** i18n
- **Where:** `docs/features/webhook-issue-closed/dossier.md`, "Locales — why `en.yml` only"; the same facts in `status.md` and in the K-09 correction in `docs/DECISIONS.md`
- **Invariant touched:** INV-5 (not violated — this is about the facts the reasoning rests on, not about inventing a translation)

**What is wrong**

The locale section's factual base is measured against the patch's merge-base
`2563fa6a5`, where it is exactly right: 49 non-English files carry the three
sibling keys, 43 still hold the verbatim English string, and the six languages
that translated the group are `bg cs gl hu ja zh-TW` — none of them `nl`, `fr`,
`de` or `es`. On today's `origin/master` (`bee32a926`, 88 commits later) that is
no longer true: **`fr.yml` has been translated**, so it is 42 verbatim English
and seven translated languages, `fr` among them. The dossier's sentence "in all
four of those the three keys still read `\"%{object_name} created\"`" is now
wrong for French.

**Why a committer would push back**

They would not push back on the choice — this is Jan's K-09 and I am not
re-litigating it. They would notice that one of the three arguments *for* the
choice no longer holds. The dossier's option 3 is rejected because translating
one label of four would leave the fieldset half English; on current trunk a
French administrator now sees *Création de… / Mise à jour de… / Suppression
de…* plus an English "Issue closed", which is the half-and-half outcome the
argument was constructed to avoid, arrived at by taking option 1. That is a
fact Jan should have in front of him when he answers K-09, and it is the kind
of detail that reads badly if a French-speaking committer spots it before the
dossier does.

**How I verified it**

Counted the group across `config/locales/*.yml` in two pristine worktrees:

```
at 2563fa6a5 (patch base): files with the key 49; verbatim English 43; translated: bg cs gl hu ja zh-TW
at bee32a926 (current master): files with the key 49; verbatim English 42; translated: bg cs fr gl hu ja zh-TW
```

and read the values directly:

```
git show 2563fa6a5:config/locales/fr.yml -> webhook_event_created: "%{object_name} created"
git show origin/master:config/locales/fr.yml -> webhook_event_created: "Création de %{object_name}"
```

`nl.yml`, `de.yml` and `es.yml` are still verbatim English in both revisions.

**Suggested direction**

Re-measure the group against whatever trunk revision the patch is finally
submitted against, and put the numbers in with the revision they belong to so
they cannot silently go stale again. Whether the new fact changes K-09 is
Jan's call, not the fixing session's — but the fixing session should hand him
the corrected fact rather than the r24882 one.

**Resolution:** fixed 2026-09-05 (Jans g05 + g10) — de patch staat nu op r25037 en de localecijfers zijn op diezelfde revisie opnieuw geteld, met de revisie erbij vermeld zodat ze niet nog een keer stil kunnen verlopen: **49** niet-Engelse bestanden dragen de groep, **42** nog letterlijk Engels, **zeven** vertaald (`bg cs fr gl hu ja zh-TW`). `fr` is er tussen r24882 en r25037 bij gekomen; `nl`, `de` en `es` niet. De consequentie staat er expliciet bij en niet verstopt: een Franse beheerder ziet sinds r25037 drie vertaalde labels plus een Engels "Issue closed" — precies de half-Engelse uitkomst waartegen optie 3 argumenteerde, bereikt door optie 1 te nemen. Dat is een feit voor Jan bij **K-09**; de keuze zelf is niet heropend

---

### F05 — `closed` is kept out of the generic callback `case` on layering grounds, then put into the generic timestamp `case` anyway

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — de code is verplaatst, niet het argument. `lib/redmine/acts/webhookable.rb` staat weer exact op trunk en `Issue::Webhookable` overschrijft `webhook_payload_timestamp` voor `closed`. De patch raakt daarmee **geen enkel bestand onder `lib/redmine/`** meer, wat voor een los ingediend deelstuk het betere verhaal is. Kosten: twee regels productiecode meer (13 toegevoegd / 2 verwijderd over drie bestanden, was 8/3 over vier). Nagelopen dat er niets aan gedrag verandert: de generieke tak was alleen bereikbaar bij een sluiting zonder journaal, en de payloadtest die juist dat geval vastzet blijft groen. "Alternatives considered" behandelt nu allebei de plekken waar `closed` had kunnen landen, met per plek de reden
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `lib/redmine/acts/webhookable.rb:75` (the `when 'updated', 'closed'` branch) against `app/models/concerns/issue/webhookable.rb:24`
- **Invariant touched:** none

**What is wrong**

The patch makes an explicit architectural argument, and then contradicts it one
file later. "Alternatives considered" rejects a `when 'closed'` branch in
`acts_as_webhookable` because *"'Closed' is not a lifecycle event, it is a state
transition, and the predicate that recognises it exists only on `Issue`"* —
and so the callback lives in `Issue::Webhookable`. But
`webhook_payload_timestamp`, in that same generic file, gains `'closed'` next
to `'updated'`. So `lib/redmine/acts/webhookable.rb` now knows the name of an
action that only `Issue` can ever fire, while the thing that fires it is
deliberately elsewhere. `Issue::Webhookable` already overrides
`webhook_payload` for issue-specific behaviour, which is where a reader who has
just been told "closed is issue-specific" would look for it.

**Why a committer would push back**

This is not a defect and I can name no wrong output from it — that is why it is
`minor`. It is a reviewability cost: the dossier's strongest architectural
paragraph is a defence of a seam, and the patch crosses that seam in the very
file the paragraph is about. A reviewer reading the four production hunks in
order hits the generic `case` and asks "so is `closed` generic or not?", and the
answer is "both, in different files". Worth noting that the generic branch is
only reachable in one situation — a closing with no visible journal, i.e. an
issue created directly in a closed status — because `Issue::Webhookable`
overwrites the timestamp with the journal's whenever there is one. So the
generic layer is carrying an issue-only action name for a single fallback.

**How I verified it**

Read-only: `git show origin/master:lib/redmine/acts/webhookable.rb` against the
patched file, plus the `%w(updated closed).include?(action)` override in the
concern, plus the two new payload tests which pin both halves (journal present
→ journal timestamp; journal absent → `updated_on`). I did not test any
alternative arrangement.

**Suggested direction**

Make the two hunks tell one story: either the action name is generic enough to
live in `lib/redmine/acts/` (in which case say so and drop the "only `Issue`
can define the predicate" framing from the argument), or the timestamp mapping
belongs with the rest of the issue-specific webhook behaviour in
`Issue::Webhookable`. Either is defensible; the fixing session should pick the
one that keeps the dossier's paragraph true, and should weigh it against INV-1
since moving it costs a line or two more than the current one-word change.

**Resolution:** fixed 2026-09-05 — de code is verplaatst, niet het argument. `lib/redmine/acts/webhookable.rb` staat weer exact op trunk en `Issue::Webhookable` overschrijft `webhook_payload_timestamp` voor `closed`. De patch raakt daarmee **geen enkel bestand onder `lib/redmine/`** meer, wat voor een los ingediend deelstuk het betere verhaal is. Kosten: twee regels productiecode meer (13 toegevoegd / 2 verwijderd over drie bestanden, was 8/3 over vier). Nagelopen dat er niets aan gedrag verandert: de generieke tak was alleen bereikbaar bij een sluiting zonder journaal, en de payloadtest die juist dat geval vastzet blijft groen. "Alternatives considered" behandelt nu allebei de plekken waar `closed` had kunnen landen, met per plek de reden

---

### F06 — The transition table omits two cases that do fire `issue.closed`: a copy taken with `keep_status`, and every duplicate closed by cascade

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — twee rijen erbij in de overgangstabel, in dezelfde vorm als de bestaande, plus een alinea eronder. Beide zijn opnieuw gemeten op de nieuwe code: `copy_from(keep_status: true)` van een gesloten issue geeft `["issue.closed", "issue.created"]`, en het sluiten van een issue met één duplicaat geeft twee keer `issue.closed` en twee keer `issue.updated`. De alinea zegt er ook bij dat het geërfd gedrag is (`update_attribute` draait callbacks, `issue.updated` doet op dezelfde paden hetzelfde) en dus niets wat deze patch beslist — de cascade is het punt dat een ontvanger vooraf wil weten. Geen codewijziging, zoals de bevinding voorstelde
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/webhook-issue-closed/dossier.md`, "Which transitions fire, and which do not"
- **Invariant touched:** none

**What is wrong**

The table is presented as the complete specification ("that table is the whole
specification of the feature"). Two reachable core paths produce
`issue.closed` and are not in it:

1. **Copying a closed issue with "keep status"** — the copy is a new record in
   a closed status, so `closing?` is true for it and the event fires alongside
   `issue.created`. This is available in the UI (single copy and bulk copy) and
   in the API.
2. **`close_duplicates`** — closing an issue closes every issue that duplicates
   it, via `duplicate.update_attribute :status`, which runs callbacks. One
   user action therefore produces `issue.closed` for N+1 issues.

Both behaviours are, I think, right: those issues genuinely were closed, and
`issue.updated` already behaves the same way. Neither is a defect. But (2) is
the one a receiver author would want to know about, because a single status
change in the UI can deliver several `issue.closed` events for issues the user
never opened.

**Why a committer would push back**

They probably would not push back at all — this is a nit and I have marked it
so. It earns its place because the table is doing double duty as the issue
text, and "what about duplicates?" is a natural committer question that the
dossier could answer before it is asked, in one row, at no cost to the patch.

**How I verified it**

Probes with a hook subscribed to all four issue events, reading the enqueued
job types:

```
copy_from(src, keep_status: true) then save  -> ["issue.closed", "issue.created"]   closed_on set
copy_from(src) then save                     -> ["issue.created"]                    status New
close a main issue that has one duplicate    -> ["issue.closed", "issue.updated", "issue.closed", "issue.updated"]
                                                (duplicate closed, closed_on set)
```

I also confirmed the negative case the dossier does cover: flipping an existing
`IssueStatus` to `is_closed` fires nothing (`[]`) while backfilling `closed_on`
through `update_all`, exactly as the objections table says.

**Suggested direction**

Two more rows, phrased as the existing ones are. No code change.

**Resolution:** fixed 2026-09-05 — twee rijen erbij in de overgangstabel, in dezelfde vorm als de bestaande, plus een alinea eronder. Beide zijn opnieuw gemeten op de nieuwe code: `copy_from(keep_status: true)` van een gesloten issue geeft `["issue.closed", "issue.created"]`, en het sluiten van een issue met één duplicaat geeft twee keer `issue.closed` en twee keer `issue.updated`. De alinea zegt er ook bij dat het geërfd gedrag is (`update_attribute` draait callbacks, `issue.updated` doet op dezelfde paden hetzelfde) en dus niets wat deze patch beslist — de cascade is het punt dat een ontvanger vooraf wil weten. Geen codewijziging, zoals de bevinding voorstelde

---

### F07 — The end-to-end test reads the first `WebhookJob` in the queue, not the job its own assertion block enqueued

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — de test onthoudt `enqueued_jobs.size` vóór het `assert_enqueued_jobs`-blok en leest daarna `enqueued_jobs.drop(jobs_before)`. Daarmee wijst een fout in deze test naar de aflevering van de sluiting en niet meer naar een payload van de create, wat precies het verkeerde-reden-falen was dat de review met een mutatie aantoonde. Eén regel erbij en één regel gewijzigd; de rest van de test is ongemoeid gelaten (INV-1). **Met de prijs erbij, want die is echt:** de mutatie opnieuw gedraaid ná de fix laat deze test gewoon slagen — het toevallige vangnet is weg. Dat was precies de dekking die F03 voor rij 1 van de overgangstabel telde, dus die rij heeft er een eigen bewaker bij gekregen (zie F03). Netto vangen nu **5** tests de weggemuteerde bewaking in plaats van 4, en geen ervan bij toeval
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/unit/webhook_test.rb:248`
- **Invariant touched:** none

**What is wrong**

`assert_enqueued_jobs 1, only: WebhookJob do … end` correctly scopes the count
to the block, but the four assertions that follow do not:
`enqueued_jobs.detect{|job| job[:job] == WebhookJob}[:args]` takes the
**first** `WebhookJob` in the whole process-wide queue. Today there is exactly
one, so it is the right job and the test is correct. It stops being correct the
moment anything before the block enqueues a `WebhookJob` — and the test itself
creates an issue before the block, which is precisely the thing that would
enqueue one if the feature regressed.

**Why a committer would push back**

They would probably not notice, and it is not wrong today — hence `nit`. It is
worth writing down because of what I found when I mutated the code: deleting
the `if saved_change_to_closed_on?` guard makes this test fail, and it fails
**for the wrong reason** — `Issue.generate!` before the block starts firing
`issue.closed`, that job lands first in the queue, and
`assert_equal 'Done', payload.dig('data', 'journal', 'notes')` reads the
create-time payload and finds no journal. The test caught the regression by
accident rather than by design. A test that catches bugs accidentally will
stop catching them after an innocent-looking edit.

**How I verified it**

Mutated `app/models/concerns/issue/webhookable.rb` to drop the guard, then ran
the six new `webhook_test` tests: **6 runs, 13 assertions, 4 failures** —
`should not trigger … reopened`, `… moves to another closed status`, `… is
updated`, and this end-to-end test, the last of them failing at line 253 (the
journal-notes assertion) rather than on the job count. The two survivors were
the two `.once` tests, which the guard removal does not affect. Restored the
file afterwards; the worktree was thrown away.

**Suggested direction**

Read the job the block produced rather than the queue's first entry — the
assertion block can capture it, or the queue can be read relative to its length
before the block. What good looks like is that a failure in this test points at
the closing delivery and not at a create-time payload.

**Resolution:** fixed 2026-09-05 — de test onthoudt `enqueued_jobs.size` vóór het `assert_enqueued_jobs`-blok en leest daarna `enqueued_jobs.drop(jobs_before)`. Daarmee wijst een fout in deze test naar de aflevering van de sluiting en niet meer naar een payload van de create, wat precies het verkeerde-reden-falen was dat de review met een mutatie aantoonde. Eén regel erbij en één regel gewijzigd; de rest van de test is ongemoeid gelaten (INV-1). **Met de prijs erbij, want die is echt:** de mutatie opnieuw gedraaid ná de fix laat deze test gewoon slagen — het toevallige vangnet is weg. Dat was precies de dekking die F03 voor rij 1 van de overgangstabel telde, dus die rij heeft er een eigen bewaker bij gekregen (zie F03). Netto vangen nu **5** tests de weggemuteerde bewaking in plaats van 4, en geen ervan bij toeval

---

### F08 — Passing the full event list means `Issue` stops inheriting future additions to `acts_as_webhookable`'s default

- **Status:** resolved
- **Resolution:** benoemd in het dossier, code ongewijzigd, 2026-09-05 — de expliciete lijst blijft. De optelling schrijven vraagt om de default `%w(created updated deleted)` uit `Redmine::Acts::Webhookable` naar buiten te halen, en dat is een wijziging in juist de generieke laag die deze patch na F05 helemaal met rust laat. De afweging staat nu als eigen alinea onder de bestandstabel: `Issue` is het enige model dat niet meebeweegt als die default ooit een generieke actie krijgt, en het faalgedrag daarvan is stilte
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `app/models/issue.rb:63`
- **Invariant touched:** none

**What is wrong**

`acts_as_webhookable` defaults to `%w(created updated deleted)` and all five
webhookable models take that default. The patch changes `Issue` to pass
`%w(created updated closed deleted)` explicitly. Functionally identical today,
and I confirmed the registry and the form pick it up in the intended order. But
`Issue` is now the one model pinned to a literal list: if a later change adds a
generic action to the default, every model gains it except the busiest one, and
nothing will fail — the event just quietly will not exist for issues.

**Why a committer would push back**

They would probably accept it as the smallest possible diff, and it is one line
either way, which is why this is a `nit` and not a design finding. It is worth
one sentence in the dossier because the failure mode is silence: a future
default gains an action, `Issue` does not, and the only symptom is a missing
checkbox that nobody is looking for.

**How I verified it**

Read `lib/redmine/acts/webhookable.rb`, the four other `acts_as_webhookable`
call sites, and `app/views/webhooks/_form.html.erb` (which renders the
checkboxes in registration order, so the new box lands between "Issue updated"
and "Issue deleted" as the dossier's screenshots claim). Not executed beyond
the suites above.

**Suggested direction**

Either note the trade-off in the dossier in one line, or express the change as
an addition to the default rather than a replacement of it. Both are one line;
the fixing session should weigh which reads better to a committer against
INV-1.

**Resolution:** benoemd in het dossier, code ongewijzigd, 2026-09-05 — de expliciete lijst blijft. De optelling schrijven vraagt om de default `%w(created updated deleted)` uit `Redmine::Acts::Webhookable` naar buiten te halen, en dat is een wijziging in juist de generieke laag die deze patch na F05 helemaal met rust laat. De afweging staat nu als eigen alinea onder de bestandstabel: `Issue` is het enige model dat niet meebeweegt als die default ooit een generieke actie krijgt, en het faalgedrag daarvan is stilte

---

### F09 — On an issue created directly in a closed status, `issue.closed` is enqueued before `issue.created`

- **Status:** resolved
- **Resolution:** benoemd in het dossier, code ongewijzigd, 2026-09-05 — omkeren kan niet zonder iets kapot te maken: de concern móet ná `acts_as_webhookable` geïncludeerd worden, anders staat `Redmine::Acts::Webhookable::InstanceMethods` bóven `Issue::Webhookable` in de ancestor-keten en wordt de `webhook_payload`-override nooit aangeroepen. De compatibiliteitsnotitie zegt het daarom expliciet voor het paar waar de volgorde betekenis heeft: bij een issue dat direct in een gesloten status wordt aangemaakt komt `issue.closed` vóór `issue.created` in de wachtrij (opnieuw gemeten), dus een ontvanger die zijn eigen record op `issue.created` aanmaakt moet een sluiting kunnen verdragen voor een issue dat hij nog niet kent. Voor het paar `issue.updated`/`issue.closed` is elke volgorde onschadelijk en dat stond er al
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/models/concerns/issue/webhookable.rb:24` (registration order relative to `lib/redmine/acts/webhookable.rb:35`)
- **Invariant touched:** none

**What is wrong**

Rails runs `after_commit` callbacks in reverse registration order (Redmine does
not set `load_defaults`, so the framework's legacy ordering applies), and the
concern is included after `acts_as_webhookable` runs. The new callback
therefore fires first, and for an issue created directly in a closed status the
queue receives `issue.closed` and then `issue.created`. Both jobs go to the
same queue, so a single worker will most likely deliver them in that order: a
receiver is told an issue was closed before it is told the issue exists.

**Why a committer would push back**

The dossier already says the order is not guaranteed and no receiver should
depend on it, which is the correct position, so this is a `nit`. But the
disclaimer is written about the `issue.updated`/`issue.closed` pair, where
either order is harmless. The `issue.created` pair is the one where order has a
meaning — "closed" arriving first is not merely unordered, it is backwards —
and a receiver that creates its local record on `issue.created` will drop or
error on the closing. It costs one sentence to say so.

**How I verified it**

Enqueued job types, read in queue order, from the probe above:

```
created closed -> ["issue.closed", "issue.created"]
open->closed   -> ["issue.closed", "issue.updated"]
```

The existing test for this row (`should trigger issue closed webhook when an
issue is created with a closed status`) asserts each event fires once and does
not assert order, which is consistent with the dossier's position.

**Suggested direction**

Say it explicitly in the compatibility notes: for a create-in-closed-status,
both events fire and `issue.closed` currently reaches the queue first, so a
receiver must tolerate a closing for an issue it has not seen. If instead the
intent is that `issue.created` should always precede it, that is a callback
registration question and belongs to the fixing session, not to me.

**Resolution:** benoemd in het dossier, code ongewijzigd, 2026-09-05 — omkeren kan niet zonder iets kapot te maken: de concern móet ná `acts_as_webhookable` geïncludeerd worden, anders staat `Redmine::Acts::Webhookable::InstanceMethods` bóven `Issue::Webhookable` in de ancestor-keten en wordt de `webhook_payload`-override nooit aangeroepen. De compatibiliteitsnotitie zegt het daarom expliciet voor het paar waar de volgorde betekenis heeft: bij een issue dat direct in een gesloten status wordt aangemaakt komt `issue.closed` vóór `issue.created` in de wachtrij (opnieuw gemeten), dus een ontvanger die zijn eigen record op `issue.created` aanmaakt moet een sluiting kunnen verdragen voor een issue dat hij nog niet kent. Voor het paar `issue.updated`/`issue.closed` is elke volgorde onschadelijk en dat stond er al

---

### F10 — Should the `closed_on` guard carry a one-line "why"?

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — Jan heeft dit beslist als **g16e**: de bewaking krijgt één regel waarom. Die regel staat nu boven de callback in `app/models/concerns/issue/webhookable.rb` en zegt waarom het sluitveld het signaal is en niet de status. INV-3 verbiedt commentaar dat herhaalt wat een regel doet, niet commentaar dat een niet-vanzelfsprekend waarom vastlegt; trunk zelf doet hetzelfde twee methodes verderop in `issue.rb`. De vraag is daarmee gesloten
- **Severity:** question
- **Confidence:** n/a
- **Category:** conventions
- **Where:** `app/models/concerns/issue/webhookable.rb:24`
- **Invariant touched:** INV-3

**What is wrong**

Nothing is wrong. This is a question for Jan because it sits on the INV-3 line
and I will not decide it. The whole correctness argument for this patch is
"`closed_on` is written by exactly one place in core, `update_closed_on`, and
it is not a safe attribute, so a save that wrote `closed_on` *is* a closing" —
two paragraphs of dossier behind a five-word guard. INV-3 forbids comments that
restate what code does but allows one for a non-obvious *why*, and this looks
like the textbook case. Trunk itself has a comment of exactly this kind two
methods further down the same concern's neighbour, at `app/models/issue.rb:1976`:
*"Attachment removal via AJAX saves only the journal, so the usual issue update
callback does not fire."*

**Why a committer would push back**

They would not push back either way — a committer might equally well ask for
the comment or leave it. The reason to raise it is that the next person to touch
`update_closed_on` or `closing?` is the one who needs the sentence, and they
will not be reading this dossier.

**How I verified it**

Read `git grep -n "closed_on" origin/master -- app lib` (the only writer in
core is `update_closed_on`, plus two `update_all` statements in
`IssueStatus#handle_is_closed_change` which run no callbacks), and confirmed
`closed_on` appears in no `safe_attributes` list and only as a read in the API
templates. So the dossier's premise is true, which is what makes the question
worth asking rather than answering.

**Suggested direction**

Jan's call: one comment naming *why* `closed_on` is a sufficient signal, or
nothing and the reasoning stays in the dossier and the issue text only.

**Resolution:** fixed 2026-09-05 — Jan heeft dit beslist als **g16e**: de bewaking krijgt één regel waarom. Die regel staat nu boven de callback in `app/models/concerns/issue/webhookable.rb` en zegt waarom het sluitveld het signaal is en niet de status. INV-3 verbiedt commentaar dat herhaalt wat een regel doet, niet commentaar dat een niet-vanzelfsprekend waarom vastlegt; trunk zelf doet hetzelfde twee methodes verderop in `issue.rb`. De vraag is daarmee gesloten

---

## Things I checked that are not findings

Recorded so that a second reviewer does not spend the afternoon I spent, and so
that "clean" here means checked rather than unexamined.

- **Backward compatibility, the patch's central claim — holds.** A hook whose
  `events` array contains only `issue.updated` receives exactly
  `["issue.updated"]` when an issue is closed. `hooks_for` filters with
  `hook.events.include?(event)`, so there is no "empty list means all"
  convention in this code to preserve: an `events: []` hook is valid, saves,
  and matches nothing — `hooks_for` returns 0 for both `issue.closed` and
  `issue.updated`, before and after the patch. A NULL `events` column reads
  back as `[]` (the `serialize … type: Array` coercion) and raises nothing.
  Existing values stay valid because `check_events_array` only ever gains
  permitted names.
- **All eight transition-table rows are correct**, measured against the job
  queue, including the two the dossier names as the subtle ones. The table is
  the best part of this dossier and it survives contact.
- **`update_all` and bulk operations behave as the dossier says.** Flipping an
  `IssueStatus` to `is_closed` fires nothing while backfilling `closed_on`
  through two `update_all` statements. Bulk edit is a loop of `issue.save`
  (`issues_controller.rb:390-410`), so three closes give three jobs — measured.
  The REST API and any rake task using `Issue#save` take the same path as the
  UI. There is no `update_all(:status_id => …)` anywhere in core.
- **Cost with webhooks absent or disabled — the claim that matters holds.**
  Zero `webhooks` queries on every save path with `webhooks_enabled = 0`,
  because the guard is an in-memory dirty check and `Webhook.trigger` reads the
  cached `Setting` before touching the database. The overstatement is narrower
  than the objection and is F01.
- **Reopen-then-close-again fires a second time, is tested, and is not
  precision-dependent** — see the closing note of F02.
- **The tests are not vacuous.** Removing the guard turns 4 of the 6 new
  `webhook_test` tests red. The end-to-end test does prove what it claims
  (exactly one job, right hook, right type, right issue, right journal note) —
  it just reads the job loosely, which is F07.
- **No test pollution found.** The new tests define no constants, load no rake
  files and leave no global state; `generate_closed_issue` is a local helper in
  the private section, and the dossier's decision not to touch `create_hook`
  avoids the 17-test breakage noted for `webhook-tracker-filter`. Three
  multi-file runs (with `issue_test`, with `issues_controller_test`, with the
  i18n test) and three seeds are all green.
- **i18n mechanics are right.** `webhook_event_closed` sits with its three
  siblings in lifecycle order, matching the group's existing non-alphabetical
  order; the form's key is `webhook_event_#{action}` with a
  `:default => name.gsub('.', ' ').humanize` fallback, so the label reads
  "Issue closed" even with no key at all; Redmine's own locale consistency test
  passes. **K-09 (en-only) I treated as Jan's settled position and did not
  re-argue** — F04 is a correction to a fact the reasoning uses, not a request
  to change the choice.
- **INV-4 and INV-10.** Neither `32a1b691d` nor `827e9e7d5` carries an
  attribution trailer, session link, model name or "generated by". The GEOxyz
  commit's diff is identical to the patch's diff with `index` and hunk lines
  filtered out.
- **INV-2 and patch hygiene.** The exported patch file's diffstat matches the
  branch (6 files, 109 insertions, 3 deletions) and `git apply --check` is
  clean against `origin/master` at `bee32a926` — 88 commits past its stated
  base. Of those 88 commits, the only ones touching this patch's territory
  change `Webhook#setable_projects` and one unrelated `en.yml` label, neither
  of which interacts. No rebase is needed before submission.
- **Minimality.** Zero lines in the production diff that the feature does not
  need. No reformatting, no renaming, no tidied neighbours. I looked for the
  usual scope creep and there is none.
- **Scope.** One change, one issue, correctly split from `webhook-tracker-filter`.
  The dossier's refusal to add `closed` to `Version` in the same patch is the
  right instinct.
- **Not applicable to this patch:** database portability (no new SQL, no new
  column, no comparison against a column), SCM adapter symmetry, authorization
  (no new controller action, no new permission, and `hooks_for` still gates on
  `visible?` and `use_webhooks`), escaping (nothing new reaches a view), and
  settings surface (no new setting).
