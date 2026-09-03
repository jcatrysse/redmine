# Review run — 2026-09-03 — claude-opus5

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `7.0-stable-GEOxyz` at `add935736` (single commit, parent `95bbb9750`) — **not** a patch branch; `upstream: nooit`, so nothing is compared against `origin/master` `bee32a926` except conventions
- **Dossier read:** `docs/features/ldap-mail-prefs/dossier.md` — **no, it does not exist** (deliberate: never goes upstream). `docs/features/ldap-mail-prefs/decisions.md` read instead — yes
- **Status read:** `docs/features/ldap-mail-prefs/status.md` (the "Wat er al bekend is" section) — yes
- **Ran the test suite:** no. There is no test to run: the file is `lib/tasks/**`, which the suite never loads, and Redmine ships **zero** rake-task tests of its own (`test/` has no rake harness at all — checked). What I did instead: I built a throwaway worktree at `add935736` on its own PostgreSQL database, seeded eight users / two groups / one project / one member with hand-tuned notification settings, and **ran the real rake task against those records five times** — happy path, second run (idempotency), group missing, group present-but-empty, and an induced mid-loop exception. Every finding below marked `confirmed` comes out of that run, not out of reading.
- **Scope covered:** reversibility and dry-run, the exact selection query and its edge cases (local-password account, admin, locked, not-yet-activated, second group, no group, missing group, recased group, empty group, hand-tuned preferences), over-reach into `notified_project_ids` / `members.mail_notification` / unrelated `others` keys, `save(validate: false)` vs `update_all` and the full `User` save-callback surface, transaction behaviour and partial writes, the forbidden-constructs table (all three `.rake` ones explicitly), RuboCop exclusion, INV-1 minimality, INV-4 AI traces, idempotency, output/observability, conventions against real trunk code.
- **Scope NOT covered:**
  - The branch test suite. I did not run it; the status file points at `docs/features/ar-sessions/status.md` for the figures and I took that on trust. This commit adds no code the suite touches, so the risk of that being wrong is low.
  - **The real GEOxyz LDAP directory and the real membership of `ldap_sync_users` in production.** This is the important gap: F02's blast radius is a function of who is actually in that group, and I cannot see it from here. My findings say what the code does to a given membership, not how many real people that is.
  - The actual cron entry on the GEOxyz server (the argument for keeping the task name is that one exists; I could not verify it).
  - MySQL and SQLite. I ran PostgreSQL only. That matters for exactly one finding (F09, case sensitivity) and for nothing else — there is no SQL in the change.
  - G9 in its literal form (browser + screenshots). A rake task has no UI, so the analogue is a committed terminal transcript; see F01's last paragraph.

## Summary

This is a small, careful, well-documented ops task, and most of what it does is
right: it aborts loudly with exit 1 when the group is gone (I measured it — a
real improvement over the 5.1 version), the `preload(:groups)` is not decorative
(3 members cost 4 statements, not 3+N — measured), `save(validate: false)` is
the right call and I checked every `User` save callback to be sure none of them
misfires (in particular `deliver_security_notification` does **not** fire on a
`mail_notification` change, so the task does not mail every affected user), it
does not over-reach into `notified_project_ids` or the `members.mail_notification`
flags, it leaves unrelated preference keys alone (a `comments_sorting` I planted
survived), it is idempotent, and it contains none of the three `.rake` sins from
the forbidden-constructs table and no AI traces. Every line in the 22 functional
lines is defensible.

The problem is not any single line. It is that **this is an irreversible bulk
write against real user records, and it behaves as though it were a safe one.**
Two things came out of running it that I would not ship to production as they
stand.

First, it does not select the users it says it selects. The task is called
`disable_mail_ldap_users`, its `desc` says "LDAP-only users", the slug says
`ldap-mail-prefs` — and the code never looks at `auth_source_id` at all. Its
only criterion is "the `ldap_sync_users` group is the only group this account is
in". In my run that muted an account with a **local password and no auth source**,
an **administrator**, a **locked** account, and a **not-yet-activated** account,
because each of them happened to be in that one group and no other. If GEOxyz's
LDAP sync puts every synced account into `ldap_sync_users`, then the criterion
reduces to "has not yet been added to a second group", which is the state a real
new employee is in on their first day.

Second, there is no dry-run and no record of what was overwritten. The three
values the task writes replace whatever was there, and nothing anywhere — not a
file, not a preference key, not a log the task itself keeps — remembers the old
ones. I gave one test user a deliberately hand-tuned setup ("selected projects",
self-notification on, one auto-watch trigger) and after one run it was gone with
no way back. The one partial mitigation is that `users.updated_on` moves, so you
can tell *which* accounts were touched; you still cannot tell *what they were*.
Those two findings compound: F02 makes a wrong-user mistake likely, F01 makes it
permanent.

