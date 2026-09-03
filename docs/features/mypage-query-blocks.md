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

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `2563fa6a5` = svn r24882 van 2026-08-03. De
  mirror liep één maand achter op de sessiedatum (2026-09-03); dat is de trap
  uit `docs/STATE.md` en de reden dat de revisie in het issue genoemd wordt.
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
  geldt dus onverkort in r24882. Een patch die de standaard verhoogt (de patch
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
symbol, the limit is read from that setting and clamped to a minimum of 1, so a
blank or zero value cannot silently disable a block that a user already has on
their page. When it is an integer, nothing changes, so any block that declares a
plain `:max_occurs` keeps working.

The literal 3 moves from the constant to `config/settings.yml`, which leaves one
place where the default lives.

| File | Change |
|---|---|
| `lib/redmine/my_page.rb` | `'issuequery'` declares `:max_occurs => :my_page_max_issuequery_blocks`; new `MyPage.max_occurs(block)` resolves it; `block_options` calls it instead of reading `:max_occurs` inline |
| `config/settings.yml` | new `my_page_max_issuequery_blocks`, `format: int`, `default: 3` |
| `app/views/settings/_general.html.erb` | the field, after `activity_days_default` |
| `config/locales/en.yml` | `setting_my_page_max_issuequery_blocks` |
| `config/locales/{nl,fr,de,es}.yml` | the same key, translated (second patch file) |
| `test/functional/my_controller_test.rb` | six tests |

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
| en | Maximum number of custom queries displayed on My page | `setting_gantt_items_limit` (en.yml:501, "Maximum number of items displayed on the gantt chart") + `label_query_plural` (812, "Custom queries") + `label_my_page` (695, "My page") |
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

Every input the field accepts, measured in a console
(`Setting.my_page_max_issuequery_blocks = x; Redmine::MyPage.max_occurs('issuequery')`):

| Stored | Setting keeps | `max_occurs` | Why |
|---|---|---|---|
| `3` (default) | `"3"` | 3 | unchanged behaviour |
| `""` | `"3"` | 3 | `Setting`'s own `validates_numericality_of` rejects it, so nothing is stored |
| `"abc"` | previous value | previous | same validation |
| `0` | `"0"` | 1 | clamped — a zero must not disable a block type a user already has |
| `-2` | `"-2"` | 1 | clamped; `only_integer` accepts a negative, the clamp catches it |
| any other block (`news`, `activity`, …) | — | 1 | `:max_occurs` absent, so the `|| 1` path, exactly as before |

# Alternatives considered

**Raise `max_occurs` from 3 to 5** (note-8 on #27313, Go MAEDA). This is the
change note-9 declined, and for a reason that still holds in r24882: My page
renders every block synchronously, so a higher number costs every installation
page-load time whether it wanted it or not, and note-5 on the same issue
describes a server that was already suffering at five. It also only moves the
argument: 5 is as arbitrary as 3, and the next request will be for 10.

**Cap the setting at some maximum**, as the issue description suggests
("certainly with some maximum"). A cap in core is another arbitrary number, and
it would be a strange thing for core to insist on: Redmine does not cap
`issues_export_limit`, `gantt_items_limit`, `attachment_max_size` or
`activity_days_default` either. The administrator setting the number is the
person who knows the server. If a committer wants a cap, it is a one-line change
to `MyPage.max_occurs` and this patch is happy to carry it.

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
| `test_page_should_disable_issuequery_option_at_the_default_maximum` | with three blocks and no setting touched, "Issues" is disabled — the default is still 3 |
| `test_page_should_enable_issuequery_option_below_the_configured_maximum` | at 5, the option is enabled with the next id `issuequery__3` |
| `test_page_should_render_issuequery_blocks_over_a_lowered_maximum` | at 2 with three blocks already in place, all three still render and only the option goes disabled |
| `test_add_issuequery_block_over_the_configured_maximum_should_error` | `POST /my/add_block` is refused with 422 and the layout is unchanged — the limit is not only a dropdown attribute |
| `test_add_issuequery_block_below_the_configured_maximum` | at 5, the fourth block is actually stored in the preference |
| `test_add_issuequery_block_with_the_maximum_set_to_zero_should_allow_one_block` | the clamp: `0` does not disable the block type |

**Evidence (INV-8 — figures, not claims):**

- **full** suite, patch worktree, run on the exact committed tree:
  `tools/test-env.sh /home/user/wt/patch-mypage-query-blocks bundle exec ruby bin/rails test:all`
  → **5926 runs, 31483 assertions, 27 failures, 2 errors, 92 skips**
  (an earlier run, before the `nl.yml` wording was changed, gave 5926 / 31485 /
  27 / 2 / 92 — the same failures, two assertions apart because Redmine
  randomises test order and some tests assert conditionally)
- **full** suite, pristine trunk r24882 (`/home/user/wt/base`, database
  `redmine_test_base`) → **5920 runs, 31455 assertions, 27 failures, 2 errors,
  92 skips**
- the 29 failing test names are **identical** on both sides (`diff` of the sorted
  name lists is empty), in both patch runs. All 29 live in
  `Redmine::ApiTest::IssuesTest`, `Redmine::ApiTest::RepositoriesTest`,
  `RepositoriesControllerTest`, `SysControllerTest` and `UserTest` and need
  `svn`, `hg`, `bzr` or `cvs`, none of which is installed in this container. They
  fail on trunk regardless of this patch.
- touched suites together in one process
  (`setting_test`, `settings_controller_test`, `my_controller_test`,
  `i18n_test`) → **126 runs, 1325 assertions, 0 failures, 0 errors**
- RuboCop on the changed Ruby files (`lib/redmine/my_page.rb`,
  `test/functional/my_controller_test.rb`): **0** offences. Baseline on the same
  two files at `origin/master`: **0**.
- each new test verified red on the old code: the three production files were
  reset with `git checkout origin/master --` while the new tests stayed in place,
  and `my_controller_test.rb` then ran **62 runs, 347 assertions, 0 failures, 5
  errors** — the five `with_settings` tests all raised
  `RuntimeError: There's no setting named my_page_max_issuequery_blocks` from
  `app/models/setting.rb:402`. That is the honest form of "red" for a new
  setting: the capability does not exist to test. The sixth test,
  `test_page_should_disable_issuequery_option_at_the_default_maximum`, is a
  **guard** and is deliberately green on both sides (1 run, 5 assertions, 0
  failures on trunk) — it is the test that would catch a change to the default,
  which is this patch's central promise.
- patch applies to pristine `origin/master` r24882: yes
- `tools/check-patch-clean.sh`: PASS

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`, driven by `verify/mypage-query-blocks.mjs` (`MODE=before`
against a pristine trunk worktree, `MODE=after` against the patch). Screenshots
in `docs/features/mypage-query-blocks/shots/`.

| Function | Screenshot | What it shows |
|---|---|---|
| The setting exists, at its default | `before-settings-general.png` / `settings-general.png` | no field between "Days displayed on project activity" and "Host name and path" before; the new field showing `3` after |
| The default is unchanged | `before-select-at-default-maximum.png` / `select-at-default-maximum.png` | "Issues" greyed out with three blocks, identically on both instances |
| Three blocks render either way | `before-dropdown-at-default-maximum.png` / `dropdown-at-default-maximum.png` | the same three blocks and the same add-block list |
| Raising the limit re-enables the entry | `before-select-raised-maximum.png` / `select-raised-maximum.png` | grey before (there is nothing to raise), black after the limit is set to 5 |
| A fourth block can be added | `before-fourth-block.png` / `fourth-block.png` | three blocks before, four after |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| Limit lowered to 1 while a user already has four blocks | `lowered-maximum.png` | all four keep rendering, adding is blocked | all four render, "Issues" greyed out |
| The same case in the add-block list | `select-lowered-maximum.png` | "Issues" disabled | disabled |
| Limit `0` | covered by `test_add_issuequery_block_with_the_maximum_set_to_zero_should_allow_one_block` | one block still allowed | allowed |

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

# Anticipated objections

| Objection | Answer |
|---|---|
| "We should load content asynchronously before raising the number of queries that can be displayed." (note-9, #27313) | Agreed, and this patch raises nothing. The default is 3, so an installation that does not touch the setting renders exactly what it renders today — `before-select-at-default-maximum.png` and `select-at-default-maximum.png` are the same picture. The async work is a prerequisite for a higher *default*, not for letting an administrator choose. It also cuts the other way: today an installation that is suffering from dashboard queries cannot ask for fewer than three, and note-5 on the same issue is exactly that installation. |
| Why not simply `max_occurs => 5`, as proposed in note-8? | That is the change note-9 declined, it costs every installation whether it wanted it or not, and 5 is as arbitrary as 3. See "Alternatives considered". |
| A setting is permanent API and translation surface; is one number worth it? | The number is already core's, in a constant nobody can reach. This adds one `format: int` row to `config/settings.yml`, one field on an existing tab and one locale key — the same shape as `feeds_limit`, `gantt_items_limit` and `issues_export_limit`. No migration, no permission, no route. |
| Should the setting be capped, as #27313's description suggests? | We did not cap it, because core does not cap `issues_export_limit`, `gantt_items_limit` or `activity_days_default` either, and any cap is another arbitrary number. If you want one, it is one line in `MyPage.max_occurs`. |
| `:max_occurs` now holds either an integer or a symbol. | It is resolved in exactly one place, `MyPage.max_occurs`, and an integer still means what it always did, so a block declaring a plain number keeps working. The alternative was to keep the literal `3` in the constant *and* add the setting, which leaves two sources for one default. |
| What happens to a user who has more blocks than a lowered limit? | Nothing is removed or hidden. `block_options` only decides whether a *new* block can be added; the existing ones keep rendering. Proved by `test_page_should_render_issuequery_blocks_over_a_lowered_maximum` and by `lowered-maximum.png`, which shows four blocks with the limit at 1. |
| `Setting[...]` inside a method called once per block on every My page render. | `Setting.[]` reads `@cached_settings`, and `block_options` already called `Redmine::MyPage.blocks[block][:max_occurs]` once per block before this patch. `MyPage.max_occurs` does the same one hash build plus a cached settings read; the per-render cost is unchanged. |

---

## Submission

- **Issue:** [#27313](https://www.redmine.org/issues/27313) — existing, status
  New, target "Candidate for next major release". Do **not** open a new issue;
  this is a note on that one, and the note has to answer note-9.
- **Patches attached:** `patches/mypage-query-blocks/2026-09-03-r24882-feature.patch`
  (code + `en.yml`) and `-locales.patch` (`nl`, `fr`, `de`, `es`)
- **Made against:** `origin/master` r24882 (2026-08-03)
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
