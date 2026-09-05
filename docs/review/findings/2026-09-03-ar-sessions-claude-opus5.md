# Review run — 2026-09-03 — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `7.0-stable-GEOxyz` commit `95bbb9750` (single commit, no patch branch), against `origin/7.0-stable` / branch parent `fe737441b`
- **Dossier read:** `docs/features/ar-sessions/dossier.md` — no (none exists; the feature is marked `upstream: nooit`, so `status.md` + `decisions.md` are the dossier)
- **Status read:** `docs/features/ar-sessions/status.md` (the "already settled" section) — yes
- **Ran the test suite:** yes, partly — `test/unit test/functional test/integration` in a throwaway worktree at `95bbb9750` on its own PostgreSQL database: **5549 runs, 30207 assertions, 0 failures, 0 errors, 37 skips**. The 28 system-test files could not be run: Chrome does not start in this container at all today. Details in "Test evidence" below; read every finding knowing the browser-level suites are unverified by me.
- **Scope covered:** the three register warnings verified one by one against a real running instance; migration behaviour on a database that already carries the `schema_migrations` row; rollback; boot without the gem; session fixation on login; the gem's `db:sessions:trim` task, its default threshold and its index use; the insecure-session fallback in the store; serializer; concurrency on inserts; growth rate under anonymous traffic; minimality; RuboCop; INV-4; test and screenshot evidence quality.
- **Scope NOT covered:** GEOxyz's actual production database (I cannot see it — several findings below turn on facts only Jan can check); the 5.1 commits `ea61e37e8`/`c2fefd51c` (not present in this repository, so I could not compare the 5.1 migration or the 5.1 gem version); MySQL and SQLite behaviour (PostgreSQL only here); load/soak behaviour of the `sessions` table at production volume; the `activerecord-session_store` upstream repository's commit activity and release date (rubygems normalises the date locally); browser-level testing beyond curl (no Playwright run of my own).

## Summary

The code itself is as small and as clean as this change can be: one Gemfile line,
one word changed in `config/application.rb`, and a 14-line migration that is the
gem's own generator output plus a two-line guard. RuboCop is clean, there is no
scope creep, no AI text, and the two things most likely to have been broken are
in fact right — `:path` and `:same_site => :lax` survive the switch, and
Redmine's `reset_session` still rotates the session on login (I logged in over
HTTP and watched the pre-login row disappear and a new row with a different
hashed id appear). All three of the register's deploy warnings are true, and the
`updated_at` index really is the index `db:sessions:trim` uses — PostgreSQL's
planner picks `index_sessions_on_updated_at` for the trim's `DELETE`.

What would bite GEOxyz is not the code, it is the deployment. The migration's
deliberate no-op on the production database is safe **only if** that database
really still has a correctly shaped `sessions` table, and nothing in this change
checks that. I reproduced the bad case: with the `20240929111106` row present and
the table dropped, `bin/rails db:migrate` prints **nothing at all** and exits 0 —
and then every single request, `/login` included, returns HTTP 500
(`PG::UndefinedTable: relation "sessions" does not exist`). That is a total
outage behind a green deploy step, with no way to log in and fix it from the UI.
The second problem is that the two operator notes contradict each other about
what production looks like today (the migration is a no-op because 5.1 already
ran it — which means production already stores sessions in the database — yet
everyone is supposedly logged out once because the old cookies are cookie-store
payloads). Both cannot be true, and which one is true also decides whether the
pre-existing rows are safe: I proved that this gem still accepts a row whose
`session_id` is stored in plain text as a valid session, so if 5.1 wrote plain
text ids, every row in that table is a usable login cookie for anyone who can
read the table or a backup of it. Third, the table grows with request volume, not
with user count: 100 anonymous requests to `/login` created 100 rows in five
seconds, and Redmine's own session lifetime/timeout settings do not delete rows,
so the 30-day default trim is far too generous and the cron entry is not part of
the change.

The good news on the item the brief flagged as risky: the gem's known
insert-race is **not** reachable here. Twelve concurrent requests carrying one
shared unknown cookie produced twelve rows, twelve HTTP 200s and zero unique-key
violations, because the store generates a fresh session id on a miss instead of
reusing the incoming one. The only residual race is last-write-wins when two
requests write the same row, and the cookie store had exactly that too — so this
is not a regression and the fixing session should not spend time on it.

**Counts:** blocker 1 · major 3 · minor 6 · nit 1 · question 1

**Lines in the diff not strictly required by the feature:** 0 of 16 added / 1
changed. The only candidate is the two-line `return if table_exists?(:sessions)`
guard, and `decisions.md` justifies it (`db/schema.rb` is gitignored). It is not
free, though — see F05 for what it costs.

---

### F01 — `db:migrate` reports success without a word while leaving the app unable to serve a single request

- **Status:** resolved
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `db/migrate/20240929111106_add_sessions_table.rb`, and the deploy note in `docs/features/ar-sessions/status.md` / `docs/REGISTER.md`
- **Invariant touched:** none (INV-10 is not in play — this is a GEOxyz-only change by design)
- **Resolution:** fixed 2026-09-05 — `redmine:sessions:check` fails with exit 1 on a missing or wrongly shaped table; the outage scenario reproduced and then caught (Jan g02)

**What is wrong**

