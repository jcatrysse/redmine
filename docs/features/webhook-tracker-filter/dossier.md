# webhook-tracker-filter — limit an outgoing webhook to the trackers you choose

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** een webhook vuurt nu bij élke issue in de
  gekozen projecten. Met deze wijziging kun je aanvinken vóór welke trackers hij
  mag vuren; vink je niets aan, dan vuurt hij zoals altijd voor alles.
- **Waar het vandaan komt:** 5.1-commit `25220b45d` (het deel met
  `trackers_webhooks`). Die commit bouwde de hele webhookfunctie zelf; upstream
  heeft die functie inmiddels, dus hier blijft alleen het trackerfilter over.
- **Doel:** upstream + GEOxyz.
- **Afwijking GEOxyz ↔ upstream:** geen. Beide branches krijgen letterlijk
  dezelfde code, dezelfde migratie en dezelfde vertalingen.
- **Kans dat Redmine dit aanneemt:** goed. Holger Just heeft in note 37 van
  [#29664](https://www.redmine.org/issues/29664) letterlijk gevraagd om je
  monolithische 5.1-patch op te splitsen in losse patches met per stuk een
  probleembeschrijving. Dit ís zo'n stuk, en het is precies punt 1 van je eigen
  note 36. Het ontwerp kopieert bovendien het bestaande projectenfilter, dus er
  is weinig nieuw om over te discussiëren.
- **Wat jij nog moet doen:** één nieuw issue aanmaken op redmine.org als
  follow-up van #29664, en de twee patchbestanden eraan hangen. De Engelse
  tekst staat hieronder vanaf "The problem", kant-en-klaar.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `2563fa6a5` van 2026-08-03 (r24882). Dat is de
  stand van de fork-mirror; die loopt achter op de echte SVN-trunk.
- **Lost trunk dit al op?** Nee — maar de context is compleet veranderd sinds
  de 5.1-commit, en dat is de belangrijkste uitkomst van deze check.
  **Webhooks zitten inmiddels ín Redmine core.** Marius Bălteanu heeft ze
  ingevoerd op 2025-10-07 (`d90d192f4`, [#29664](https://www.redmine.org/issues/29664))
  en er staan 25 commits op: events voor `Issue`, `News`, `WikiPage`,
  `TimeEntry` en `Version`, een `:use_webhooks`-permissie, een
  aan/uit-instelling, HMAC-ondertekening, en een reeks
  beveiligingsverscherpingen op de doel-URL. De hele 5.1-commit `25220b45d`
  hoeft dus niet opnieuw ingediend te worden; er is precies één ding dat
  upstream níet heeft, en dat is het trackerfilter.
  `Webhook` heeft `has_and_belongs_to_many :projects` en verder geen enkele
  manier om te bepalen wélke issues een hook mogen laten vuren.
- **Bestaand issue op redmine.org?** Gezocht op het enkele trefwoord `webhook`
  (22 issues). Niets over trackers of over het beperken van een hook binnen een
  project. Wel twee die er tegenaan liggen:
  - [#29664](https://www.redmine.org/issues/29664) — de webhookfunctie zelf,
    gesloten, target version 7.0.0. In **note 36** (2025-12-02) somt Jan
    Catrysse zijn zes uitbreidingen op, waarvan de eerste "An option to select
    trackers" is. In **note 37** (2025-12-02, 20:16) antwoordt Holger Just
    verbatim: *"In order for us to be able to use your work in a future Redmine
    version (such as 7.0), please rebase your patch on top of the latest trunk
    (which contains the current status of the webhooks feature). Your current
    monolithic patch duplicates a lot of exisging functionality and appears to
    subtly change some parts. This makes the patch very hard to review. To be
    able to more easily evaluate your proposed changes, it is often helpful to
    extract the different changes in separate patches and to describe why you
    are proposing your specific changes, i.e. which specific problem they solve
    and (if applicable) why you chose your specific approach. With more
    manageable and up-to-date patches, your changes may become part of a future
    Redmine release."* Deze patch is het antwoord op die note.
  - [#44337](https://www.redmine.org/issues/44337) — "Add an administration page
    listing all webhooks", open. Dat is punt 4 van note 36, een aparte feature,
    en de reden dat deze patch de webhooklijst met opzet niet aanraakt.
- **Verandert iets in trunk het ontwerp?** Ja, twee dingen.
  1. `acts_as_webhookable` (`d43437161`, 2026-02-22) maakt de webhooklaag
     generiek over vijf modeltypes. Een trackerfilter geldt alleen voor issues,
     dus het moet zo geschreven zijn dat het de andere vier nooit tegenhoudt.
     Dat bepaalt de vorm van `Webhook#matches_tracker?`.
  2. [#44386](https://www.redmine.org/issues/44386) is ná de mirror-datum
     gesloten (r25011, "Use pluck in before_validation to compare webhook ids"):
     een N+1 in `Webhook#setable_projects`. Dat is dus een levend aandachtspunt
     in precies dit bestand, en de reden dat deze patch `preload(:trackers)`
     meeneemt in plaats van per hook een query te doen — met meting hieronder.
     De patch raakt `setable_projects` zelf niet aan, dus r25011 en deze patch
     bijten elkaar niet.

---

# The problem

Redmine 7.0 lets a user register a webhook for a set of events across a set of
projects. There is no way to narrow it any further. A hook that subscribes to
`issue.created` in a project fires for every issue in that project, whatever
its tracker.

That is coarser than the way most projects are actually organised. A project
commonly carries several trackers for genuinely different kinds of work —
customer-facing requests next to internal bugs, or a tracker that feeds an
external planning or invoicing system next to trackers that do not. When only
one of those has an integration behind it, Redmine currently posts every issue
of every other tracker to that endpoint as well, and the receiver has to look
at the payload and throw most of it away.

Two consequences, and the second is the one that matters:

- Every issue event in the project is a POST. The receiver is called for work it
  will discard, and every discarded call is still a request Redmine made,
  retried nothing for, and logged nothing about.
- **The endpoint sees issue data it has no reason to see.** A webhook payload is
  a full issue rendering — subject, description, journal notes, custom fields.
  Selecting projects is the only way to control what leaves the installation, so
  a single tracker with an integration forces the whole project's issue traffic
  out to that endpoint. Filtering on the receiving side does not help: by then
  the data has already left. Splitting the trackers into separate projects to
  get the granularity means reorganising the project structure to work around
  the webhook configuration.

`Webhook#hooks_for` already narrows per hook in Ruby — on the event list, on
whether the hook's user can see the object, and on that user's `:use_webhooks`
permission. There is simply no tracker among the things it can narrow on.

# Why this belongs in core

The decision is taken inside `Webhook.hooks_for`, called from
`Webhook.trigger`, which is itself called from the `after_*_commit` callbacks
installed by `acts_as_webhookable`. A plugin that wanted to filter there would
have to monkey-patch `Webhook.hooks_for` or `Webhook.trigger` and keep that
patch in step with the method's signature and its hand-written join — a method
that has been reworked twice since October 2025 and is under active
development.

It also needs to be stored on the hook. A hook is a core model with a core
form and a core controller; a plugin adding a tracker selection would need its
own join table keyed to `webhooks.id`, its own fields injected into
`webhooks/_form`, its own strong parameters into `WebhooksController`, and its
own cleanup when a webhook or a tracker is destroyed. That is a plugin that
exists only to add one column's worth of configuration to a core screen.

Honest counterpoint: a receiver *can* filter. If the only concern were the
number of requests, filtering on the receiving side would be an acceptable
answer and this patch would be a convenience. It is the second consequence
above — issue content leaving the installation for trackers that have no
integration — that a receiver cannot fix, because it only sees the data after
it has been sent.

# Proposed change

A webhook gains a set of trackers, the same way it already has a set of
projects. Behaviour:

- Trackers selected → the hook's **issue** events fire only for issues of those
  trackers. Its other events are unaffected.
- No tracker selected → the hook fires for every tracker. This is the existing
  behaviour, and it is what every hook has after an upgrade.
- Events for objects that have no tracker (`News`, `WikiPage`, `TimeEntry`,
  `Version`) are never filtered, whatever is selected.

| File | Change |
|---|---|
| `db/migrate/20260903081500_create_trackers_webhooks.rb` | new join table `trackers_webhooks`, the same shape as the `projects_webhooks` table created by `CreateWebhooks` |
| `app/models/webhook.rb` | `has_and_belongs_to_many :trackers`; `preload(:trackers)` in `hooks_for`; new `matches_tracker?(object)` used by `hooks_for` |
| `app/controllers/webhooks_controller.rb` | permit `tracker_ids: []` |
| `app/views/webhooks/_form.html.erb` | a `Trackers` fieldset next to the existing `Projects` one, a check box per tracker, and a hint saying what leaving them all unchecked means |
| `config/locales/en.yml` | one new key, `webhook_trackers_info` |

The whole decision is one line:

```ruby
def matches_tracker?(object)
  tracker_ids.blank? || !object.respond_to?(:tracker_id) || tracker_ids.include?(object.tracker_id)
end
```

`respond_to?(:tracker_id)` rather than `is_a?(Issue)` because the webhook layer
is generic over model types. Of the five models that currently
`acts_as_webhookable`, only `Issue` responds to `tracker_id` (verified), so the
two are equivalent today — but a model that later becomes webhookable without
having a tracker is then never filtered, which is the safe direction. A model
that does have a tracker gets the filter for free.

**New setting / migration / gem / route / permission:** one migration, no
setting, no gem, no route, no permission.

The migration is unavoidable: the selection is per hook and per tracker, so it
is a many-to-many. It mirrors the `projects_webhooks` table that
`CreateWebhooks` already creates in the same feature — same column types, same
`null: false`, same single-column indexes, same implicit primary key — so the
two join tables on `Webhook` stay identical in shape.

There is deliberately **no setting**. The filter is per hook, which is where the
knowledge lives; an installation-wide switch would answer a question nobody
asked. And deliberately **no permission**: Redmine has no per-tracker
permission to hang one on, and the filter only ever narrows what a hook sends,
so it cannot widen anyone's access. Every existing check in `hooks_for`
(visibility of the object to the hook's user, `:use_webhooks` on the project)
still runs unchanged.

**Translations** (INV-5 — every row names the existing key it was patterned on).
One new key, `webhook_trackers_info`, in all five locales this work ships:

| Locale | Text | Derived from, in the same file |
|---|---|---|
| en | Issue events are only sent for the selected trackers. Leave all trackers unchecked to send them for every tracker. | `webhook_url_info`, the hint directly above it on the same form |
| nl | Issue-gebeurtenissen worden alleen verstuurd voor de geselecteerde trackers. Als u geen enkele tracker selecteert, worden ze voor alle trackers verstuurd. | *issue* → `label_issue: Issue`; *gebeurtenis* → `label_user_mail_option_all` ("Bij elke gebeurtenis in al mijn projecten"); *verstuurd* and *selecteer* → `text_select_mail_notifications` ("Selecteer acties waarvoor mededelingen via e-mail moeten worden verstuurd"); *geselecteerde* → `label_user_mail_option_selected`; *trackers* → `label_tracker_plural`; *alle* → `field_is_for_all`. `nl.yml` has no check-box vocabulary at all (no "aanvinken", no "vinkje"), which is why the second sentence says *selecteert* rather than translating "unchecked" literally, and the formal *u* follows `text_user_mail_option`. |
| fr | Les événements de demande ne sont envoyés que pour les trackers sélectionnés. Si aucun tracker n'est sélectionné, ils sont envoyés pour tous les trackers. | *demande* → `label_issue: Demande`; *envoyés* → `text_select_mail_notifications` ("une notification par e-mail est envoyée"); *sélectionnés* → `text_user_mail_option` ("Pour les projets non sélectionnés"); *aucun tracker* → `error_no_tracker_allowed_for_new_issue_in_project`; *tous les trackers* → `label_tracker_all` verbatim. **One word is not derived:** `fr.yml` contains no occurrence of *événement* anywhere, so there is nothing to pattern it on. It is the ordinary French word and not a Redmine domain term, and the two terms that *are* contested (*demande*, *trackers*) are both cited above. Also note `fr.yml`'s single existing *selectionnée* (in `text_issues_destroy_confirmation`) is missing its accent; the correctly accented form from `text_user_mail_option` was followed instead of copying that typo. |
| de | Ticket-Ereignisse werden nur für die ausgewählten Tracker gesendet. Wird kein Tracker ausgewählt, werden sie für alle Tracker gesendet. | *Ticket* → `label_issue: Ticket`; *Ereignisse* → `label_webhook_events: Ereignisse`; *ausgewählten* → the German `webhook_url_info` right above it ("in einem der ausgewählten Projekte"); *Tracker* (unchanged in the plural) → `label_tracker_plural: Tracker`; *alle* → `field_is_for_all` |
| es | Los eventos de peticiones solo se envían para los tipos seleccionados. Si no selecciona ningún tipo, se envían para todos los tipos. | *peticiones* → `label_issue_plural: Peticiones`; *eventos* → `label_user_mail_option_all` ("Para cualquier evento en todos mis proyectos") and `text_select_mail_notifications` ("Seleccionar los eventos a notificar"); *solo* → `label_user_mail_option_only_my_events`; *se envían* → `notice_email_sent` ("Se ha enviado un correo"); *seleccionados* → `label_bulk_edit_selected_issues`; *ningún* → `label_none: ninguno`; *todos los tipos* → `label_tracker_all` verbatim. **Spanish is the one that proves the rule:** in `es.yml` a tracker is a **tipo**, not a "tracker" (`label_tracker: Tipo`, `label_tracker_plural: Tipos de peticiones`). A sentence composed from the English would have said *trackers* and clashed with the fieldset legend printed directly above it — visible in `shots/hint-es.png`. |

Honest note on `nl`, `fr` and `es`: in those three files the two sibling hints
on this same form (`webhook_url_info` and `webhook_secret_info_html`) are still
the untranslated English strings — only `de.yml` has that block translated. So
after this patch the Trackers hint is in the user's language while the two hints
above it are not, which `shots/webhook-form-es.png` shows plainly. Redmine's own
process is that translations for a new feature arrive as separate per-language
issues from the language teams (#43423 Japanese, #43468 Bulgarian, #43471 and
#43847 Traditional Chinese, #44323 French — all webhook strings), and
`config.i18n.fallbacks` is `true`, so dropping the three costs nothing but the
translation. They are in a **separate patch file** from the feature precisely so
that a reviewer who would rather leave them to the language teams can take the
feature patch alone and discard the other. Say the word and they come out.

**Backward compatibility:** an existing hook has no row in `trackers_webhooks`,
`tracker_ids` is empty, `matches_tracker?` returns `true`, and the hook fires
exactly as it did before. Nothing is required of anyone on upgrade, and there is
no data migration. The empty list keeps meaning "all", and the two delivery
screenshots below show that being true in a running instance rather than
asserted.

# Alternatives considered

**Require at least one tracker when issue events are selected.** This is what
the GEOxyz 5.1 implementation did (`validate_trackers` adds an error on
`:trackers` when any `issue.*` event is selected and no tracker is chosen). It
makes the setting explicit and avoids the empty-means-all ambiguity, and it is
the single biggest reason that implementation is not what is proposed here: it
would make every existing hook invalid on upgrade, so the first time anyone
saved one it would refuse, and any code path that re-saves a hook would start
failing. Rejected on backward compatibility.

**Offer only the trackers of the projects selected on the hook.** Also what the
5.1 implementation did (`setable_trackers` walked the user's setable projects
and collected their trackers). Rejected for three reasons: the tracker list
would have to change as project check boxes are ticked, which means JavaScript
and a second endpoint for a list of three items; it puts a per-project
association walk into the same model whose project lookup a committer had just
optimised for N+1 (#44386); and it buys nothing, because selecting a tracker no
project uses simply means the hook never matches it. The form therefore offers
`Tracker.sorted`, which is how every other tracker check box list in Redmine is
built (`custom_fields/_visibility_by_tracker_selector`, `roles/_form`,
`workflows/edit`, `workflows/permissions`, `settings/_projects`,
`settings/_repositories`).

**Filter in SQL instead of in Ruby.** `hooks_for` would need a left join against
`trackers_webhooks` plus a "no rows, or a matching row" condition. Rejected: it
is harder to read than the one-line predicate, it complicates a query that
already carries a hand-written `INNER JOIN`, and it saves nothing measurable —
`preload(:trackers)` makes the Ruby version a fixed one extra query regardless
of how many hooks match.

**A generic condition mechanism** (filter on status, priority, custom field, …).
Rejected as speculative. Trackers are the axis a project is actually structured
along, `matches_tracker?` is deliberately named for exactly what it does, and a
second axis can be added later without touching this one.

**Show the trackers in the webhook list** (`app/views/webhooks/index.html.erb`).
Left out on purpose. The list has a Projects column, so a Trackers column is the
obvious symmetry, but an empty cell there would read as "no trackers" when it
means "all trackers", and resolving that honestly needs another string. More to
the point, [#44337](https://www.redmine.org/issues/44337) proposes reworking
this listing into an administration page, so the column belongs to whoever does
that. If it is wanted here anyway it is two lines, and this patch is easier to
review without them.

# Tests

| Test | What it proves |
|---|---|
| `WebhookTest#test_should_find_hook_for_issue_of_a_selected_tracker` | a hook limited to a tracker still matches an issue of that tracker |
| `WebhookTest#test_should_not_find_hook_for_issue_of_a_tracker_that_is_not_selected` | the filter actually excludes — the behaviour of the feature |
| `WebhookTest#test_should_find_hook_for_issue_of_any_tracker_when_no_tracker_is_selected` | the compatibility guard: an empty selection matches every tracker. **Passes unchanged on trunk**, so it pins existing behaviour rather than the new code |
| `WebhookTest#test_should_find_hook_for_object_without_a_tracker_when_trackers_are_selected` | a `news.created` hook with trackers selected is not silently suppressed — the `acts_as_webhookable` generality |
| `WebhooksControllerTest#test_should_create_webhook_with_trackers` | `tracker_ids` reaches the model through strong parameters and is persisted |
| `WebhooksControllerTest#test_new_should_offer_a_check_box_per_tracker` | the form renders three check boxes under `fieldset#webhook_tracker_ids`, labelled `Bug` and `Feature request` |

The existing `create_hook` helpers in both files are left untouched: the new
tests set trackers with `hook.update!` instead. Changing the helper's signature
made 17 unrelated tests error on trunk, which buries the red proof in noise and
would have made the diff larger for no gain.

**Evidence (INV-8 — figures, not claims):**

- **full** suite with the patch, `tools/test-env.sh … bundle exec ruby bin/rails test:all`:
  **5926 runs, 31473 assertions, 27 failures, 2 errors, 92 skips**
- **full** suite on a pristine `origin/master` worktree, same command:
  **5920 runs, 31455 assertions, 27 failures, 2 errors, 92 skips**
- **full** suite on `7.0-stable-GEOxyz` with the same change applied, on the
  branch tip: **5986 runs, 31936 assertions, 0 failures, 0 errors, 39 skips** —
  7.0-stable does not carry the trunk tests that need the missing SCM binaries,
  so there it is genuinely clean
- Redmine's own locale-consistency suite
  (`test/unit/lib/redmine/i18n_test.rb`) run together with the webhook suites,
  on both branches: **69 runs, 950 assertions, 0 failures, 0 errors**
- **failure names identical on both** — 29 named failures, byte-identical lists.
  All 29 are repository, changeset and `SysController` tests that need an SCM
  binary this container does not have (only `git` is installed); none of them is
  touched by this patch.
- webhook suites alone (`webhook_test`, `webhook_payload_test`,
  `webhooks_controller_test` in one process): **66 runs, 246 assertions,
  0 failures, 0 errors**
- RuboCop on the five changed/added Ruby files: **0 offences**. Baseline on the
  same four existing files at the merge base: **0 offences**.
- each new test verified red on the old code: the six new tests were copied onto
  a pristine `origin/master` worktree and run there. Five fail — four with
  `ActiveModel::UnknownAttributeError: unknown attribute 'trackers'` /
  `NoMethodError: undefined method 'trackers'`, one with
  `Expected at least 1 element matching "fieldset#webhook_tracker_ids …", found
  0`. That is honest red of the "the feature is absent" kind, which is all a new
  association can be. The sixth,
  `test_should_find_hook_for_issue_of_any_tracker_when_no_tracker_is_selected`,
  **passes on trunk and passes with the patch** — that is the point of it.
- N+1 avoided, measured on the patched tree by counting `sql.active_record`
  notifications around `hooks_for` with and without the `preload`:

  | matching hooks | with `preload(:trackers)` | without |
  |---|---|---|
  | 5 | 5 queries | 8 queries |
  | 20 | **5 queries** | **23 queries** |

  Constant with the preload, one query per hook without it — the same class of
  defect as #44386.
- patch applies to pristine `origin/master` r24882: yes, both files, each on its
  own and the two together.
- `tools/check-patch-clean.sh`: PASS

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`, driven by `verify/webhook-tracker-filter.mjs`. Screenshots
in `docs/features/webhook-tracker-filter/shots/`.

A screenshot cannot show an outgoing POST, so the verification script runs a
real HTTP receiver that records what Redmine sends and serves it back as a page
— the delivery tables below are real requests from the running application, made
by the real `WebhookJob`, not a description of them. The receiver binds to the
container's own address rather than loopback, because
`WebhookEndpointValidator` rejects loopback and link-local unconditionally.

| Function | Screenshot | What it shows |
|---|---|---|
| the form before the change | `before-webhook-form.png` | New webhook form on unpatched trunk: a Projects fieldset and nothing else — a hook cannot be limited to a tracker |
| a check box per tracker, and the hint | `webhook-form.png` | the same form with the patch: a Trackers fieldset with Bug, Feature and Support, and the hint that leaving them unchecked sends every tracker |
| the selection round-trips | `webhook-form-edit-selected.png` | the saved hook re-opened: Bug checked, Feature and Support not |
| delivery before the change | `before-deliveries-tracker-selected.png` | on unpatched trunk, one Bug issue and one Feature issue were created and **both** were delivered |
| delivery with the filter on | `deliveries-tracker-selected.png` | hook limited to Bug, one issue of each tracker created, **only the Bug** delivered |
| the hint in Dutch | `webhook-form-nl.png`, `hint-nl.png` | the form in Dutch; the cropped fieldset shows the sentence under Redmine's own `Trackers` legend |
| the hint in French | `webhook-form-fr.png`, `hint-fr.png` | the form in French |
| the hint in German | `webhook-form-de.png`, `hint-de.png` | the form in German, the new hint directly under Redmine's own German `webhook_url_info` and using the same words |
| the hint in Spanish | `webhook-form-es.png`, `hint-es.png` | the form in Spanish. The legend reads `Tipos de peticiones` and the hint says `los tipos` — the one image that shows why the translations had to be derived rather than composed |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| tracker not selected → no delivery | `deliveries-tracker-selected.png` | the Feature issue does not reach the endpoint | one delivery, tracker Bug. The Feature issue was created in the same run and was given as long to arrive as the Bug issue had taken |
| no tracker selected at all → everything delivered | `deliveries-no-tracker-selected.png` | identical to the unpatched behaviour | two deliveries, Bug and Feature — the same result as `before-deliveries-tracker-selected.png` |
| clearing a selection persists | `webhook-form-edit-none.png` | unchecking every tracker saves as empty, not as "unchanged" | zero check boxes checked after save |
| object with no tracker | covered by the unit test | a `news.created` hook with trackers selected still fires | `hooks_for('news.created', News.find(1))` returns the hook |

Both modes were produced by the same version of the script: the German step was
added after the first before-run, so the before-run was repeated.

Screenshots read, not just generated: yes. `webhook-form.png` was checked for
the fieldset being styled as a `box` like the Projects one next to it, for the
toggle-all chevron in the legend, and for the hint being legible. Each of the
four `hint-<locale>.png` crops was read word by word against the table above,
and against the legend printed immediately over it — that is how the Spanish
*tipo* / *tracker* clash was caught before it shipped. The two delivery tables
were read for the tracker column and the issue subjects, which carry a per-run
timestamp, so they cannot be a stale page.

Reading `webhook-form-de.png` also turned up two pre-existing upstream defects
on that screen, **not touched by this patch** (INV-1) and worth their own
report: the `webhook_event_created` / `_updated` / `_deleted` keys in `de.yml`
are still the untranslated English `"%{object_name} created"`, and
`_form.html.erb` interpolates `:object_name => type.to_s.humanize`, an
un-localised class name. The result is a German page whose fieldset legend reads
`Tickets` while the check box inside it reads `Issue created`.

# Anticipated objections

| Objection | Answer |
|---|---|
| "Trackers are issue-specific, and the webhook layer is generic." | Correct, and that is why the tracker knowledge sits in one predicate on `Webhook` and not in `acts_as_webhookable`. `matches_tracker?` returns `true` for anything without a `tracker_id`, so the other four webhookable models are untouched — with a test for exactly that. |
| "Why not just filter on the receiving side?" | For request volume, that works. For what leaves the installation, it does not: the payload is a full issue rendering and it has already been sent. Projects are currently the only lever, so one integrated tracker exports the whole project's issue traffic. |
| "Another migration for the webhook feature." | It is the second join table on the same model and it is identical in shape to the first, which `CreateWebhooks` created. There is no way to express a per-hook, per-tracker selection without one, and no existing column to overload — `events` is a serialised list of event names, not a place for foreign keys. |
| "This should be a setting." | It is per hook, not per installation; two hooks in the same project routinely want different trackers. There is no new setting. |
| "It will break existing webhooks." | An empty selection means every tracker, so an upgraded installation behaves identically with no action. There is a unit test that passes unchanged on trunk, and `deliveries-no-tracker-selected.png` shows it in a running instance. |
| "Empty meaning 'all' is ambiguous." | It is, and it is the only choice that is backward compatible. The form says so in a hint next to the field, in the user's own language. Requiring a selection was tried in the 5.1 implementation and is rejected above. |
| "You changed `hooks_for` — is it slower?" | One extra query in total, not one per hook, and the numbers are in the evidence section. `matches_tracker?` is evaluated before `object.visible?`, so a non-matching tracker now short-circuits *before* the visibility lookup the old code always did. |
| "The webhook list does not show the tracker filter." | Deliberate, and argued above: #44337 proposes reworking that listing, and an empty cell there would read as the opposite of what it means. Two lines if it is wanted here. |
| "Translations should come from the language teams, not from a feature patch." | Agreed, and that is why they are a second patch file you can take or leave: the feature patch touches only `en.yml`. The four are offered because they are derived rather than composed — every term is traced to an existing key in the same file in the table above, so each one can be checked in seconds. On `nl`, `fr` and `es` they will sit next to two hints that are still English until those teams get to the webhook block. |
| "`setable_projects` looks different in trunk now." | #44386 (r25011) changed `setable_projects` and the `before_validation` after the revision this patch is made against. This patch does not touch either, so it rebases without conflict. |
| "Should the tracker list be limited to the hook's projects?" | Argued above under alternatives: it needs JavaScript, it risks the N+1 that #44386 just fixed in this model, and selecting an unused tracker is harmless — the hook simply never matches it. |

---

## Submission

- **Issue:** nog aan te maken — nieuw issue, follow-up van
  [#29664](https://www.redmine.org/issues/29664)
- **Patches attached:** `patches/webhook-tracker-filter/2026-09-03-r24882-feature.patch`
  (code + `en.yml`) and `patches/webhook-tracker-filter/2026-09-03-r24882-locales.patch`
  (`nl.yml`, `fr.yml`, `de.yml`, `es.yml`)
- **Made against:** `origin/master` r24882 (`2563fa6a5`, 2026-08-03)
- **Status:** klaar voor inzending
- **Feedback en wat ermee gebeurde:** nog geen

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** zie `status.md`
- **Suites daar groen:** zie `status.md`
- **Locales toegevoegd:** `en`, `nl`, `fr`, `de` en `es` — letterlijk dezelfde strings
  als de patch (per locale gecontroleerd, regel voor regel identiek)
- **`tools/check-geoxyz-branch.sh`:** zie `status.md`
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. De GEOxyz-commit blijft dus nodig tot
  GEOxyz zelf naar die release gaat. De vijf bestanden die deze patch aanraakt
  zijn op dit moment byte-identiek tussen `origin/master` en
  `7.0-stable-GEOxyz`, dus de merge is dan een no-op.
