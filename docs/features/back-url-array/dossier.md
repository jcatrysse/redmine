# back-url-array — geen HTTP 500 meer als back_url als lijst binnenkomt

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** als een verzoek `back_url[]=...` (een lijst)
  meestuurt in plaats van `back_url=...` (één tekst), gaf Redmine 7 een HTTP 500:
  het contextmenu van de ticketlijst opende niet meer, en de formulieren voor een
  nieuwe tijdregistratie of versie crashten. Nu wordt zo'n waarde behandeld alsof
  er geen `back_url` was, en valt Redmine terug op de referer, zoals het al deed.
- **Waar het vandaan komt:** geen 5.1-commit. Gevonden door de
  `redmine_inline_edit_issues`-sessie, die het in de plugin opving; Jans keuze
  core-q3 optie A (2026-10-07): de echte fix hoort in core.
- **Doel:** upstream + GEOxyz.
- **Afwijking GEOxyz ↔ upstream:** geen. Dezelfde commit, letterlijk.
- **Kans dat Redmine dit aanneemt:** goed — één regel, een defect met een
  reproduceerbare 500 zonder plugins, en een test die rood is op trunk.
- **Wat jij nog moet doen:** de mirror syncen (41 commits achter), een Defect
  aanmaken op redmine.org met de tekst hieronder en het patchbestand erbij.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** mirror `origin/master` = `e3962939c` (r25136,
  2026-09-25) — **41 commits achter echte trunk**. Echte trunk ook gelezen:
  `713d29813` (r25215, 2026-10-07), opgehaald van github.com/redmine/redmine.
- **Lost trunk dit al op?** Nee. `ApplicationController#back_url` is in r25215
  identiek: `url = params[:back_url]` geeft een Array of een
  `ActionController::Parameters` ongefilterd door.
- **Bestaand issue op redmine.org?** Niets gevonden. Gezocht op `back_url`
  (issues, alle projecten), `back_url array`, `back_url 500`,
  `back_url NoMethodError`, `context menu back_url`. Verwant maar anders:
  #43603 (Delete-link ontbreekt bij een relative URL root), #35616 (de wijziging
  die de 500 in het contextmenu blootlegde).
- **Verandert iets in trunk het ontwerp?** Nee. De 41 ontbrekende commits raken
  `application_controller.rb` en de contextmenu-controllers niet; de patch
  applyt schoon op r25215.

---

# The problem

`ApplicationController#back_url` returns `params[:back_url]` as it comes in.
When a request carries `back_url[]=/issues` (or `back_url[x]=/issues`), that is
an `Array` (or an `ActionController::Parameters`), and every caller that
expects a string raises:

| Request | Error | Where |
|---|---|---|
| `GET /issues/context_menu?ids[]=1&back_url[]=/issues` | `NoMethodError: undefined method 'start_with?' for an instance of Array` | `Rails.application.routes.recognize_path(back_url)` in `ContextMenus::IssuesController#issues` |
| same, `back_url[x]=/issues` | `NoMethodError ... for an instance of ActionController::Parameters` | same |
| `GET /projects/foo/time_entries/new?back_url[]=/issues` | `TypeError: no implicit conversion of Array into String` | `CGI.unescape` in `validate_back_url`, called from `back_url_hidden_field_tag` |
| `GET /projects/foo/versions/new?back_url[]=/issues` | same | same |

All of them are HTTP 500. The context menu case is the visible one: on the
issue list, the right-click menu simply does not open. It became reachable
with #35616 (r23938, 2025-09-04, part of 7.0-stable), which started passing `back_url` to
`recognize_path` to decide whether to show "Delete"; before that, the context
menu only interpolated it into links.

The issue list sends its hidden `back_url` field with every context-menu
request (`context_menu.js` serializes the list form), so anything that adds a
second field of that name, or names it `back_url[]`, triggers it — a plugin
did, which is how this was found. But no plugin is needed: the URLs above
reproduce it on a clean trunk.

# Why this belongs in core

It is a defect in a core method that core itself calls from four places, and
a plugin cannot fix it without overriding `ApplicationController#back_url`.

# Proposed change

`back_url` ignores a `back_url` parameter that is not a string, exactly as if
it were absent, and so falls back to the referer as it already does.

```ruby
def back_url
  url = params[:back_url] if params[:back_url].is_a?(String)
```

Fixing it in `back_url` rather than in each caller covers all of them with one
line: the context menus, `back_url_hidden_field_tag`, `cancel_button_tag` and
`attachments/edit_all`. An empty string keeps its current meaning (no fallback
to the referer): only the type check is new.

| File | Change |
|---|---|
| `app/controllers/application_controller.rb` | one line: accept `params[:back_url]` only when it is a `String` |
| `test/functional/context_menus/issues_controller_test.rb` | one test: array `back_url` on the context menu |
| `test/functional/timelog_controller_test.rb` | one test: array `back_url` on a form page (`back_url_hidden_field_tag`, `cancel_button_tag`) |

**New setting / migration / gem / route / permission:** none.

**Translations:** none — no user-visible string.

**Backward compatibility:** a string `back_url` and a missing one behave as
before. Only a non-string value changes, from an HTTP 500 to "no back_url
given".

# Alternatives considered

- **Guard in each caller** (`ContextMenus::IssuesController`,
  `validate_back_url`). Four places instead of one, and the next caller of
  `back_url` would have the same bug.
- **`params[:back_url].to_s`**, the idiom `redirect_back_or_default` already
  uses. It turns `nil` into `""`, which disables the referer fallback for every
  request without a `back_url`, and turns `["/issues"]` into the string
  `'["/issues"]'`, which is then carried around as a bogus URL.
