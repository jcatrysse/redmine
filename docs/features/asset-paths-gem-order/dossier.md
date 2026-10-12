# asset-paths-gem-order — gems in vendor/bundle achter de assetpaden van Redmine zelf

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** als de gems in `vendor/bundle` binnen de
  Redmine-map staan (dat is wat Bundler's deployment-modus standaard doet),
  wint een gem-bestand van een core-bestand met dezelfde naam. De redmineup-gem
  (elke RedmineUP-plugin) levert Chart.js 3 als `chart.min.js`, dus geen enkele
  core-grafiek werkt nog. De patch laat Redmine's eigen laadpad de gems weer
  achter de eigen bestanden zetten.
- **Waar het vandaan komt:** de redmine_tags-sessie (branch
  `fix/asset-paths-gems-under-rails-root`, commit `3d0c1b2`), daarna op
  2026-10-07 als `6abebe886` op `7.0-stable-GEOxyz`, dezelfde avond met
  `1bf0ef69b` teruggedraaid toen je de serverregel koos. Op 2026-10-12 herzag je
  dat: **keuze B, ook als patch voor redmine.org** (`docs/DECISIONS.md`,
  "asset-paths-gem-order herzien").
- **Doel:** upstream + GEOxyz.
- **Afwijking GEOxyz ↔ upstream:** geen. Dezelfde commit, letterlijk (een
  cherry-pick; de diff tegen de eigen basis is byte-identiek, want
  `lib/redmine/asset_path.rb` en de test zijn op 7.0-stable en trunk gelijk).
- **Ander ontwerp dan `6abebe886`.** Dezelfde sortering, maar op een andere
  plek: in `Redmine::AssetLoadPath` (de klasse waarmee Redmine het laadpad van
  Propshaft al overneemt) in plaats van een `after_initialize` in
  `config/application.rb`. Eén bestand code in plaats van twee, en geen
  afhankelijkheid meer van de volgorde van callbacks. De tweede test is
  herschreven zodat hij ook in CI faalt zonder de fix; de oude was alleen rood
  met de bundle in `vendor/bundle`. Zie "Alternatives considered".
- **Kans dat Redmine dit aanneemt:** redelijk. Voor: een echt defect met een
  test die rood is op trunk, klein, en precies hetzelfde symptoom als #44294,
  dat Marius binnen een week oploste. Tegen: het wordt pas zichtbaar met een
  gem van derden in de bundle, en een committer kan zeggen "dat hoort in
  Propshaft". Dat bezwaar staat met antwoord onderaan.
- **Wat jij nog moet doen:** zie `status.md` — mirror syncen, `--submit`,
  het issue aanmaken; in productie de GEOxyz-branch deployen met
  `assets:precompile`.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** mirror `origin/master` = `e3962939c` (r25136,
  2026-09-25) — **51 commits achter echte trunk**. Echte trunk ook gelezen:
  `9b4eab622` (r25227, 2026-10-12), opgehaald van github.com/redmine/redmine.
- **Lost trunk dit al op?** Nee. In r25227 zijn `lib/redmine/asset_path.rb`,
  `config/initializers/10-patches.rb`, `config/initializers/30-redmine.rb` en
  `config/application.rb` identiek aan r25136; de Gemfile houdt
  `propshaft ~> 1.3.0` (alleen rails, rubyzip en de json-pin veranderden). Ook
  Propshaft zelf niet: `lib/propshaft/railtie.rb` op `main` sorteert nog
  steeds met `path.to_s.start_with?(Rails.root.to_s)`.
- **Bestaand issue op redmine.org?** Niets over dit mechanisme. Gezocht op
  `propshaft` (14 issues), `vendor/bundle` (36, alle over installatie),
  `"Chart is not a constructor"` (1). Verwant: **#44294** (Defect, gesloten,
  7.0.1) — hetzelfde symptoom, maar door een leeg `app/assets/javascripts/chart.min.js`
  in core zelf; opgelost in r24879 door het bestand te wissen, plus een
  systeemtest in r24882. Bij Propshaft: rails/propshaft#89 (open) vraagt hoe je
  gem-assets uitsluit; geen issue over `vendor/bundle`.