Below that, three more things worth the time: there is no transaction, so a
mid-run failure leaves a partial write and a stack trace that does not say which
user it died on (I induced this and confirmed it — user 1 mutated, user 2 crashed,
user 3 untouched); all the logic sits inline in a `.rake` file, which is why it
is neither linted (`rubocop --force-exclusion` inspects **0 files** here) nor
testable, and which is not how Redmine does it (`User.prune`, `Watcher.prune`,
`Token.destroy_expired`, `Redmine::Ciphering.encrypt_all` are all model/lib
methods with a one-line task on top); and there is no test.

**Counts:** blocker 2 · major 3 · minor 3 · nit 2 · question 1

**Lines in the diff not strictly required by the feature:** 0. 38 lines, of
which 16 are Redmine's GPL header (every neighbour in `lib/tasks/` has it) and
22 are the task. All three preference fields it writes are defensible as "stop
this account generating mail": `mail_notification` is the direct control,
`no_self_notified` and `auto_watch_on` are the two other paths by which an idle
account acquires mail. Nothing was reformatted, nothing adjacent was touched, no
trailing whitespace, final newline present, no `frozen_string_literal` — which
is correct here, because **none** of the 17 other `.rake` files has one either
(checked all of them).

---

### F01 — A destructive bulk overwrite with no dry-run and no record of the previous values

- **Status:** open
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:28-32`
- **Invariant touched:** none directly; it is the G2 "failure modes safe" half of the gate

**What is wrong**

The task writes three preference values — `user.mail_notification`,
`pref[:no_self_notified]`, `pref.auto_watch_on` — unconditionally, over whatever
was there, for every user it selects. There is no report-only mode, no
confirmation, and no capture of the prior values anywhere: not in a file, not in
a spare `pref.others` key, not in the task's own stdout (which prints only the
login, see F06). Once the task has run, the state it replaced does not exist in
the database or anywhere else, so there is no revert task that could be written
after the fact — the input a revert would need is gone.

**Why a committer would push back**

Concrete failure path, run against real records: a user with a hand-tuned setup
(`mail_notification = 'selected'` with one notified project, `no_self_notified =
false`, `auto_watch_on = ['issue_created']`) went to `only_assigned` / `true` /
`[]` in one run, and there is now nothing in the database from which the three
original values could be recovered. This user was selected only because they
were in `ldap_sync_users` and no other group — see F02 for why that is not a
reliable proxy for "nobody uses this account". A cron entry runs this on a
schedule, so a membership change in LDAP silently enrols new accounts into the
same one-way write.

There is exactly one partial mitigation, and I confirmed it: `users.updated_on`
is bumped for the accounts the task changed and not for the ones it skipped, so
the *set* of affected accounts is recoverable from the database for as long as
nothing else saves those users. Their previous preferences are not.

Two secondary effects belong to the same finding because they change what a
revert would have to do:

- The task calls `user.pref`, which is `self.preference ||= UserPreference.new(...)`.
  On a persisted user that `has_one` writer **saves immediately**, so merely
  touching `pref` inserts a `user_preferences` row for a user who had none — I
  probed this in isolation (0 rows before, 1 row after, with no explicit save).
  So for those users the pre-state was "no row, inherit site defaults at
  creation time", and a revert has to *delete* the row, not reset its fields.
  Nothing records which users were in that state.
- The same save writes a default `my_page_layout` and an empty `my_page_settings`
  into `others` (from `UserPreference#clear_unused_block_settings`). Behaviourally
  inert — it is the default layout — but it is state the task did not intend to
  write and did not record either.

**How I verified it**

Throwaway worktree at `add935736`, own PostgreSQL database, `RAILS_ENV=test
bundle exec ruby bin/rails user:disable_mail_ldap_users` against seeded records.
Before / after for the hand-tuned user `picky`:

```
BEFORE picky  mail=selected  no_self=false auto_watch=["issue_created"] notified=[1] others={..., :comments_sorting=>"desc"}
AFTER  picky  mail=only_assigned no_self=true auto_watch=[] notified=[1] others={:no_self_notified=>true, :auto_watch_on=>[], :my_page_layout=>{...}, :my_page_settings=>{}, :comments_sorting=>"desc"}
```

`updated_on` after the first run: `ldaponly=2026-09-03 21:57:37` (touched),
`outsider=2026-09-03 21:57:12` (not in the group, untouched). Separate probe for
the `pref` side effect: `rows before merely touching user.pref: 0` /
`rows after merely touching user.pref: 1`.

**Suggested direction**

What good would look like, in rough order of value per line of code:

