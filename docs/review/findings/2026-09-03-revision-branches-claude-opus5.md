# Review run — 2026-09-03 — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `patch/revision-branches` at `181dda224` against `origin/master` `bee32a926` (branch parent is `2563fa6a5` = r24882; trunk has since moved 100 commits)
- **Dossier read:** `docs/features/revision-branches/dossier.md` — yes
- **Status read:** `docs/features/revision-branches/status.md` (the "already settled" section) — yes; `docs/features/revision-branches/decisions.md` and `docs/DECISIONS.md` — yes
- **Ran the test suite:** yes — the five touched files, twice: once on the patch as authored (r24882 base) and once with the two exported `.patch` files applied to **current** trunk `bee32a926`. Git fixtures unpacked both times (`git_repository.tar.gz` **and** `git_utf8_repository.tar.gz`; without the second, `test_branches_containing_should_convert_branch_names_to_utf8` is inside a block that still runs, but the neighbouring UTF-8 suite skips).
  - patch as authored: `test/unit/lib/redmine/scm/adapters/git_adapter_test.rb` + `test/unit/repository_git_test.rb` + `test/unit/changeset_test.rb` → **125 runs, 684 assertions, 0 failures, 0 errors, 15 skips**; `test/functional/repositories_git_controller_test.rb` + `test/functional/issues_controller_test.rb` → **522 runs, 3455 assertions, 0 failures, 0 errors, 1 skip**
  - both `.patch` files applied to current trunk `bee32a926`, all five files in one process → **647 runs, 4139 assertions, 0 failures, 0 errors, 16 skips**
  - RuboCop on the 8 changed Ruby files (trunk + patch): **8 files inspected, no offenses detected**
  - both `.patch` files still `git apply --check` cleanly on current trunk `bee32a926` — the r24882 base in the dossier is stale but harmless
