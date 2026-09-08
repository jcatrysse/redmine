# Review run — 2026-09-08 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** the `ar-sessions` change on `7.0-stable-GEOxyz`, the commit
  `status.md` calls `8bf6dce3e` — **live sha `bc745ce73`**, see the note below.
  No patch branch, and there never will be — `upstream: nooit`.
- **Dossier read:** none exists, by design (a local-only item gets no dossier)
- **Status read:** `docs/features/ar-sessions/status.md`, including the deploy
  note and "wat er al bekend is" — yes
- **Round-1 findings read:** **no, deliberately.**
  `docs/review/findings/2026-09-03-ar-sessions-claude-opus5.md` was not opened.
- **Ran the test suite:** **no**, and it matters here. The three worktrees I
  have built this session are the remaining patch branches and their trunk
  baseline; `7.0-stable-GEOxyz` was not among them. What I ran instead was the
  gem's own source, to settle two questions that decide two of the findings
  below: whether `secure_session_only` is a real option, and which serializer is
  in force.
- **Scope covered:** the store swap and its options, the gem, the migration and
  its irreversibility, the deploy check and the facts it prints, the trim
  retention, the tests as code, and the security properties that change when
  session data moves from a signed cookie into a database column.
- **Scope NOT covered:**
  - **No execution.** No test run, no rake task invoked, no database inspected.
  - **MySQL and SQLite.** The migration's `t.text :data` is 64 KB on MySQL and
    unbounded on PostgreSQL; the check reports which one you have, and GEOxyz
    runs PostgreSQL, so I did not pursue it.
  - **Production.** Whether the GEOxyz database already holds rows from the 5.1
    store is the thing the deploy check exists to answer, and it can only be
    answered there.

## Summary

The engineering here is careful and the deploy note is the best in the register.
The insight it is built on is real and easy to miss: on the database that
matters, the sessions migration's version is already in `schema_migrations`, so
`db:migrate` skips it **in silence** and a missing table is invisible until the
first request 500s on every page including `/login`. `redmine:sessions:check`
exists precisely to make that loud, it exits 1 with the reason, and it prints
the handful of facts a deploy actually needs. The integration tests are the
right kind: they drive the real middleware and one of them pins the security
property directly.

Two things I would put to Jan before this goes near production, and only one of
them is about code that was written here.

The first is the serializer, and it is the one I would act on. With no
serializer configured the gem uses **Marshal**, so `sessions.data` is
Base64-encoded Marshal that Rails `Marshal.load`s on every request with no
integrity check. Under the cookie store that data was signed by
`secret_key_base` and a tampered value was refused; under this store the bytes
come from a database column. `secure_session_only`, which the patch correctly
sets, closes the *read* half of the threat (a stolen row is not a login). It
does nothing about the *write* half, where `Marshal.load` on attacker-chosen
bytes is code execution in the Redmine process.

The second is smaller: the retention period is hard-coded as `TRIM_DAYS = 7` in
the check and repeated as an environment variable in the cron line in the deploy
note, and nothing keeps the two in step.

**Counts:** blocker 0 · major 1 · minor 1 · nit 1 · question 0

**Lines in the diff not strictly required by the feature:** 0. Six files, and
the two largest are tests.

## A note on the sha

`status.md` and `docs/REGISTER.md` give `8bf6dce3e`, which is not on
`7.0-stable-GEOxyz` — it was rewritten by the K-13 identity cleanup of
2026-09-06. The live commit is **`bc745ce73`**, same subject, and it is what I
reviewed. Written up once, for all ten affected features, as F01 of
`docs/review/findings/2026-09-08-gitignore-credentials-claude-opus5-round3.md`.

## What came back clean