- **Report-only by default.** The task prints exactly what it would change, per
  user, old value → new value, and changes nothing. Writing requires an explicit
  opt-in — Redmine's own style for this is an ENV variable read at the top of the
  task, the way `redmine:users:prune` reads `DAYS` and aborts on a bad value.
  That single change also makes F02 discoverable before it does damage: Jan runs
  it, reads the list, and sees his own admin account on it.
- **Capture the prior values before writing them**, in a form a revert can
  consume: one line per user with login, `mail_notification`, `no_self_notified`,
  `auto_watch_on`, and whether a `user_preferences` row existed at all. A CSV or
  JSON file under `tmp/` or a path given by ENV is enough; it does not need a
  migration or a table. Whether the revert task itself gets written now is Jan's
  call, but the *data* has to be captured now, because it cannot be reconstructed
  later.
- Consider making the previous state visible in the UI instead of only on disk —
  but only if that is free; the file is the part that matters.
- Independently of the above: the run described in `status.md` is prose plus a
  hand-made table, with no committed artifact. `docs/features/ldap-mail-prefs/`
  contains only `status.md` and `decisions.md` — no `shots/`, and there is no
  `verify/ldap-mail-prefs.mjs`. `imap-oauth` committed a
  `shots/terminal-transcript.txt` for exactly this case. For a task with no UI
  that transcript *is* the G9 evidence, and it is missing. I could reproduce the
  status file's three-row table, so I have no reason to doubt it — but the next
  session has to take my word or re-run it, which is the situation INV-8 exists
  to prevent.

**Resolution:**

---

### F02 — It does not select LDAP-only users: it selects "in this one group and no other", which also catches admins, locked, unactivated and local-password accounts

- **Status:** open
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:21-27`
- **Invariant touched:** none

**What is wrong**

The whole selection is:

```ruby
group = Group.find_by(:lastname => 'ldap_sync_users')
group.users.preload(:groups).find_each do |user|
  other_groups = user.groups.reject {|g| g.id == group.id}
```

`auth_source_id` never appears. Neither does `status`, nor `admin`, nor
`last_login_on`, nor `hashed_password`. The criterion is purely "member of
`ldap_sync_users` and of no other group". The task name, its `desc` string, the
slug and the status file all describe the population as "LDAP-only users" and as
"an account the LDAP sync created that nobody uses"; the code cannot distinguish
either property. Group membership is being used as a proxy for two things it
does not measure — that the account is LDAP-authenticated, and that it is idle.

**Why a committer would push back**

Concrete failure path, all four confirmed in one real run against seeded
records:

| Account | Why it is not an idle LDAP account | What the task did |
|---|---|---|
| `localpw` | `auth_source_id` is `nil`; it has a local Redmine password | `UPDATE` — muted |
| `bossadmin` | `admin = true` | `UPDATE` — muted |
| `lockedone` | `status = 3` (locked) | `UPDATE` — muted |
| `reg` | `status = 2` (registered, never activated) | `UPDATE` — muted |

The administrator is the one that should stop the fixing session: an admin whose
only group is `ldap_sync_users` loses their notification settings, irreversibly
(F01), on a cron schedule, and nothing in the output distinguishes them from the
placeholder accounts.

The structural version of the same problem is worse than any single row above.
If GEOxyz's LDAP sync places **every** synced account into `ldap_sync_users` —
which is what a group by that name normally means — then "member of
`ldap_sync_users` and no other group" is not "a robot account", it is "a real
person who has not been added to a project group yet". That is the state a new
employee is in between the sync creating their account and someone granting them
access, i.e. precisely the window in which they most need mail to work. I cannot
tell from here whether that is GEOxyz's actual topology; that is the unverifiable
part, and it is why this is a blocker rather than a major — the failure mode is
plausible, silent, and permanent.

Two edge cases the brief asked about, for completeness:

- **Nested / child groups: not applicable, by construction.** Redmine has no
  group nesting. `Group#users` is a `has_and_belongs_to_many` to `User`, and
  `User`'s STI scope on the shared `users` table (`type IN ('User',
  'AnonymousUser')`) would exclude a group id even if one were inserted into
  `groups_users` by hand. There is no transitive membership to miss.
- **A user in no group at all** is correctly untouched (`outsider` in my run) —
  the task only ever walks the group's members.

**How I verified it**

The table above is the literal output of one run. Task output:

```
UPDATE: ldaponly
SKIP:   ldapboth is also in projectleads
UPDATE: localpw
UPDATE: bossadmin
UPDATE: lockedone
UPDATE: reg
UPDATE: picky
```

and the post-run dump confirming `localpw` has `auth=nil`, `bossadmin` has
`admin=true`, `lockedone` has `status=3`, `reg` has `status=2`, and all four
ended on `mail=only_assigned no_self=true auto_watch=[]`. `ldapboth` (second
group) and `outsider` (no group) were untouched, as intended.

I also read `User#check_password?` (`app/models/user.rb:347`) to confirm that
`auth_source_id.present?` is what actually distinguishes an externally
authenticated account from a local one, so it is available and cheap to test.