The design deliberately relies on the production database already carrying
`schema_migrations` row `20240929111106` from 5.1, so that `db:migrate` skips the
migration. That is correct reasoning, but it makes the presence and the shape of
the `sessions` table a *precondition* of the deploy rather than something the
deploy establishes — and there is no step anywhere that verifies the
precondition. Rails prints nothing for a migration it skips, so the operator gets
no signal either way, and the guard inside the migration cannot help because the
migration is never invoked.

**Why a committer would push back**

Concrete failure path, reproduced end to end: `schema_migrations` contains
`20240929111106` and the `sessions` table is absent (a restore that excluded it, a
table dropped by hand, a different schema/`search_path`, or a database that was
migrated on 5.1 before the table was created there). `bin/rails db:migrate`
produces **zero output** and exit status 0. The app then boots fine — the store
touches no table at boot — and the first HTTP request raises
`PG::UndefinedTable: relation "sessions" does not exist`. `/login` is a 500 too,
so nobody can log in, and a smoke test that only checks "the process came up"
passes. Under the old cookie store there was no table to be missing, so this
failure mode is new.

**How I verified it**

Throwaway worktree at `95bbb9750`, PostgreSQL, dev server on 127.0.0.1:3123.

```
$ psql -c 'drop table sessions;'                       DROP TABLE
$ psql -tc "select count(*) from schema_migrations
            where version='20240929111106';"           1
$ bundle exec ruby bin/rails db:migrate                (no output at all)
$ psql -tc "select count(*) from information_schema.tables
            where table_name='sessions';"              0
$ curl -o /dev/null -w '%{http_code}\n' .../login      500
server log: PG::UndefinedTable (ERROR: relation "sessions" does not exist
```

For contrast, with the `schema_migrations` row deleted and the table present the
guard works exactly as `status.md` claims: the migration logs
`-- table_exists?(:sessions)` and finishes without touching the six rows I had
put in it.

**Suggested direction**

The deploy needs a positive assertion about the table before traffic reaches the
new code — something that names the expected columns and both indexes and fails
loudly when they are not there, run as its own step next to `db:migrate` and
written down in the deploy note. Whether that lives in a rake task, a psql
one-liner in the runbook, or a `db:migrate`-safe re-check is the fixing session's
call. The migration's own guard should also not be the only line of defence,
because on the very database that matters the guard never executes.

**Resolution:** fixed, 2026-09-05, per Jan's g02. `redmine:sessions:check`
(`lib/redmine/session_store_check.rb`, `lib/tasks/session_store.rake`) is the
deploy step this needed: it fails with exit 1 when the table is missing, when a
column the store needs is gone, or when either index is gone. The scenario in
this finding was reproduced end to end and then run against the fix, on the
development database of a live instance:

```
$ psql -c 'drop table sessions;'                          DROP TABLE
$ psql -tAc "select count(*) from schema_migrations
             where version='20240929111106';"             1
$ bin/rails db:migrate                                    (no output, exit 0)
$ node verify/ar-sessions.mjs   (STEP=missing-table)      GET /login -> HTTP 500
$ bin/rails redmine:sessions:check
  FAIL  the table 'sessions' does not exist, so every request would be a 500 - /login included
  exit 1
```

The 500 is committed as `shots/before-login-500-without-the-sessions-table.png`
and the same URL after the table is restored as
`shots/after-login-with-the-sessions-table.png`. The deploy note now names the
check as its own step between `db:migrate` and letting traffic in.

---

### F02 — The two deploy notes describe two different production databases, and the difference decides whether the old session rows are dangerous

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed (the contradiction; the production state itself is unverifiable from here)
- **Category:** backward-compat
- **Where:** `docs/features/ar-sessions/status.md` ("Wat Jan nog moet doen"), mirrored in `docs/REGISTER.md`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the check reports the row count and the number of older-store rows, so the deploy asks production instead of the note guessing

**What is wrong**

Note 2 says the migration does nothing on production *because 5.1 already ran
it*. If that is true, production has been storing sessions in the database for as
long as 5.1 has been running, and the cookies users hold today are already bare
session ids pointing at rows that already exist. The next note then says everyone
is logged out once *because the old cookies are cookie-store payloads*. That is
only true if the deployment being replaced used `:cookie_store`. The two
statements cannot both describe the same before-state.

**Why a committer would push back**

This is not cosmetic, because the answer changes three concrete things. (a) If
production is a 5.1 install with database sessions, nobody is logged out, the
`sessions` table already holds live rows, and the deploy is a gem/Rails upgrade
of an existing store rather than a cutover — which is the case F03 makes
dangerous. (b) If production really is a 7.0 install with `:cookie_store`, then
the `schema_migrations` row is *not* necessarily there and the migration is not a
no-op after all, which is F01's other branch. (c) It changes what "everyone is
logged out once" means for support on deploy day. I confirmed the cookie half of
the claim mechanically — a 300-character old-style payload cookie is ignored and
a fresh hashed row is created, so users would indeed be logged out *if* they came
from a cookie-store deployment — but I cannot tell which world GEOxyz is in.

**How I verified it**

Read both notes against `decisions.md`; then the cookie behaviour by hand:

```
$ curl -H "Cookie: _redmine_session=<300 random base64 chars>" .../login   200
$ psql -tc 'select count(*), left(min(session_id),6) from sessions;'       1 | 2::c9f
```

The 5.1 commits `ea61e37e8`/`c2fefd51c` are not objects in this repository
(`git cat-file -t` fails on both), so I could not read the 5.1 migration or the
5.1 gem pin to settle it.

