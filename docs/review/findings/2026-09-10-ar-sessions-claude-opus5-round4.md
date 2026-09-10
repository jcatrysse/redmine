# Review run — 2026-09-10 — claude-opus5-round4

- **Reviewer:** Claude Code (Opus 5), round 4 (Deel A of `docs/review/prompt-round4.md`)
- **Reviewed:** the `ar-sessions` change on `origin/7.0-stable-GEOxyz` (`8612a76f4` + `bc745ce73` + `22daa7c96` + `5b04c5c15` + `bf5b41a0d`), against `origin/7.0-stable`. GEOxyz-local, `upstream: nooit`.
- **Dossier read:** `docs/features/ar-sessions/dossier.md` — yes
- **Status read:** `docs/features/ar-sessions/status.md` — yes, including the deploy steps
- **Ran the test suite:** partly — `session_store_check_test.rb` and `session_store_test.rb` in one process on the branch.
- **Scope covered:** the `Gemfile` line, the migration, the `config.session_store` change, `Redmine::SessionDataSerializer`, `Redmine::SessionStoreCheck` and the `.rake` file; **the serializer's whole input space, traced into activerecord-session_store 2.3.0's own code rather than reasoned about** — a real session, valid JSON that is not a hash, a hash with no `value` key, unparsable data, and a NULL column; every `session[:key]` the application writes, compared against the shapes the tests pin; RuboCop.
- **Scope NOT covered:** no `test:all` for this feature, and nothing was deployed. The one thing that cannot be checked here is the deploy sequence itself, which is what `status.md`'s four steps are for.

## Summary

**No findings.** The serializer is the whole risk in this feature and it is
airtight, which I established by reading the gem instead of the patch.

`Redmine::SessionDataSerializer` inherits the gem's `JsonSerializer` and adds
one thing: a row it cannot read as a session becomes an empty session. Whether
that is enough depends entirely on what the parent does, so I read it:

```ruby
def self.load(value)
  hash = JSON.parse(value)
  hash.is_a?(Hash) ? hash.with_indifferent_access[:value] : hash
end
```

Four ways that can hand back something Rails will choke on, and the subclass
covers all four. Valid JSON that is not a hash (`[]`, `"text"`, `1`) is
returned as-is by the parent and turned into `{}` by
`restored.is_a?(Hash) ? restored : {}`. A hash *without* a `value` key —
which is what a Marshal-era row looks like if it happens to parse — makes the
parent return `nil`, and `nil` is not a Hash, so it becomes `{}` too. Garbage
raises `JSON::ParserError`, which is rescued. And a NULL `data` column never
reaches `load` at all, because the gem's `deserialize` is
`serializer_class.load(data) if data` — I went looking for a `TypeError` there
and the gem had already closed it.

The `secure_session_only => true` line is the security half and its comment is
exact: without it the store falls back to accepting the raw cookie value as a
session id, so a row written by an older activerecord-session_store — which is
what a database upgraded from 5.1 holds — becomes a working login cookie for
anyone who can read the table. There is a test named after that
(`test_a_plain_text_session_id_should_not_be_accepted_as_a_login`).

The migration refuses to roll back, with the reason in a comment: `up` is
guarded by `table_exists?`, so a recorded rollback would be a silent no-op that
still removes the `schema_migrations` row, and dropping the table logs every
user out. That is the right trade and it is written down.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0. The new gem is
the one thing INV-6 puts a burden of proof on, and a database session store
cannot be had without it; `status.md` also records the failure mode when it is
missing, which is a Rails 8.1 message that does **not** name the gem
(`Unable to resolve session store :active_record_store`).

## Evidence I re-measured

| Claim | What I measured | Same? |
|---|---|---|
| the two test files are green | **28 runs, 127 assertions, 0 failures, 0 errors, 0 skips** | yes |
| RuboCop on the changed files: 0 | **0** on all six (rubocop 1.90.0) | yes |
| a NULL `data` column cannot raise | **confirmed** in the gem: `deserialize(data)` is `serializer_class.load(data) if data` (`session_store.rb:25-27`) | yes |
| the parent serializer returns non-hashes as-is | **confirmed** at `session_store.rb:70-79`; a hash without `value` yields `nil`, which the subclass also turns into `{}` | yes |
| the tests pin the session shapes the app stores | 10 keys pinned directly, `issue_query` by its own round-trip test; the four not pinned by name are each type-identical to a pinned one — see below | yes in substance |

## What I attacked and what held

1. **A `TypeError` from `JSON.parse(nil)`**, which the subclass's
   `rescue JSON::ParserError` would not catch. The gem never calls `load` with
   nil.
2. **A hash with no `value` key**, the most likely shape of a half-migrated
   row. Parent returns `nil`, subclass returns `{}`, the user is logged out
   once. That is `bf5b41a0d` and it is the case an ordinary `rescue` would
   have missed — the commit message says so.
3. **JSON losing a type Redmine depends on.** `test_an_integer_session_value_should_not_come_back_as_a_string`
   pins `sudo_timestamp` and `per_page` as Integers, and
   `test_a_nested_session_hash_should_still_be_readable_by_symbol` pins the
   symbol access that `SudoMode` and the registration flow use. Those are the
   two ways JSON usually bites.
4. **A session key the tests do not cover.** The application writes fourteen
   `session[:…]` keys; the shape test pins ten and `issue_query` has its own.
   The four not named are `must_activate_twofa` and `pwd` (both literally
   `'1'`, same as the pinned `twofa_autologin`), and `registered_user_id`
   (`user.id`, same as the pinned `user_id`). So the gap is nominal: every
   uncovered key is type-identical to a covered one, and the one with a
   distinct access pattern has a dedicated test. I am not filing it. What would
   rot is a *new* key of a new type — a `Time`, a symbol value, an array —
   arriving without the test growing, and that is worth knowing rather than
   worth a finding.
5. **`config.after_initialize` versus `on_load(:active_record)`** for setting
   the serializer. The comment explains the choice: `ActiveRecord::Base` loads
   before the autoload paths exist, so the constant is not resolvable in the
   `on_load` hook, and the store only deserialises on a request, which is
   later. Correct, and it is the kind of ordering detail that is invisible
   until production.

## Where I disagree with the previous rounds

Read after writing everything above, as the prompt asks.

**Nothing.** The one thing I want to record is that this feature's `status.md`
does something none of the others do, and it is the right response to the fact
that the risk here is not in the code: it turns the deploy into four numbered
steps and makes step 3 a **separate** one, `rake redmine:sessions:check`,
before traffic reaches the new code. The reason given is exact — on the
database that matters, `20240929111106` is already in `schema_migrations`, so
`db:migrate` is skipped without printing a line, and if the table is then
absent every page including `/login` is a 500. A migration that cannot fail
loudly needs a check that can, and that is what `Redmine::SessionStoreCheck`
is. For a change whose blast radius is "everyone is logged out or nobody can
log in", that is worth more than any test in the file.

**Nothing in `docs/DECISIONS.md` looks wrong to me.** K-17 option A (JSON, with
the one-time logout accepted and explained) is the choice that keeps
`Marshal.load` out of the request path, which is the only version of this
feature I would run.