| Hypothesis | Outcome |
|---|---|
| `secure_session_only` is not a real option and the security comment is wishful | **clean, and the comment is exactly right** — `activerecord-session_store-2.3.0/lib/action_dispatch/session/active_record_store.rb:66` reads `options.delete(:secure_session_only) { false }`, and line 169 is the fallback it disables: `elsif !@secure_session_only && (insecure_session = session_class.find_by_session_id(sid.public_id))`. Default is `false`, so setting it is load-bearing |
| the migration re-runs on a fresh install and clashes with an existing table | clean — `return if table_exists?(:sessions)` in `up`, and `down` raises `IrreversibleMigration` with a comment saying why (dropping it logs everyone out, and the guard would make a rollback a silent no-op that still removes the `schema_migrations` row) |
| the deploy check duplicates what `db:migrate` already reports | clean, and this is the point of the whole feature — the migration's version came over from 5.1, so it is skipped without printing a line, and the check is the only thing that looks at the table |
| the check's "rows written by an older store" is guesswork | clean — `session_id NOT LIKE '%::%'`, and a modern id really is `<n>::<digest>`; the integration test asserts `/\A\d+::/` on a freshly written row |
| the tests would pass on the old code | clean by construction — `test_session_should_be_stored_in_the_database` counts rows in a table the cookie store never writes, and `test_a_plain_text_session_id_should_not_be_accepted_as_a_login` is red without `secure_session_only`. They drive the real middleware through `Redmine::IntegrationTest`, which the comment at the top explains is the only level that can see the store at all |
| the check is an N+1 or a table scan on a large table | clean enough for a deploy step — three `COUNT`s, and it verifies the `updated_at` index exists precisely so the trim is not a scan |
| the new gem is unjustified (INV-6) | clean — the feature is the gem; the deploy note makes `bundle install` step 1 and records that without it Rails 8.1 says only `Unable to resolve session store :active_record_store`, which does not name the gem |

---

### F01 — session data is Marshal, loaded from the database with no integrity check

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed (the mechanism; the precondition — that someone can write the table — is a deployment question I cannot answer from here)
- **Category:** security
- **Where:** `config/application.rb:107` — the `config.session_store(:active_record_store, …)` call sets no serializer, and nothing else in `config/` does either
- **Invariant touched:** none

**What is wrong**

`ActiveRecord::SessionStore::Session.serializer` is a `mattr_accessor` with no
default. `serializer_class` reads `case self.serializer when :marshal, nil then
MarshalSerializer`, so leaving it unset selects Marshal:

```ruby
class MarshalSerializer
  def self.load(value)  Marshal.load(::Base64.decode64(value)) end
  def self.dump(value)  ::Base64.encode64(Marshal.dump(value)) end
end
```

Every request deserialises `sessions.data` with `Marshal.load`. There is no
signature and no MAC on that column — the store's integrity model is that the
row is only reachable by session id, not that its contents are authenticated.

This is a change in kind from what Redmine had. The cookie store put the same
data in a cookie signed with `secret_key_base`; a modified cookie was rejected
before anything was deserialised. `Marshal.load` was never applied to bytes an
attacker chose.

**Why a committer would push back**

The precondition is write access to the `sessions` table, and the honest version
of the threat model is that somebody with arbitrary write access to Redmine's
database can already make themselves an administrator by updating `users`. So
the delta is not "no access" to "admin". It is **"admin" to "shell"**: one
`UPDATE sessions SET data = …` and the next request that loads that row runs the
attacker's object graph inside the Redmine process, as the Redmine user, with
its filesystem and its database credentials.

The path that makes this worth writing down rather than shrugging at is the
narrow one: a SQL-injection defect anywhere in Redmine or a plugin that permits
a write but not command execution is, with this change, remote code execution.
Before it, it was not.

`secure_session_only` is set and does its job, and its comment is accurate about
what it does — it refuses a **read** attacker's forged login. It is silent about
the write side, which is the half that got worse, and a reader of that comment
would reasonably conclude the store had been made safe.

**How I verified it**

Read `activerecord-session_store-2.3.0/lib/active_record/session_store.rb` lines
18-105: the `mattr_accessor`, the `case … when :marshal, nil` dispatch, and all
four serializer classes. Then grepped `config/` on the branch for `serializer` —
no hits outside comments — so the `nil` branch is what runs. Not executed: I did
not write a crafted row and watch it deserialise.

**Suggested direction**

`ActiveRecord::SessionStore::Session.serializer = :json` removes `Marshal.load`
from the request path entirely. Two things to settle before doing it, neither of
which a reviewer should decide:

- **Existing rows.** JSON cannot read a marshalled row, so every live session
  breaks on deploy. `db:sessions:clear` makes that explicit and harmless (a
  logout for everyone, once). The gem also ships `:hybrid`, which reads Marshal
  and writes JSON — but read its `load`: it still calls `Marshal.load` on any
  value starting with `BAh`, so it is a migration aid, **not** a fix. Ending on
  `:hybrid` leaves the hole open.
