# Review run — 2026-09-03 — gitignore-credentials — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `7.0-stable-GEOxyz` commit `e2c0447b6` ("Ignore the Rails credentials files, so master.key can never be committed"), parent `885f04097`. GEOxyz-only — no `patch/gitignore-credentials` branch exists and none is intended (`upstream: nooit`). Judged as production/ops risk, not as an upstream submission.
- **Dossier read:** `docs/features/gitignore-credentials/dossier.md` — no such file (deliberate: GEOxyz-only, recorded in `status.md`). `docs/features/gitignore-credentials/decisions.md` — yes.
- **Status read:** `docs/features/gitignore-credentials/status.md` (the "already settled" section) — yes. The deliberate omission of the `/.github/` rule from the 5.1 version is settled and is **not** reported below; I re-confirmed it is absent and that `.github/workflows/*` stays visible to git.
- **Ran the test suite:** no — `.gitignore` is not code and no suite reads it. Instead I built a throwaway worktree at `e2c0447b6`, created the real files on disk and measured `git check-ignore -v`, `git status --porcelain` and `git add -A --dry-run`; and I drove Rails' own `Rails::Generators::EncryptionKeyFileGenerator` (railties 8.1.3.1, the version this branch pins) against a copy of this `.gitignore` to see what Rails does with it.
- **Scope covered:** whether the two patterns match the paths Rails actually uses; coverage of per-environment credentials (`config/credentials/<env>.key` / `.yml.enc`); shadowing by an earlier negation; whether anything that should be tracked becomes ignored; consistency with Rails' own ignore convention; whether ignoring `credentials.yml.enc` breaks anything in Redmine; ordering/whitespace conventions of the file; minimality (INV-1); AI traces (INV-4).
- **Scope NOT covered:** I did not boot the app or run `bin/rails credentials:edit` end to end (it needs a database and an interactive editor); instead I invoked the exact generator methods that command calls, which is the same code with the I/O removed. I did not audit git history for a key that was already committed before this change — `git ls-files | grep -iE 'master\.key|credentials'` is empty on this commit, but that only proves nothing is tracked *now*, not that nothing ever was. I did not review the rest of the branch.

## Summary

The two lines do exactly what they say for the two paths they name, and nothing
here is subtly broken: both patterns are root-anchored with a leading `/`, both
match a file rather than a directory, no earlier `!` negation shadows them, and
no file that should be tracked becomes ignored. The placement is also careful —
both lines are slotted into the existing alphabetical run of `/config/` entries,
with no trailing whitespace and no missing newline.

The hole is the one the brief suspected. Rails supports per-environment
credentials at `config/credentials/<env>.key` and
`config/credentials/<env>.yml.enc`, and the `.key` there is just as much a
master key as `config/master.key` is. Neither is covered. I confirmed this the
blunt way: with `config/credentials/production.key` on disk,
`git status --porcelain` shows `?? config/credentials/` and
`git add -A --dry-run` says `add 'config/credentials/production.key'`. So a
plaintext decryption key for production can still be staged and committed —
which is precisely the outcome the commit message promises can "never" happen
(F01).

Two smaller things. The entries are written in a form Rails does not recognise
as its own, so the first time anyone runs `bin/rails credentials:edit` Rails
appends its own `/config/*.key` block to `.gitignore`, leaving a spurious
modification on a tracked file (F02). And ignoring `config/credentials.yml.enc`
inverts Rails' intended workflow — that file is *encrypted* and is meant to be
committed; only the key is secret — which is harmless in Redmine today but is a
choice worth Jan confirming rather than inheriting (F03). Nothing here is a
blocker; F01 should be closed before anyone starts using Rails credentials on
this branch.

**Counts:** blocker 0 · major 1 · minor 1 · nit 0 · question 1

**Lines in the diff not strictly required by the feature:** 1 —
`/config/credentials.yml.enc`. The stated goal is that "master.key can never be
committed", and the `.enc` file is not a secret. See F03; this is a question for
Jan, not an assertion that the line is wrong.

---

### F01 — Per-environment credential keys (`config/credentials/<env>.key`) are not ignored, so a production master key can still be committed

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** security
- **Where:** `.gitignore:11` and `.gitignore:14`
- **Invariant touched:** none

**What is wrong**

Both new patterns are exact, root-anchored file paths: `/config/master.key` and
`/config/credentials.yml.enc`. Rails' `credentials` command supports a second
layout for environment-specific overrides, and it lives in a *subdirectory*:
`Rails::Command::CredentialsCommand` sets