- **Verandert iets in trunk het ontwerp?** Nee. De patch applyt schoon op
  r25227 (`git apply --check` en `patch -p1 --dry-run`).

---

# The problem

Redmine 7 serves assets through Propshaft. Every engine gem in the bundle adds
its `app/assets/*` directories to `config.assets.paths`, and for each logical
path the first directory that has the file wins. Propshaft orders the
application's paths before those of gems, but it decides what belongs to the
application by a string prefix on `Rails.root`
(`lib/propshaft/railtie.rb`):

```ruby
config.assets.paths.sort_by!.with_index { |path, i| [path.to_s.start_with?(Rails.root.to_s) ? 0 : 1, i] }
```

When the bundle is installed inside the Redmine directory, every gem path
starts with `Rails.root` too, so the gems keep their place in front of
`app/javascript` and `vendor/javascript`. That is not an unusual layout: it is
what `bundle config set --local deployment true` does (Bundler: "Equivalent to
setting frozen to true and path to vendor/bundle"), and what
`bundle config set --local path vendor/bundle` does.

A gem that ships a file with the same logical path as a core asset then
replaces the core asset. Concretely, the `redmineup` gem (a dependency of the
RedmineUP plugins) ships Chart.js 3.9.1 as
`app/assets/javascripts/chart.min.js`. The importmap pin
`chart.js` → `chart.min.js` then serves that UMD build instead of Redmine's
Chart.js 4.5.1 module, and every chart fails with
`TypeError: Chart is not a constructor` — the issue report details and the
repository statistics, the same symptom as #44294. The same happens to any
other core asset a gem happens to ship under the same name.

To reproduce on trunk:

1. `bundle config set --local path vendor/bundle`
2. add an engine gem that has `app/assets/javascripts/chart.min.js` to
   `Gemfile.local` (any `Rails::Engine` gem with that file will do), `bundle install`
3. open Issues → Summary → Tracker: the table is shown, the chart is not, and
   the browser console has `Chart is not a constructor`

`rails runner 'puts Rails.application.assets.load_path.find("chart.min.js").path'`
prints the gem's file instead of `vendor/javascript/chart.min.js`.

# Why this belongs in core

The load path is Redmine's: `Redmine::AssetLoadPath` already replaces
Propshaft's to add plugin and theme assets, so Redmine decides the search
order whether it means to or not. Plugins bring gems into the bundle through
their own `Gemfile`, and neither the administrator nor any one plugin can see
which of those gems ship a file that collides with a core asset. A plugin can
work around one gem (`config.assets.excluded_paths` for that gem's
directories), but not for the next one.

# Proposed change

`Redmine::AssetLoadPath` puts the application's paths first before handing
them to Propshaft, counting a path as the application's only if it is under
`Rails.root` **and** not inside Bundler's or RubyGems' gem directories. The
order within each group is kept, so nothing else moves.

| File | Change |
|---|---|
| `lib/redmine/asset_path.rb` | `Redmine::AssetLoadPath.application_paths_first(paths, root:, gem_dirs:)`, a stable sort; `AssetLoadPath#initialize` passes `config.paths` through it |
| `test/unit/lib/redmine/asset_path_test.rb` | two tests |
| `test/fixtures/asset_path/bundle/gems/shadow-1.0/app/assets/javascripts/chart.min.js` | a one-line fixture: a gem's own `chart.min.js` under a gem directory inside `Rails.root` |

**New setting / migration / gem / route / permission:** none.

**Translations:** none — no user-visible string.

**Backward compatibility:**

- Bundle outside `Rails.root` (the default, and the official Docker image):
  nothing changes, Propshaft already put the gems last.
- Bundle inside `Rails.root`: a logical path that exists both in a gem and in
  the application now resolves to the application's file, as it already does
  in the default layout. With the stock bundle there is no such path (measured:
  0 duplicated logical paths), so nothing changes there either; with a gem that
  ships `chart.min.js`, only that path changes owner (measured, 1 of 1).
- Code under `Rails.root` that is not in a gem directory — the application,
  and a plugin that defines its own engine — stays in the application group,
  where it was.
- Plugin and theme assets (`plugin_assets/...`, `themes/...`) are not in
  `config.assets.paths` and are not affected.
- Production needs the usual `rake assets:precompile` after upgrading, so
  `public/assets/chart.min-*.js` is rebuilt from the right file.

# Alternatives considered

- **Reorder `config.assets.paths` in an `after_initialize` hook in
  `config/application.rb`.** This is how the fix was first written. It works,
  but it touches two files instead of one, and it is only right if it runs
  after Propshaft's own `after_initialize` and before
  `config/initializers/30-redmine.rb` builds the load path in production
  (`needs_precompile?`). Doing it in `Redmine::AssetLoadPath#initialize` makes
  the order a property of the load path itself, whenever it is built.
- **`config.assets.excluded_paths` for one gem's directories** (in
  `config/additional_environment.rb`). Works, but per gem and per server, and
  the next gem that ships a colliding file breaks a page again.