- **What Redmine puts in the session.** `app/helpers/queries_helper.rb:362-390`
  stores a nested, symbol-keyed hash (`{:id => …, :project_id => …}`, then
  `[:filters]`, `[:group_by]`, `[:sort]`) and reads it back with symbol keys.
  JSON does not round-trip symbols. The gem's `JsonSerializer.load` returns
  `hash.with_indifferent_access[:value]`, and `HashWithIndifferentAccess`
  converts nested hashes too, so this probably survives — **probably** is the
  operative word, and it should be settled by running the query-persistence
  tests under `:json`, not by reasoning about it. That is exactly the kind of
  thing the existing integration test file is the right home for.

**Resolution:**

---

### F02 — the trim retention is written down twice and nothing keeps the two in step

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed (by reading)
- **Category:** correctness
- **Where:** `lib/redmine/session_store_check.rb` — `TRIM_DAYS = 7`, used by `facts` for `'rows the first trim would delete'`; and the cron line in `docs/features/ar-sessions/status.md`, `SESSION_DAYS_TRIM_THRESHOLD=7`
- **Invariant touched:** none

**What is wrong**

The check does not trim anything. The gem's `db:sessions:trim` does, and it
takes its cutoff from the environment:

```ruby
cutoff_period = (ENV['SESSION_DAYS_TRIM_THRESHOLD'] || 30).to_i.days.ago
```

The check computes its reported figure from its own constant instead:
`count("updated_at < ?", TRIM_DAYS.days.ago)`. The two agree today only because
the deploy note happens to write `SESSION_DAYS_TRIM_THRESHOLD=7` in the cron
line, and the constant happens to be 7. Nothing connects them: no test, no
shared source, and the constant's comment explains the choice of 7 without
mentioning that the value must be repeated in crontab for the number to be true.

**Why a committer would push back**

Concrete path, and it is the likely one rather than an exotic one: the cron line
is set up without the environment variable, or with `=30` after somebody decides
a week is too aggressive. `redmine:sessions:check` then keeps printing
`rows the first trim would delete   N` computed over seven days, while the job
deletes what is older than thirty. The number is an over-estimate, which is the
safe direction, but the deploy note uses it as a decision input — it tells the
operator to consider running the first trim by hand "if that number is large
(hundreds of thousands)". A figure that is silently four times too large steers
that decision.

**How I verified it**

Read both sides: the gem's `db:sessions:trim` task (its only cutoff source is
`ENV['SESSION_DAYS_TRIM_THRESHOLD']`, default 30) and the check's `facts`
method. Then grepped `status.md` for the cron line and confirmed it carries the
variable, so today the two match by coincidence rather than by construction.

**Suggested direction**

Have the check read the same thing the trim reads —
`(ENV['SESSION_DAYS_TRIM_THRESHOLD'] || 30).to_i` — and print the period it used
next to the count, so the output says what it measured. The constant can stay as
the recommended value that the deploy note quotes. Then the two cannot drift,
and the printed number describes whatever cron will actually do.

**Resolution:**

---

### F03 — the check reports the size limit but nothing enforces it

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed (by reading)
- **Category:** portability
- **Where:** `db/migrate/20240929111106_add_sessions_table.rb` — `t.text :data`; `lib/redmine/session_store_check.rb` — the `'session size limit'` fact
- **Invariant touched:** none

**What is wrong**

Nothing on PostgreSQL, which is what GEOxyz runs and where `text` is unbounded;
the check duly prints `none (text)`. On MySQL the same migration produces a
`TEXT` column capped at 65 535 bytes, and a session larger than that raises on
write. The check reports the limit — `"#{data.limit} bytes (#{data.sql_type}); a
bigger session raises"` — which is a good line to have, but it is a report at
deploy time about a failure that happens at request time, to one user, on the
request that grew the session.

The gem's own guidance for MySQL is `t.text :data, limit: 16.megabytes`
(mediumtext). The migration does not take that route and the branch does not say
why.

**Why a committer would push back**

They would not, and this is marked a nit for that reason: the branch is
GEOxyz-only, GEOxyz is on PostgreSQL, and the check tells you which one you are
on before traffic arrives. It is worth a line only because the migration is in
`db/migrate/` and will run for anyone who ever takes this branch to a different
database, and because the reason for the choice is not written down anywhere.

**How I verified it**

Read the migration and the `facts` method; read the gem's `create_table!` for
comparison. Not executed on MySQL — no MySQL here.

**Suggested direction**

One sentence in `status.md` under "wat er al bekend is": the column is `text`
because PostgreSQL makes that unbounded, and a MySQL deployment would want
`limit: 16.megabytes`. No code change while GEOxyz is on PostgreSQL.

**Resolution:**
