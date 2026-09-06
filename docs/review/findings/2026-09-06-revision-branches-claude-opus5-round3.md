# Review run — 2026-09-06 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** `patch/revision-branches` at `3e2c6b432` against `origin/master` `bee32a926` (r25037)
- **Dossier read:** `docs/features/revision-branches/dossier.md` — yes
- **Status read:** `docs/features/revision-branches/status.md` (the "already settled" section) — yes
- **Round-1 findings read:** **no, deliberately.** This is the blind pass of
  ronde 3 (`docs/STATE.md`): `docs/review/findings/2026-09-03-revision-branches-claude-opus5.md`
  was not opened before or during the review. `status.md` does name one round-2
  correction (F03, about note 20 and the three git commands) and that sentence
  was read, so the pass is blind to the round-1 reasoning but not to the fact
  that it existed.
- **Ran the test suite:** yes, in a fresh worktree of the patch tip with its own
  PostgreSQL 16 database and the Git fixture repository extracted into
  `tmp/test` (without it the repository tests skip silently and prove nothing).
  - the six touched files together in one process: `672 runs, 4271 assertions,
    0 failures, 0 errors, 16 skips`
  - `test:all`: see **Suite** below
  - RuboCop 1.90.0 on the ten changed Ruby files: `10 files inspected, no
    offenses detected`
  - `tools/check-patch-clean.sh revision-branches --submit`: PASS, re-run today
- **Scope covered:** minimality, feature scope, settings surface, conventions of
  the touched files, backward compatibility, authorization, escaping, SCM
  adapter symmetry, performance in the hot path, i18n and locale symmetry, tests
  as code, test pollution, the dossier itself, and four hypotheses of my own
  driven against the real fixture repository (below).
- **Scope NOT covered:**
  - **No live browser check.** I did not bring up a running Redmine and click a
    branch link. The G9 screenshots in `shots/` were read, not reproduced.
  - **No repository with many branches.** Everything here ran against the
    8-branch Git fixture. The performance claims in the dossier (F02 below)
    were reasoned about and read, not measured on a large repository.
  - **Database portability** is not applicable: the patch adds no query.
  - **Mercurial named branches**, which the design leaves for later, were not
    investigated.

## Summary

This is the strongest dossier I have read in this register, and the patch
matches it. The feature is fifteen years old on redmine.org and every earlier
attempt died on four specific objections from Toshi MARUYAMA; the dossier quotes
all four verbatim and the design answers each one structurally rather than
rhetorically — nothing is stored, so there is no cache to disagree with a
force-push; nothing runs unless an administrator turns it on; and the issue tab
refuses to run any command at all above a revision count. The three layers are
cleanly separated, and the adapter deliberately knows nothing about `Setting`,
which is the right call.

I could not find a blocker or a major. Four hypotheses I expected to pay off did
not, and I am recording them because a clean answer is worth as much as a
finding: branch names with slashes and capitals do **not** break URL generation
(they fall back to a query-parameter URL that routes correctly); the repository
objects on the issue tab are already preloaded so there is no database N+1 on
top of the subprocesses; `repository_log_display_limit` at `0` means "show
nothing" in both the existing repository log and this new cap, so the two agree;
and the duplicate keys in `es.yml` are 35 on both sides of the diff, so they are
upstream's and the patch correctly left them alone.

What I did find is one real defect in new code (F01): the exclusion patterns are
anchored with `\A...\z` around an un-grouped pattern, so a regular expression
containing alternation silently anchors only its first and last branch.
`feature|hotfix` excludes `feature-123` and `my-hotfix`. It is copied faithfully
from `MailHandler`'s identical line, which is the mitigating fact and also the
reason no test caught it — the tests use patterns without alternation.

The other two are trade-offs rather than bugs, and both are worth a sentence in
the note rather than a change to the code.

**Counts:** blocker 0 · major 0 · minor 2 · nit 1 · question 0

**Lines in the diff not strictly required by the feature:** 0. I looked
specifically for reformatting, renamed variables and tidied neighbours in the
five production files and found none; every hunk is additive and sits next to
the code it belongs with.

## Suite

Run in `/home/user/wt/review-revision-branches`, patch tip `3e2c6b432`, own
`revbranches` database on PostgreSQL 16, Ruby 3.3.6.

| What | Result |
|---|---|
| the six touched files in one process | `672 runs, 4271 assertions, 0 failures, 0 errors, 16 skips` |
| `test:all` | `5995 runs, 31782 assertions, 27 failures, 2 errors, 92 skips` |
| RuboCop on the ten changed `.rb` files | `10 files inspected, no offenses detected` |
| `tools/check-patch-clean.sh revision-branches --submit` | PASS (19 files, locales exactly the five, no AI trace, applies to pristine r25037, patch files agree with the branch) |
| locale key symmetry | 6 added keys in each of `en nl fr de es`, none of them a duplicate of an existing key |