```ruby
@content_path = "config/credentials/#{environment}.yml.enc" unless config.overridden?(:content_path)
@key_path     = "config/credentials/#{environment}.key"     unless config.overridden?(:key_path)
```

so `bin/rails credentials:edit --environment production` produces
`config/credentials/production.key` — a file with the same secret in it as
`config/master.key`, and one that neither new pattern touches. `/config/master.key`
matches only that one path; it does not match one directory deeper.

**Why this would bite GEOxyz**

Concretely, in a throwaway worktree at this exact commit:

```
$ printf 'bbbb\n' > config/credentials/production.key
$ git status --porcelain
?? config/credentials/
$ git add -A --dry-run
add 'config/credentials/production.key'
add 'config/credentials/production.yml.enc'
```

The plaintext production decryption key is staged by a routine `git add -A` /
`git add .`, and once it is in a pushed commit it is in the history forever and
has to be treated as leaked and rotated. That is the exact event this commit
exists to prevent, for the exact file that matters most.

Rails does partly cover for this: when `credentials:edit` *creates* a key it
calls `EncryptionKeyFileGenerator#add_key_file`, which appends
`/config/credentials/*.key` to `.gitignore` itself. But that path is skipped
whenever the key already exists or `RAILS_MASTER_KEY` is set
(`ensure_encryption_key_has_been_added` returns early on `credentials.key?`) —
i.e. exactly the ops flow where a key is copied in from a password manager, a
backup, or a deploy step rather than generated locally. That is the realistic
GEOxyz path.

The sharper argument is the internal inconsistency. If you trust Rails'
auto-ignore, then `/config/master.key` is redundant too and the commit should
not exist (INV-1). If you do not trust it — which is the premise of writing the
line by hand — then the per-environment keys need the same belt-and-braces
treatment. The current state takes both positions at once.

**How I verified it**

Worktree at `e2c0447b6`, `git check-ignore -v --no-index` against the real
paths:

```
config/master.key                     -> .gitignore:14:/config/master.key
config/credentials.yml.enc            -> .gitignore:11:/config/credentials.yml.enc
config/credentials/production.key     -> NOT IGNORED
config/credentials/production.yml.enc -> NOT IGNORED
config/credentials/staging.key        -> NOT IGNORED
config/credentials/development.key    -> NOT IGNORED
```

then the `git add -A --dry-run` result quoted above with the files actually on
disk. Path shapes read from
`railties-8.1.3.1/lib/rails/commands/credentials/credentials_command.rb:22-24`
and the early-return from `ensure_encryption_key_has_been_added` in the same
file.

**Suggested direction**

The protection needs to cover the key wherever Rails puts it, in both layouts,
and it should stay a pattern that cannot be defeated by a new environment name
nobody thought of. Rails' own answer to the same question — visible in
`EncryptionKeyFileGenerator#key_ignore`, which emits `/<dirname>/*.key` — is a
glob per directory rather than a filename; adopting that shape would also make
F02 disappear, since Rails checks for its own string before appending. Whatever
is chosen, re-measure it with `git check-ignore -v` against
`config/master.key`, `config/credentials/production.key` and
`config/credentials/<some-new-env>.key`, and re-run the "does anything tracked
become ignored" sweep below, because a glob is wider than an exact path.

**Resolution:**

---

### F02 — Rails appends its own ignore block on top of these lines, dirtying a tracked file

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `.gitignore:14`
- **Invariant touched:** none (but see below)

**What is wrong**

`EncryptionKeyFileGenerator#ensure_key_files_are_ignored_silently` decides
whether to write to `.gitignore` with a plain substring test:

```ruby
if File.exist?(".gitignore")
  unless File.read(".gitignore").include?(ignore)
    append_to_file ".gitignore", ignore
  end
end
```

where `ignore` is the whole heredoc block, comment line included, and the
pattern inside it is `/<dirname>/*.key` — for `config/master.key` that is
`/config/*.key`. This `.gitignore` contains `/config/master.key`, which does not
contain the string `/config/*.key`, so the test fails and Rails appends its
block anyway. The hand-written line does not suppress Rails' own.

**Why this would bite GEOxyz**

Measured, against a copy of this exact `.gitignore`:

```
$ ruby -e '...EncryptionKeyFileGenerator...ensure_key_files_are_ignored_silently("config/master.key")'
      append  .gitignore
appended: "\n# Ignore key files for decrypting credentials and more.\n/config/*.key\n\n"
```