**Suggested direction**

The note needs one factual answer, obtained from production before the deploy
rather than reasoned about afterwards: does the `sessions` table exist there
today, does it hold rows, and what do the `session_id` values look like. Whatever
the answer, only one of the two sentences should survive.

**Resolution:** fixed, 2026-09-05, and the fix is that the note no longer
reasons about production — it tells Jan to ask it. `redmine:sessions:check`
prints the row count and the number of rows written by an older store, which is
exactly the pair that settles which of the two worlds GEOxyz is in: rows present
with `<n>::` ids means 5.1 was already on the database store and nobody is
logged out; no table or no rows means the deployment being replaced used the
cookie store and everyone is. The contradictory sentences are gone from
`status.md`; what replaces them is one conditional statement plus the command
that resolves it. Measured on a real table:

```
  rows                               2
  rows written by an older store     1
```

---

### F03 — A `sessions` row whose `session_id` is stored in plain text is accepted as a valid login, so the "reading the table gives you nothing" claim only holds for rows this gem wrote

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed (mechanism); the precondition — that production has such rows — is unverified
- **Category:** security
- **Where:** `config/application.rb:104` (`:active_record_store`, no `secure_session_only`)
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — `secure_session_only => true`, pinned by an integration test that is red without it

**What is wrong**

`status.md` states that the database holds the hashed form `2::<sha256>` and that
"wie de tabel leest heeft daarmee nog geen bruikbare cookie". That is true of
rows written by version 2.3.0. It is not a property of the store: the store's
`get_session_with_fallback` first looks the private (hashed) id up, and then — because
`secure_session_only` defaults to `false` — falls back to looking up the raw
cookie value as a plain `session_id`. A row stored in the old plain-text form is
therefore a directly usable credential, and the store silently rewrites it to the
hashed form on first use.

**Why a committer would push back**

Concrete failure path, reproduced: I logged in, cloned the resulting row under
the plain-text `session_id` `plaintextcookie1234567890abcdef1`, and requested
`/my/account` with that value as the cookie. The response was an authenticated
302 to `/my/password` (the anonymous control redirects to
`/login?back_url=...`), and the row's `session_id` was then rewritten to
`2::284d0da…`. So on any database whose rows came from an older
`activerecord-session_store` — which is exactly the 5.1 database F02 is about —
every row in `sessions` is a working login cookie for whoever can read the table,
a read-only reporting user, or a database backup. The gem ships
`db:sessions:upgrade` precisely for this migration path, and neither the change
nor the deploy note mentions it.

**How I verified it**

```
$ curl -c jar ... POST /login (admin)                     302
$ psql -tc 'select id,left(session_id,12) from sessions;'  17 | 2::4ce40479b
$ psql -c "insert into sessions (session_id,data,created_at,updated_at)
           select 'plaintextcookie1234567890abcdef1', data, now(), now()
           from sessions order by id desc limit 1;"        INSERT 0 1
$ curl -H "Cookie: _redmine_session=plaintextcookie1234567890abcdef1" \
       -o /dev/null -w '%{http_code} %{redirect_url}\n' .../my/account
  302 http://127.0.0.1:3123/my/password        <- authenticated
$ curl ... .../my/account            (no cookie)
  302 .../login?back_url=...                   <- control
$ psql -tc 'select id,left(session_id,14) from sessions order by id;'
  17 | 2::4ce40479bba
  18 | 2::284d0da0792                          <- rewritten in place
```

Plus the code path in
`activerecord-session_store-2.3.0/lib/action_dispatch/session/active_record_store.rb`
(`@secure_session_only = options.delete(:secure_session_only) { false }`).

**Suggested direction**

Two independent levers exist and the fixing session should pick deliberately:
emptying the table once at deploy (which also makes the promised single logout
true, and matches `db:sessions:clear`), and/or refusing the insecure fallback in
the store configuration. Whichever is chosen, `status.md`'s claim about the table
should be narrowed to the rows this version writes.

**Resolution:** fixed, 2026-09-05. `config/application.rb` now passes
`:secure_session_only => true`, which turns off the store's fallback in
`get_session_with_fallback` that looks the raw cookie value up as a
`session_id`. Pinned by
`test/integration/session_store_test.rb#test_a_plain_text_session_id_should_not_be_accepted_as_a_login`,
which clones a signed-in row under a plain-text id and asks for `/my/account`:
with the option it is a redirect to `/login`, and with the option removed as a
mutation the same test gets `200 OK` — i.e. the finding's exploit reproduced
inside the suite. `redmine:sessions:check` counts the rows that predate the
secure id and names `db:sessions:clear` / `db:sessions:upgrade` as the way to
get rid of them; `status.md`'s claim about the table is narrowed to the rows
this version writes.

---

### F04 — The table grows with request volume rather than with logins, and the change ships neither a cron entry nor a chosen threshold

- **Status:** resolved
- **Severity:** major
- **Confidence:** confirmed
- **Category:** performance
- **Where:** `config/application.rb:104`; deploy note in `status.md` / `docs/REGISTER.md`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — retention chosen at 7 days, cron line written out, and the check predicts the size of the first trim (Jan g02)

**What is wrong**