**The dossier's figures reproduce.** It records `5995 runs, 31785 assertions,
27 failures, 2 errors, 92 skips` for the patch side; I measure `5995` runs and
the same failures, errors and skips, with `31782` assertions — three apart. For
the six touched files it records `672 runs, 4275 assertions` and I measure the
same runs and skips with `4271`. Both drifts are assertion counts only, in the
same direction, with no failure either way; this image has no ImageMagick
(`sh: 1: convert: not found` appears mid-run), which moves an assertion count
without moving an outcome.

**The 29 failing names are the trunk baseline, checked against a run of my
own.** Earlier today, reviewing `imap-oauth`, I ran `test:all` on a pristine
`origin/master` r25037 worktree in this same container and kept the sorted list
of failing test names. `diff` against this patch's list is **empty** — same 29
names, same classes (14 `RepositoriesControllerTest`, 8
`Redmine::ApiTest::RepositoriesTest`, 5 `SysControllerTest`, 1 `UserTest`,
1 `Redmine::ApiTest::IssuesTest`), all needing `svn`, `hg`, `bzr` or `cvs`,
none of which exist here. So the patch adds no failure, verified against a
baseline I measured rather than one I was told.

Hypotheses driven against the real fixture repository, all disproven:

```
# URL generation for realistic branch names — no raise, falls back to ?rev=
master                       -> /projects/ecookbook/repository?rev=master
feature/foo                  -> /projects/ecookbook/repository?rev=feature%2Ffoo
Release-2.0                  -> /projects/ecookbook/repository?rev=Release-2.0

# valid_name? consults the repository, so slashes and capitals are fine
master               valid_name?=true
test_branch          valid_name?=true
nope                 valid_name?=false
```

---

### F01 — the exclusion patterns anchor only the first and last alternative of a regular expression

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `app/models/changeset.rb`, `excluded_branch_patterns` — `Regexp.new("\\A#{pattern}\\z", Regexp::IGNORECASE)`
- **Invariant touched:** none

**What is wrong**

The pattern the administrator typed is interpolated between `\A` and `\z`
without being grouped. Alternation binds more loosely than concatenation, so
`\Afeature|hotfix\z` parses as `(\Afeature)|(hotfix\z)` — "starts with feature,
**or** ends with hotfix" — rather than "is exactly feature or exactly hotfix".
The intent the surrounding code expresses everywhere else, and that the glob
branch on the line below gets right, is an exact match.

**Why a committer would push back**

Concrete path, verified. An administrator turns on `revision_branches_enable_regex`
and sets `revision_branches_excluded` to `feature|hotfix`, meaning the two
long-lived branches by those names:

```
pattern "feature|hotfix" -> /\Afeature|hotfix\z/i
    feature        excluded=true    <- intended
    hotfix         excluded=true    <- intended
    feature-123    excluded=true    <- NOT intended
    my-hotfix      excluded=true    <- NOT intended
    main           excluded=false
    develop        excluded=false