So the first developer to run `bin/rails credentials:edit` on this branch ends
up with `.gitignore` showing as modified in `git status` — a tracked file
changed by a command they ran for an unrelated reason. Either they commit it
(and the branch now carries a duplicate rule plus an explanatory comment, which
is the kind of line INV-3 exists to keep out) or they revert it every time. It
is a small, recurring papercut rather than a defect, but it is the sort of thing
that trains people to `git checkout -- .gitignore` reflexively, which is how
real changes get discarded.

**How I verified it**

Read
`railties-8.1.3.1/lib/rails/generators/rails/encryption_key_file/encryption_key_file_generator.rb`
(`key_ignore`, `ensure_key_files_are_ignored`,
`ensure_key_files_are_ignored_silently`), then ran both
`ensure_key_files_are_ignored_silently("config/master.key")` and
`...("config/credentials/production.key")` against copies of this `.gitignore`
in a scratch directory. Output for the second call:
`"\n# Ignore key files for decrypting credentials and more.\n/config/credentials/*.key\n\n"`.

**Suggested direction**

Writing the rule in the shape Rails already looks for makes Rails leave the file
alone, which closes this and F01 in one move. If instead the exact-path style is
kept deliberately, that is a defensible choice — but then it is worth a line in
`status.md` saying Rails will append its own block and that the appended block
should be reverted, so the next person is not surprised.

**Resolution:**

---

### F03 — Ignoring `config/credentials.yml.enc` inverts Rails' intended workflow — is that deliberate?

- **Status:** question
- **Severity:** question
- **Confidence:** confirmed
- **Category:** minimality
- **Where:** `.gitignore:11`
- **Invariant touched:** INV-1 (raised as a question, not asserted as a violation)

**What is wrong**

In Rails' design the two files play opposite roles: `master.key` is the secret
and must never be committed, while `credentials.yml.enc` is the *encrypted*
payload and is meant to be committed — Rails' own `credentials` USAGE text gives
that as the reason the feature exists ("This also allows for atomic deploys: no
need to coordinate key changes to get everything working as the keys are shipped
with the code"). Ignoring the `.enc` file removes that. It is also not needed for
the commit's stated goal, which is about `master.key`.

**Why this is a question rather than a finding**

Today it costs nothing: Redmine core does not use Rails credentials at all.
`config.require_master_key` is present but commented out in
`config/environments/production.rb:23`, nothing in `app/`, `lib/` or `config/`
reads `Rails.application.credentials`, and `secret_key_base` comes from
`config/initializers/secret_token.rb` written by `lib/tasks/initializers.rake`
(or from `config.secret_key_base` in `test.rb`). So there is no encrypted
credentials file to lose. The question is what happens if GEOxyz ever does adopt
credentials — for an SMTP password or an OAuth client secret, say. At that point
a git-based deploy would ship the key-less half of the pair: the `.enc` file
would exist only on the developer's machine, the server would have `master.key`
but nothing to decrypt, and `Rails.application.credentials.foo` would silently
return `nil` rather than raising anywhere obvious. That is a slow, confusing
failure, and it would be discovered in production.

Two readings are both reasonable and it is Jan's call: (a) "we will never use
Rails credentials, so ignore both and make the whole mechanism inert" —
consistent, and then the line is deliberate; or (b) "ignore only the secret, as
Rails intends, so the mechanism works the day we want it" — one line smaller and
INV-1-cleaner.

**How I verified it**

`git grep -n "credentials\|master\.key\|RAILS_MASTER_KEY" -- config lib app Rakefile`
on `e2c0447b6`: the only non-locale, non-LDAP, non-login hits are the two
commented lines at `config/environments/production.rb:21-23`. `git grep -rn
"secret_key_base" -- config lib` returns only `config/environments/test.rb:79`
and `lib/tasks/initializers.rake:37`. Rails' intent read from
`railties-8.1.3.1/lib/rails/commands/credentials/USAGE`.

I also ran the "does this ignore anything that should be tracked" sweep, and it
is **clean** in both directions:

```
$ git ls-files -z | git check-ignore -z --stdin -v     # tracked files now ignored
(no output)
$ git ls-files | grep -iE "master\.key|credentials"
(no output)
```

and the file itself is tidy: `cat -A .gitignore` shows both new lines slotted
into the existing alphabetical `/config/` run (`configuration.yml` <
`credentials.yml.enc` < `database.yml`, and `email.yml` < `master.key` <
`secrets.yml`), with no trailing whitespace and a final newline. No
`Co-authored-by`, no session link, no generated-by marker in the commit — INV-4
clean.

**Suggested direction**

This is a decision, not a defect. Whichever way it goes, the reasoning belongs
in `status.md` next to the `/.github/` note, because the next person to read the
file will otherwise assume the `.enc` line was copied in by habit and "fix" it.

**Resolution:**