**Suggested direction**

The selection needs to say out loud which properties define the population, and
test each of them rather than inferring them from one group. The candidates,
which the fixing session should choose between and then *document*:

- `auth_source_id.present?` — the only reliable "this is an LDAP account" test.
  If the task's name is to stay honest this one is not optional.
- an activity test, since the real intent is "nobody uses this account":
  `last_login_on.nil?` is the strongest single signal and is already on the
  users table.
- explicit exclusions for `admin?` and for non-active statuses, or a conscious,
  written decision that those are in scope.

Whatever is chosen, the `desc` string and the task name should describe the
actual criterion, and the SKIP line should say which test the user failed (see
F06) so the report-only run from F01 is readable. If Jan wants to keep the
one-group criterion as the *primary* filter, the others can be cheap guards that
only ever narrow the set — that keeps the existing cron behaviour for the
placeholder accounts and takes the four categories above out of the blast radius.

**Resolution:**

---

### F03 — No transaction: a mid-run failure leaves a partial write, and the error does not say which user it died on

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:24-36`
- **Invariant touched:** none

**What is wrong**

The loop performs two independent saves per user (`user.pref.save`, then
`user.save(:validate => false)`) with no enclosing transaction and no rescue.
An exception on user *n* aborts the task with users 1..n-1 already committed,
user *n* possibly half-written (its `pref` saved but the `User` row not, or vice
versa), and users n+1.. untouched. The exception surfaces as a raw rake stack
trace that names the file and line but **not the login**, so the operator cannot
tell where the run stopped except by counting the `UPDATE:` lines that got
printed first.

**Why a committer would push back**

Redmine's own bulk mutation of the same shape does the opposite, and it is one
file away in the same directory. `lib/tasks/ciphering.rake` calls
`Redmine::Ciphering.encrypt_all`, which is:

```ruby
def encrypt_all(attribute)
  transaction do
    all.each do |object|
      clear = object.send(attribute)
      object.send :"#{attribute}=", clear
      raise(ActiveRecord::Rollback) unless object.save(validate: false)
    end
  end ? true : false
end
```

— a transaction, an explicit rollback on a single failure, and the task above it
turning that into `"Some objects could not be saved after encryption, update was
rolled back."`. That is the established Redmine idiom for "iterate users, save
each with validations off", and this task departs from it without saying why.

Concrete failure path, confirmed. I gave the middle of three group members a
`user_preferences.others` that YAML-loads as a `String` instead of a `Hash`
(a shape a plugin or an older Redmine can leave behind), which makes
`UserPreference#[]=` raise. Result:

```
bin/rails aborted!
NoMethodError: undefined method `update' for an instance of String (NoMethodError)
      h.update(attr_name => value)
/tmp/rev-ldap-mail-prefs/lib/tasks/disable_mail_ldap_users.rake:30
EXIT=1
```

and the state afterwards:

```
AFTER-CRASH ldaponly: mail=only_assigned  others={:no_self_notified=>true, :auto_watch_on=>[], ...}   <- committed
AFTER-CRASH localpw:  mail=all            others="---\n:my_page_settings: corrupted-by-a-plugin\n"    <- failed
AFTER-CRASH picky:    mail=all            NOPREF                                                      <- never reached
```

The specific trigger I used is contrived — I induced it deliberately — but the
property it demonstrates is not: the task has no transaction and no per-user
rescue, so *any* exception in the loop produces exactly this partial state. A
re-run after fixing the cause is safe, because the task is idempotent (see the
Summary); the problem is the window in between, and the fact that F01 means the
operator has no record of which users are on which side of the crash beyond the
lines that scrolled past.

Note that the crash message names neither the login nor the user id. On a group
of any real size that is the difference between a five-minute fix and an audit.

**How I verified it**

The transcript above, produced by running the real task in the throwaway
worktree after planting the malformed `others` on the middle member. I also read
`Redmine::Ciphering.encrypt_all` on `origin/7.0-stable-GEOxyz` to establish the
in-tree convention, and grepped `lib/tasks/` for `abort` to confirm the
abort-with-message style the task already uses elsewhere is Redmine's (17 hits
across 8 files).

**Suggested direction**

Two independent decisions, both of which should be made explicitly rather than
by omission:

- **All-or-nothing, or per-user resilience?** Wrapping the loop in a
  `transaction` with a rollback on failure gives the `encrypt_all` behaviour: the
  run either happened or it did not, which is much easier to reason about
  together with F01. Rescuing per user and printing `FAIL: <login> <message>`
  gives a run that completes and tells you which accounts it could not do. Both
  are defensible; picking neither is not.
- Either way, **the error has to name the user.** The failure output is the only
  thing the operator has.
- The two saves per user (`pref` and `User`) should at least be atomic with
  respect to each other, so no account ends up with a muted `pref` and an
  unchanged `mail_notification` or the reverse.

**Resolution:**

---

### F04 — All the logic lives inline in a `.rake` file, so it is neither linted nor testable, and Redmine does not do it that way

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:18-38`
- **Invariant touched:** none (it is what makes G3 and G4 unreachable for this change)

