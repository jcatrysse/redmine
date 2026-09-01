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

## Driving the real app

Chromium is preinstalled with `PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers`. Do
not run `playwright install`. Useful for verifying UI behaviour that
`assert_select` cannot — a link that is present in the DOM but hidden by CSS
with no handler bound was a real defect in the existing port, and no test
caught it.