- **Take the first element of the array.** It guesses what the client meant;
  a malformed parameter is better treated as absent, which is what Redmine does
  with other invalid back URLs.
- **Rescue in `validate_back_url`.** Hides the type problem at one caller and
  leaves the context menu broken.

# Tests

| Test | What it proves |
|---|---|
| `ContextMenus::IssuesControllerTest#test_context_menu_with_back_url_as_array_should_use_referer` | the context menu renders with `back_url[]`, and uses the referer instead: the Delete link carries the referer as its `back_url` |
| `TimelogControllerTest#test_get_edit_with_back_url_as_array_should_not_fail` | a form page renders with `back_url[]`: no hidden `back_url` field, Cancel falls back to the project's time entries |

**Evidence (INV-8 — figures, not claims):**

- **full** suite: see `status.md` → *Bewijs* for the figures of the final run
  (`tools/test-env.sh <worktree> bundle exec ruby bin/rails test:all`)
- RuboCop on the three changed files: `0` offences (baseline at merge base: `0`)
- each new test verified red on the old code: run with the old
  `application_controller.rb` and the new tests, on trunk and on
  `7.0-stable-GEOxyz`: `NoMethodError: undefined method 'start_with?' for an
  instance of Array` (context menu) and `ActionView::Template::Error: no implicit
  conversion of Array into String` (timelog); green with the fix
  (`context_menus/issues_controller_test.rb` 25 runs, 199 assertions;
  `timelog_controller_test.rb -i /back_url/` 4 runs, 19 assertions, 0 failures)
- patch applies to pristine `origin/master` r25136: yes; to real trunk r25215
  (`713d29813`): yes (`git apply --check`)
- `tools/check-patch-clean.sh back-url-array`: PASS. `--submit`: FAIL only on
  "origin/master is 41 commits behind real trunk" (K-19/K-20, the mirror is Jan's)

# Live verification (G9)

Exercised in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`, with `verify/back-url-array.mjs`. Before: unpatched trunk
`e3962939c`. After: `patch/back-url-array`. The same after-run passed against
`7.0-stable-GEOxyz` with the commit applied (7 of 7 checks).

| Function | Screenshot | What it shows |
|---|---|---|
| context menu, normal case | `before-context-menu-string.png` | right-click on the issue list, `back_url` as a string: menu opens (unchanged behaviour) |
| context menu, normal case | `context-menu-string.png` | the same after the patch: identical |
| context menu, `back_url[]` | `before-context-menu-array.png` | the list's hidden field renamed `back_url[]`, right-click: the request answers 500, the row is selected and no menu opens |
| context menu, `back_url[]` | `context-menu-array.png` | the same after the patch: menu opens, "Delete issue" included (taken from the referer) |
| form page, `back_url[]` | `before-time-entry-new.png` | `/time_entries/new?back_url[]=...`: `TypeError` in `validate_back_url`, HTTP 500 |
| form page, `back_url[]` | `time-entry-new.png` | the form renders, Cancel present |
| form page, `back_url[]` | `before-version-new.png` | `/versions/new?back_url[]=...`: HTTP 500 |
| form page, `back_url[]` | `version-new.png` | the form renders |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| string `back_url` (must not change) | `context-menu-string.png` | menu with Delete | menu with Delete |
| invalid string `back_url` (must still be rejected) | — (existing tests) | no Delete / fallback Cancel | `test_context_menu_should_not_include_delete_for_disallowed_back_urls`, `test_get_edit_should_validate_back_url` green |
| `back_url[x]=` (hash) | — (probe, 500 before) | handled like an array | `is_a?(String)` is false for `ActionController::Parameters`; probed 500 before, covered by the same line |

Screenshots read, not just generated: yes — checked that the before array shot
has a selected row and no menu, and that both after-shots of the form pages are
the form and not an error page.

# Anticipated objections

| Objection | Answer |
|---|---|
| Why fall back to the referer instead of rejecting the request? | That is what `back_url` already does when the parameter is missing, and every caller already validates the result. An unusable parameter is the same as no parameter. |
| Why not `.to_s` like `redirect_back_or_default`? | It would turn a missing `back_url` into `""` and switch off the referer fallback for every request. See *Alternatives*. |
| Who sends an array? | Nothing in core; a plugin or a hand-made URL. But a URL parameter must not be able to cause a 500, and four core pages do today. |
| `redirect_back_or_default` still reads `params[:back_url]` directly | It calls `.to_s` first, so an array is turned into a string that fails validation and the default is used: no error. Left alone (INV-1). |

---

## Submission

- **Issue:** — (Jan maakt het aan; type Defect)
- **Patches attached:** `patches/back-url-array/2026-10-07-r25136-feature.patch` (no locale patch: no strings)
- **Made against:** `origin/master` r25136 (2026-09-25); also applies to r25215 (2026-10-07)
- **Status:** patch klaar
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** zie `status.md` (`geoxyz_commit`)
- **Suites daar groen:** zie `status.md` → *Bewijs*
- **`nl.yml` toegevoegd:** n.v.t. — geen strings
- **`tools/check-geoxyz-branch.sh`:** zie `status.md`
- **Wanneer kan deze commit vervallen?** Als GEOxyz naar de release gaat die de
  trunk-fix bevat (7.1 of later). Wordt het upstream als defect ook naar
  7.0-stable gebackport — bij defects gebeurt dat wel — dan bij de eerste 7.0.x
  die hem bevat.