- **Install the bundle outside `Rails.root`.** Avoids the problem without
  code, but contradicts Bundler's deployment mode, and one `bundle config`
  brings it back without any visible sign.
- **Fix the heuristic in Propshaft.** That is where it ultimately belongs, and
  worth proposing there too. Redmine pins `propshaft ~> 1.3.0` and already
  owns the load path, so a fix in Redmine does not have to wait for it, and
  becomes a no-op once Propshaft sorts the same way.

# Tests

| Test | What it proves |
|---|---|
| `application_paths_first puts gem paths behind the application's, also under the root` | the sort on literal paths: a gem under the root and one outside it both go behind the application's paths; the order inside each group is kept |
| `gem assets under Rails.root do not shadow the application's assets` | end to end through `Redmine::AssetLoadPath`: a gem directory inside `Rails.root` (the fixture, made a gem directory by stubbing `Bundler.bundle_path`) that ships `chart.min.js`, listed first as Propshaft would list it, does not win over `vendor/javascript/chart.min.js` |

The second test does not depend on where the test run's own bundle is
installed, so it guards the fix in CI as well.

**Evidence (INV-8):**

- **full** suite with the patch, `tools/test-env.sh <worktree> bundle exec ruby bin/rails test:all`:
  see `status.md`, "Bewijs" (figures and the comparison with clean trunk)
- touched suite: `5 runs, 8 assertions, 0 failures, 0 errors, 0 skips`
- each new test red on the old code: `lib/redmine/asset_path.rb` reverted,
  tests kept → `5 runs, 7 assertions, 1 failures, 1 errors`: the first test
  `NoMethodError: undefined method 'application_paths_first'`, the second
  `expected vendor/javascript/chart.min.js, actual
  test/fixtures/asset_path/bundle/gems/shadow-1.0/app/assets/javascripts/chart.min.js`
- RuboCop 1.91.0 (with rubocop-rails 2.38.0, rubocop-performance 1.27.0) on
  the two Ruby files, `--cache false`: 0 offences; baseline at `origin/master`: 0
- `assets:precompile` with the bundle in `vendor/bundle` and a gem shipping
  `chart.min.js`: unpatched, `public/assets/chart.min-a89b27c8.js` is the gem's
  file; patched, `chart.min-cae696ba.js`, Chart.js v4.5.1
- patch applies to `origin/master` r25136 and to real trunk r25227: yes
- `tools/check-patch-clean.sh asset-paths-gem-order`: PASS

# Live verification (G9)

Real Redmine (development server), bundle installed with
`bundle config set --local path vendor/bundle` inside the tree,
`tools/dev-seed.rb` data. Script: `verify/asset-paths-gem-order.mjs`; it reports
the file behind the `chart.js` pin, the painted pixels in the chart canvas and
the page errors.