- **Scope covered:** minimality; feature scope; settings surface (incl. a live POST to `/settings/edit`); conventions of the touched files; backward compatibility; SCM adapter symmetry; performance in the hot path (subprocesses counted by instrumenting `AbstractAdapter#shellout` on four real page renders); authorization (permission map read, `Changeset.visible` path exercised); escaping (hostile branch names rendered through the real view); i18n (all five locale files, every cited source key checked against trunk, sortedness of the locale files measured); tests as code (four mutation experiments); test pollution; the dossier's anticipated-objection answers; robots/crawler reachability.
- **Scope NOT covered:** no full `test:all` run (I trusted the dossier's byte-identical failure-list comparison rather than re-running ~50 minutes); no browser/G9 re-run — I did not re-take the screenshots and did not look at `docs/features/revision-branches/shots/*.png`; no database-portability review (the patch adds no SQL); no check of the `7.0-stable-GEOxyz` commit `115230bc2` (I reviewed only the trunk patch); no system tests; no review of `docs/features/revision-branches/seed.rb`.

## Summary

This is a good patch and the best-argued of the seven that #5386 has seen. It is
genuinely minimal — 300 added lines, no deletions, no reformatting, no tidying
of neighbours — the layering is right (adapter knows nothing about `Setting`,
filtering lives in the model, rendering in a helper), the escaping is correct
(I fed `<script>alert(1)</script>` through as a branch name and it comes back
fully escaped in both the link text and the href), the authorization reasoning
checks out against `lib/redmine/preparation.rb` (`repositories#show` really is
granted under both `:view_changesets` and `:browse_repository`), the tests are
real (three mutations I made each turned exactly the right test red), and the
patch still applies and stays green on a trunk that has moved 100 commits since
it was written.

The single biggest reason a committer would send it back is **F01**: the patch
copies the `mail_handler_excluded_filenames` / `..._enable_regex_...` pair,
which is the right precedent, but it does not copy the half of that precedent
that lives in `Setting.validate_all_from_params`. I checked this by posting both
settings forms: typing `[` as a regular expression into the mail-handler field
is rejected with an error and not saved; typing `[` into the new field saves
happily, and from then on every render logs a warning and silently ignores the
pattern. The administrator is told nothing. That is a five-line omission in the
place the reviewer of that original code will look first.

Two other things a committer will find. **F02**: the cost is exactly what note 18
predicted and I measured it — an issue with 29 associated revisions runs 29
`git branch --no-color --contains` subprocesses in one tab render, all distinct,
and the render goes from 466 ms to 1007 ms on a 29-commit fixture repository on
local disk. Nothing bounds N. (The *cache* question is settled and I am not
reopening it; a cap is a different thing and the dossier itself leaves it open.)
And **F03**: the dossier defends that cost partly with "the revision page already
calls three Git commands (note 20)". It does not. I counted: the revision page
makes **zero** SCM subprocesses on today's trunk; it is the repository *browse*
page that makes five. That sentence is going into a public note on a 16-year-old
issue and it is trivially disprovable, so it should go.

Positive surprises: the note-20 crawler argument is *better* than the dossier
claims in one respect — `issue_tab` returns 422 to any non-XHR request, so a
crawler cannot reach it even by URL, not merely "because it needs JavaScript".
It is weaker in another (F08). And the escaping, the `\A…\z` anchoring, the
`scm_iconv` handling and the `respond_to?` guard for the other five adapters are
all exactly right.

**Counts:** blocker 0 · major 3 · minor 5 · nit 2 · question 1

**Lines in the diff not strictly required by the feature:** 0 gratuitous — no
reformatting, no renames, no unrelated fixes, and every added line traces to the
feature. The only trimmable *scope* is the `revision_branches_enable_regex`
switch and its branch in `excluded_branch_patterns` (about 12 lines plus one
setting plus five translations), and that is Jan's settled decision, recorded,
with the concession already costed in the dossier.

---

### F01 — An invalid regular expression in `revision_branches_excluded` is silently accepted and stored; the core pattern this is modelled on rejects it at the form

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — the pair is now the third row of `Setting.validate_all_from_params`, so the settings form refuses `Abc[` with "is not a valid regular expression" and stores nothing, exactly as the mail-handler pair does. New test `SettingsControllerTest#test_post_revision_branches_excluded_should_not_save_an_invalid_regular_expression`, verified red without the row (302, value stored). The `rescue RegexpError` in `excluded_branch_patterns` stays as a guard against a value written straight into the `settings` table, and its `logger.warn` is gone — it fired once per rendered row. The dossier and the objections table now describe it that way instead of as a correction of core
- **Severity:** major
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `app/models/setting.rb:161-186` (`validate_all_from_params`, unmodified by the patch); `app/models/changeset.rb:243-255`; `app/views/settings/_repositories.html.erb:62-69`
- **Invariant touched:** none

**What is wrong**

The patch deliberately mirrors `mail_handler_excluded_filenames` +
`mail_handler_enable_regex_excluded_filenames`, and mirrors it faithfully in
`Changeset#excluded_branch_patterns` — same `\A…\z` anchoring, same
`IGNORECASE`, same `*` → `.*` translation. But that core pair is not only
`MailHandler#accept_attachment?`. It is also a registered entry in the table at
the top of `Setting.validate_all_from_params`, which is what actually stops a
malformed regular expression from being stored:

```ruby
[
  [:mail_handler_enable_regex_delimiters, :mail_handler_body_delimiters, /[\r\n]+/],
  [:mail_handler_enable_regex_excluded_filenames, :mail_handler_excluded_filenames, /\s*,\s*/]
].each do |enable_regex, regex_field, delimiter|
```

The new pair is not in that table. The `rescue RegexpError` in
`excluded_branch_patterns` is presented in the dossier and in `decisions.md` as
an improvement on core ("Core's `MailHandler#accept_attachment?` does not guard
this, which is fine in a background job and would not be on a page"). Core does
guard it — one layer up, where the value is saved, which is the better place —
so the patch has replaced a validate-at-save design with a swallow-at-render
design without saying so.

**Why a committer would push back**

Concrete path, both halves measured. Administrator opens Administration →
Mail handling, ticks "Enable regular expressions", types `[` into "Exclude
attachments by name", saves: HTTP 200, an `errorExplanation` box is rendered,
and `Setting.mail_handler_excluded_filenames` is still `""`. Same administrator
opens Administration → Repositories, ticks the new "Enable regular expressions",
types `[` into "Exclude branches by name", saves: HTTP 302, no error anywhere,
and `Setting.revision_branches_excluded` is now `"["`. From that moment the
exclusion list does nothing, the administrator has no way to know, and every
revision page and every associated-revisions render writes one
`logger.warn` line per changeset per pattern — on an issue with 29 associated
revisions that is 29 warning lines per page view, per bad pattern.

The reviewer most likely to read this patch is the one who wrote
`validate_all_from_params`. "You took our settings pair but not our validation"
is the first comment.

**How I verified it**

Integration test against the patch on current trunk, posting both real settings
forms as `admin`:

```
MAILHANDLER  status=200 stored="" body_has_error=true
REVBRANCHES  status=302 stored="[" body_has_error=false
```

**Suggested direction**

The cheap, conventional fix is to make the new pair a third row of the table in
`Setting.validate_all_from_params`, with the same `/\s*,\s*/` delimiter. Whether
the `rescue RegexpError` in `excluded_branch_patterns` then stays is a judgement
call — keeping it as a belt-and-braces guard against a value written directly to
the `settings` table is defensible, but the dossier and `decisions.md` should
then describe it that way rather than as a correction of core. If it stays, the
per-changeset `logger.warn` should not fire once per rendered row.

**Resolution:** fixed 2026-09-05 — the pair is now the third row of `Setting.validate_all_from_params`, so the settings form refuses `Abc[` with "is not a valid regular expression" and stores nothing, exactly as the mail-handler pair does. New test `SettingsControllerTest#test_post_revision_branches_excluded_should_not_save_an_invalid_regular_expression`, verified red without the row (302, value stored). The `rescue RegexpError` in `excluded_branch_patterns` stays as a guard against a value written straight into the `settings` table, and its `logger.warn` is gone — it fired once per rendered row. The dossier and the objections table now describe it that way instead of as a correction of core

---

### F02 — One `git branch --contains` subprocess per associated revision, with nothing bounding the count

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 per Jan's g12 (and F11 option A) — `RepositoriesHelper#display_changeset_branches?` drops the whole display when the issue carries more associated revisions than `Setting.repository_log_display_limit` (default 100), so N is bounded by a number the administrator already sets and no fifth setting is added (INV-6). All-or-nothing rather than branches for the first N, so there is no half-rendered page to report as a bug. Test `IssuesControllerTest#test_show_changesets_tab_should_not_display_branches_above_the_revision_display_limit`, red without the cap. The exception itself is recorded as E-02 in `docs/exceptions.md`. Memoising `Changeset#branches` and hoisting `excluded_branch_patterns` out of the loop were deliberately **not** done: the view assigns the helper's result to a local, so `branches` is called exactly once per rendered changeset and memoisation saves nothing, and compiling a handful of patterns is orders of magnitude below the fork the cap bounds (INV-1)
- **Severity:** major
- **Confidence:** confirmed
- **Category:** performance
- **Where:** `app/views/issues/tabs/_changesets.html.erb:23-26`; `app/models/changeset.rb:204-210`; `app/controllers/issues_controller.rb:257`
- **Invariant touched:** none — but this is the "an SCM call per row inside a view loop" row of the forbidden-constructs table in `CLAUDE.md`, and the "no database cache / the command stays" decision that makes it unavoidable is Jan's, settled 2026-09-01. See F11.

**What is wrong**

`issue_tab` loads `@issue.changesets.visible.preload(:repository, :user).to_a`
with no limit, and the partial calls `link_to_revision_branches(changeset)` for
every row, each of which reaches `repository.scm.branches_containing(scmid)` and
forks one `git` process. The Rails-level work is done properly — `preload(:repository)`
means one `Repository` instance and therefore one memoised adapter for the whole
loop, so there is no N+1 in SQL and no repeated adapter construction — but the
subprocess is per row and the row count is whatever the issue has.

`Changeset#branches` is also not memoised, and `excluded_branch_patterns`
re-reads two settings and recompiles every pattern on each call. Those are
minor next to the fork, but they are in the same loop.

**Why a committer would push back**

This is note 18 restated with a measurement instead of a prediction, so it will
be the first thing raised on the issue. Measured on the patch, with
`display_associated_revision_branches` on and issue 1 given all 29 changesets of
the Git fixture repository:

```
issue tab, setting OFF: 0 shellout calls, 466 ms
issue tab, setting ON : 29 shellout calls (29 distinct), 1007 ms
sample: 'git' '--git-dir' '…/git_repository' '-c' 'core.quotepath=false' \
        '-c' 'log.decorate=no' 'branch' '--no-color' '--contains' '7234cb27…'
```

That is a 29-commit repository with 8 branches on local disk. `git branch --contains`
walks history for every branch tip, so on a real repository with hundreds of
branches and years of history the per-call cost is much higher, and it is paid
serially. Two further costs are worth naming even though I did not measure them:
`shellout` has no timeout, so one slow `git` blocks the request thread for as
long as it takes and N of them multiply that; and with the setting on, any
authenticated user who may view an issue can make Redmine fork N processes per
request simply by reloading the tab, which is a cheaper amplification than
anything else on the issue page.

The off-by-default position genuinely answers "no existing installation pays
anything". It does not answer "what happens to the installation that turns it
on and has an issue like #61".

**How I verified it**

Instrumented `Redmine::Scm::Adapters::AbstractAdapter#shellout` with a `prepend`
that records every command, then drove real requests through
`Redmine::IntegrationTest` (numbers above). Cross-checked that the count is
exactly one per rendered changeset and that all 29 commands are distinct.

**Suggested direction**

The dossier already names the shape of the answer — "a cap on the number of
revisions it will do this for is a two-line addition once someone picks the
number" — and I think it is worth picking the number before submission rather
than after, because it converts the strongest objection on the issue into a
resolved line in the patch. `repository_log_display_limit` (default 100) is the
existing precedent for "a repository display limit an administrator can tune",
and reusing it costs no new setting. Memoising `Changeset#branches` and hoisting
`excluded_branch_patterns` out of the per-changeset path are separate, smaller
wins. Whether to do any of this before submitting is F11, a question for Jan.

**Resolution:** fixed 2026-09-05 per Jan's g12 (and F11 option A) — `RepositoriesHelper#display_changeset_branches?` drops the whole display when the issue carries more associated revisions than `Setting.repository_log_display_limit` (default 100), so N is bounded by a number the administrator already sets and no fifth setting is added (INV-6). All-or-nothing rather than branches for the first N, so there is no half-rendered page to report as a bug. Test `IssuesControllerTest#test_show_changesets_tab_should_not_display_branches_above_the_revision_display_limit`, red without the cap. The exception itself is recorded as E-02 in `docs/exceptions.md`. Memoising `Changeset#branches` and hoisting `excluded_branch_patterns` out of the loop were deliberately **not** done: the view assigns the helper's result to a local, so `branches` is called exactly once per rendered changeset and memoisation saves nothing, and compiling a handful of patterns is orders of magnitude below the fork the cap bounds (INV-1)

---

### F03 — The dossier defends the cost with "the revision page already calls three Git commands"; the revision page calls none

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — the sentence is gone. The objections row now says what is true and measured: the revision page makes no SCM call on trunk and gains exactly one when the setting is on, note 20's "three git commands" is about the repository *browse* page which this patch does not touch, and the revision page is already crawler-excluded by the `Disallow: /projects/<project>/repository` prefix. The 466 ms → 1007 ms figure for a 29-revision issue tab is now in the same row
- **Severity:** major
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/revision-branches/dossier.md`, "Anticipated objections", first row ("the revision page already calls three Git commands (note 20) and is already in `robots.txt`")
- **Invariant touched:** none

**What is wrong**

Note 20 says "Repository page calls three git commands". The dossier reuses that
sentence about the **revision** page, which is a different page. On today's trunk
the revision page renders entirely from the cached changeset in the database and
issues no SCM command at all; it is `repositories#show`, the browse page, that
shells out.

So the patch does not add a fourth Git command to a page that already ran three.
It adds the **first** Git command to a page that previously touched the SCM zero
times. That is a materially different claim, and it is one of only three things
offered against the central objection.

**Why a committer would push back**

The text from "# The problem" onwards is meant to be pasted verbatim into a note
on #5386, an issue whose participants include the person who wrote note 20. A
reader who checks — and on this issue someone will — finds the sentence is false
and discounts the rest of the argument with it. The remaining two bounds (off by
default; the revision page is already in `robots.txt` under the
`Disallow: /projects/<p>/repository` prefix) are both true and both survive, so
the argument does not need this sentence at all.

**How I verified it**

Same `shellout` instrumentation, anonymous-equivalent logged-in requests against
the patch on current trunk:

```
revision page, setting OFF : n=0  cmds=[]
revision page, setting ON  : n=1  cmds=["branch"]
repository browse page     : n=5  cmds=["branch","show-ref","ls-tree","log","tag"]
diff page, setting OFF     : n=1  cmds=["show"]
diff page, setting ON      : n=2  cmds=["show","branch"]
```

**Suggested direction**

Say what is true and let it be the stronger sentence: the revision page renders
one extra command, only when enabled, and it is already excluded from crawlers
by the existing `Disallow` prefix — and note 20's "three commands" observation
applies to the repository browse page, which this patch does not touch. Nothing
else in the objections table depends on the wrong version.

**Resolution:** fixed 2026-09-05 — the sentence is gone. The objections row now says what is true and measured: the revision page makes no SCM call on trunk and gains exactly one when the setting is on, note 20's "three git commands" is about the repository *browse* page which this patch does not touch, and the revision page is already crawler-excluded by the `Disallow: /projects/<project>/repository` prefix. The 466 ms → 1007 ms figure for a 29-revision issue tab is now in the same row

---

### F04 — The feature also appears, and runs `git`, on the diff page — which the setting name, the dossier and the G9 evidence all omit

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 by stating it, which is the reviewer's own recommendation — `setting_display_revision_branches` now reads "Display branches on the revision and diff pages" in all five locales, the dossier's file table says `repositories/_changeset` is rendered by both `revision.html.erb` and `diff.html.erb`, the G9 table gains a `before-diff-branches.png` / `diff-branches.png` pair, and `RepositoriesGitControllerTest#test_diff_should_show_the_branches_containing_the_revision` covers the second page
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** ui
- **Where:** `app/views/repositories/_changeset.html.erb:23-28`; the partial is rendered by `app/views/repositories/revision.html.erb:29` **and** `app/views/repositories/diff.html.erb:29`
- **Invariant touched:** none

**What is wrong**

`_changeset.html.erb` is shared by two views. The setting is called
`display_revision_branches`, is labelled "Display branches on the revision page",
and is documented in the dossier's file table as "one `<li>` in `ul.revision-info`,
between parent and child" on the revision page. It also renders on
`repositories#diff` whenever that page shows a single changeset, and adds a
second Git subprocess there. The diff body is fragment-cached
(`@cache_key` / `read_fragment` in `RepositoriesController#diff`), but
`_changeset` is rendered outside that cache, so the subprocess is paid on every
diff page view even when the diff itself is served from the cache.

**Why a committer would push back**

Two smaller things rather than one big one. A setting whose label names one page
and which silently affects a second is a documentation defect that will be
reported as a bug. And the G9 evidence table has no diff-page row, before or
after, so the reviewer is being shown two of the three places the change is
visible. The behaviour itself is defensible — arguably desirable — it is only
undescribed.

**How I verified it**

`git grep "render :partial => 'changeset'"` finds both call sites; then a real
request:

```
diff page, setting OFF: n=1 cmds=["show"]
diff page, setting ON : n=2 cmds=["show","branch"]   Branches row present: true
```

**Suggested direction**

Either state it (setting label and dossier both saying the row appears wherever
a single revision is shown, with a diff-page screenshot added to the G9 table),
or scope the row to `revision.html.erb` only if the diff page is not wanted. The
first is less code and probably the better product; it is the *silence* that is
the finding, not the behaviour.

**Resolution:** fixed 2026-09-05 by stating it, which is the reviewer's own recommendation — `setting_display_revision_branches` now reads "Display branches on the revision and diff pages" in all five locales, the dossier's file table says `repositories/_changeset` is rendered by both `revision.html.erb` and `diff.html.erb`, the G9 table gains a `before-diff-branches.png` / `diff-branches.png` pair, and `RepositoriesGitControllerTest#test_diff_should_show_the_branches_containing_the_revision` covers the second page

---

### F05 — The four settings are offered on installations where Git is not an enabled SCM, and nothing in the UI says the feature is Git-only

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 by wording, not by gating — a new `text_revision_branches_git_only` ("Branch information is only available for Git repositories.") renders as an `em.info` under the block, in all five locales. Not gated on `enabled_scm`: Git enabled with this project's repository on Subversion is a legitimate mixed case in which the setting still means something, and hiding it there would be wrong
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** scm-symmetry
- **Where:** `app/views/settings/_repositories.html.erb:59-69`; `config/locales/en.yml:471-474`
- **Invariant touched:** none

**What is wrong**

The dossier's stated position — "Git only, of six adapters", with
`Changeset#branches` guarding on `respond_to?(:branches_containing)` — is the
right position and I am not disputing it. But the skill's requirement is
two-part: an explicit "Git only" statement **and** the UI must not offer the
feature where it does nothing. The four checkboxes and the exclusion field are
rendered unconditionally on the Repositories tab, including on an installation
whose `enabled_scm` does not contain Git, and neither the labels
("Display branches on the revision page", "Exclude branches by name") nor any
`em.info` hint mentions Git.

**Why a committer would push back**

Concrete path: a Subversion-only site upgrades, an administrator sees a new and
plausible-sounding "Display branches on the revision page", ticks it, saves,
visits a revision, sees nothing, and files a bug. Nothing in the product tells
them why. The same page already knows the answer — the fieldset directly above
these settings lists every SCM with whether its client is available — so the
information is one screen-inch away and unused.

**How I verified it**

Rendered `/settings?tab=repositories` as `admin` inside
`with_settings :enabled_scm => ['Subversion']`:

```
SVN-ONLY checkbox present=true
SVN-ONLY label="Display branches on the revision page"
```

**Suggested direction**

The smallest honest fix is to say so in words — an `em.info` under the pair, or
"(Git only)" folded into the labels — which costs one translated string in five
files and no logic. Hiding or disabling the block when Git is not in
`enabled_scm` is the stronger fix but has no precedent on this tab and would
need a story for the mixed case (Git enabled, this project's repository is SVN),
where the setting is legitimately meaningful. I would not gate on `enabled_scm`
without deciding that; wording is enough.

**Resolution:** fixed 2026-09-05 by wording, not by gating — a new `text_revision_branches_git_only` ("Branch information is only available for Git repositories.") renders as an `em.info` under the block, in all five locales. Not gated on `enabled_scm`: Git enabled with this project's repository on Subversion is a legitimate mixed case in which the setting still means something, and hiding it there would be wrong

---

### F06 — The hint under the exclusion field shows a regular-expression example, but the field is glob syntax unless the box below it is ticked

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — the hint is now `l(:text_comma_separated)` plus `l(:label_example)` and the literal `dependabot/*, wip-*`, copied from `app/views/settings/_mail_handler.html.erb`, so the example matches the mode the field is actually in by default. `text_regexp_info` is no longer used here, and no new key was needed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** ui
- **Where:** `app/views/settings/_repositories.html.erb:67-68`

**What is wrong**

The hint is `l(:text_comma_separated)` + `l(:text_regexp_info)`, which renders as
"Multiple values allowed (comma separated). eg. ^[A-Z0-9]+$". The default state
of `revision_branches_enable_regex` is `0`, in which the field takes shell-style
globs, so the only example the administrator is shown is one that does not work
in the mode they are in. Core's equivalent field does the opposite: the
mail-handler hint is `l(:label_example) %>: smime.p7s, *.vcf` — glob examples —
and `text_regexp_info` is used in `custom_fields/formats/_regexp.html.erb`, where
the field genuinely is always a regular expression.

**Why a committer would push back**

Concrete path: administrator wants to hide Dependabot branches, reads the hint,
types `^dependabot/.*$`, leaves the checkbox alone because nothing suggests it
matters, saves. Nothing is excluded and nothing is reported. The correct entry in
the default mode is `dependabot/*`, which the hint never shows.

This is also the one place the screenshot-reading pass (which caught the earlier
"Example: eg." duplication, a good catch) stopped one step short: the string is
now well-formed, but it is the wrong example for the default mode.

**How I verified it**

Read the two views side by side and the five locale files
(`text_regexp_info` exists and means "eg. ^[A-Z0-9]+$" in all five; nl is
"bv.", de "z. B.", fr "ex.", es "ej."). Not executed — the rendered string is
already recorded in the dossier's own screenshot description.

**Suggested direction**

Show a glob example, the way the mail-handler field does, since that is the
default mode; if both modes deserve an example, the pattern to copy is
`label_example` plus a literal, not a locale key that assumes regular
expressions. No new key is needed either way.

**Resolution:** fixed 2026-09-05 — the hint is now `l(:text_comma_separated)` plus `l(:label_example)` and the literal `dependabot/*, wip-*`, copied from `app/views/settings/_mail_handler.html.erb`, so the example matches the mode the field is actually in by default. `text_regexp_info` is no longer used here, and no new key was needed

---

### F07 — `test_show_changesets_tab_should_not_display_branches_without_view_changesets_permission` passes with the entire feature removed

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — the test now drives the same request twice inside one `with_settings` block: with `:view_changesets` it asserts `div#changeset-102 em` reads `Branches: main`, and after `Role.find(1).remove_permission!` it asserts no branch row anywhere on the response, not just inside the changeset block. Both halves fail on the feature-removed mutation, so it is no longer green with the feature gone
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** test-quality
- **Where:** `test/functional/issues_controller_test.rb:3360-3374`

**What is wrong**

The test removes `:view_changesets` from role 1 and asserts
`assert_select 'div#changeset-102', :count => 0`. That assertion is about the
changeset block, which `Changeset.visible` already removes on trunk; it says
nothing about branches. The `Changeset.any_instance.stubs(:branches)` line and
the `with_settings` block have no effect on the outcome.

**Why a committer would push back**

Not very hard — a test that documents an inherited guarantee is not harmful. But
the dossier presents it as the evidence for the authorization design ("the
display inherits `Changeset.visible`, so a user without `:view_changesets` gets
no changeset and therefore no branches"), and it does not test that inheritance:
it would keep passing if the branch row were rendered outside the visible scope,
because the assertion never looks at a branch. Of fourteen listed tests, this is
the one that asserts nothing about the change.

**How I verified it**

Mutation: deleted the four-line branches block from
`app/views/issues/tabs/_changesets.html.erb` and ran the three new
issue-tab tests. One failed (`..._should_display_the_branches_of_each_revision`,
"Expected at least 1 element matching \"div#changeset-102 em\", found 0"); this
one and `..._not_display_branches_by_default` both passed. The `_by_default`
guard is deliberately green on trunk and the dossier says so; this one is not
labelled that way.

I also confirmed by mutation that the other new tests are not vacuous:
un-anchoring the glob (`\A…\z` → bare) turned
`test_changeset_branches_should_exclude_names_matching_a_pattern` red
(`["master-20120212","test_branch"]` vs `["test_branch"]`), and dropping
`scm_iconv` turned `test_branches_containing_should_convert_branch_names_to_utf8`
red (`"latin-1-branch-Ü-01"` vs `"latin-1-branch-\xDC-01"`).

**Suggested direction**

Either give it an assertion that can only be satisfied by the feature — that the
`em` carrying the branch names is absent while a changeset the user *can* see
still shows one, for instance — or keep it as a guard and say in the dossier
that it is a guard, the way the two `_by_default` tests are labelled. What
should not stand is the dossier claiming it proves something it does not test.

**Resolution:** fixed 2026-09-05 — the test now drives the same request twice inside one `with_settings` block: with `:view_changesets` it asserts `div#changeset-102 em` reads `Branches: main`, and after `Role.find(1).remove_permission!` it asserts no branch row anywhere on the response, not just inside the changeset block. Both halves fail on the feature-removed mutation, so it is no longer green with the feature gone

---

### F08 — The note-20 answer holds for crawlers that do not run JavaScript; it does not hold for the ones that do

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — both the "Proposed change" paragraph and the objections row are rewritten around `IssuesController#issue_tab`'s `422 unless request.xhr?`, which is the real defence, and both now name the residual case explicitly: a JavaScript-executing crawler that follows `?tab=changesets` does fire the XHR, because the inline `javascript_tag` runs on load and `/issues/:id` is not in `robots.txt`. What bounds it is the F02 cap. `Disallow: /issues/*/tab/` is offered as the one-line alternative if a reviewer wants it closed outright, rather than being done unasked
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** dossier
- **Where:** `docs/features/revision-branches/dossier.md`, "Proposed change" and "Anticipated objections", second row; `app/views/common/_tabs.html.erb:31`; `app/helpers/issues_helper.rb:737-748`

**What is wrong**

The dossier's answer is that `GET /issues/123` renders an empty container and
"a crawler that executes no JavaScript never triggers it". That is literally
true and I confirmed it. But the qualifier is doing all the work, and the
mainstream crawler this objection is about does execute JavaScript.

Two details make the exposure concrete. `/issues/:id` is **not** in
`robots.txt` — `robots.text.erb` disallows `/projects/<p>/issues`, `/issues?*sort=`,
`?query_id=`, `?set_filter=` and the PDF paths, but not a bare issue URL. And
when `changesets` is the selected tab, `common/_tabs.html.erb` emits
`<%= javascript_tag default_action %>`, so the page contains an inline script
that calls `getRemoteTab('changesets', '/issues/1/tab/changesets', …)` **on
load**, not on click. `/issues/1?tab=changesets` is itself an ordinary `href` in
the tab bar, so a rendering crawler reaches it by following links, runs the
inline script, and the XHR then does the N subprocesses of F02.

The patch is stronger than the dossier claims in the other direction, and this
deserves to be said: `IssuesController#issue_tab` begins
`return render_error :status => 422 unless request.xhr?`, so a non-rendering
crawler cannot reach the endpoint even if it discovers the URL. The correct
statement is "the endpoint refuses non-XHR requests", which is a much better
answer than "the content only arrives through JavaScript".

**Why a committer would push back**

Note 20 is one of the four objections this patch exists to answer, and its
author will read the answer. "A crawler that executes no JavaScript never
triggers it" invites the one-line reply "Googlebot renders JavaScript", and the
patch then looks like it has not thought about the case rather than like it has
a 422 guard that mostly handles it.

**How I verified it**

Anonymous request against the patch, with `view_changesets` granted to the
anonymous role, issue 1 carrying 5 Git changesets, the setting on:

```
GET /issues/1?tab=changesets      status=200  shellout=0
  inline script present (unescaped, i.e. inside <script>):
  getRemoteTab('changesets', '/issues/1/tab/changesets', '/issues/1?tab=changesets')
GET /issues/1/tab/changesets      status=422  shellout=0   (non-XHR)
```

**Suggested direction**

Rewrite the answer around the 422 guard, which is the real defence, and be
honest about the residual case: a JavaScript-rendering crawler that follows
`?tab=changesets` will fire the XHR. Then say what bounds it — which, if F02
gains a cap, is a satisfying answer, and otherwise is the argument for adding
`Disallow: /issues/*/tab/` to `robots.text.erb` (a one-line change that only
affects a route no human navigates to directly, and does not deindex issue
pages, which is the outcome the dossier rightly wants to avoid).

**Resolution:** fixed 2026-09-05 — both the "Proposed change" paragraph and the objections row are rewritten around `IssuesController#issue_tab`'s `422 unless request.xhr?`, which is the real defence, and both now name the residual case explicitly: a JavaScript-executing crawler that follows `?tab=changesets` does fire the XHR, because the inline `javascript_tag` runs on load and `/issues/:id` is not in `robots.txt`. What bounds it is the F02 cap. `Disallow: /issues/*/tab/` is offered as the one-line alternative if a reviewer wants it closed outright, rather than being done unasked

---

### F09 — `names.sort!` can raise where the rest of the method carefully returns `[]`

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — a `scm_iconv` that returns `nil` is dropped instead of pushed, so `names.sort!` cannot raise and the method keeps the contract the rest of it follows. Test `GitAdapterTest#test_branches_containing_should_skip_names_that_cannot_be_converted` builds the adapter with `path_encoding` `ISO-2022-JP`, in which the fixture's two Latin-1 branch names really do fail to convert; on the unguarded version it errors with `ArgumentError: comparison of NilClass with String failed` from `sort!`, so the reachability half is now measured rather than reasoned
- **Severity:** nit
- **Confidence:** probable
- **Category:** correctness
- **Where:** `lib/redmine/scm/adapters/git_adapter.rb:97-113`

**What is wrong**

`scm_iconv` returns `nil` when the conversion fails
(`abstract_adapter.rb:287-299`: it rescues everything and returns `nil` after
logging). `branches_containing` pushes that result straight into `names` and then
calls `names.sort!`, and `Array#sort!` raises
`ArgumentError: comparison of NilClass with String failed` as soon as one element
is `nil`. Every other failure in this method is handled — a blank identifier
returns `[]`, a non-zero exit returns `[]` — so a raise from the sort is out of
character for it, and it reaches a view.

**Why a committer would push back**

Weakly, and I want to be honest about how narrow the path is. It needs a
repository whose `path_encoding` is set to an encoding into which some branch
name's bytes do not convert — the common cases do not qualify, because
`path_encoding` blank means `UTF-8` and takes the `to == from` early return, and
Latin-1 → UTF-8 is total. A multi-byte `path_encoding` (Shift_JIS, ISO-2022-JP)
with a branch name that is not valid in it is the realistic trigger, and those
are exactly the repositories `path_encoding` exists for. The existing `branches`
method has a comparable exposure (`GitBranch.new(nil)`), so this is a family
trait rather than something the patch invented.

**How I verified it**

Read `scm_iconv`; `[nil, 'a'].sort!` raising is not in doubt. I did **not**
construct a repository that triggers the conversion failure, so the reachability
half is reasoning, not measurement — hence `probable`.

**Suggested direction**

Dropping the failed conversions before sorting is the obvious answer and keeps
the method's own contract; whether a name that cannot be decoded should be
skipped or passed through undecoded is a real choice and the fixing session owns
it.

**Resolution:** fixed 2026-09-05 — a `scm_iconv` that returns `nil` is dropped instead of pushed, so `names.sort!` cannot raise and the method keeps the contract the rest of it follows. Test `GitAdapterTest#test_branches_containing_should_skip_names_that_cannot_be_converted` builds the adapter with `path_encoding` `ISO-2022-JP`, in which the fixture's two Latin-1 branch names really do fail to convert; on the unguarded version it errors with `ArgumentError: comparison of NilClass with String failed` from `sort!`, so the reachability half is now measured rather than reasoned

---

### F10 — The commit message is far longer than anything in trunk's history

- **Status:** resolved
- **Resolution:** fixed 2026-09-05 — the commit message is the subject line alone, `Show the Git branches that contain a revision (#5386).`, which is the shape 196 of trunk's last 200 commits have. The explanation lives in the dossier text that goes into the note
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** commit `181dda224`; `patches/revision-branches/2026-09-03-r24882-feature.patch:1-40`

**What is wrong**

The message is a 35-line essay. Measured over the last 200 commits on
`origin/master`, the body (excluding the `git-svn-id` trailer) is 0 or 1 lines in
196 of them — the 1-line case being "Patch by Go MAEDA (user:maeda)." — with a
single 12-line outlier. The subject line itself is exactly right in form:
`Show the Git branches that contain a revision (#5386).`

**Why a committer would push back**

Barely, and possibly not at all: a committer applying an attached patch writes
their own commit message, so this text never lands in SVN. Its real audience is
the reviewer reading the `.patch` file, for whom the explanation is useful rather
than harmful. I am recording it because it is a measurable deviation from the
touched project's convention, not because I think it costs anything. Lowest
priority of anything in this file.

**How I verified it**

`git log -200 --format=%H origin/master`, then counting non-blank `%b` lines per
commit: 102 commits with 1, 94 with 2, and one each with 3, 4, 6 and 12 — where
the `git-svn-id` line accounts for one of those in every case.

**Suggested direction**

If it is trimmed, the parts that carry weight for a reviewer are the first
paragraph and the note-17/18/20 paragraph; the settings detail is all in the
dossier text that goes into the issue note anyway. Equally defensible to leave
it alone.

**Resolution:** fixed 2026-09-05 — the commit message is the subject line alone, `Show the Git branches that contain a revision (#5386).`, which is the shape 196 of trunk's last 200 commits have. The explanation lives in the dossier text that goes into the note

---

### F11 — Question for Jan: bound the per-revision command before submitting, or let the core team ask?

- **Status:** resolved
- **Resolution:** answered 2026-09-05 by Jan's g12: option A, the cap goes in before submission, reusing `repository_log_display_limit` so no fifth setting appears. Implemented and evidenced under F02; the deliberate rule-break it bounds is written up as E-02 in `docs/exceptions.md`
- **Severity:** question
- **Confidence:** n/a
- **Category:** performance
- **Where:** the F02 measurement; `docs/features/revision-branches/status.md`, "Wat er al bekend is"; `docs/DECISIONS.md` (2026-09-01)
- **Invariant touched:** the "an SCM call per row inside a view loop" row of the forbidden-constructs table in `CLAUDE.md`

**This is settled and I am not reopening it.** Jan decided on 2026-09-01 to keep
the feature Git-only, keep the underlying `git branch --contains`, keep all four
settings, and let the core team react rather than cutting scope pre-emptively.
Nothing in this review argues for a database cache; notes 4 and 17 rule it out
and the dossier is right about that.

What is new is the number. F02 measures 29 subprocesses and a 2.2× render time
for one issue tab on a toy repository, and F03 removes one of the three sentences
currently defending it. A cap is not a cache — it does not reintroduce anything
notes 4 and 17 reject, it needs no schema, and the dossier already describes it
as "a two-line addition once someone picks the number" and explicitly hands the
choice to the reviewer.

- **Keuze:** een bovengrens op het aantal revisies waarvoor de issuetab het
  git-commando draait — nu inbouwen, of pas als het core-team erom vraagt?
- **Opties:** A) Nu inbouwen, hergebruik de bestaande instelling
  `repository_log_display_limit` (standaard 100) zodat er geen vijfde instelling
  bij komt: boven die grens toont de tab gewoon geen branches. B) Laten zoals
  het is en het antwoord klaarhouden in de note; het core-team kiest dan zelf
  het getal.
- **Aanbeveling:** A — het grootste bezwaar op #5386 sinds 2013 is precies dit,
  en het als opgelost aanleveren is overtuigender dan het als open vraag
  aanleveren; de kosten zijn een handvol regels en geen nieuwe instelling.
- **Haast?** nee — blokkeert het indienen niet, maar het is wel goedkoper vóór
  de note dan erna.

**Resolution:** answered 2026-09-05 by Jan's g12: option A, the cap goes in before submission, reusing `repository_log_display_limit` so no fifth setting appears. Implemented and evidenced under F02; the deliberate rule-break it bounds is written up as E-02 in `docs/exceptions.md`

---

## Checked and found fine — recorded so the gaps are visible

These are the dimensions I walked that produced no finding. Each was checked, not
assumed.

- **Escaping.** `link_to_revision_branches` uses `safe_join` over `link_to`; no
  `html_safe` anywhere in the patch. I stubbed `Changeset#branches` to return
  `["<script>alert(1)</script>", "a&b", "quo\"te"]` and rendered the real
  revision page: output is
  `<a href="…?rev=%3Cscript%3E…">&lt;script&gt;alert(1)&lt;/script&gt;</a>, <a href="…?rev=a%26b">a&amp;b</a>, …`
  — escaped in both text and href. The pre-existing
  `.collect{…}.join(", ").html_safe` for Parent/Child two lines above is
  correctly reported-not-fixed in the dossier (INV-1).
- **Command injection.** `git_cmd` shell-quotes every argument; the observed
  command is `'git' '--git-dir' '…' … 'branch' '--no-color' '--contains' '<sha>'`.
- **Authorization.** `lib/redmine/preparation.rb:140-141` confirms
  `repositories#show` is granted by **both** `:view_changesets` and
  `:browse_repository`, so the dossier's argument for adding no permission check
  is correct and adding a `:browse_repository` check would indeed be stricter
  than the branch selector on the target page. `Changeset.visible` gates both
  entry points.
- **N+1 in SQL.** `issue_tab` preloads `:repository`, so the whole loop shares one
  `Repository` and therefore one memoised adapter — I confirmed exactly one
  subprocess per changeset, not two.
- **The other five adapters.** `respond_to?(:branches_containing)` guard verified
  by `ChangesetTest#test_branches_should_be_empty_for_a_scm_without_branch_support`,
  which really does use a Subversion changeset (`Changeset.find(102)`), and no
  subprocess is attempted for one.
- **Defaults.** Both display settings default to `0` in `config/settings.yml` with
  no `format:` key, matching `commit_logs_formatting` and the rest of the file;
  measured zero subprocesses on the revision page and on the issue tab with the
  settings off. The default really is off.
- **Settings placement.** The four keys sit at the end of the repository group in
  `config/settings.yml` (after `commit_logtime_activity_id`, before the autologin
  block) and in the first `div.box.tabular.settings` of the Repositories tab, next
  to `autofetch_changesets`, `repository_log_display_limit` and
  `commit_logs_formatting`. The `setting_textarea` + `setting_check_box :label => false`
  + `em.info` shape is copied exactly from `settings/_mail_handler.html.erb`.
- **i18n.** Exactly `en, nl, fr, de, es` (INV-5), five keys each. Every source key
  the dossier's translation table cites exists in trunk with the value claimed:
  `label_branch` (Branch/Branch/Branche/Zweig/Rama), `label_associated_revisions`,
  `setting_display_subprojects_issues`, `setting_mail_handler_excluded_filenames`,
  `setting_mail_handler_enable_regex` (de "Reguläre Ausdrücke verwenden" and es
  "Habilitar expresiones regulares" are reused verbatim, which is right),
  `field_regexp` nl "Reguliere expressie", `text_regexp_info` and
  `text_comma_separated` in all five. The two "reported, not fixed" locale defects
  (missing accent in fr, untranslated nl) are real and correctly left alone.
- **Locale key ordering.** I checked whether inserting the setting keys after
  `setting_display_subprojects_issues` breaks a sort convention. It does not:
  `lib/tasks/locales.rake`'s `locales:update` **appends** new keys to the end of
  each file, and the files already carry 18 (de) to 46 (fr) `setting_` keys out of
  alphabetical order on trunk. No convention is being broken.
- **Adapter parsing.** `line[2..].to_s.strip` handles both the two-space and the
  `* ` prefixes; the `start_with?('(')` guard catches `(HEAD detached at …)` and is
  locale-robust because the parenthesis survives translation. No `-a`, so no
  `remotes/origin/HEAD -> …` lines to mis-parse.
- **Method naming.** `Changeset#branches` does not collide: `Changeset` has no such
  method or association on trunk, and `Repository#branches` (a different thing) is
  untouched. `branches_containing` matches the adapter's existing `branches`/`tags`
  naming; no `get_` prefix exists in the current codebase.
- **Comments.** One two-line comment on `Changeset#branches`, stating what the
  method returns and that the setting filters it — this is the documented style of
  its neighbours in `changeset.rb` and is a "why", not a restatement (INV-3).
- **AI traces.** None in the branch, the commit message, the authorship, or either
  `.patch` file (INV-4). Author is `Jan Catrysse <jan.catrysse@geoxyz.eu>`.
- **Test pollution.** No constants, no `minitest/autorun`, no rake loading, no
  global state left behind; the new `new_changeset` helper is a plain instance
  method inside the existing `if File.directory?(REPOSITORY_PATH)` block. All five
  touched files ran together in one process, twice, clean.
- **Patch hygiene.** Both `.patch` files apply to current trunk `bee32a926` with
  `git apply --check`, 100 commits after the r24882 they were made against.
