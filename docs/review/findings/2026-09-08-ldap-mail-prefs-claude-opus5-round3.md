# Review run — 2026-09-08 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** the `ldap-mail-prefs` rebuild on `7.0-stable-GEOxyz`, the commit
  `status.md` calls `113f32117` — **live sha `bc7314a62`**, see the note below.
  No patch branch, and there never will be — `upstream: nooit`.
- **Dossier read:** none exists, by design (a local-only item gets no dossier)
- **Status read:** `docs/features/ldap-mail-prefs/status.md`, including "wat er
  al bekend is" — yes, and `docs/DECISIONS.md` for g01, g01b and g01c
- **Round-1 findings read:** **no, deliberately.**
  `docs/review/findings/2026-09-03-ldap-mail-prefs-claude-opus5.md` was not
  opened. `status.md` says in passing that there were eleven findings, two of
  them blockers, and what the rebuild's goal became; those sentences were read.
- **Ran the test suite:** **no**, and this is the gap that matters most for how
  the findings below should be read. `7.0-stable-GEOxyz` was not available to me
  as a built worktree this session — the four I have are running the three
  remaining patch branches and their trunk baseline. What I did instead: read
  the 226-line test file and check that it drives the production class rather
  than a copy of it (it does), run RuboCop on the changed Ruby, and reproduce
  the one behaviour a finding rests on in plain Ruby with ActiveSupport loaded.
- **Scope covered:** the rake file against the forbidden-constructs table, the
  option parsing, the dry-run/apply safety model, the journal and the undo path,
  the account selection, transaction and rollback behaviour, N+1, the tests as
  code, and lint.
- **Scope NOT covered:**
  - **No execution against a database.** No test was run, no task was invoked.
    Every claim below is from reading, except the `present?` behaviour in F01,
    which I ran.
  - **No LDAP server.** The selection is `auth_source_id IS NOT NULL`; whether
    GEOxyz's import populates that field for the accounts Jan means is a
    question about their directory, not about this code.

## Summary

The rebuild is good work and the shape is right: the rake file holds no logic at
all — no top-level `def`, no top-level constant, just two `task` blocks that
hand `ENV.to_h` to `Redmine::LdapNotificationDefaults` and turn its one exception
class into `abort`. That is exactly what the forbidden-constructs table asks for
and it is the half the 5.1 original got wrong. The class journals previous
values before it writes, wraps the pass in a transaction so a failure halfway
cannot leave half the accounts changed, names the account an exception came
from, preloads preferences so the pass is not an N+1, and has an undo that reads
the journal back. Twenty-odd tests drive the real class.

One thing is wrong and it is wrong in the safety mechanism itself: **`apply=0`
writes.** The guard is `options['apply'].present?`, and `"0".present?` is `true`,
so `apply=0`, `apply=false` and `apply=no` all apply the change. The documented
usage is safe, and the tests only ever pass `apply => '1'` or leave it out, so
nothing catches it. Two methods further up the same file, `no_self_notified`
goes through a proper `BOOLEANS` table — the machinery to do this right is
already there and unused for the one option where being wrong is destructive.

**Counts:** blocker 0 · major 1 · minor 1 · nit 1 · question 0

**Lines in the diff not strictly required by the feature:** 0. The 38 deleted
lines are the old task, which g01 replaced.

## A note on the sha

`status.md` and `docs/REGISTER.md` give `113f32117`. That commit is not on
`7.0-stable-GEOxyz` — it was rewritten by the K-13 identity cleanup of
2026-09-06 and the record was never updated. The live commit is **`bc7314a62`**,
same subject, and it is what I reviewed. This is not a defect of this feature;
it affects 21 of 32 recorded shas across ten features and is written up once, as
F01 of `docs/review/findings/2026-09-08-gitignore-credentials-claude-opus5-round3.md`,
with the full old-to-new table. Mentioned here only so the next reader knows
which object these findings point at.

## What I checked, and what came back clean