**Stand-in, not redmineup itself.** Starting Redmine with a RedmineUP plugin
installed is refused in these sessions by the execution environment's safety
check (third-party plugin code). The mechanism is shown with
`asset_shadow_probe`, a three-file engine gem written for this check and
installed into `vendor/bundle` from a local git source in `Gemfile.local`
(`vendor/bundle/ruby/3.3.0/bundler/gems/asset_shadow_probe-719e5ea1a98a`): a
`Rails::Engine` with `app/assets/javascripts/chart.min.js` that, like
redmineup's Chart.js 3 UMD build, exports no ES module. It reproduces the
reported error exactly.

| Function | Screenshot | What it shows |
|---|---|---|
| core chart, trunk r25136 unpatched, gem in `vendor/bundle` ships `chart.min.js` | `before-issue-report-chart.png` | table only, no chart (canvas 300×150, 0 painted pixels); the pin serves the gem's file; `Chart is not a constructor` (2×) |
| same bundle, with the patch | `issue-report-chart.png` | both charts drawn (930×465, 84890 painted pixels); the pin serves Chart.js v4.5.1; no page errors |
| `7.0-stable-GEOxyz` at `1bf0ef69b` (fix reverted), same gem | `geoxyz-before-issue-report-chart.png` | no chart; gem's file; `Chart is not a constructor` (2×) |
| `7.0-stable-GEOxyz` with the same commit as the patch | `geoxyz-issue-report-chart.png` | both charts drawn (84890 painted pixels); Chart.js v4.5.1; no page errors |

Failure paths:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| patch applied, no colliding gem in the bundle | `nogem-issue-report-chart.png` | unchanged behaviour | charts drawn, Chart.js v4.5.1, no errors; 0 duplicated logical paths in the load path; byte-identical to `issue-report-chart.png` |

Screenshots read, not just generated: yes — looked for the chart area under
the table (empty in both before shots, two bar charts in the after shots) and
checked the script's output for the served file and the page errors.

# Anticipated objections

| Objection | Answer |
|---|---|
| This is Propshaft's heuristic, fix it there | Agreed that it belongs there too. Redmine already owns the load path (`Redmine::AssetLoadPath`) and pins `propshaft ~> 1.3.0`; the change is a no-op once Propshaft sorts the same way. |
| Just don't install gems in `vendor/bundle` | That is Bundler's deployment mode. Redmine's install guide (`doc/INSTALL`, RedmineInstall) leaves the gem location to Bundler, and nothing warns when a gem shadows a core asset. |
| Only a third-party gem triggers it | Plugins add gems through their Gemfile by design. #44294 shows how a shadowed `chart.min.js` looks to users: every chart silently gone. |
| `Gem.path` may contain odd directories | A gem directory that contains `Rails.root` itself puts every path in the gem group; the stable sort then keeps Propshaft's order, i.e. today's behaviour. No case orders worse than without the patch. |
| Why a stub of `Bundler.bundle_path` in the test | It makes a directory inside `Rails.root` a gem directory, which is the layout under test, without depending on how the test run's own bundle is installed. |

---

## Submission

- **Issue:** nog niet aangemaakt — Defect, categorie "Third-party libraries" of
  "Code cleanup/refactoring"; relateren aan #44294
- **Patch attached:** `patches/asset-paths-gem-order/2026-10-12-r25136-feature.patch`
  (één bestand: geen locales)
- **Made against:** `origin/master` r25136 (2026-09-25); applyt ook op r25227
- **Status:** patch klaar, niet ingediend
- **Feedback en wat ermee gebeurde:** —

## GEOxyz

- **Commits op `7.0-stable-GEOxyz`:** `6abebe886` (eerste vorm), `1bf0ef69b`
  (revert), en de commit met het upstream-ontwerp — de sha staat in
  `status.md` (`geoxyz_commit`)
- **Suites daar groen:** zie `status.md`
- **`nl.yml` toegevoegd:** n.v.t. (geen strings)
- **`tools/check-geoxyz-branch.sh`:** zie `status.md`
- **Wanneer kan deze commit vervallen?** Pas als GEOxyz naar de Redmine-release
  gaat die deze patch bevat (7.1 of later), of naar een Propshaft die zelf
  `vendor/bundle` achteraan zet. Tot dan blijft hij nodig zolang de bundle in
  `vendor/bundle` staat en een RedmineUP-plugin geïnstalleerd is.
