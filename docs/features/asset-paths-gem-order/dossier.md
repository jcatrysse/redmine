# asset-paths-gem-order — gems in vendor/bundle achter de assetpaden van Redmine zelf

## Voor Jan (Nederlands)

> **Beslist 2026-10-07 (avond): de regel op de server, niet de code-fix.** De
> rest van dit dossier beschrijft de code-fix zoals hij gereviewd en eerst
> gecommit werd (`6abebe886`); die gaat er met een revert weer af. De
> GEOxyz-oplossing is nu het snippet onder "Onderzoek: oplossen aan de
> RedmineUP-kant", bewezen in "Live verification" (rij "server line").

- **Wat het doet, in gewone taal:** als de gems in `vendor/bundle` binnen de
  Redmine-map staan, laat Propshaft een gem-bestand winnen van een
  core-bestand met dezelfde naam. De redmineup-gem (elke RedmineUP-plugin)
  levert Chart.js 3 als `chart.min.js`, dus geen enkele core-grafiek werkt
  nog. Deze commit zet de assetpaden van gems weer achter die van Redmine.
- **Waar het vandaan komt:** de redmine_tags-sessie, branch
  `fix/asset-paths-gems-under-rails-root` (commit `3d0c1b2`). Hier
  gereviewd, één test herschreven, en als één schone commit op
  `7.0-stable-GEOxyz` gezet.
- **Doel:** alleen GEOxyz. Jouw keuze core-q2 (2026-10-07): optie A, niet B,
  dus geen upstream-patch.
- **Afwijking GEOxyz ↔ upstream:** ja, en die blijft: een permanente eigen
  patch in `config/application.rb` en `lib/redmine/asset_path.rb`, tot
  Redmine of Propshaft dit zelf oplost. Trunk heeft hetzelfde gedrag (zie G1).
- **Kan het aan de RedmineUP-kant?** Ja, technisch wel, zonder de gem te
  patchen: één regel `config.assets.excluded_paths` in
  `config/additional_environment.rb`. Getest, werkt. Toch niet gekozen, zie
  "Onderzoek: oplossen aan de RedmineUP-kant" hieronder.
- **Wat jij nog moet doen:** na de deploy `assets:precompile` in productie, en
  één keer in de browser kijken naar een core-grafiek met de RedmineUP-plugins
  erbij (de echte plugin kon in deze sessie niet draaien, zie G9).

## Onderzoek: oplossen aan de RedmineUP-kant (stap 1 van de opdracht)

Tijdgebonden onderzoek, op de broncode van `redmineup` 1.1.13 (van rubygems)
en Propshaft 1.3.2.

**Wat de gem doet.** `Redmineup::Engine < Rails::Engine`. Een engine krijgt
van Propshaft automatisch zijn `app/assets/*` in `config.assets.paths`
(`propshaft/railtie.rb`, initializer `propshaft.append_assets_path`), dus
`app/assets/javascripts/chart.min.js` (Chart.js v3.9.1, UMD-build zonder
ES-module-export) komt op het logische pad `chart.min.js`, hetzelfde als
core's `vendor/javascript/chart.min.js` (Chart.js 4.5.1, importmap-pin
`chart.js`). Daarnaast registreert de gem zijn assets nog eens zelf, onder
`plugin_assets/redmineup/` (`Redmine::AssetPath` in
`config.assets.redmine_extension_paths`). **Alle** verwijzingen in de gem
gebruiken die tweede weg (`javascript_include_tag(..., plugin: 'redmineup')`
in `external_assets_helper.rb`); de paden op rootniveau gebruikt de gem zelf
nergens.

**Waarom het misgaat.** Propshaft sorteert na het laden de paden "binnen
`Rails.root`" vóór de rest. `vendor/bundle` ligt binnen `Rails.root`, dus de
gem-paden blijven vóór `app/javascript` en `vendor/javascript` staan, en de
eerste treffer wint. Gemeten met de bundle in `vendor/bundle`:
`chart.min.js => vendor/bundle/ruby/3.3.0/gems/<gem>/app/assets/javascripts/chart.min.js`.

**De mogelijkheden aan die kant:**

| Optie | Werkt? | Kost |
|---|---|---|
| De gem zelf aanpassen (nieuwe versie) | er is geen nieuwere gem | n.v.t. |
| Het geïnstalleerde gembestand verwijderen of hernoemen | ja, tot de volgende `bundle install` | elke deploy opnieuw, onzichtbaar |
| Een eigen fork van redmineup | ja | een gem onderhouden, in elke plugin-Gemfile omleiden |
| `config.assets.excluded_paths` voor de gem-paden, in `config/additional_environment.rb` | **ja, getest** | zie hieronder |
| De bundle buiten `Rails.root` zetten (`bundle config set --local path /elders`) | ja, Propshaft's eigen sortering doet dan het werk | productie-layout wijzigen; één `bundle config` terug en de fout is er weer |

De vierde is de enige echte kandidaat: één plek, door GEOxyz beheerd, geen
gem gepatcht. Getest met de stand-in-gem:

