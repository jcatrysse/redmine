# Runbook — a working Redmine test environment

Established and verified on 2026-09-01 (Ruby 3.3.6, Rails 8.1.3,
PostgreSQL 16). Everything below was actually run; the notes are the traps that
cost time the first time.

## Once per session

```sh
service postgresql start
su postgres -c "psql -c \"CREATE USER redmine WITH PASSWORD 'redmine' SUPERUSER;\""
su postgres -c "psql -c 'CREATE DATABASE redmine_test OWNER redmine;'"
```

`config/database.yml` does not exist in the repo and is gitignored — write it
in each worktree that needs to run tests:

```yaml
test:
  adapter: postgresql
  database: redmine_test
  host: localhost
  username: redmine
  password: redmine
  encoding: utf8
```

**Trap:** Redmine's `Gemfile` reads `config/database.yml` to decide which
database gems to load. Writing it changes the bundle, so `bundle install` again
afterwards or the `pg` gem is missing.

```sh
bundle install --jobs 4
RAILS_ENV=test bundle exec ruby bin/rails db:migrate
```

**Trap:** there is no `rake` binstub in the bundle — `bundle exec rake` fails
with "command not found". Use `bundle exec ruby bin/rails <task>`.

## SCM fixtures

Repository tests **skip silently** without the test repositories, so a green
run proves nothing about them:

```sh
mkdir -p tmp/test
gunzip < test/fixtures/repositories/git_repository.tar.gz | tar -x -C tmp/test
```

With `tmp/test/git_repository` present, `git_adapter_test.rb` and
`repositories_git_controller_test.rb` run for real.

## Running tests

One file:

```sh
RAILS_ENV=test bundle exec ruby -Itest test/unit/query_test.rb
```

Filter by name — note `-n` is deprecated, use `-i`:

```sh
RAILS_ENV=test bundle exec ruby -Itest test/unit/query_test.rb -i "/nobody|assigned_to/"
```

**Several files in one process — do this, always.** Redmine's own `rake test`
loads whole suites together, and test pollution only shows up this way. Five
files in the existing port pass alone and fail together:

```sh
RAILS_ENV=test bundle exec ruby -Itest -e '
%w[
test/unit/query_test.rb
test/functional/queries_controller_test.rb
].each { |f| require File.expand_path(f) }'
```

Long runs belong in the background with the output to a file; the suites used
in the PR #1 review took 75–120 s each.

## The full suite, including the system tests

`bundle exec ruby bin/rails test` runs everything except `test/system/`.
`test:all` adds the system tests — and on a bare image every one of them errors
in setup, roughly 260 of them, because `driven_by :selenium, using: :chrome`
needs two things this image does not line up:

- a `chrome`/`google-chrome` binary on `PATH`. There is none; Playwright's
  Chromium lives at `/opt/pw-browsers/chromium-*/chrome-linux/chrome`.
- a chromedriver whose **major version matches that binary**.
  `/opt/node22/bin/chromedriver` is several majors ahead and refuses the
  session.

A 260-error run proves nothing, and it is easy to mistake for "system tests are
not available here". They are. `tools/test-env.sh` fixes both — it symlinks
Playwright's Chromium as `google-chrome` and takes `/opt/node22/bin` off `PATH`
so Selenium Manager downloads the matching driver itself:

```sh
tools/test-env.sh /home/user/wt/patch-<slug> bundle exec ruby bin/rails test:all
```

Verified on 2026-09-01: `test/system/groups_test.rb` goes from 3 errors to
3 runs, 31 assertions, 0 failures.

**Two databases, so two suites can run at once.** A trunk patch and the GEOxyz
branch are separate worktrees; give the second its own database
(`redmine_test_geoxyz`) and both suites run in parallel instead of one after
the other.

**Attachment storage is per worktree.** `dev-server.sh` now points every
worktree at `/tmp/redmine-dev-files`; before that, an attachment uploaded while
worktree A served the app was invisible from worktree B, and anything checking
`Attachment#readable?` silently dropped it. That cost one false "the feature
does not work" during G9 verification of `wiki-export-attachments`.