| Hypothesis | Outcome |
|---|---|
| the rake file carries logic, as the 5.1 original did | clean — `grep -nE '^\s*def \|^[A-Z_]+ *='` over the `.rake` file returns nothing; both tasks are a single call plus a `rescue` that aborts |
| `user.pref` inside the loop is an N+1 | clean — `scope.preload(:preference).find_each`, and `current_values` reads only `user.mail_notification` and `user.pref` |
| a failure halfway leaves half the accounts written | clean — `transaction(apply?)` wraps the whole pass and yields without a transaction when only reporting, and there is a test that rolls back on a later failure |
| the pass touches local accounts or the built-in administrator | clean — `User.where.not(:auth_source_id => nil)`, with tests for both the scope and for groups |
| it silently resets a preference the operator did not name | clean — `parse` uses `options.key?(field)`, so an unnamed field is absent from `values` and never assigned; there is a test |
| `save!(validate: false)` hides a real problem | deliberate and documented in a comment: LDAP accounts do not always pass Redmine's validations, and this pass must still set their preferences. Reasonable for a one-off admin task |
| the tests reimplement the code they test | clean — they call `Redmine::LdapNotificationDefaults.parse`, `.new(...).run` and `.undo(...)` and assert literal values |
| lint | `2 files inspected, no offenses detected` on the two Ruby files (`lib/tasks/**` is excluded by Redmine's own `.rubocop.yml`) |
| selecting every auth-source account is too broad | **settled, not a finding** — g01b decided exactly this: "selection is `auth_source_id IS NOT NULL`; group membership is no longer consulted" |

---

### F01 — `apply=0` applies the change

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/redmine/ldap_notification_defaults.rb` — `@apply = options['apply'].present?` in `initialize`, and the same expression in `self.undo`
- **Invariant touched:** none

**What is wrong**

The entire safety model of this task is that it reports unless it is told to
write. That decision is `options['apply'].present?`. `present?` is `!blank?`,
and for a String only `""` and whitespace are blank, so **every** non-empty
value is "apply":

```
apply="1"      present? -> true
apply="0"      present? -> true
apply="false"  present? -> true
apply="no"     present? -> true
(absent)       present? -> false
apply=""       present? -> false
```

The same expression governs `undo`, so `undo … apply=0` writes the old values
back rather than reporting them.

**Why a committer would push back**

This is GEOxyz-local, so the reviewer is Jan, and the concrete path is his:

```
# report first
bundle exec rake redmine:users:set_ldap_notification_defaults \
  mail_notification=none no_self_notified=1 auto_watch_on= apply=1 RAILS_ENV=production
# ...read the output, want to look again without writing, so change the 1 to a 0
bundle exec rake redmine:users:set_ldap_notification_defaults \
  mail_notification=none no_self_notified=1 auto_watch_on= apply=0 RAILS_ENV=production
```

The second command writes every LDAP account. Editing `1` to `0` is a more
natural way to go back to a dry run than deleting the whole token, and the task
prints `Reporting only. Add apply=1 to write.` **only** when it is reporting, so
the absence of that line is the sole signal that something went wrong — on a run
the operator believes is a no-op.

The change is not catastrophic (the journal is written and `undo` exists), which
is why this is major and not a blocker. It is still a destructive bulk write on
an explicit "do not write" instruction.

**And the file already knows how to do this.** `parse_no_self_notified` runs its
value through `BOOLEANS`, a frozen table mapping `1/true/yes` and `0/false/no`,
and raises on anything else. That is the right treatment, applied to the option
where being wrong costs a preference, and not to the one where being wrong costs
the whole run.

**How I verified it**

Ran the predicate itself under ActiveSupport 8.1 — the six rows above. Then read
both call sites and the twenty test cases: every test passes either
`'apply' => '1'` or no `apply` key at all, so `apply=0` is untested in both
directions, which is why the suite is green and the behaviour is still wrong.

**Suggested direction**

Route `apply` through `BOOLEANS` the way `no_self_notified` already is, and
raise `Error` on a value that is in neither column, so `apply=maybe` fails
loudly instead of writing. A test for `apply=0` on both `run` and `undo` is what
would have caught this; a test that `apply=nonsense` raises is what keeps it
caught.

**Resolution:**

---

### F02 — the journal that makes the run reversible is written after the transaction commits

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed (by reading; not reproduced)
- **Category:** correctness
- **Where:** `lib/redmine/ldap_notification_defaults.rb` — `run`, the second `write_journal(journal)`, which sits after the `transaction(apply?)` block
- **Invariant touched:** none

**What is wrong**

`run` writes the journal twice on purpose, and the comment explains the first
one: an unwritable path must fail before the first account changes. That is
right. But the *useful* journal — the one holding the previous values — is
written only after the transaction has committed. Between the commit and that
write there is a window in which the database is changed and the file on disk
still says `"users": []`.

**Why a committer would push back**

Two ways in, both real for a run over a few hundred accounts:

1. The process dies after the commit (a SIGKILL, a session that drops, an OOM).
2. The write fails where the early write succeeded. The early write is a few
   hundred bytes; the final one carries one entry per changed account, so a full
   disk or a quota is a case where exactly the second write fails.

In both cases the accounts are changed and the journal is the empty one, so
`undo` on it reports `0 accounts` and restores nothing. Worse, the file is not
obviously wrong to read: the early write already stamps `'applied' => apply?`,
so it says `applied: true` with an empty user list, which reads like "the run
found nothing to do" rather than "this journal is a stub".

The probability is low and the operator is a human watching the output, which is
why this is minor rather than major. But the journal is the only thing standing
between a mistaken run and a manual repair of every LDAP account, so the window
is worth closing.

**How I verified it**

Read only — I did not kill a run or fill a disk. The ordering is plain in the
source: `write_journal([])`, then `self.class.transaction(apply?) do … end`, then
`write_journal(journal)`.

**Suggested direction**

Write the real journal inside the transaction, after the loop and before the
block ends, so that a failure to write it rolls the accounts back too, and the
two states cannot disagree. The early `write_journal([])` still earns its place
as the writability probe. Whatever the fix, the property to pin in a test is
"the file on disk lists every account the run changed", not "a file exists".

**Resolution:**

---

### F03 — the journal file lands in `log/` by default, where nothing protects it

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed (by reading)
- **Category:** conventions
- **Where:** `lib/redmine/ldap_notification_defaults.rb` — `self.default_journal_path`, `Rails.root.join('log', "ldap-notification-defaults-<timestamp>.json")`
- **Invariant touched:** none

**What is wrong**

Nothing functionally. Two smaller things about the choice of directory:

- `.gitignore` carries `/log/*.log*`, which does **not** match a `.json` file.
  A journal written into a git checkout therefore shows up as an untracked file
  in `git status`, and `git add -A` would stage it. It holds logins and their
  notification preferences — not secret, but not something to commit either.
- `log/` is what logrotate and deploy scripts clean. The file that makes the run
  reversible is the one file that should outlive a deploy.

**Why a committer would push back**

They would not; this is a nit and marked as one. The realistic path is mild: a
deploy rotates or wipes `log/`, and the undo journal for a run made that morning
is gone. Since the operator can pass `journal=<path>` explicitly, the fix may
well be documentation rather than code.

**How I verified it**

Read the method, then checked `.gitignore` on the same branch: the `log` entries
are `/log/*.log*` and `/log/mongrel_debug`, neither of which matches
`ldap-notification-defaults-20260908-101500.json`.

**Suggested direction**

Either default to a directory that is ignored and not rotated (`tmp/` is
ignored wholesale by `/tmp/*`), or keep `log/` and say in the task description
that the journal is the undo record and should be copied somewhere durable
before the next deploy. One line either way.

**Resolution:**