The note treats trimming as an operational afterthought ("zet `db:sessions:trim`
in de cron") and leaves the gem's 30-day default in place. But a row is inserted
for every request that renders a CSRF token — which is every HTML page, including
`/login` and the anonymous home page — not for every login. Redmine's own
`Setting.session_lifetime` / `session_timeout` do not help: `User#verify_session_token`
filters on the `tokens` table (`app/models/user.rb:494-498`) and never deletes a
`sessions` row. So expired and abandoned sessions accumulate for a full 30 days
by default.

**Why a committer would push back**

Measured on the real thing: 100 sequential cookieless GETs of `/login` produced
**100 rows in 5 seconds**; three anonymous GETs of `/` produced 3 rows; 12
concurrent requests sharing one unknown cookie produced 12 rows. A single client
can therefore add rows at roughly 20/s with no authentication and no rate limit —
about 1.7 M rows/day — and every crawler, uptime check and health probe
contributes on every hit. At 30-day retention that is tens of millions of rows
whose only cleanup is a single unbatched `DELETE` (`Session.where("updated_at < ?").delete_all`),
i.e. one long transaction and a large volume of dead tuples. A bogus path (404)
does *not* create a row, so this is bounded to page views, but page views from
unauthenticated clients are exactly what an internet-facing Redmine gets most of.

**How I verified it**

```
$ truncate sessions; for i in 1..100: curl .../login ; elapsed=5s
$ psql -tc 'select count(*) from sessions;'                100
$ truncate sessions; curl .../ x3   -> 3 rows
$ truncate sessions; 12 concurrent curls, same unknown cookie -> 12 rows, all 200
$ curl .../nonexistent-path-xyz  -> 404, 0 rows
```

Trim behaviour and its index use, also confirmed (this is the register's third
warning, and it holds):

```
$ bundle exec ruby bin/rails -T | grep sessions
  db:sessions:clear / :create / :trim  "Trim old sessions from the table (default: > 30 days)" / :upgrade
$ update one row to updated_at = now() - 40 days; db:sessions:trim -> 12 rows -> 11 rows
$ explain delete from sessions where updated_at < now() - interval '30 days';
  -> Bitmap Index Scan on index_sessions_on_updated_at
```

`SESSION_DAYS_TRIM_THRESHOLD` is read in the gem's `lib/tasks/database.rake`, so
the override named in the note is real.

**Suggested direction**

The retention window is a decision, not a default to inherit: something at or
below Redmine's own session lifetime, with the cron entry (and its `RAILS_ENV`)
written into the deploy note rather than described in prose, and a plan for the
first trim on a table that may already be large. Whether the delete needs
batching depends on the number the fixing session picks.

**Resolution:** fixed, 2026-09-05, per Jan's g02. The retention window is a
decision now, not the gem's default: **7 days**, as
`Redmine::SessionStoreCheck::TRIM_DAYS`, with the cron line written out in the
deploy note instead of described. `redmine:sessions:check` reports how many rows
the next trim would delete, so the size of the first one is known before it runs
rather than after. Verified that the number the check predicts is the number the
gem's task actually deletes:

```
  rows                               4
  rows the first trim would delete   3
$ SESSION_DAYS_TRIM_THRESHOLD=7 bin/rails db:sessions:trim
  rows                               1
```

The batching question the finding leaves open is answered the same way: the
count tells Jan whether the first trim is a one-liner or wants doing in
batches, and the note says so with the statement to use.

---

### F05 — `db:rollback` on this migration reports "reverted" and does nothing, then leaves the app 500-ing until someone re-migrates

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `db/migrate/20240929111106_add_sessions_table.rb:3`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the migration is `up`/`down` and `down` raises `IrreversibleMigration` instead of recording a rollback that does nothing

**What is wrong**

`return if table_exists?(:sessions)` is evaluated in the reverse direction too —
`ActiveRecord::Migration::CommandRecorder` delegates `table_exists?` to the real
connection — and in the reverse direction the table exists by definition. So the
`change` method records nothing and the rollback is a silent no-op that still
removes the `schema_migrations` row.

**Why a committer would push back**

Reproduced: with one session row present, `db:migrate:down VERSION=20240929111106`
printed `reverting` / `reverted`, left the table, its two indexes and the row
untouched, and deleted `20240929111106` from `schema_migrations`. The state is now
inconsistent, and in the development environment Rails' pending-migration check
then makes **every** request a 500 until `db:migrate` is run again (I hit exactly
this by accident: `check_pending_migrations` in the server log, 500 on `/login`).
Re-running `db:migrate` converges — the guard fires, nothing is created, the row
comes back — so no data is lost; the defect is that the tooling reports a
rollback that did not happen. Not being able to destroy live sessions by
accident is arguably the *safer* behaviour, which is why this is minor rather
than major, but it is undocumented and it surprised me.

**How I verified it**

```
$ insert 1 row into sessions
$ bundle exec ruby bin/rails db:migrate:down VERSION=20240929111106
  == 20240929111106 AddSessionsTable: reverting / reverted
$ psql '\d sessions'   -> table + both indexes still there, row still there
$ psql -tc "select count(*) from schema_migrations where version='20240929111106';"  0
$ curl .../login  -> 500, ActiveRecord check_pending_migrations
$ bundle exec ruby bin/rails db:migrate  -> guard fires, row restored
```

**Suggested direction**

Either make the rollback honest or make it explicitly refuse. Rails' own
`if_not_exists:` option (which trunk already uses in
`db/migrate/20260319170822_add_index_to_users_login.rb`) keeps the migration
reversible, but note that it makes `down` really drop the table and every live
session with it — which is the opposite trade-off. Whichever way it goes, the
behaviour belongs in the deploy note, because "rollback" and "roll back the
schema" are not the same thing here.

**Resolution:** fixed, 2026-09-05. The migration is `up`/`down` instead of
`change`, and `down` raises `ActiveRecord::IrreversibleMigration`. Dropping the
table would log every user out and destroy every live session, so refusing is
the right half of the choice this finding offered, and it is now loud instead of
silent. Measured, with a row in the table:

```
$ bin/rails db:migrate:down VERSION=20240929111106
  == 20240929111106 AddSessionsTable: reverting
  ActiveRecord::IrreversibleMigration (exit 1)
$ psql: table, both indexes and the row still there
$ psql -tAc "select count(*) from schema_migrations where version='20240929111106';"  1
```

The `schema_migrations` row survives, so the inconsistent state this finding
described — and the 500 on every request that followed it — cannot happen. The
`up` path was re-verified from scratch on an empty database: the table and both
indexes are created.

---

### F06 — The boot failure is real and loud, but the error message quoted in the note does not exist in Rails 8.1

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/ar-sessions/status.md` (deploy note 1), `docs/REGISTER.md`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the note quotes the message Rails 8.1 actually raises

**What is wrong**

The note promises that without `bundle install` "Rails geeft dan letterlijk de
melding dat `ActiveRecord::SessionStore` uit Rails is gehaald en een gem is".
That message was Rails' old dedicated warning for this case; it is not in Rails
8.1. `grep` finds no mention of `activerecord-session_store` or
`ActiveRecordStore` anywhere in railties 8.1.3.1 or actionpack 8.1.3.1.

**Why a committer would push back**

The substance of the warning is right — I removed the gem and the app refuses to
boot — but the operator who hits this at 2 a.m. will grep the log for a string
that is not there. What Rails 8.1 actually raises, from
`actionpack/lib/action_dispatch.rb:116`, is a generic `RuntimeError`: "Unable to
resolve session store :active_record_store. … Is :active_record_store spelled
correctly, and are any necessary gems installed?" — it never names the gem to
install. It is raised while building the middleware stack, so the process dies at
startup rather than serving broken requests, which is the important half and is
correct.

**How I verified it**

Second throwaway worktree at the same commit, gem line removed from the Gemfile,
`bundle install`, then `bundle exec ruby bin/rails runner 'puts "BOOTED OK"'`:

```
action_dispatch.rb:116:in `rescue in resolve_store':
  Unable to resolve session store :active_record_store. (RuntimeError)
  ... from rails/application/default_middleware_stack.rb:76
```

I did not separately reproduce the other half of the same scenario — Gemfile
updated, `bundle install` not run at all — where Bundler refuses before Rails is
reached; that one is Bundler's standard `Gem::MissingSpecError` and I reasoned it
rather than executing it.

**Suggested direction**

Quote the message Rails 8.1 actually prints, or drop the quotation and keep the
instruction.

**Resolution:** fixed, 2026-09-05. The invented quotation is gone from
`status.md`; the note now gives the message Rails 8.1 actually raises,
`Unable to resolve session store :active_record_store`, and says that it never
names the gem to install.

---

### F07 — Session data is `Marshal`-loaded from the database, so database write access becomes code execution in the Redmine process

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed (mechanism), speculative as an exploit path (needs write access)
- **Category:** security
- **Where:** `config/application.rb:104` (no `ActiveRecord::SessionStore.serializer` set)
- **Invariant touched:** none
- **Resolution:** decided 2026-09-05 — the serializer stays Marshal, because a JSON round-trip loses the symbol keys of `session[:issue_query]`; reason recorded in `decisions.md`

**What is wrong**

The gem's default serializer is `MarshalSerializer`:
`Marshal.load(::Base64.decode64(value))` on every session read
(`lib/active_record/session_store.rb:58-66`). The cookie store signed its payload
with `secret_key_base`, so the equivalent attack needed the secret. With the
database store the bytes come from a table row and are deserialised
unconditionally.

**Why a committer would push back**

Anyone who can write a row into `sessions` — a compromised database account, a
write-capable SQL injection, a restored-from-untrusted-source dump — gets
`Marshal.load` of bytes they chose inside the application process, which is
remote code execution rather than session theft. The bar is high, and this is why
it is minor and not major; but the gem ships `:json` and `:hybrid` serializers
(the latter reads existing Marshal rows and writes JSON), so the surface can be
removed with one configuration line and no cutover.

**How I verified it**

Read the gem source; not exploited. I did confirm the stored `data` really is
base64 Marshal (`BAh7BkkiEF9jc3JmX3Rva2Vu…` in every row I created).

**Suggested direction**

If the change is going to be permanent, the serializer is worth an explicit
decision with a line in `decisions.md`, in either direction. Note that Redmine
stores non-trivial objects in the session, so a straight switch to `:json` is not
free — that is exactly what `:hybrid` is for.

**Resolution:** decided, 2026-09-05, and the decision is **not** to change the
serializer — with the reason written down, which is what the finding asked for.
`:json` and `:hybrid` are not free here: `app/helpers/queries_helper.rb:370`
stores `session[:issue_query] = {:project_id => …, :filters => …, :group_by =>
…}` and reads it back with symbol keys at line 382, and a JSON round-trip
returns string keys, so the remembered issue filter would silently stop working
on every page that uses it. Removing an attack that needs database write access
by breaking a feature every user touches is the wrong trade. Recorded in
`docs/features/ar-sessions/decisions.md`. If Jan wants it closed anyway, it is a
change to Redmine's own session usage first, not to this line.

---

### F08 — `t.text` is unlimited on PostgreSQL but 64 KB on MySQL, where an oversized session becomes a 500 instead of a truncation

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed (mechanism), unverified for GEOxyz (adapter unknown to me)
- **Category:** portability
- **Where:** `db/migrate/20240929111106_add_sessions_table.rb:7`
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the check prints the adapter and the `data` column limit of the database it is run against

**What is wrong**

The gem checks the `data` column's declared limit before saving and raises
`ActionController::SessionOverflowError` when the serialised session exceeds it
(`session.rb:raise_on_session_data_overflow!`). On PostgreSQL `text` reports no
limit, so the check is inert. On MySQL `TEXT` is 65 535 bytes and the check
fires.

**Why a committer would push back**

Redmine supports MySQL, and Redmine sessions are not tiny — a stored issue query
with many filters plus the CSRF token plus a flash can grow. If GEOxyz is on
MySQL, the user who trips the limit gets a 500 on the request that would have
saved the session, repeatedly, with nothing in the UI to explain it. The cookie
store had a 4 KB ceiling — which is the very limit this change is meant to remove
— but it failed differently (a cookie-overflow error at 4 KB, mentioned in the
feature's own rationale). `config/database.yml` is gitignored, so I could not
determine which adapter production uses.

**How I verified it**

Read the gem's overflow guard; confirmed the column is `character varying`/`text`
with no limit on my PostgreSQL instance (`\d sessions`). Not tested on MySQL —
no MySQL in this environment.

**Suggested direction**

If production is PostgreSQL, one line in `status.md` saying so closes this. If it
is MySQL, the column type deserves a deliberate choice rather than the
generator's default.

**Resolution:** fixed, 2026-09-05, by making the deploy answer it instead of
the dossier guessing. `redmine:sessions:check` prints the adapter and the
declared limit of the `data` column, taken from the database it is run against:
`session size limit  none (text)` on PostgreSQL, and the byte count with "a
bigger session raises" wherever the column has one. So the MySQL question is
answered by the same command that has to be run at deploy time anyway.

---

### F09 — Nothing in the suite asserts that sessions are in the database, and the 65 functional test files never touch the store at all

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** the commit adds no test
- **Invariant touched:** none (G3)
- **Resolution:** fixed 2026-09-05 — `test/integration/session_store_test.rb` (4 tests, red on `:cookie_store`) plus 11 unit tests for the check

**What is wrong**

The evidence for a change with this blast radius is "the full suite is still
green". That is worth having, but it is weaker than it looks, and there is no
test anywhere that would fail if `config/application.rb` were reverted to
`:cookie_store` tomorrow.

**Why a committer would push back**

`ActionController::TestCase` builds its own `TestSession`
(`actionpack/lib/action_controller/test_case.rb:51,197`) and never runs the
session middleware, so all 65 files under `test/functional` are blind to which
store is configured. Only the 93 files under `test/integration` and the 28 under
test/system exercise the real stack. So a green `test:all` mostly proves the
change did not break something else — which is valuable — while the change's own
behaviour rests entirely on the manual browser check and on my curl probes. One
integration-level assertion (log in, expect exactly one row, expect the id in the
row not to equal the cookie) would make the store's behaviour a regression test
instead of a screenshot.

**How I verified it**

Read `action_controller/test_case.rb`; counted the suites
(`ls test/integration/**/*.rb | wc -l` → 93, `test/system` → 28,
`test/functional` → 65); grepped the commit for tests (none).

**Suggested direction**

One small integration test, in the shape Redmine's own
`test/integration/*_test.rb` files use. It also gives the fixing session a place
to pin F03's expectation (that the stored id is not the cookie value).

**Resolution:** fixed, 2026-09-05.
`test/integration/session_store_test.rb`, four tests: the session is in the
table, the stored id is not the cookie value, deleting the row logs the user
out, and a plain-text id is refused. Reverting `config/application.rb` to
`:cookie_store` as a mutation gives **2 failures and 2 errors** in that file, so
it is the regression test this finding asked for. Plus
`test/unit/lib/redmine/session_store_check_test.rb`, eleven tests for the deploy
check, each of the four structural checks confirmed red by removing it.

---

### F10 — The one committed screenshot would look identical with the old store, and there is no before/after pair

- **Status:** resolved
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/ar-sessions/shots/logged-in-with-a-database-session.png`, `verify/ar-sessions.mjs`
- **Invariant touched:** none (G9)
- **Resolution:** fixed 2026-09-05 — the shot that could not fail is deleted; a 500/working pair and a revocation pair replace it

**What is wrong**

`verify/ar-sessions.mjs` logs in, prints the cookie's attributes to the console,
navigates to `/my/page` and takes one screenshot. I opened the image: it is a
normal My page with the seeded verification issues. Nothing in it distinguishes a
database session from a cookie session, and the console line that *does* carry
the evidence (`sameSite`, `path`, `httpOnly`, 32 bytes) is not captured as an
artefact.

**Why a committer would push back**

For the highest-risk item in the register, G9's requirement is the part that
would catch a store that "works" in tests and not in a browser — and the shot as
taken cannot fail. There is no `before-*.png`, so the image also cannot show that
it is this change's doing. The verification that convinced me was elsewhere: the
row content, the id rotation on login, and the failure paths — and none of that
is in the committed evidence. The failure paths in particular (gem missing, table
missing, session store disabled) are the ones a reviewer would most want to see
proven, and F01 shows they are exactly where the risk sits.

**How I verified it**

Read `verify/ar-sessions.mjs` and viewed the PNG.

**Suggested direction**

Evidence that changes when the feature changes: the cookie/row pair rendered
somewhere visible or captured as text next to the shot, a before/after pair, and
at least one screenshot of the change correctly failing (the 500 with the table
absent is a good one, and it doubles as F01's regression evidence).

**Resolution:** fixed, 2026-09-05. `verify/ar-sessions.mjs` was rewritten
into three steps and the screenshot this finding is about was deleted, because
it could not fail. What replaces it:

| Screenshot | What it shows |
|---|---|
| `before-login-500-without-the-sessions-table.png` | `/login` as a 500, `PG::UndefinedTable: relation "sessions" does not exist` — F01's failure path, in a browser |
| `after-login-with-the-sessions-table.png` | the same URL with the table restored |
| `revoked-before-deleting-the-row.png` | signed in on `/my/account` |
| `revoked-after-deleting-the-row.png` | the same page after `delete from sessions`: the login form |

The cookie/row pair is captured as text by the same script and quoted in
`status.md` (`cookie bytes=32 … value=ea5b2a82…` next to
`database session_id=2::10bb2045…`, and "cookie value stored verbatim? no").

---

### F11 — `status.md`'s RuboCop evidence lists a file this commit does not touch

- **Status:** resolved
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/ar-sessions/status.md` ("RuboCop op de gewijzigde bestanden: 0 offences op 4 bestanden")
- **Invariant touched:** none
- **Resolution:** fixed 2026-09-05 — the RuboCop line names the files this feature changes

**What is wrong**

Four files are named, including `config/environments/development.rb`. This commit
changes three: `Gemfile`, `config/application.rb` and the migration.
`config/environments/development.rb` belongs to `geoxyz-hosts` (`fe737441b`).

**Why a committer would push back**

It is only a count, and the count that matters is right — I re-ran RuboCop on the
three real files and got "3 files inspected, no offenses detected". But INV-8's
whole point is that the numbers in the dossier are the evidence, so a number that
includes another feature's file is the kind of thing that erodes trust in the
rest of the table.

**How I verified it**

`git show 95bbb9750 --stat` (3 files); `git log` for
`config/environments/development.rb`;
`rubocop --force-exclusion --format simple Gemfile config/application.rb db/migrate/20240929111106_add_sessions_table.rb`
→ 0 offences.

**Resolution:** fixed, 2026-09-05. The RuboCop line in `status.md` now names
the files this feature actually changes. For the ronde-2 commit that is five
linted files — `config/application.rb`, the migration,
`lib/redmine/session_store_check.rb` and the two tests — with 0 offences;
`lib/tasks/session_store.rake` is not inspected, because `.rubocop.yml` excludes
`lib/tasks/**`.

---

### Q01 — The commit's committer is `Claude <noreply@anthropic.com>` (INV-4), which traps.md records as knowingly not fixed

- **Status:** resolved
- **Severity:** question
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** commit `95bbb9750` metadata
- **Invariant touched:** INV-4
- **Resolution:** answered 2026-09-05 — this session commits as Jan; the two commits it put on the branch earlier today are named as worse, and are not force-pushed away

**What is wrong**

Author is `Jan Catrysse <jan.catrysse@geoxyz.eu>`, committer is
`Claude <noreply@anthropic.com>`. The message body is clean and the diff contains
no AI traces at all (I grepped it). This is not specific to `ar-sessions`: 13 of
the 19 commits on `7.0-stable-GEOxyz` are the same, and `docs/traps.md` already
explains the cause (`tools/session-push.sh` replays commits as a rebase, which
stamps the container's git identity) and records the conclusion that fixing it
after the fact needs a force push on a branch other sessions push to, "en dat is
het niet waard".

**Why this is a question and not a finding**

Per the review rules, a finding that would relax INV-4 is Jan's call, and the
decision is already recorded. I raise it once, here, so that it is visible on the
one item that goes to production: the branch GEOxyz runs carries an AI identity
in the commit metadata of most of its commits. Nothing in the working tree or in
any patch is affected.

**How I verified it**

`git log -1 --format="A:%an <%ae>%nC:%cn <%ce>"` on `95bbb9750`; the same across
`origin/7.0-stable..origin/7.0-stable-GEOxyz`; `git show 95bbb9750 | grep -i
"claude\|co-authored\|generated\|opus\|anthropic\|session_01\|TODO"` → nothing.

**Resolution:** partly fixed, 2026-09-05, and the honest part first: the two
commits **this framework's own sessions** put on the branch on 2026-09-05
(`113f32117`, `030aaf471`) are worse than the ones this finding is about — their
**author** is `Claude <noreply@anthropic.com>`, not just their committer. That
was my mistake; `docs/traps.md` names the fix and I did not apply it. From this
commit on, the worktree carries
`git config user.name "Jan Catrysse" / user.email jan.catrysse@geoxyz.eu`, so
`8bf6dce3e` has Jan as both author and committer. The earlier commits stay as
they are: correcting them needs a force push on a branch other sessions push to,
and `docs/traps.md` already records that as not worth it. Worth knowing that
`tools/check-geoxyz-branch.sh` greps commit *messages* only, so it does not see
this at all — that is why it went unnoticed twice.

---

## Checked and found clean — do not spend time here

These are the things the brief asked about that turned out to be fine. Each was
tested, not assumed.

- **The register's warning 1 (bundle install first) is true.** Removing the gem
  makes the app refuse to boot with a `RuntimeError` while the middleware stack
  is built, before any request is served. Only the quoted message is wrong (F06).
- **The register's warning 3 (trim + the index) is true in every part.**
  `db:sessions:trim` exists in 2.3.0, its default threshold is 30 days,
  `SESSION_DAYS_TRIM_THRESHOLD` overrides it, it filters on `updated_at`, and
  PostgreSQL's planner uses `index_sessions_on_updated_at` for that `DELETE`. The
  index is there for the reason `decisions.md` says. What is missing is the cron
  entry and a threshold decision (F04), not the mechanism.
- **Session fixation is handled.** `logged_user=` → `reset_session`
  (`app/controllers/application_controller.rb:206`) destroys the pre-login row
  and the next write creates a new one under a new id. Observed over HTTP: row
  `2::e4f58ca…` before `POST /login`, row `2::d7becdb…` after, cookie 32 bytes.
  A CSRF rejection (422) rotates it too, via the `reset_session` at line 197.
- **`:path` and `:same_site => :lax` survive the switch**, as `decisions.md`
  claims. The store only defaults `same_site` when the option is absent
  (`active_record_store.rb`: `options[:same_site] = DEFAULT_SAME_SITE unless
  options.key?(:same_site)`), and the cookie in my jar keeps `path=/` and 32
  bytes of value.
- **The gem's insert race is not reachable here.** On a lookup miss the store
  calls `generate_sid` instead of reusing the incoming id, so 12 concurrent
  requests with one shared unknown cookie produced 12 rows, 12× HTTP 200 and 0
  `RecordNotUnique`/`PG::UniqueViolation` in the log. The residual is
  last-write-wins when two requests write the same row, which the cookie store
  had identically — not a regression.
- **Version pinning and compatibility are right.** `~> 2.3.0`; 2.3.0 is the
  newest published version (`gem list -r -a` → 2.3.0 highest); it requires
  `activerecord/actionpack/railties >= 7.1` and `rack >= 2.0.8, < 4`, and the
  branch pins Rails 8.1.3.1 with rack 3.2.7 resolved — it installed, booted and
  served requests. Worth one line somewhere that the `rack < 4` ceiling couples
  a future Rails upgrade to a new release of this gem. `Gemfile.lock` is
  gitignored in Redmine, so the deployed patch level is whatever the server
  resolves; that matches the project's own practice.
- **Minimality (INV-1) and comments (INV-3).** 16 added lines, 1 changed, no
  reformatting, no tidying of neighbours; the commented-out `:cookie_store`
  block from the 5.1 version was correctly left behind. `ActiveRecord::Migration[8.1]`
  matches the branch's other new migration. The migration body is the gem
  generator's output verbatim apart from the guard.
- **Out-of-order migration numbering is harmless to Rails.** `20240929111106`
  sorts between upstream's `20240213101801` and `20241007144951`; Rails runs an
  un-run migration regardless of where its timestamp sits. I confirmed it both
  ways: fresh database (runs in sequence) and a fully migrated database with the
  row deleted (runs, guard fires, no complaint).
- **RuboCop:** 3 files inspected, 0 offences.

## Test evidence

Full `test:all` in a throwaway worktree at `95bbb9750`, own PostgreSQL database,
git fixtures unpacked, `svn`/`hg`/`bzr`/`cvs`/`filesystem` repositories and LDAP
absent (so those suites skip, as they do on pristine trunk in this environment).

```
$ RAILS_ENV=test bundle exec ruby bin/rails test test/unit test/functional test/integration
Finished in 645.053778s, 8.6024 runs/s, 46.8287 assertions/s.
5549 runs, 30207 assertions, 0 failures, 0 errors, 37 skips
```

**Green, and the 93 integration files — the ones that actually run the session
middleware — are inside that number.** So the change does not break the rest of
Redmine on PostgreSQL.

**The 28 system-test files are not in it, and I could not run them.** In this
container Chrome will not start at all right now:
`Selenium::WebDriver::Error::SessionNotCreatedError: session not created: Chrome
instance exited`, raised in `application_system_test_case.rb:75` before any
Redmine code executes. A first attempt at `test:all` produced 92 such errors and
`test/system/quick_jump_test.rb` alone fails in 2.4 s the same way (3 runs, 3
errors). Selenium also warns that the chromedriver in PATH (147.0.7727.24) does
not match the installed Chrome (141.0.7390.37). A browser that never launches
cannot be a session-store failure, and `status.md` reports these suites green
earlier today, so I read this as the environment rather than the change — but it
does mean **I have not re-verified the system tests myself**, and they are the
suites closest to what F10 is about.

RuboCop on the three changed files: `3 files inspected, no offenses detected`.


Two earlier attempts at the same run were lost to the environment rather than to
the code: the first two overlapped on one database after a background wrapper
returned while its child kept running, and a third detached run was SIGTERMed at
`test/functional/projects_controller_test.rb`. Two other review sessions were
running their own suites on this machine throughout, so wall-clock timings here
mean nothing and a flaky system test would not surprise me.