**What is wrong**

The selection predicate, the mutation and the reporting are all written directly
in the `task` block. Nothing is callable from anywhere else. Two consequences,
both mechanical:

- `lib/tasks/**/*` is in the `Exclude` of Redmine's `.rubocop.yml`, so the file
  is never linted. `status.md` says this and it is correct — I confirmed it:
  `rubocop --force-exclusion --format simple lib/tasks/disable_mail_ldap_users.rake`
  reports **`0 files inspected, no offenses detected`**. Zero *files*, not zero
  offences. The G4 gate cannot be satisfied for this change as written, only
  declared n/a.
- There is no seam a test could call, which is F05.

**Why a committer would push back**

This is not a taste argument; it is how every comparable task in the tree is
built. In `lib/tasks/redmine.rake` the destructive tasks are one line each —
`Token.destroy_expired`, `User.prune(days.days)`, `Watcher.prune` — with the
logic on the model. In `lib/tasks/ciphering.rake` the task is a wrapper around
`Redmine::Ciphering.encrypt_all`. The rake file holds argument parsing, the
`abort` on bad input, and the call; nothing else. That pattern is why
`User.prune` has tests and this task cannot.

The failure path is indirect but real: a future change to the predicate (which
F02 makes likely) lands in a file that no linter and no test looks at, on a
branch whose gate output will still read "RuboCop: n.v.t." and "no test". The
next person to touch it has no way to know they broke it except by running it
against production.

**How I verified it**

```
$ rubocop --force-exclusion --format simple lib/tasks/disable_mail_ldap_users.rake
0 files inspected, no offenses detected

$ rubocop --format simple lib/tasks/disable_mail_ldap_users.rake     # exclusion off
C:  1:  1: [Correctable] Style/FrozenStringLiteralComment: Missing frozen string literal comment.
1 file inspected, 1 offense detected
```

(That single offence is **not** a finding — I checked all 17 other `.rake` files
on the branch and none of them has a `frozen_string_literal` comment either, so
the file matches its neighbours exactly.)

Convention checked by reading `lib/tasks/redmine.rake:36-64` and
`lib/tasks/ciphering.rake` on `origin/7.0-stable-GEOxyz`, and by grepping
`test/` for any rake-task test harness — there is none.

**Suggested direction**

Move the body somewhere the linter and the suite can see it, and leave the rake
task as the thin shell Redmine's other tasks are. The natural shapes, in
descending order of how much they look like existing Redmine code:

- a class method on the model, the way `User.prune` and `Watcher.prune` are —
  the predicate ("does this account qualify") and the mutation are both about
  `User`;
- or a small module under `lib/redmine/` returning the affected set and applying
  the change, the way `Redmine::Ciphering.encrypt_all` does, which also gives the
  transaction from F03 a natural home;
- either way the *predicate* should be separately callable and should return the
  set without writing, because that is also what the report-only mode in F01
  needs. One extraction serves F01, F03, F04 and F05.

Note for the record that the file is **clean** on the three `.rake` constructs
from the forbidden-constructs table — no top-level `def`, no top-level constant,
no `require_relative` — which is what `status.md` claims and what I confirmed by
reading. This finding is about where the code lives, not about it leaking onto
`Object`.

**Resolution:**

---

### F05 — No test at all for the UPDATE/SKIP predicate that decides whose mail gets muted

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `lib/tasks/disable_mail_ldap_users.rake` (no corresponding file under `test/`)
- **Invariant touched:** INV-8 (green means proven green), G3

**What is wrong**

There is no test. `status.md` states this openly and gives the reason — `lib/tasks/**`
is not reached by the suite — which is true as far as it goes, but the
consequence is that the one decision in this change that can cause harm, "is
this account in scope", has no automated coverage of any kind. The four
categories in F02 would each have been a two-line assertion.

**Why a committer would push back**

Honest mitigation first, because it changes the severity: **Redmine itself has no
rake-task tests.** I looked; there is no harness, no `test/unit/tasks/`, nothing.
So "a rake task without a test" is not by itself a departure from Redmine's
practice, and I am not asking anyone to invent a rake harness.