```

Branches vanish from the revision page and the issue tab with no error and no
log line, and the administrator's only clue is that something they expected to
see is missing. Writing `(feature|hotfix)` works, so the failure is
silent-and-recoverable rather than damaging — which is why this is minor and not
major.

**The mitigating fact, and it is a real one.** `app/models/mail_handler.rb:365`
does exactly the same thing for `mail_handler_excluded_filenames`:

```ruby
regexp = %r{\A#{pattern}\z}i
```

The dossier names that pair as its direct precedent and follows it deliberately,
and the patch is in one respect *better* than its model — it wraps the
construction in `rescue RegexpError`, where `%r{}` interpolation would raise at
match time. So a committer may well accept this as consistency with core rather
than a defect, and that is a defensible answer. It is a finding because the
consistency argument is not written down anywhere, and because no test would
notice: `test_changeset_branches_should_exclude_names_matching_a_regular_expression`
uses `.*-\d+`, which has no alternation.

**How I verified it**

Ran the three patterns through the exact expression the method builds, in the
patch worktree (output above), then read `mail_handler.rb:362-373` to establish
where the shape comes from.

**Suggested direction**

Group the interpolation so both anchors apply to the whole pattern, and add a
case with alternation to the regex test. Whether to change `MailHandler` too is
a separate question and explicitly not this patch's to answer (INV-1) — but if
the answer here is "keep it consistent with core and leave it", that sentence
belongs in the dossier so a reviewer sees it was a choice.

**Resolution:**

---

### F02 — the only brake on the issue tab's fork count is a setting that also truncates the repository log

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** performance
- **Where:** `app/helpers/repositories_helper.rb`, `display_changeset_branches?`; `Setting.repository_log_display_limit` (default **100**)
- **Invariant touched:** none

**What is wrong**

`display_changeset_branches?` drops the whole display when an issue has more
associated revisions than `repository_log_display_limit`. That is a real bound
and it is the right shape of answer to note 18. But the number it uses belongs
to a different feature: `repository_log_display_limit` is read in exactly one
other place, `RepositoriesController#show`, where it caps the revision list on
the repository log page. The two are now coupled through one knob.

**Why a committer would push back**

The default is 100. An administrator who turns the feature on accepts that an
issue with 100 associated revisions fires **100 `git branch --contains`
subprocesses** on one XHR, each of which walks the commit graph for every
branch in the repository — the operation whose cost note 18 objected to in the
first place. An administrator who finds that too slow and wants the branches
only on small issues has one lever, and pulling it to 10 also truncates every
repository log page in the installation to ten revisions. There is no way to say
"branches up to 10 revisions, log still 100".

I am marking this minor, not major, deliberately. The feature is off by default,
the bound exists and is documented, and inventing a fifth setting to decouple
the two would trade this for an INV-6 problem the dossier has already argued its
way out of once. The finding is that the coupling is presented in the dossier
only as a virtue ("reuses the setting an administrator already has") and never
as the constraint it also is.

**How I verified it**

`grep -rn "repository_log_display_limit" app/ lib/` on the patch tip returns the
new helper and `repositories_controller.rb:120` and nothing else; read
`Repository#latest_changesets` to confirm what the other caller does with it.
I did **not** measure `git branch --contains` on a large repository — the
fixture here has eight branches, where the cost is invisible. The dossier
reports its own timings; I did not reproduce them.

**Suggested direction**

Nothing in the code. One sentence in the note, saying which number bounds the
fork count, what its default is, and that lowering it also shortens the
repository log — so the committer weighs the trade-off the author already
weighed instead of discovering it.

**Resolution:**

---

### F03 — a branch whose name is not UTF-8 is displayed, but its link leads to "not found"

- **Status:** open
- **Severity:** nit
- **Confidence:** confirmed (the mechanism, on the fixture repository)
- **Category:** correctness
- **Where:** `lib/redmine/scm/adapters/git_adapter.rb`, `branches_containing` — `scm_iconv('UTF-8', @path_encoding, name)`; consumed by `RepositoriesHelper#link_to_revision_branches`
- **Invariant touched:** none

**What is wrong**

`branches_containing` converts each branch name from the repository's path
encoding to UTF-8, which is right for display and is what the neighbouring
`branches` and `tags` already do. The helper then puts that converted string
into the link as `:rev`. On the way back in, `RepositoriesController#find_project_repository`
calls `valid_name?`, which runs `git show-ref -- <name>` — and git looks the ref
up by its raw bytes, which are not the UTF-8 ones. The name that was safe to
show is not the name that can be looked up.

**Why a committer would push back**

They would not, and I am marking this a nit for one reason: **it is not this
patch's defect.** The existing branch dropdown in
`app/views/repositories/_navigation.html.erb` is built from
`@repository.branches`, which runs the identical `scm_iconv`, and selecting such
a branch there fails in the same place today. Fixing it is out of scope (INV-1).

It is worth writing down anyway, because the patch takes an existing broken link
that lived in one dropdown and puts it on the revision page, the diff page and
the issue tab. Verified against Redmine's own Git fixture, whose branches
include two with a latin-1 byte in the name:

```
displayed by branches_containing:
  ["latin-1-branch-Ü-01", "latin-1-branch-Ü-02", "latin-1-path-encoding",
   "master", "master-20120212", "test-latin-1", "test_branch"]

  latin-1-branch-Ü-01      valid_name?=false   <- link leads to show_error_not_found
  latin-1-branch-Ü-02      valid_name?=false   <- link leads to show_error_not_found
  latin-1-path-encoding    valid_name?=true
  master                   valid_name?=true
```

The patch's own encoding tests cover the conversion
(`test_branches_containing_should_convert_branch_names_to_utf8`) but not the
round trip, which is why this is invisible from inside the test suite.

**How I verified it**

Built a `GitAdapter` on `tmp/test/git_repository` with `ISO-8859-1` as the path
encoding, called `branches_containing` for the revision the tests use, and
called `valid_name?` on each name it returned (output above). Then read
`_navigation.html.erb` and `GitAdapter#branches` to establish that the same
mechanism already exists on trunk.

**Suggested direction**

Nothing in this patch. It is worth one line in the dossier's "what this does not
fix" so that a reviewer who tries a non-UTF-8 branch name knows it is
pre-existing, and it is a candidate for a separate trunk issue — the fix belongs
in whatever maps a displayed ref name back to its bytes, which is core's problem
and not this feature's.

**Resolution:**