```ruby
# config/additional_environment.rb
if (spec = Gem.loaded_specs['redmineup'])
  config.assets.excluded_paths += Dir[File.join(spec.full_gem_path, 'app/assets/*')]
end
```

Resultaat: `chart.min.js => vendor/javascript/chart.min.js`.

**Waarom toch optie A.** Het is niet goedkoper, alleen kleiner:

1. `config/additional_environment.rb` staat in Redmine's `.gitignore`. Het
   bestand leeft per server, niet op `7.0-stable-GEOxyz`: geen gate ziet het,
   geen test dekt het, en een herinstallatie verliest het zonder dat iemand
   het merkt. Het in git forceren botst met een bestaand lokaal bestand op de
   productieserver.
2. Het lost alleen redmineup op. Het mechanisme (een engine-gem in
   `vendor/bundle` met een bestand dat ook in core bestaat) blijft open voor
   de volgende gem; de core-fix sluit het voor allemaal.
3. De core-fix bestond al, met een test die zonder de fix faalt, en blijkt
   na review correct (G2 hieronder). Beide vragen dezelfde productiestap
   (`assets:precompile`).

Dat is een Class B-afweging (bereik versus omvang), gelogd in
`decisions.md`. Wie de core-wijziging toch liever niet draagt: het
snippet hierboven is het getest alternatief.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** mirror `origin/master` `e3962939c` van
  2026-09-25. Niet gesynchroniseerd tegen redmine.org; niet nodig, want er
  wordt niets ingediend.
- **Lost trunk dit al op?** nee. Trunk heeft dezelfde `config/application.rb`
  (geen ordening van assetpaden), dezelfde Propshaft `~> 1.3.0` en dezelfde
  pin `chart.js` → `chart.min.js`. `git log --grep` op "propshaft", "asset
  path", "vendor/bundle" levert alleen #39111, #43396 en #44010, alle drie
  over iets anders.
- **Bestaand issue op redmine.org?** niet gezocht met de hand; een webzoekopdracht
  op het Propshaft-gedrag gaf niets specifieks. Irrelevant voor deze keuze:
  Jan koos geen upstream-patch.
- **Verandert iets in trunk het ontwerp?** nee.

---

# The problem

With Propshaft (Redmine 7), every engine gem contributes its `app/assets/*`
directories to `config.assets.paths`, and the first path that has a given
logical path wins. Propshaft orders the application's paths before those of
gems, but it decides "application" by a string prefix on `Rails.root`. When
the bundle is installed in `vendor/bundle` (a common deployment layout), every
gem path is under `Rails.root`, so the gems keep their place in front of
`app/javascript` and `vendor/javascript`.

A gem that ships a file with the same logical path as a core asset then
replaces it. The `redmineup` gem (1.1.13, a dependency of every RedmineUP
plugin) ships Chart.js 3.9.1 as `app/assets/javascripts/chart.min.js`. The
importmap pin `chart.js` resolves to that file instead of core's Chart.js
4.5.1 module, and every core chart (issue report details, repository
statistics) fails with `Chart is not a constructor`.

# Why this belongs in core

It is a load-order decision core makes implicitly by relying on Propshaft's
heuristic. No plugin can fix it for all gems, and the gem that triggers it
does not use the colliding root-level paths itself.

# Proposed change

After Propshaft's own sort, sort the asset paths once more: paths under
`Rails.root` and outside Bundler's and RubyGems' directories first, everything
else after, keeping the order inside each group.