What makes it a major here rather than a nit is the combination with F01 and F02.
The predicate is not incidental plumbing; it is the entire risk surface of an
irreversible write against real user records, and it is currently verified only
by a hand-run described in prose in `status.md` (three users, one scenario). My
own run added five categories that hand-run did not cover, and four of them
behaved in a way nobody had recorded. That is what an absent test costs: not a
red build, but an unexamined edge case reaching production.

Concretely: if the fixing session adds the `auth_source_id` guard from F02, there
is nothing that will tell the *next* session if a later refactor drops it again.

**How I verified it**

`find docs/features/ldap-mail-prefs -type f` → `status.md`, `decisions.md` only.
No `test/` file references the task (grepped the branch for
`disable_mail_ldap_users`: four hits, all in the two framework markdown files).
`git ls-tree -r origin/7.0-stable-GEOxyz test/ | grep -i rake` → nothing.

**Suggested direction**

This is F04's twin and one extraction fixes both. Once the predicate and the
mutation are a model or `lib/redmine/` method, a plain unit test can cover the
cases without any rake machinery: in-group-only, in a second group, no group,
plus one row per exclusion the fixing session decides on in F02
(`auth_source_id` nil, admin, locked, registered). Redmine's existing fixtures
already have groups (`groups_users.yml`), users with and without
`auth_source_id`, and locked users, so this needs no new fixture records.

Each new assertion should be red against the current predicate — for the four
F02 categories that is automatic, since I have shown the current code returns
them as in-scope.

**Resolution:**

---

### F06 — The output prints `UPDATE:` for users it did not change, so the log is not a record of what the run did

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:34`
- **Invariant touched:** none

**What is wrong**

`puts "UPDATE: #{user.login}"` is printed unconditionally in the else branch,
whether or not the saves actually changed anything. On a second run every
already-muted user is reported as `UPDATE` again. Rails correctly writes nothing
(no changed attributes, so no UPDATE statement and no `updated_on` bump), but the
output says otherwise.

**Why a committer would push back**

The task is idempotent at the data level — I confirmed that, and it is the right
behaviour — but the output being non-idempotent matters more here than it
normally would, because per F01 **the stdout of the run is the only record that
exists** of what the task touched. A cron mail that reports seven UPDATEs every
night, six of which are no-ops, is a log nobody reads, which means the night a
real new account appears in the list nobody notices.

The SKIP line has the opposite virtue and shows what good looks like: it says
*why* (`is also in projectleads`). The UPDATE line says nothing about what
changed.

**How I verified it**

Second consecutive run of the real task, same records, no changes in between:

```
### RUN 2 (idempotency)
UPDATE: ldaponly
SKIP:   ldapboth is also in projectleads
UPDATE: localpw
... (7 lines, identical to run 1)
run2: mail=only_assigned no_self=true watch=[] updated_on=2026-09-03 21:57:37 UTC
```

`updated_on` is unchanged from run 1, proving no write occurred behind those six
`UPDATE:` lines.

**Suggested direction**

Report what actually happened, and enough of it to be useful as the record F01
needs: distinguish a user that was changed from one that was already in the
target state, and on a changed user print the old values alongside the new. The
same line then serves as the dry-run output, which is one fewer thing to build.

**Resolution:**

---

### F07 — An empty or unpopulated group is a silent exit-0 no-op with no output at all

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:22-24`
- **Invariant touched:** none

**What is wrong**

The `abort` covers only the case where the group does not exist. If the group
exists but has no members, the loop body never runs, the task prints **nothing**
and exits 0. There is no summary line at any point — no "n members, n updated, n
skipped" — so a run that did nothing is indistinguishable, from the outside, from
a run that had nothing to do, and both are indistinguishable from a successful
run in a cron mail that only shows non-empty output.

**Why a committer would push back**

Concrete failure path: the LDAP sync stops writing to `ldap_sync_users` (a
mapping change, a directory reorganisation, a sync failure). The group is still
there, now empty. The task keeps exiting 0 with no output, every night, and Jan's
evidence that the mute is still being applied is silence — which is exactly what
success looks like too. The 5.1 version's exit-0-on-missing-group was fixed for
precisely this reason (`decisions.md`, and I confirmed the fix works: exit 1);
the same argument applies one step further in.

**How I verified it**

Emptied the group's membership and ran the real task:

```
### empty group
EXIT=0
```

— no stdout, no stderr. For contrast, the missing-group path, also measured:

```
Group 'ldap_sync_users' not found.
EXIT=1
```

**Suggested direction**

A one-line summary at the end, always printed: how many members the group had,
how many were changed, how many skipped and why. That makes a zero-member run
say so out loud. Whether zero members should be an `abort` as well is Jan's
call — it is a legitimate state on day one — but it must not be silent.

**Resolution:**