**Only git is available as an SCM.** `svn`, `svnadmin`, `hg`, `bzr` and `cvs`
are all absent from the image, so unpacking their fixtures would not help:
those suites announce themselves as skipped at the top of the run, and a handful
of repository tests fail rather than skip. Check against a pristine trunk run
before attributing any of that to a patch.

## RuboCop

Not exposed as a bundle binstub in this environment. Call it directly:

```sh
/opt/rbenv/versions/3.3.6/bin/rubocop --force-exclusion --format simple <files>
```

Always measure the **baseline** too, on the same files at the merge base — G4
asks for both numbers. The cheapest way is a worktree at the base:

```sh
git worktree add --detach /tmp/base origin/master
cd /tmp/base && /opt/rbenv/versions/3.3.6/bin/rubocop --force-exclusion --format offenses <files>
```

`--format offenses` gives per-cop counts, which is what belongs in a dossier.

**Trap:** `lib/tasks/**/*` is excluded in Redmine's `.rubocop.yml`. Rake files
are never linted, so nothing mechanical will catch a top-level method or
constant there.

## Attributing an offence to your own lines

Whether an offence sits on a line you added, rather than one that was already
there:

```sh
git diff -U0 origin/master...HEAD -- '*.rb' '*.rake' | awk '
  /^\+\+\+ b\// { f=substr($0,7) }
  /^@@/ { s=0;n=1;
          if (match($0,/\+[0-9]+,[0-9]+/)) { split(substr($0,RSTART+1,RLENGTH-1),a,","); s=a[1]; n=a[2] }
          else if (match($0,/\+[0-9]+/))   { s=substr($0,RSTART+1,RLENGTH-1) }
          for(i=0;i<n;i++) print f":"(s+i) }' | sort -u > /tmp/added.txt
```

Then intersect with `rubocop --format json` output on `path:line`.

## A real Redmine, in a real browser — G9

One command does the whole setup, idempotently:

```sh
tools/dev-server.sh /home/user/wt/patch-<slug>
# -> http://127.0.0.1:3000   admin / GEOxyzDev123!   project geoxyz-verify
tools/dev-server.sh --stop
```

It starts PostgreSQL, creates the dev database, writes `config/database.yml`,
bundles, migrates, loads Redmine's default data, runs `tools/dev-seed.rb`, and
boots the server — then waits until it actually answers 200 before printing
PASS. The seed gives two projects (one a subproject), three users, a group,
versions, six issues (some unassigned) and a three-page wiki hierarchy.

Then drive it:

```sh
SHOT_DIR=docs/features/<slug>/shots PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers \
  node verify/<slug>.mjs
```

`tools/verify-lib.mjs` logs in and hands you `go(path)` and
`shot(name, caption)`; `report(shots)` prints the dossier table rows.

### Six traps, each of which cost time here

1. **Playwright is a global CommonJS module.** `import { chromium } from
   'playwright'` does not resolve outside the global `node_modules`, and the
   named import fails even by absolute path. Use
   `import pw from '/opt/node22/lib/node_modules/playwright/index.js'` then
   `const { chromium } = pw`.
2. **Do not pass `executablePath`.** The browser lives in a versioned directory
   (`/opt/pw-browsers/chromium-1194/...`), not `/opt/pw-browsers/chromium`. Set
   `PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers` and let Playwright resolve it.
3. **`admin` / `admin` does not work.** Set the password deterministically —
   `tools/dev-seed.rb` does it via `rails runner` and also clears
   `must_change_passwd`.
4. **`bundle exec rake` does not exist** in this bundle. Use
   `bundle exec ruby bin/rails <task>`.
5. **`config/database.yml` drives the Gemfile**, so write it *before*
   `bundle install` or the `pg` gem is missing.
6. **Never `pkill -f "rails server"`** — the pattern matches the shell running
   it and kills your own session. Kill by pidfile, or list `ps -eo pid,cmd` and
   filter.

### Reading the screenshots

Look at them. A file that exists is not evidence. The defect this gate exists
for was a link that rendered, passed `assert_select`, and did nothing when
clicked because its JavaScript was never loaded on that page — visible in a
screenshot only if someone actually looks, and only conclusive if you also
clicked it.