| File | Change |
|---|---|
| `lib/redmine/asset_path.rb` | `Redmine::AssetPath.application_paths_first(paths, root:, gem_dirs:)` — the stable sort |
| `config/application.rb` | an `after_initialize` hook that applies it to `config.assets.paths` (Propshaft's own `after_initialize` is registered earlier, so it runs first; the load path is built lazily, on first use) |
| `test/unit/lib/redmine/asset_path_test.rb` | two tests |

**New setting / migration / gem / route / permission:** none.

**Translations:** none.

**Backward compatibility:** with the bundle outside `Rails.root` nothing
changes (Propshaft already put gems last). With it inside, the only logical
path that changes owner in the measured bundle is `chart.min.js`. Gems
installed with `path:` inside the tree (not in a gem directory) stay in the
application group, as they were. redmineup's own pages keep working: they use
`plugin_assets/redmineup/chart.min.js`, which is a separate logical path.

**Production:** a fresh `rake assets:precompile` is required after deploying,
so `public/assets/chart.min-*.js` is rebuilt from core's file.

# Alternatives considered

- **`config.assets.excluded_paths` for redmineup's paths in
  `config/additional_environment.rb`.** Works (tested), but only for that gem,
  and lives in an untracked per-server file. See the Dutch section above.
- **Bundle outside `Rails.root`.** Works without any code; rejected as the
  fix because it depends on server state that one `bundle config` undoes.
- **Patching Propshaft.** The heuristic is Propshaft's, so that is where it
  ultimately belongs; out of scope for a GEOxyz-only fix.

# Tests

| Test | What it proves |
|---|---|
| `test_application_paths_first_puts_gems_under_rails_root_behind_the_application` | the sort on literal paths: gem paths under the root, gem paths outside it, application paths, stable order inside each group |
| `test_application_asset_paths_come_before_gem_asset_paths` | the hook ran on the real configuration (the configured paths are already in the order `application_paths_first` gives), and `chart.min.js` resolves to `vendor/javascript` |

**Review change to the original branch:** the second test used to compute the
gem directories and the classification itself, which is the forbidden "test
that reimplements the code it tests". It now calls the production method and
asserts a literal path.

**Evidence (INV-8):**

- touched suite, bundle in `vendor/bundle`, stand-in gem present:
  `5 runs, 9 assertions, 0 failures, 0 errors, 0 skips`
- same, with the `config/application.rb` hook removed:
  `5 runs, 8 assertions, 1 failures` — `test_application_asset_paths_come_before_gem_asset_paths`
  fails with the gem paths in front of `app/javascript` and
  `vendor/javascript`. The first test is red on the old code with
  `NoMethodError` (the method does not exist).
- **Limit:** with the bundle outside `Rails.root` (the default in this
  container and in CI) the second test passes with and without the hook,
  because Propshaft already sorts correctly there. It guards the
  `vendor/bundle` layout only when the suite runs in it.
- full suite: see `status.md` (Bewijs)
- RuboCop on the three files: 0 offences; baseline at `origin/7.0-stable-GEOxyz`: 0
- `assets:precompile` (production, stand-in gem in `vendor/bundle`):
  without the fix `public/assets/chart.min-25f1e464.js` is the gem's file;
  with the fix `chart.min-cae696ba.js`, Chart.js v4.5.1

# Live verification (G9)

Real Redmine on `7.0-stable-GEOxyz`, bundle installed in `vendor/bundle`
inside the tree, `tools/dev-seed.rb` data. Script:
`verify/asset-paths-gem-order.mjs`.

**Stand-in, not redmineup itself.** Running Redmine with the RedmineUP plugin
(`redmine_checklists`) installed was refused in this session by the execution
environment's safety check (third-party plugin code). The mechanism is
therefore shown with `asset_shadow_probe`, a three-file engine gem written for
this check, installed into `vendor/bundle` through `Gemfile.local`: a
`Rails::Engine` with `app/assets/javascripts/chart.min.js` that, like
redmineup's Chart.js 3 UMD build, exports no ES module. It reproduces the
reported error exactly (`Chart is not a constructor`). Jan's check with the
real plugins is in `status.md`.

| Function | Screenshot | What it shows |
|---|---|---|
| core chart, gem shadows `chart.min.js`, unpatched | `before-issue-report-chart.png` | table only, no chart; pin `chart.js` serves the gem's file; page errors `Chart is not a constructor` (2×) |
| same bundle, with the fix | `issue-report-chart.png` | both charts drawn (930×465 canvas, 84890 painted pixels); pin serves Chart.js v4.5.1; no page errors |
| server line, before: branch with `6abebe886` reverted, stand-in gem named `redmineup`, no `additional_environment.rb` | `before-server-line-issue-report-chart.png` | no chart; pin serves the gem's file; `Chart is not a constructor` (2×) |
| server line, after: same, with the `excluded_paths` snippet in `config/additional_environment.rb`, verbatim | `server-line-issue-report-chart.png` | both charts drawn (84890 painted pixels); Chart.js v4.5.1; no page errors |

The server-line run used the development server. The same check in
production mode (precompile and a `RAILS_ENV=production` server) was refused
by the execution environment and has not been done; the production precompile
measured further up applies to the code fix only. redmineup's own assets are
not affected by the snippet: they are served through
`config.assets.redmine_extension_paths` (`plugin_assets/redmineup/...`), which
`excluded_paths` does not filter.

Failure paths:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| fix applied, no colliding gem in the bundle | `nogem-issue-report-chart.png` | unchanged behaviour | charts drawn, Chart.js v4.5.1, no errors |

Screenshots read, not just generated: yes — looked for the chart area under
the table (empty in before, two bar charts after) and checked the script's
console output for the served file and the page errors.

# Anticipated objections

| Objection | Answer |
|---|---|
| This is Propshaft's heuristic, fix it there | Agreed in principle; GEOxyz needs working charts now, and Jan chose a GEOxyz-only fix. |
| `Gem.path` may contain odd directories | A gem dir that contains `Rails.root` would put every path in the gem group; the stable sort then keeps Propshaft's order, i.e. today's behaviour. No case makes it worse than without the fix. |
| `after_initialize` is late | Propshaft builds the load path lazily on first use (`Redmine::AssetLoadPath` memoised in `config/initializers/10-patches.rb`); the precompile and the live server both show the reordered result. |
| Why not just exclude redmineup's paths | Tested and documented; narrower, untracked, and leaves the next gem open. |