---

### F08 — The `desc` says "Mute the mail notifications", but `only_assigned` still sends mail

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:19`
- **Invariant touched:** none

**What is wrong**

The `desc` — the one sentence an operator sees in `rails -T` and the only
documentation the task carries on the server — says the task mutes mail
notifications. It sets `mail_notification` to `'only_assigned'`, which is one of
seven `User::MAIL_NOTIFICATION_OPTIONS` and is not the muting one; `'none'` is.
An account left on `only_assigned` still receives mail for every issue assigned
to it.

**Why a committer would push back**

`status.md` describes the behaviour accurately in Dutch ("alleen wat aan mij is
toegewezen"), so the intent is documented — but the `desc` is what is on the
server, and it overstates. Concrete consequence: someone reads
`rails -T user`, believes these accounts no longer generate mail, assigns a
batch of issues to a synced account (Redmine allows assigning to any member),
and mail starts flowing to a mailbox nobody reads. The task name
`disable_mail_ldap_users` carries the same overstatement.

**How I verified it**

Read `User::MAIL_NOTIFICATION_OPTIONS` in `app/models/user.rb:83-91` — `'none'`
and `'only_assigned'` are distinct values — and confirmed the post-run value is
`only_assigned` in the dumps quoted in F01/F02. I did not send mail; the
behaviour of `only_assigned` is Redmine's documented notification semantics, not
something this change alters.

**Suggested direction**

Make the `desc` say what the task does — narrow the notifications to assignments
only, turn off self-notification, clear auto-watch — in one sentence, and have it
name the actual selection criterion once F02 is settled. See F11 for the separate
question of whether `only_assigned` is the value Jan wants.

**Resolution:**

---

### F09 — `find_by(:lastname => ...)` is case-sensitive; Redmine has a `Group.named` scope for exactly this lookup

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:21`
- **Invariant touched:** none

**What is wrong**

`Group.find_by(:lastname => 'ldap_sync_users')` compares with `=`, which is
case-sensitive on PostgreSQL. `Group` already ships the scope written for this:
`scope :named, lambda {|arg| where("LOWER(#{table_name}.lastname) = LOWER(?)", arg.to_s.strip)}`
(`app/models/group.rb:35`), and `Group` validates `lastname` uniqueness
case-insensitively, so `named` cannot be ambiguous.

**Why a committer would push back**

Low severity because the failure is loud, not silent: if an administrator recases
the group in the UI the task aborts with exit 1. But the message it prints is
wrong — it says the group was not found when the group is right there — which
sends whoever reads the cron mail looking for a deleted group. Also worth noting
that this behaves differently on MySQL, where the default collation is
case-insensitive and the same rename would silently keep working; the branch's
own `database.yml` decides which of the two GEOxyz gets.

**How I verified it**

Renamed the group to `LDAP_Sync_Users` and ran the real task:

```
Group 'ldap_sync_users' not found.
EXIT=1
```

then, in the same database, `Group.named("ldap_sync_users").first.lastname`
returned `"LDAP_Sync_Users"` — the scope finds what `find_by` missed.

**Suggested direction**

Use the existing scope, and if the group really is absent say so in a way that
distinguishes "no group by that name, in any case" from anything else.

**Resolution:**

---

### F10 — Two different idioms for writing the same object's preferences, three lines apart

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:30-31`
- **Invariant touched:** none

**What is wrong**

```ruby
user.pref[:no_self_notified] = true
user.pref.auto_watch_on = []
```

The first goes through `UserPreference#[]=` and writes the raw `others` hash; the
second goes through the model's own writer. `UserPreference` defines
`no_self_notified=` (`app/models/user_preference.rb:94`) and it does exactly
`self[:no_self_notified] = value`, so the two lines could use the same idiom.

**Why a committer would push back**

Behaviourally identical — I confirmed the stored value is `:no_self_notified =>
true` either way, and `no_self_notified` reads back `true`. Purely a
readability point, and it is a nit for that reason: the `[]=` form makes a reader
check whether `no_self_notified` is a column or an `others` key, which is the
question the accessor exists to answer. `decisions.md` records a deliberate
choice about the *value* of `auto_watch_on` (`[]` over `['']`) but not about
which writer to use.

**How I verified it**

Read `UserPreference#[]=` and `#no_self_notified=`; the post-run `others` dump in
F01 shows the stored key and value.

**Suggested direction**

Pick one, and prefer the model writers — they are the documented surface and they
survive a column being added later.

**Resolution:**

---

### F11 — For an account nobody uses, is `only_assigned` the value you want, or `none`?

- **Status:** open
- **Severity:** question
- **Confidence:** confirmed (the behaviour; the intent is yours)
- **Category:** scope
- **Where:** `lib/tasks/disable_mail_ldap_users.rake:29`
- **Invariant touched:** none

