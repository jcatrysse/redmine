# mypage-query-blocks — the limit of 3 custom query blocks on My page becomes a setting

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** op "Mijn pagina" mag je maximaal drie
  blokken met een eigen zoekopdracht zetten. Dat getal staat hard in de code.
  Deze patch maakt er een instelling van in Beheer > Configuratie > Algemeen,
  met **3 als standaard** — dus voor wie niets instelt verandert er niets.
- **Waar het vandaan komt:** 5.1-commit `0214f3ecc`, port-commit `256e7ff0d`
  (`ansifi/learn-and-test-7.0`, alleen gelezen)
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen
- **Kans dat Redmine dit aanneemt:** redelijk — het issue bestaat al
  ([#27313](https://www.redmine.org/issues/27313)) en vraagt letterlijk om deze
  instelling, maar Jean-Philippe Lang heeft het op 2018-12-08 geparkeerd met één
  bezwaar. Deze patch is precies zo gebouwd dat dat bezwaar niet opgaat: de
  standaard blijft 3, dus er wordt voor niemand iets verhoogd. Zie "Anticipated
  objections", rij 1 — dat is de kern van het gesprek dat je op dat issue gaat
  hebben.
- **Wat jij nog moet doen:** de twee patchbestanden als note hangen aan
  [#27313](https://www.redmine.org/issues/27313) (bestaand issue, dus **geen**
  nieuw issue aanmaken), en in die note het antwoord op note-9 van JPL zetten.
  De Engelse tekst staat hieronder kant-en-klaar vanaf "The problem".
- **Wat er in ronde 2 veranderd is (2026-09-05):** de instelling heeft nu een
  bereik — 0 tot en met 10 — en alles daarbuiten wordt in het formulier
  geweigerd in plaats van stilletjes anders uitgelegd. Daarmee is `0` een
  bruikbare waarde geworden ("geen nieuwe eigen zoekopdrachten meer"), wat
  precies is wat note-5 op dat issue vroeg, en is de bovengrens uit de
  issuebeschrijving ("certainly with some maximum") ingevuld. Welk getal die
  bovengrens moet zijn is een keuze die onderaan dit dossier voor jou
  openstaat.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `bee32a926` = svn **r25037** van 2026-09-05,
  opnieuw opgehaald bij het verversen van de patch. De eerste versie van dit
  dossier stond op `2563fa6a5` (r24882, 2026-08-03); die 88 commits verschil
  waren precies waarom het locale-patchbestand niet meer toepasbaar was.
- **Lost trunk dit al op?** Nee. `lib/redmine/my_page.rb` heeft nog steeds
  `'issuequery' => {:label => :label_issue_plural, :max_occurs => 3}`, en
  `Redmine::MyPage.block_options` is de enige plek die `:max_occurs` leest.
- **Waar komt die 3 vandaan?** `git log -S "max_occurs" -- lib/redmine/my_page.rb`
  wijst precies één commit aan: `4cfd51337`, svn **r16413**, Jean-Philippe Lang,
  2017-03-16, "Allow multiple instances of custom queries on My page (#1565)".
  De 3 is daar zonder toelichting neergezet en is sindsdien nooit aangeraakt.
- **Bestaand issue op redmine.org?** Ja, twee, en dit is de vierde sessie op rij
  waarin dat zo is.
  - [#1565](https://www.redmine.org/issues/1565) — de oorspronkelijke feature,
    gesloten in 3.4.0. Al in de discussie daar staat "I just stumbled over that
    3 custom query limit too. I would very much like to use more queries"
    (Martin von Wittich); #27313 is daar rechtstreeks uit ontstaan en verwijst
    zelf naar `#1565#note-88`.
  - [#27313](https://www.redmine.org/issues/27313) — "More custom queries on My
    page", Igor Rybak, 2017-10-27, status **New**, target version **Candidate
    for next major release**. De beschrijving vraagt exact wat wij bouwen: "Lets
    increase number of custom queries on My page up to 10. Or add an
    administrative setting to set number of possible blocks with queries
    (certainly with some maximum)."
    - note-5, Olivier Houdas: "A setting to control the maximum number of
      queries sounds a must to me. I had the case once of a user who had put 5
      or even more blocks in his page, and who had used a Chrome plugin to
      refresh his page every minute. It put our redmine server on its knees..."
    - note-8, **Go MAEDA** (kerncommitter): stelt voor `max_occurs` van 3 naar 5
      te zetten, en wijst het issue toe aan Jean-Philippe Lang.
    - note-9, **Jean-Philippe Lang** (projectleider): haalt de toewijzing weg,
      zet de target op "Candidate for next major release" en schrijft: "We
      should probably load content asynchronously before raising the number of
      queries that can be displayed."
  - Gezocht op redmine.org met één trefwoord per keer: `issuequery`,
    `asynchronously`. Er is **geen** issue voor asynchroon laden van
    My-page-blokken.
- **Verandert iets in trunk het ontwerp?** Ja, en dit is het belangrijkste
  resultaat van de trunk-check. `app/views/my/page.html.erb` rendert nog steeds
  elk blok synchroon via `MyHelper#render_blocks`; het bezwaar van JPL uit 2018
  geldt dus onverkort in r25037. Een patch die de standaard verhoogt (de patch
  van Go MAEDA) loopt daar recht tegenaan. Een patch die de **standaard laat
  staan** en alleen de beheerder de knop geeft, niet — en die vorm is precies
  wat de issuebeschrijving en note-5 vragen. Daarom is dit een instelling met
  default 3 en niet `max_occurs => 5`.

---

# The problem

`Redmine::MyPage::CORE_BLOCKS` allows at most three `issuequery` blocks on My
page, as a constant in `lib/redmine/my_page.rb`. The number has been there,
unexplained, since r16413 (#1565, 3.4.0), and #27313 has been open about it
since 2017 with a "Candidate for next major release" target.

Three is not obviously the wrong number, and it is not obviously the right one
either: how many issue lists a dashboard can carry depends on how big the
queries are, how many users hit the page, and what the server is. That is
exactly the kind of judgement an administrator can make and the code cannot.
Both directions are useful. An installation whose users want six small lists
has no way to allow them; an installation that has been hurt by heavy dashboard
queries — note-5 on #27313 describes a server brought down by five blocks on an
auto-refreshing page — has no way to allow fewer than three.

Note-9 on #27313 says content should probably load asynchronously before the
number of queries is *raised*. This patch does not raise it. The default stays
3, so every existing installation and every new one behaves exactly as it does
today; what changes is that an administrator who knows their own server can
move the number, in either direction. Asynchronous loading of My page blocks
remains a separate and larger change, and nothing here depends on it or gets in
its way.

# Why this belongs in core

The limit is enforced in `Redmine::MyPage.block_options`, which is also what
`valid_block?` uses to accept or reject `POST /my/add_block`. A plugin can only
change it by reopening `Redmine::MyPage` and rewriting a constant or a class
method — and it would then have to keep the dropdown and the POST validation in
step by hand, because both read the same private path. There is also nowhere for
a plugin to put the field: plugin settings live on their own page, not on
Administration > Settings > General next to the other display limits
(`per_page_options`, `search_results_per_page`, `activity_days_default`,
`feeds_limit`).

More simply: the number already is core's decision. This patch does not add a
concept, it moves one number from a constant to `config/settings.yml`, where
Redmine keeps every other number of this kind.

# Proposed change

`:max_occurs` may now name a setting instead of holding an integer. When it is a
symbol, the limit is read from that setting; when it is an integer, nothing
changes, so any block that declares a plain `:max_occurs` keeps working.

The literal 3 moves from the constant to `config/settings.yml`, which leaves one
place where the default lives.

The setting is accepted between `0` and `Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS`
(10). Anything outside that range is refused in the settings form, next to the
field, the way `default_issue_due_date_offset` already refuses a negative in
`Setting.validate_all_from_params`. Both ends of the range earn their keep:

- `0` means no new custom query block may be added at all. That is what note-5
  on #27313 asks for, and it is the direction the hardcoded 3 makes impossible
  today. It removes nothing: a user who already has blocks keeps them.
- the upper bound answers the issue description's own "certainly with some
  maximum". Every block is a real marginal cost (see the measurements below),
  and Redmine clamps the other My page block setting at both ends already —
  `MyHelper#render_timelog_block` does `days = 7 if days < 1 || days > 365`.

Nothing is silently reinterpreted: a value the form accepts is the value that
runs.

| File | Change |
|---|---|
| `lib/redmine/my_page.rb` | `'issuequery'` declares `:max_occurs => :my_page_max_issuequery_blocks`; new `MyPage.max_occurs(block)` resolves it; `block_options` calls it instead of reading `:max_occurs` inline |
| `config/settings.yml` | new `my_page_max_issuequery_blocks`, `format: int`, `default: 3` |
| `app/views/settings/_general.html.erb` | the field, after `activity_days_default` |
| `config/locales/en.yml` | `setting_my_page_max_issuequery_blocks` |
| `config/locales/{nl,fr,de,es}.yml` | the same key, translated (second patch file) |
| `app/models/setting.rb` | `validate_all_from_params` refuses a value outside `0..Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS` |
| `test/functional/my_controller_test.rb` | seven tests |
| `test/functional/settings_controller_test.rb` | three tests for the range |
| `test/unit/lib/redmine/my_page_test.rb` | new file, five tests for `MyPage.max_occurs` |

**New constant:** one, `Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS`, the upper end
of the range. It sits next to the block declarations it bounds, so the setting's
validation and the block table do not drift apart.

**New setting:** one, `my_page_max_issuequery_blocks` (`format: int`,
`default: 3`). It is the whole point of the change, and INV-6's null hypothesis
does not survive here: the alternative is a hardcoded number, which is what
#27313 is about. No migration, no gem, no route, no permission — the setting is
read through the existing `Setting` mechanism, the field sits on an existing tab,
and `POST /my/add_block` already validates through `block_options`.

It belongs on the **General** tab because that is where Redmine keeps its
display limits: `per_page_options`, `search_results_per_page`,
`activity_days_default` and `feeds_limit` are all there.

**Translations** (INV-5 — every row names the existing key it was patterned on):

| Locale | Value | Patterned on |
|---|---|---|
| en | Maximum number of custom queries displayed on My page | `setting_gantt_items_limit` (en.yml:500, "Maximum number of items displayed on the gantt chart") + `label_query_plural` (812, "Custom queries") + `label_my_page` (695, "My page") |
| nl | Max. aantal eigen zoekopdrachten op Mijn pagina | `setting_gantt_items_limit` (nl.yml:880, "Max. aantal objecten op Gantt-grafiek") + `label_query_plural` (506, "Eigen zoekopdrachten") + `label_my_page` (465, "Mijn pagina") |
| fr | Nombre maximum de rapports personnalisés affichés sur Ma page | `setting_gantt_items_limit` (fr.yml:452, "Nombre maximum d'éléments affichés sur le gantt") + `label_query_plural` (722, "Rapports personnalisés") + `label_my_page` (618, "Ma page") |
| de | Maximale Anzahl anzuzeigender eigener Abfragen auf "Meine Seite" | `setting_diff_max_lines_displayed` (de.yml:1011, "Maximale Anzahl anzuzeigender Diff-Zeilen") + `label_my_queries` (651, "Meine eigenen Abfragen") + `label_my_page` (649, "Meine Seite") |
| es | Número máximo de consultas personalizadas mostradas en Mi página | `setting_gantt_items_limit` (es.yml:940, "Número máximo de elementos mostrados en el diagrama de Gantt") + `label_query_plural` (563, "Consultas personalizadas") + `label_my_page` (522, "Mi página") |

The word "block" was deliberately avoided: it is not translated anywhere in
`nl.yml` or `es.yml` in the dashboard sense, so any wording using it would have
had to be invented. "Custom queries" is the term #1565 and #27313 use
themselves, and it exists as `label_query_plural` in all five files.

The key is placed where each file's own convention puts it: in `en.yml` next to
`setting_activity_days_default`, matching the order in `config/settings.yml` and
in the settings form; in the four translated files at the end, which is where
`rake locales:update` appends a new key (`lib/tasks/locales.rake` opens each file
with `File.open(file, 'a')`).

**Backward compatibility:** the default is 3, so nothing changes for any
existing installation until an administrator changes it. Lowering the setting
below what a user already has does not remove or hide their blocks: their
existing blocks keep rendering and only the "Add" entry goes grey
(`lowered-maximum.png` below). `Redmine::MyPage.blocks['issuequery'][:max_occurs]`
now returns a symbol rather than `3`; `MyPage.max_occurs('issuequery')` returns
the integer.

Every input the field accepts, measured end to end through the real form path
(`Setting.set_all_from_params`, then `Redmine::MyPage.max_occurs('issuequery')`),
starting from the default of 3 each time:

| Typed in the form | Refused | Setting keeps | `max_occurs` | Why |
|---|---|---|---|---|
| `3` (default) | no | `"3"` | 3 | unchanged behaviour |
| `""` | no | `"3"` | 3 | `Setting`'s own `validates_numericality_of` rejects it, so nothing is stored and the previous value survives |
| `abc` | **yes** | `"3"` | 3 | "is not a number" |
| `2.9` | **yes** | `"3"` | 3 | "is not a number" — `only_integer` |
| `0` | no | `"0"` | 0 | no new custom query block may be added; the ones a user already has keep rendering |
| `-2` | **yes** | `"3"` | 3 | "must be greater than or equal to 0" |
| `5` | no | `"5"` | 5 | |
| `10` | no | `"10"` | 10 | the upper bound itself is accepted |
| `11` | **yes** | `"3"` | 3 | "must be less than or equal to 10" |
| `999999` | **yes** | `"3"` | 3 | the same |
| any other block (`news`, `activity`, …) | — | — | 1 | `:max_occurs` absent, so the `|| 1` path, exactly as before |
| an unknown block name or a block id (`issuequery__1`) | — | — | 1 | guarded lookup; it used to raise `NoMethodError` |

# Alternatives considered

**Raise `max_occurs` from 3 to 5** (note-8 on #27313, Go MAEDA). This is the
change note-9 declined, and for a reason that still holds in r24882: My page
renders every block synchronously, so a higher number costs every installation
page-load time whether it wanted it or not, and note-5 on the same issue
describes a server that was already suffering at five. It also only moves the
argument: 5 is as arbitrary as 3, and the next request will be for 10.

**Leave the setting unbounded**, as `issues_export_limit`,
`gantt_items_limit` and `activity_days_default` are. That was the first shape of
this patch, and it does not survive contact with the field: `999999` was
accepted and returned as the limit, and `0` and `-2` were stored, redisplayed in
the form and then silently treated as 1. The neighbouring settings are not a
good precedent either, because Redmine does bound this kind of number where a
My page block is involved — `MyHelper#render_timelog_block` clamps its `days`
setting to `1..365`. A range that is refused at the form is both what #27313's
description asks for and the honest version of what the code does.

**Make My page load its blocks asynchronously first**, which is what note-9
asks for. That is a much larger change to `MyHelper#render_blocks`,
`app/views/my/page.html.erb` and every block partial, it has no issue of its own
yet, and it is not a prerequisite for this patch — this patch raises nothing by
default. Doing the async work would make a *higher default* defensible, which is
a different proposal.

**Hardcode the block name in `MyPage.blocks`**, which is what the GEOxyz 5.1
implementation (`0214f3ecc`) did: `blocks` merged a fresh
`:max_occurs => Setting...` into the `'issuequery'` entry on every call. It
works, but it puts one specific block's name inside the generic accessor, and
`blocks` is called once per block from inside `block_options`, so it rebuilt two
hashes per iteration. Resolving `:max_occurs` where it is read keeps `blocks`
what it was.

**A per-user rather than per-installation limit.** Nobody asked for it, it needs
a `UserPreference` field, and it does not answer note-5 — the administrator is
the one who has to defend the server.

# Tests

| Test | What it proves |
|---|---|
| `test_page_should_disable_issuequery_option_at_the_default_maximum` | with three blocks and no setting touched, "Issues" is disabled — the default is still 3. **A guard, deliberately green on both sides:** it is the test that fails if anyone changes the default, which is this patch's central promise. Changing `config/settings.yml` from 3 to 5 makes it fail. |
| `test_page_should_enable_issuequery_option_below_the_configured_maximum` | at 5, the option is enabled with the next id `issuequery__3` |
| `test_page_should_disable_issuequery_option_at_a_lowered_maximum` | at 2 with two blocks in use, "Issues" is disabled — the old code enables it, so this is the test that pins the *lowering* direction |
| `test_page_should_render_issuequery_blocks_over_a_lowered_maximum` | at 2 with three blocks already in place, all three still render. **Also a guard:** rendering never consults the limit, on the old code or the new one, so this test passes on both. It is here to fail if a future change ever starts dropping blocks. |
| `test_add_issuequery_block_over_the_configured_maximum_should_error` | `POST /my/add_block` is refused with 422 and the layout is unchanged — the limit is not only a dropdown attribute |
| `test_add_issuequery_block_below_the_configured_maximum` | at 5, the fourth block is actually stored in the preference |
| `test_add_issuequery_block_with_the_maximum_set_to_zero_should_error` | `0` means no new block, and the request that tries anyway gets 422 |
| `test_post_edit_with_my_page_max_issuequery_blocks_over_the_upper_bound_should_error` | one over the bound is refused in the form and nothing is stored |
| `test_post_edit_with_negative_my_page_max_issuequery_blocks_should_error` | the same at the low end |
| `test_post_edit_with_my_page_max_issuequery_blocks_set_to_zero` | `0` itself is accepted and stored — the range is `0..`, not `1..` |
| `test/unit/lib/redmine/my_page_test.rb` (5) | `MyPage.max_occurs`: the default of 1, an integer `:max_occurs` (the plugin compatibility claim), the setting-named one, `0`, and an unknown block name — including a block *id* such as `issuequery__1`, which is the shape `find_block` accepts and which used to raise `NoMethodError` |

**Evidence (INV-8 — figures, not claims):**

- **full** suite, patch worktree, run on the exact committed tree
  (`tools/test-env.sh /home/user/wt/patch-mypage-query-blocks bundle exec ruby bin/rails test:all`,
  PostgreSQL 16, Ruby 3.3.6, system tests included)
  → **5992 runs, 31762 assertions, 27 failures, 2 errors, 92 skips**
- **full** suite, pristine trunk r25037 (`/tmp/base-mypage`, database
  `redmine_test_trunk`, same command) → **5977 runs, 31708 assertions,
  27 failures, 2 errors, 92 skips**. The 15 extra runs on the patch side are
  exactly the 15 new tests.
- the 29 failing test names are **identical** on both sides — `diff` of the
  sorted name lists is empty. They are 14 in `RepositoriesControllerTest`, 8 in
  `Redmine::ApiTest::RepositoriesTest`, 5 in `SysControllerTest`, 1 in
  `Redmine::ApiTest::IssuesTest` and 1 in `UserTest`, and every one of them
  needs `svn`, `hg`, `bzr` or `cvs`, none of which is installed in this
  container. They fail on trunk regardless of this patch.
- touched suites together in one process (`my_controller_test`,
  `settings_controller_test`, `setting_test`, `my_page_test`, `i18n_test`)
  → **135 runs, 1346 assertions, 0 failures, 0 errors, 0 skips**
- RuboCop on the changed Ruby files (`app/models/setting.rb`,
  `lib/redmine/my_page.rb`, `test/functional/my_controller_test.rb`,
  `test/functional/settings_controller_test.rb`,
  `test/unit/lib/redmine/my_page_test.rb`): **0** offences, baseline on the same
  files at `origin/master`: **0**.
- each new test verified red on the old code, by three separate mutations of the
  worktree with the new tests left in place:
  - **all production files reset** to `origin/master` → 92 runs, 459
    assertions, **14 errors**: eleven `RuntimeError: There's no setting named
    my_page_max_issuequery_blocks` and three `NoMethodError: undefined method
    'max_occurs' for module Redmine::MyPage`. That is the honest form of "red"
    for a new setting: the capability does not exist to test.
  - **only `lib/redmine/my_page.rb` reset**, the setting and the validation kept
    → 5 failures and 7 errors, and the failures are behavioural:
    `..._enable_issuequery_option_below_the_configured_maximum`,
    `..._disable_issuequery_option_at_a_lowered_maximum`,
    `..._add_issuequery_block_over_the_configured_maximum_should_error`,
    `..._add_issuequery_block_below_the_configured_maximum`,
    `..._with_the_maximum_set_to_zero_should_error`.
  - **only the upper-bound branch removed** from `Setting.validate_all_from_params`
    → `test_post_edit_with_my_page_max_issuequery_blocks_over_the_upper_bound_should_error`
    fails, and nothing else does. Each half of the range is pinned separately.
  - two tests are **guards, deliberately green on both sides**, and are labelled
    as such in the table above:
    `test_page_should_disable_issuequery_option_at_the_default_maximum` (changing
    the default in `config/settings.yml` from 3 to 5 makes it fail) and
    `test_page_should_render_issuequery_blocks_over_a_lowered_maximum`.
- `tools/check-patch-clean.sh mypage-query-blocks --submit`: **PASS** — both
  files apply to a pristine `origin/master` r25037 checkout, touch only Redmine
  paths, keep to the five locales, carry no AI trace, and agree with the branch.

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`, driven by `verify/mypage-query-blocks.mjs` (`MODE=before`
against a pristine trunk worktree, `MODE=after` against the patch). Screenshots
in `docs/features/mypage-query-blocks/shots/`. Every block on the page is
pointed at a public saved query the run creates itself, so the shots show
rendered issue lists rather than empty "Custom query" forms.

| Function | Screenshot | What it shows |
|---|---|---|
| The setting exists, at its default | `before-settings-general.png` / `settings-general.png` | no field between "Days displayed on project activity" and "Host name and path" before; the new field showing `3` after |
| The setting has a range | `rejected-out-of-range.png` | one above the upper bound is refused with "must be less than or equal to 10" and nothing is stored |
| The default is unchanged | `before-select-at-default-maximum.png` / `select-at-default-maximum.png` | "Issues" greyed out with three blocks, identically on both instances |
| Three blocks render either way | `before-dropdown-at-default-maximum.png` / `dropdown-at-default-maximum.png` | the same three blocks and the same add-block list |
| Raising the limit re-enables the entry | `before-select-raised-maximum.png` / `select-raised-maximum.png` | grey before (there is nothing to raise), black after the limit is set to 5 |
| A fourth block can be added | `before-fourth-block.png` / `fourth-block.png` | three blocks before, four after |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| Limit lowered to 1 while a user already has four blocks | `lowered-maximum.png` | all four keep rendering, adding is blocked | all four render, "Issues" greyed out |
| The same case in the add-block list | `select-lowered-maximum.png` | "Issues" disabled | disabled |
| Limit `0` | `select-zero-maximum.png` | no new block may be added, the four already there survive | "Issues" greyed out, four blocks still rendering |
| One above the upper bound | `rejected-out-of-range.png` | refused in the form, nothing stored | the error line above the tab, and the field still reads 3 |

Screenshots read, not just generated: yes. Two things were found by looking at
the images rather than by the assertions.

1. A `<select>` shows only its selected entry, so the option states were not in
   the first images at all; the listbox is now grown with
   `el.size = el.options.length` before every shot (the trap is already in
   `docs/STATE.md`).
2. At full-page scale the difference between a grey and a black `<option>` is a
   few pixels of text colour and was not readable, and `getComputedStyle`
   reports `rgb(33, 37, 41)` for a disabled option just as for an enabled one —
   so the DOM cannot show it and the assertion alone proves nothing a reviewer
   can see. The select is therefore also cropped on its own
   (`select-*.png`), where the grey/black pair is unambiguous.
3. The first round of shots showed four *empty* "Custom query" forms, not four
   issue lists, because nothing in the run had a saved query to select — so the
   page whose cost this note argues about had never been photographed. The run
   now creates one public query itself and points every block at it;
   `fourth-block.png` is four rendered issue lists of ten rows each.
4. The two shots that the note calls the same picture are now the same picture
   by construction: the pointer is parked before the crop, and the run compares
   the two files by SHA-256 (`c786076ccd8692104de3b07c613e3227` in both) and
   fails if they differ. The earlier pair differed by a stray browser tooltip.

# What asynchronous loading would and would not fix

Note-9 is the one objection standing between #27313 and a decision, so it is
worth being precise about what it buys.

**Measurement conditions**, so this is reproducible rather than quoted: Redmine
trunk r25037 with this patch, PostgreSQL 16, Ruby 3.3.6, **Redmine's own test
fixtures** (`test/fixtures`, loaded by an integration test — not a seeded
instance, so the numbers are ones a committer can reproduce), one **distinct**
public `IssueQuery` per block so that no two blocks issue identical SQL,
`sql.active_record` counted with `SCHEMA` and cached statements excluded, and
one warm request before each measured one.

| Blocks | SQL queries for `GET /my/page` | Marginal | Response body |
|---|---|---|---|
| 0 | 5 | — | 12.9 KB |
| 1 | 18 | +13 | 29.7 KB |
| 2 | 22 | +4 | 46.7 KB |
| 3 | 26 | +4 | 63.6 KB |
| 6 | 32 | +2 per block | 114.2 KB |

Three consecutive runs gave identical figures.

The absolute numbers depend heavily on the dataset — a My page block spends most
of its queries enumerating `available_filters` and `available_columns`, which
grows with the number of projects, versions, categories, users and custom
fields. On a large installation the marginal cost per block is several times
this. What does not change with the dataset is the shape: the cost is linear in
the number of blocks, and it is query work rather than overhead.

Two things this measurement says that help the argument:

- **The first block is the expensive one.** It costs 13 queries; every block
  after it costs 2 to 4, because Rails' per-request query cache absorbs the
  statements the earlier blocks already ran. So the difference between three
  blocks and six is 6 queries here, not 26.
- **Six blocks pointing at the same saved query cost exactly what one block
  costs** — 18 queries, measured. "Six blocks" is a worst case only when the six
  queries are different, which is the case the table above measures.
- **The response body grows by a steady ~17 KB per block**, and that is the part
  asynchronous loading does not change either: the same HTML still has to be
  produced and sent, in six responses instead of one.

Loading the blocks asynchronously spreads those same queries over as many
separate requests. The total is unchanged and slightly higher, because each
request repeats the session lookup, `User.current` and the render setup. What it
buys is perceived latency: the page shell arrives at once and one slow block no
longer holds up the rest. What note-5 describes — a server brought down by five
blocks on a page auto-refreshed every minute — is load, and async does not
reduce load.

So the two changes answer different problems, and this one answers note-5's: an
administrator gets a ceiling, in both directions, and nothing is raised for
anybody who does not set it.

# Anticipated objections

| Objection | Answer |
|---|---|
| "We should probably load content asynchronously before raising the number of queries that can be displayed." (note-9, #27313) | Agreed, and this patch raises nothing. The default is 3, so an installation that does not touch the setting renders exactly what it renders today — `before-select-at-default-maximum.png` and `select-at-default-maximum.png` are the same picture, and that is asserted by the verification script itself: the run compares the two files by SHA-256 and fails if they differ. The async work is a prerequisite for a higher *default*, not for letting an administrator choose. It also cuts the other way: today an installation that is suffering from dashboard queries cannot ask for fewer than three, and note-5 on the same issue is exactly that installation. |
| Why not simply `max_occurs => 5`, as proposed in note-8? | That is the change note-9 declined, it costs every installation whether it wanted it or not, and 5 is as arbitrary as 3. See "Alternatives considered". |
| A setting is permanent API and translation surface; is one number worth it? | The number is already core's, in a constant nobody can reach. This adds one `format: int` row to `config/settings.yml`, one field on an existing tab and one locale key — the same shape as `feeds_limit`, `gantt_items_limit` and `issues_export_limit`. No migration, no permission, no route. |
| Should the setting be capped, as #27313's description suggests? | It is. The field accepts `0..10` and refuses anything else in the form, so an administrator cannot type a number the page cannot serve. The precedent is in the same helper: `MyHelper#render_timelog_block` clamps its `days` setting to `1..365`. The upper end is a judgement — 10 is what the issue description itself proposes ("up to 10") and double what note-8 asked for — and it is one constant, `Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS`, if you want a different number. |
| Why is `0` allowed at all? | Because it is the value note-5 on this issue is asking for: an installation that has been hurt by dashboard queries can stop new custom query blocks being added. It removes nothing — the blocks a user already has keep rendering — and it is pinned by `test_add_issuequery_block_with_the_maximum_set_to_zero_should_error` and by `select-zero-maximum.png`. |
| An out-of-range value used to be accepted and reinterpreted. | Not any more, and that is the one behaviour change since the first version of this patch. `Setting.validate_all_from_params` refuses it with `activerecord.errors.messages.greater_than_or_equal_to` / `less_than_or_equal_to`, the same messages and the same place `default_issue_due_date_offset` uses, so there is no new translation surface. |
| `:max_occurs` now holds either an integer or a symbol. | It is resolved in exactly one place, `MyPage.max_occurs`, and an integer still means what it always did, so a block declaring a plain number keeps working. The alternative was to keep the literal `3` in the constant *and* add the setting, which leaves two sources for one default. |
| What happens to a user who has more blocks than a lowered limit? | Nothing is removed or hidden. `block_options` only decides whether a *new* block can be added; the existing ones keep rendering. Proved by `test_page_should_render_issuequery_blocks_over_a_lowered_maximum` and by `lowered-maximum.png`, which shows four blocks with the limit at 1. |
| `Setting[...]` inside a method called once per block on every My page render. | `Setting.[]` reads `@cached_settings`, and `block_options` already called `Redmine::MyPage.blocks[block][:max_occurs]` once per block before this patch. `MyPage.max_occurs` does the same one hash build plus a cached settings read; the per-render cost is unchanged. |

---

## Submission

- **Issue:** [#27313](https://www.redmine.org/issues/27313) — existing, status
  New, target "Candidate for next major release". Do **not** open a new issue;
  this is a note on that one, and the note has to answer note-9.
- **Patches attached:** `patches/mypage-query-blocks/2026-09-05-r25037-feature.patch`
  (code + `en.yml`) and `-locales.patch` (`nl`, `fr`, `de`, `es`)
- **Made against:** `origin/master` r25037 = `bee32a926` (2026-09-05)
- **Status:** nog niet ingediend — wacht op Jan
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `198cbfb63`
- **Suites daar groen:** volledige suite, database `redmine_test_geoxyz` →
  **5945 runs, 31800 assertions, 0 failures, 0 errors, 39 skips**. Helemaal
  groen: de 29 SCM-fouten van trunk bestaan op `7.0-stable` niet.
- **Diff identiek aan de patch:** ja, mechanisch nagemeten — `diff` van de
  productie-diff op beide branches is leeg (INV-10). Alleen de locale-bestanden
  staan op een andere regel, omdat de GEOxyz-branch al sleutels van
  `wiki-export-attachments` onderaan heeft.
- **`nl.yml` toegevoegd:** ja — dezelfde vijf locales als de patch (INV-10)
- **`tools/check-geoxyz-branch.sh`:** PASS
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus pas als GEOxyz naar die release gaat.