**What is wrong**

Not wrong — a choice that is currently implicit. The task narrows these accounts
to "mail me about issues assigned to me". If the population really is
placeholder accounts created by the LDAP sync that nobody logs into, then the one
remaining path is still open: assign an issue to such an account and it mails a
mailbox nobody reads (and, if the address does not exist, it bounces into
Redmine's outgoing mail). `'none'` closes that. Keeping `only_assigned` is
defensible too — it means a real person behind one of these accounts still finds
out when work lands on them, which is a useful safety net given F02.

**Why a committer would push back**

This is a Class B judgement in the framework's terms — user-visible behaviour,
taste, no obviously correct answer — and it interacts with F02. If F02 is fixed
so that only genuinely idle LDAP accounts are selected, `'none'` becomes the
natural value. If the one-group criterion stays, `only_assigned` is the safer of
the two because it leaves a channel open to a real person caught by mistake.
I am not asking for a change; I am asking that the answer be written down, since
`decisions.md` records six choices about this task and not this one.

**How I verified it**

`User::MAIL_NOTIFICATION_OPTIONS` (`app/models/user.rb:83-91`) lists both values;
the run dumps confirm the stored value is `only_assigned`. The mail behaviour of
each option is Redmine's, unchanged by this commit — read, not exercised.

**Suggested direction**

One line in `docs/features/ldap-mail-prefs/decisions.md` saying which it is and
why, and the `desc` from F08 matching it. My own recommendation, for what it is
worth: fix F02 first, then `'none'`, because the reason to keep `only_assigned`
is a safety net against F02 and a fixed F02 does not need one.

**Resolution:**

---

## Observations that are not findings

Recorded so the fixing session does not spend time on them:

- **`save(:validate => false)` is correct and I checked the callback surface.**
  `status.md` says LDAP accounts do not always pass Redmine's validations; that is
  the right reason. More importantly the callbacks that *do* still run are all
  harmless for a `mail_notification` change, and I verified each by reading:
  `generate_password_if_needed` and `update_hashed_password` need `password` set,
  `destroy_tokens` needs a `hashed_password`/`status`/`twofa_scheme` change,
  `update_notified_project_ids` needs `@notified_projects_ids_changed`, and
  `deliver_security_notification` fires only on admin/status/id changes. The last
  one is worth stating explicitly: this task does **not** mail an "account
  changed" notice to the affected users or to the admins. `update_all` would have
  skipped these too, but `save` is the better choice here because it keeps
  `updated_on` moving, which is the only audit trail F01 leaves.
- **No over-reach into `notified_project_ids` or `members.mail_notification`** —
  confirmed by experiment, not by reading. My `picky` user kept
  `notified_projects_ids = [1]` and its `members.mail_notification = true` flag
  across the run. Those selections are inert while `mail_notification` is
  `only_assigned` and would come back if it were set to `'selected'` again, which
  is the good outcome: it is the one part of the prior state the task does not
  destroy.
- **Unrelated preference keys survive** — a planted `others[:comments_sorting] =
  'desc'` was still there afterwards. The task does not clobber the hash.
- **`preload(:groups)` is not decorative.** Measured: 3 group members cost 4 SQL
  statements, i.e. constant, not 3+N. The decision in `decisions.md` is sound and
  effective.
- **`abort` is Redmine's idiom** — 17 occurrences across 8 `lib/tasks/` files,
  including `redmine:users:prune`'s own bad-input abort. The exit-1-on-missing-group
  improvement over 5.1 is real and I measured it.
- **`find_each` is safe here.** It batches by `users.id` and the task mutates
  `users.mail_notification`, not group membership, so the iteration set cannot
  shift under it and no member can be skipped.
- **INV-4 is clean.** `git log -1 --format='%(trailers)'` is empty, the commit
  message is one plain sentence, and the diff contains no tool name, model name,
  session link, "generated by", or TODO of the author's making.
- **INV-1 is clean.** No reformatting, no adjacent tidying, no trailing
  whitespace, final newline present. The GPL header matches every neighbour.
- **No `frozen_string_literal` is correct**, not an omission — none of the 17
  other `.rake` files on the branch has one.
- **The `user:` top-level namespace** (rather than Redmine's `redmine:users:`)
  is a settled decision in `decisions.md`, taken to keep an existing cron entry
  working. I mildly disagree on convention grounds and would have nested it under
  `redmine:`, but the cron argument is a real cost and the collision risk is
  theoretical. Not raising it as a finding.
- **`upstream: nooit` is right.** The hardcoded group name settles it, and no
  amount of parameterisation would make a "mute these users' mail" bulk task
  something Redmine core wants. Nothing in this review argues for submitting it.
