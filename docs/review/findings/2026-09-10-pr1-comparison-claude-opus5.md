# Review run — 2026-09-10 — pr1-comparison-claude-opus5

- **Reviewer:** Claude Code (Opus 5), round 4 **Deel B** of `docs/review/prompt-round4.md`
- **Reviewed:** ansifi's [PR #1](https://github.com/jcatrysse/redmine/pull/1) at head `5693540cd` (14 own commits from the fork `a7fe622f92`) against our nine `patch/<slug>` branches and `7.0-stable-GEOxyz` at `fd2365dc3`. Every comparison is **per feature against each side's own base**, never tip against tip.
- **Read first, deliberately:** the PR body, then ansifi's fourteen commits, then the 5.1 originals they port. `CLAUDE.md`'s forbidden-constructs table and `docs/DECISIONS.md`'s verdict on this PR were re-read **after** I had measured, because our rulebook is a document written partly about this PR by the side being scored.
- **Ran the test suite:** yes — the **full** `test:all` on ansifi's head and, separately, on the fork point `a7fe622f92`, so that a failure can be attributed rather than assumed; RuboCop 1.90.0 on ansifi's 48 changed Ruby/rake files and on the same files at the fork; `zeitwerk:check` on ansifi's head; four purpose-written probes against a database built from ansifi's own migrations; a probe that loads `lib/tasks/email_oauth.rake` and counts what it leaves on `Object`.
- **Scope covered:** all seventeen 5.1 GEOxyz commits, mapped to both sides; every one of ansifi's fourteen commits read as a diff against the fork; the six accusations our own documents make about this PR, each checked against `5693540cd`; the six-axis score.
- **Scope NOT covered:** no browser on either side — I did not re-run G9 for our features and could not run ansifi's UI at all; no live OAuth against a real provider (nobody can — it needs consent); ansifi's live Gmail verification is taken at face value from the PR body, because it is not reproducible here.

## Summary

**Counts (defects in *our* work; ansifi's are described, not filed):** blocker 0 · major 1 · minor 2 · nit 0 · question 0

**Both sides did the same job and ours is the better one, but not for the reason
our own documents give, and not on every axis.** The headline numbers are
**ansifi 248 of 420 available points (59%), us 343 of 405 (85%)**, and the gap is almost entirely in
two places: *Evidence* and *Correctness*. On *GEOxyz fitness* the two sides are
close, and on one feature ansifi is ahead of us outright.

What I could measure rather than assert:

- **ansifi's full suite is red: 5865 runs, 31066 assertions, 4 failures.** Two of
  those four are **existing Redmine tests broken by a one-line change** —
  `QueryTest#test_assigned_to_values_should_be_sorted_by_status_and_name` and
  `QueriesControllerTest#test_assignee_filter_should_return_active_and_locked_users_grouped_by_status`,
  both broken by adding `<< nobody >>` to `assigned_to_values`. We added the same
  line and repaired both tests. Redmine's own submission rule is that all
  existing tests pass, so this is not a stylistic difference.
- **Three defects I found by running the code, not by reading it.** ansifi's
  target-version filter silently drops versions shared from other projects (it
  offers 4 of project 1's 6 `shared_versions`); the assignee filter raises
  `PG::InvalidTextRepresentation` when "is not" is combined with `<< nobody >>`;
  and the wiki ZIP silently loses a page when two titles sanitise to the same
  name (10 pages in, 9 entries out, and a sequential reader stops at 7). Ours
  returns 6 of 6, 2 issues, and 10 of 10 on the same probes.
- **The `/queries/filter` 500 is on both sides.** ansifi's unguarded
  `q.build_from_params(params)` raises `NoMethodError: undefined method 'each'
  for an instance of String` for `?f=status_id&op[status_id]==`. Ours raised the
  same error until this morning; it is fixed as of `43246a900`, and that is
  round 4's own major finding, not something we knew before ansifi did.
- **The "73 lint offences" is exactly right.** RuboCop 1.90.0 on ansifi's 48
  changed Ruby/rake files: **81 offences, against a baseline of 8 on the same
  files at the fork — 73 added.** The accompanying claim that half are trailing
  whitespace and missing newlines is **not** right: 24 of the 73.
- **What ansifi has that we do not:** two operator guides in the repository
  (`doc/GMAIL_IMAP_OAUTH.md`, `doc/O365_IMAP_OAUTH.md`), a live Gmail OAuth fetch
  that created a real issue, and a whole-wiki TXT export. The first of those is a
  gap on our side that no amount of dossier quality closes, because the dossier
  is not on the branch GEOxyz deploys.

And one correction that matters, because it is load-bearing in our own rules:
**the `.html_safe`-on-SCM-input row of the forbidden-constructs table is true of
the GEOxyz 5.1 code and false of ansifi's port.** ansifi replaced
`links_to_branches.join(', ').force_encoding("UTF-8").html_safe` with
`safe_join`. The table says "the existing GEOxyz code **or** its 2026 port", so
it is defensible as written — but anyone reading it as a list of ansifi's sins
would be wrong about that row.

## The accusations our own documents make, checked one by one

Each row is checked against `5693540cd`, and against the 5.1 original where
provenance matters. "Inherited" means the same code is in the 5.1 commit ansifi
ported.

| Our claim | Verdict | Evidence |
|---|---|---|
| "~73 lint offences on a file set that had 0" | **true on the number, wrong on the baseline** | 81 offences on the 48 changed Ruby/rake files at `5693540cd`; 8 on the 38 of them that existed at the fork — so **73 added**, and the baseline was 8 rather than 0 (7 × `Rails/StrongParametersExpect`, 1 × `Style/DirectiveScope`, all upstream's own lines) |
| "half of them trailing whitespace and missing final newline" | **overstated** | 22 `Layout/TrailingWhitespace` + 2 `Layout/TrailingEmptyLines` = **24 of 73**, a third. The next two groups are 16 × `Style/RedundantRegexpEscape` and 16 × `Layout/IndentationConsistency` |
| "a link in the DOM, green under `assert_select`, dead when clicked because its JavaScript was never loaded on that page" | **true, and understated** | the handler for `a.scm-branch-group` is in `app/assets/javascripts/repository_navigation.js`, which is included from exactly one place, `app/views/repositories/_navigation.html.erb`, which is rendered by `show.html.erb` alone. The branch-group link renders on the **single revision page** and on the **issue page**, and neither loads it. `.scm-branch-group{display:none}` plus `.scm-branch-hide > .scm-branch-group{display:inline}` means the list stays hidden with no way to open it |
| "a top-level `def` in a `.rake` file, defining private methods on `Object`" | **true, measured** | loading `lib/tasks/email_oauth.rake` in a `rails runner` leaves **9 private methods on `Object`** (`secure_file`, `env_bool`, `normalize_token_file`, `mask_token`, `show_oauth_help`, `abort_usage`, `build_oauth_client`, `oauth_get_token`, `save_oauth_files`) and the constant **`PERMITTED`**; `Issue.new.respond_to?(:mask_token, true)` is `true` |
| "`.html_safe` on text from user, SCM or mail input" | **false of ansifi's port, true of the 5.1 original** | 5.1 `cf826e3fd` rendered `links_to_branches.join(', ').force_encoding("UTF-8").html_safe`; ansifi's `_changesets.html.erb` uses `safe_join(links_to_branches, ', '.html_safe)`, where the only `html_safe` is on the literal separator. **ansifi fixed this** |
| "`sub(...)` where every occurrence must go" | **true, and inherited** | `git_adapter.rb:99`, `cleaned_hash = hash.to_s.sub(/[^\w]/, '')` — strips only the first non-word character before the value goes to `git branch --contains`. 5.1 had `hash.sub(...)`; the port kept it. Low impact because `git_cmd` shell-quotes its arguments, but the sanitisation does not do what it says |
| "an instance variable assigned inside a view or partial" | **true, and inherited** | `app/views/issues/tabs/_changesets.html.erb` assigns `@repository` and `@rev` **inside the loop over changesets**, so after the tab renders they point at the last changeset. 5.1 did the same |
| "an SCM call per row inside a view loop" | **true, and unbounded** | the same partial calls `links_to_branches` per changeset → `@repository.scm.branch_contains(@rev)` → one `git branch --contains` subprocess per row, with no limit. Ours runs the same command per changeset but only while `@changesets.size <= Setting.repository_log_display_limit` (`display_changeset_branches?`) |
| "a test method that reimplements the code it tests" | **true, and it is most of one feature's evidence** | all four OAuth task test files define a `run_*_logic` method that re-writes the task body and then assert on the copy: `email_oauth_status_test.rb` (62 lines), `email_oauth_test.rb` (320), `google_oauth2_init_test.rb` (61), `o365_oauth2_init_test.rb` (141). **584 of the feature's ~630 test lines never invoke the shipped rake task** |
| "`require_relative` to a file under an autoload path breaks Zeitwerk" | **present, but the stated consequence does not follow here** | `lib/tasks/email_oauth.rake` has `require_relative '../redmine/email_oauth_helper'`, and `lib` is autoloaded (`config.autoload_lib(ignore: %w(tasks generators plugins))`). `bin/rails zeitwerk:check` on ansifi's head prints **"All is good!"**, because the file is correctly namespaced `Redmine::EmailOauthHelper` and matches its path. The line is redundant, not dangerous |
| "his commits carry the **nine inherited bugs**" (`docs/DECISIONS.md`, 2026-09-01) | **the nine are enumerated nowhere in our documents** | `grep` over `docs/` finds the phrase once, in the decision itself, and once as narrative in `docs/STATE.md`. There is no findings file from 2026-09-01. See "The nine, as far as I can reconstruct them" below |
| "two of ansifi's commits carry `Co-authored-by: Cursor`" (the round-4 prompt) | **three, not two** | `031bff8a1`, `d8f19ff00`, `f93620ba4`. Author and committer are `Ansif <ansif.pi@gmail.com>` on all fourteen, so the identity fields are clean; only the trailers would have to go before anything reached redmine.org |

#### The nine, as far as I can reconstruct them

Nobody wrote them down, so this is my list rather than a recovery of theirs.
Reading ansifi's head against the 5.1 commits it ports, these are the functional
defects I can name, with provenance:

| # | Defect | Inherited from 5.1? |
|---|---|---|
| 1 | `branch_contains` sanitises with `sub`, so only the first non-word character goes | yes, `cf826e3fd` |
| 2 | `@repository` / `@rev` assigned inside the changesets loop in a partial | yes, `cf826e3fd` |
| 3 | one `git branch --contains` per changeset row, unbounded | yes, `cf826e3fd` |
| 4 | the branch-group toggle has no JavaScript on either page that renders it | yes — 5.1 put the handler in `public/javascripts/repository_navigation.js`, with the same reach |
| 5 | assignee `<< nobody >>` with the "is not" operator raises `PG::InvalidTextRepresentation` | no — 5.1's `9b03b74b2` has the same `=`-only shape, so the defect travelled, but the 5.1 code is not identical |
| 6 | the target-version filter replaces `shared_versions` and loses versions shared from other projects | no — this is the port's own rewrite (`fixed_version_values` in `IssueQuery`) |
| 7 | `/queries/filter` 500s on a scalar `f` | no — the port's own, and **ours had it too until today** |
| 8 | the wiki ZIP loses a page when two titles sanitise alike | no — the port's own, introduced by replacing the `(n)` de-duplication with directories |
| 9 | two existing Redmine tests left failing | no — the port's own |

So **four of the nine are genuinely inherited and five are the port's own**, which
is the opposite of what `docs/STATE.md` says ("alle negen uit de originele
5.1-commits"). I cannot rule out that the original nine were a different nine;
what I can say is that the sentence is not supported by anything written down,
and that on my reading the inherited-versus-introduced split is roughly even.

## 1. The score, per feature

Axes: **C**orrectness, **U**pstream acceptability, **G**EOxyz fitness,
**E**vidence, **M**aintenance cost (5 = least), **H**ygiene. Anchors as in the
prompt. Every cell carries its reason; a cell I could not evidence is `n/e` and
counts for neither side.

For the five company-local features (`gitignore-credentials`, `geoxyz-hosts`,
`members-pagination`, `ldap-mail-prefs`, `ar-sessions`) **neither side proposes
anything upstream**, so *Upstream acceptability* is `n/e` on both sides rather
than a guess about a submission nobody will make. That is 10 of the `n/e` cells.

#### assignee-nobody — ansifi 16/30 · us 28/30

| Axis | ansifi `031bff8a1` | us `patch/assignee-nobody` |
|---|---|---|
| C | **2** — the happy path works, but `assigned_to_id` `!` + `none` raises `PG::InvalidTextRepresentation: invalid input syntax for type integer: "none"` (probe, reachable from the filter UI: "Assignee" → "is not" → "<< nobody >>") | **5** — same probe returns 2 issues; `=`, `!` and the history operators (`ev`/`!ev`/`cf`) all handled in `sql_for_field` |
| U | **2** — a committer reads the suite first, and this change leaves two existing tests red | **4** — clean, generic, all tests green; it does widen `sql_for_field` for every `list_optional` filter, which a reviewer may want narrower |
| G | **3** — works for the case GEOxyz uses, breaks on a neighbouring one | **5** — no known failing combination |
| E | **2** — 25 test lines, happy path only; and it broke `QueryTest#test_assigned_to_values_should_be_sorted_by_status_and_name` and `QueriesControllerTest#test_assignee_filter_should_return_active_and_locked_users_grouped_by_status` without repairing them | **5** — 155 test lines, both existing tests repaired by value rather than by position, full suite green |
| M | **4** — 11 production lines | **4** — 23 production lines in a core method |
| H | **3** — reuses the existing `label_nobody` key, no new locale needed (good); but the `include_none` local is computed in `statement` and consumed in an `elsif` three branches down | **5** — same key reuse, the logic sits in `sql_for_field` where the operators live |

#### version-subprojects — ansifi 14/30 · us 27/30

| Axis | ansifi `d8f19ff00` | us `patch/version-subprojects` |
|---|---|---|
| C | **1** — `fixed_version_values` **replaces** `project.shared_versions` with `Version.visible.where(project_statement)`, so versions shared from other projects vanish: for project 1 it offers `["1","2","3","4"]` where `shared_versions` is `["1","2","3","4","6","7"]` (probe). Plus the `/queries/filter` 500 below | **4** — same probe returns all 6; ours unions `shared_versions` with the project tree. Not 5: the `/queries/filter` 500 was ours too until `43246a900`, this morning |
| U | **2** — an unguarded `q.build_from_params(params)` on a public endpoint, and a values list that loses rows | **4** — guarded, and the union keeps existing behaviour a superset |
| G | **2** — GEOxyz uses cross-project shared versions; dropping them from the list is the failure users would notice | **5** |
| E | **3** — 65 test lines, and neither defect is covered | **5** — 169 test lines, including the scalar-`f` regression test added today |
| M | **4** — 19 lines | **4** — 21 lines |
| H | **2** — the JS serialises the **whole** filter form into a `GET` query string, `authenticity_token` included, which puts a CSRF token in URLs and logs | **5** — the JS sends only `f[]`, `op[`, `v[` parameters, with the reason in a comment |

#### search-token-limit — ansifi 20/30 · us 26/30

| Axis | ansifi `cd60c0b63` | us `patch/search-token-limit` |
|---|---|---|
| C | **3** — correct as built, but the **default is still 5**, so the reported problem (text filters silently dropping keywords after the fifth) persists until an admin changes a setting | **4** — filters are unlimited, the global search keeps its 5 where the cost is |
| U | **2** — a new setting for something upstream regards as a bug; `Setting` additions are the hardest thing to get accepted | **4** — framed as a bugfix with no new setting, which is why it is submittable |
| G | **5** — keeps the knob GEOxyz had in 5.1, `0` = unlimited | **4** — the knob is gone; GEOxyz gets the behaviour it presumably set the knob for, but cannot pick a finite higher limit |
| E | **3** — 14 test lines | **4** — 78 test lines across four files |
| M | **3** — a permanent private setting if upstream declines | **5** — nothing private left if accepted |
| H | **4** — one `en` key only, plus a second `text_..._info` key | **5** — five locales, existing keys matched |

#### mypage-query-blocks — ansifi 21/30 · us 27/30

| Axis | ansifi `256e7ff0d` | us `patch/mypage-query-blocks` |
|---|---|---|
| C | **4** — works; clamps to a floor of 1 but has **no ceiling**, so `my_page_max_issuequery_blocks = 1000` is accepted and every block runs its own query | **5** — `Setting` validation rejects anything above `MAX_ISSUEQUERY_BLOCKS = 20` |
| U | **3** — sound, but `blocks` rebuilds and re-`freeze`s a merged hash on every call | **4** — `:max_occurs => :my_page_max_issuequery_blocks` resolved in one new method |
| G | **4** | **5** |
| E | **4** — 66 test lines | **5** — 183 test lines including the settings form |
| M | **3** — new setting either way | **3** — new setting either way |
| H | **3** — one `en` key; trailing whitespace after the new `<p>` in `_general.html.erb` | **5** — five locales, no stray whitespace |

#### revision-branches — ansifi 12/30 · us 24/30

| Axis | ansifi `1e726250f + 1b8d5862c` | us `patch/revision-branches` |
|---|---|---|
| C | **1** — the group toggle is dead on both pages that render it (no JS there); `@repository`/`@rev` assigned in a loop inside a partial; `sub` where `gsub` is meant | **4** — no view state, `Changeset#branches` on the model, regex compiled with a `rescue`, `scm_iconv` on the name |
| U | **1** — a committer would reject ivar assignment in a view outright, before the dead JS | **4** — 141 production lines is a lot to ask, but every piece is in the layer it belongs to |
| G | **2** — the feature renders, and the "[name...]" groups cannot be opened | **4** — works, and branch display is skipped above `repository_log_display_limit` changesets rather than spawning N subprocesses |
| E | **3** — 160 test lines against the real Git fixture repository, which is the right way; they cannot catch the dead JS, and nothing bounds the subprocess count | **4** — 260 test lines, same fixture repository |
| M | **3** | **3** |
| H | **2** — 9 RuboCop offences in `repositories_helper.rb` alone (6 trailing whitespace), `scm.css` without a final newline, new `label_branches` where Redmine's convention is `label_X_plural` | **5** — `label_branch_plural`, five locales, 0 offences added |

#### wiki export (ZIP + attachments) — ansifi 13/30 · us 27/30

| Axis | ansifi `0832bb3d0` | us `patch/wiki-export-attachments` |
|---|---|---|
| C | **1** — measured data loss: a wiki with 10 pages including `Foo*` and `Foo"` produces **9 central-directory entries** (one page gone) and a sequential reader stops after **7**. The `(n)` de-duplication upstream had for pages was dropped and kept only for attachments | **5** — the same wiki produces **10 entries**, readable both ways, with `Foo_` and `Foo_(1)` |
| U | **2** — `IO.binread` (`Security/IoMethods`), `require 'set'` (redundant on Ruby 3.3), 7 × `Style/RedundantRegexpEscape`, and attachments added to an existing export with no opt-out | **4** — the helper lives in `lib/redmine/export/zip/`, `File.binread`, attachments behind a checkbox |
| G | **3** — nested folders and attachments, which is what GEOxyz asked for, minus one page per collision | **5** |
| E | **3** — 80 test lines, none covering the collision | **5** — 295 test lines, two of them added today for exactly this property |
| M | **2** — the TXT export is a permanent private patch (Jan dropped it, K-03) | **4** |
| H | **2** — 10 offences in `wiki_controller.rb` + 7 in its test | **4** — `Style/MapToSet` fixed today; five locales |

#### webhook — issue.closed — ansifi 20/30 · us 23/30

| Axis | ansifi (part of `798714bd7`) | us `patch/webhook-issue-closed` |
|---|---|---|
| C | **4** — triggers on the status transition, so it has **no timestamp window**; but `after_update_commit` means an issue **created** in a closed status never fires `issue.closed` | **4** — fires on create-closed too and tests it, but misses a re-closing whose `updated_on` equals the stored `closed_on` (round 4, F01; a second on a MySQL `datetime`, a microsecond on PostgreSQL) |
| U | **3** — keeps a second definition of "closing" in step with core, and pays one `IssueStatus.find_by` per issue update | **4** — reads core's own answer (`closed_on`), no extra query; the window is now stated in the dossier rather than hidden |
| G | **4** | **4** |
| E | **3** — part of 89 shared test lines; `webhook_payload_test` covers the payload | **5** — 118 test lines, eight transitions enumerated and seven tested |
| M | **4** | **4** |
| H | **2** — `setable_events` gained a bare `[Issue, News, TimeEntry, Version, WikiPage]` statement whose value is discarded, as a dev-mode autoload workaround unrelated to the feature | **2** — same migration shape as ansifi (see below); nothing else |

#### webhook — tracker filter — ansifi 22/30 · us 26/30

| Axis | ansifi (part of `798714bd7`) | us `patch/webhook-tracker-filter` |
|---|---|---|
| C | **4** — `tracker_allowed?` is equivalent to ours; empty list = all trackers | **5** — equivalent, plus `tracker_ids=` drops unknown ids instead of trusting the form |
| U | **4** | **4** |
| G | **4** | **5** — Dutch, French, German and Spanish labels for the new fieldset |
| E | **4** — 89 test lines incl. the controller | **5** — 93 test lines plus the GEOxyz-only test covering the combination with `issue.closed` |
| M | **3** — new migration either way | **3** — new migration either way |
| H | **3** — one `en` key; `before_validation` intersect with `setable_trackers` mirrors upstream's project handling, which is right | **4** — five locales; `preload(:trackers)` avoids an N+1 in `hooks_for` |

Both sides wrote **the same migration**, `create_table :trackers_webhooks` with an
implicit `id` column. I checked whether that is wrong for a `has_and_belongs_to_many`
table and it is not a defect on either side: upstream's own `projects_webhooks`
(`20251007073256_create_webhooks.rb`) has exactly that shape, and both sides
copied it.

#### imap-oauth — ansifi 17/30 · us 25/30

| Axis | ansifi `5693540cd` | us `patch/imap-oauth` |
|---|---|---|
| C | **3** — the IMAP side is small and right (`auth_type`, `imap.authenticate`); the authorization flow has **no `state` parameter**, and the `gmail_xoauth` fallback is dead code: `Net::IMAP::XOauth2Authenticator` is defined by net-imap 0.6.7, so the guard never fires and the gem (plus its `oauth` 1.1.8 dependency) is never loaded | **4** — `state` generated and compared with `secure_compare`; no second gem. No PKCE on either side (ours argues that in the submission, K-23) |
| U | **1** — a separate `receive_imap_oauth2` task, provider-specific rake tasks, vendor documents in `doc/`, two new gems, 9 methods and a constant on `Object` | **4** — two options on the existing `receive_imap`, one generic authorization task, provider specifics in an operator-owned YAML file |
| G | **4** — token files on disk with `chmod 0600`, per-provider init tasks, **and two operator guides in the repository** | **4** — one generic task and a hand-written YAML; the walkthrough exists only in a dossier on `geoxyz/framework`, which the deploy never sees |
| E | **2** — ~630 test lines of which **584 are in files that re-implement the task body** and never invoke it; the two `imap_test` cases are real but assert a mocked `authenticate` call, so they would pass with a wrong mechanism name. Against that: **a live Gmail OAuth fetch that created a real issue**, which is evidence neither of us can produce twice | **4** — 478 test lines against the shipped code, including a test that asks net-imap itself whether `XOAUTH2` exists and what it emits; **no live run, and none is possible here** |
| M | **4** — `lib/redmine/imap.rb` touched in 8 lines | **4** — 20 lines, plus a new `lib/redmine/oauth2_client.rb` |
| H | **3** — `Style/ClassEqualityComparison`, `Rails/Output` ×2, `Rails/Blank` ×2, `require_relative` into an autoloaded path, top-level defs; the documents themselves are well written | **5** — 0 offences added |

#### gitignore-credentials — ansifi 18/25 · us 23/25 *(U = n/e both)*

| Axis | ansifi `9d0d8e937` | us `af0af806d + 737b0a549` |
|---|---|---|
| C | **4** — ignores `master.key`, `credentials.yml.enc` and `email_oauth2*.yml` | **5** — `master.key`, `credentials.yml.enc` and the per-environment `config/credentials/` directory |
| U | n/e | n/e |
| G | **4** | **5** — also covers `config/credentials/*.key`, which is what Rails 7+ actually generates |
| E | **2** — none, and none is easy: `git check-ignore` is the test | **4** — `git check-ignore` run and recorded |
| M | **5** | **5** |
| H | **3** — appended at the end of the file, and drops the final newline | **4** — inserted alphabetically in the existing `/config/` block |

#### geoxyz-hosts — ansifi 20/25 · us 23/25 *(U = n/e both)*

| Axis | ansifi `f93620ba4` | us `075c86e8a + 363686456` |
|---|---|---|
| C | **4** — `config.hosts << /.*\.geoxyz\.eu/` works. I checked the obvious worry and it is **not** a hole: `ActionDispatch::HostAuthorization` wraps a Regexp as `/\A#{host}#{PORT_REGEX}?\z/`, so it is anchored. It is case-**sensitive** though, and a `Host:` header is not | **5** — `/[a-z0-9-]+(?:\.[a-z0-9-]+)*\.geoxyz\.eu/i`; our first version was byte-identical to ansifi's and we fixed the case problem on 2026-09-06 |
| U | n/e | n/e |
| G | **4** — `redmine.GEOXYZ.eu` is refused | **5** |
| E | **3** — none | **3** — none either; both are one line of development configuration |
| M | **5** | **5** |
| H | **4** | **5** — the reason is in the commit message, which is where the next reader looks |

#### members-pagination — ansifi 19/25 · us 22/25 *(U = n/e both)*

| Axis | ansifi `b1a9fbb6e` | us (4 commits) |
|---|---|---|
| C | **4** — same design as ours (both follow Takenori's trunk approach for #43355): ordered ids, `.uniq`, one page loaded. No high-end clamp, so deleting the last row of the last page leaves an empty page — which is what unpatched Redmine does everywhere (Jan's g15) | **5** — `22a4244c0` adds the clamp |
| U | n/e — **neither side submits this**; the upstream work is Takenori TAKAKI's on [#43355](https://www.redmine.org/issues/43355) | n/e |
| G | **4** | **5** |
| E | **4** — 154 test lines | **4** — 205 test lines |
| M | **4** | **4** — both stay private until #43355 lands |
| H | **3** — `Layout/EmptyLinesAroundModuleBody` in `members_helper.rb`; 11 trailing-whitespace offences in `my_controller_test.rb` | **4** |

#### ldap-mail-prefs — ansifi 13/25 · us 21/25 *(U = n/e both)*

| Axis | ansifi `2f5d58d2f` | us (5 commits) |
|---|---|---|
| C | **3** — does what it says, but it is the **5.1 selection**: members of the holding group only. Jan's corrected goal (g01) is every LDAP-sourced account, `auth_source_id IS NOT NULL`. It also writes immediately, with no dry run and nothing to undo | **5** — the corrected selection, dry run by default, previous values journalled, an undo |
| U | n/e | n/e |
| G | **3** — selects the wrong set for what the task is for | **5** |
| E | **1** — **no tests at all** | **5** — 360 test lines |
| M | **4** — 44 lines | **3** — 425 lines is a large private surface for an ops task |
| H | **2** — a `.rake` with `puts` reporting and no `--dry-run`; no locale, which is fine for an ops task | **3** — large, but namespaced under `lib/redmine/` with no top-level `def` |

#### ar-sessions — ansifi 12/25 · us 21/25 *(U = n/e both)*

| Axis | ansifi `70cd8113f` | us (5 commits) |
|---|---|---|
| C | **2** — works, and **leaves the serializer at the gem default, which is Marshal**. `sessions.data` is then unmarshalled on every request before anything verifies it; the cookie store it replaces is signed. Nothing in the PR body or the commit mentions the choice | **4** — JSON via `Redmine::SessionDataSerializer`, at the cost of one forced logout at cutover |
| U | n/e | n/e |
| G | **3** — sessions survive a restart, which is the point; the store is weaker than the one removed | **5** — plus `redmine:sessions:check`, which refuses to start on a missing table rather than 500-ing every page |
| E | **1** — **no tests at all** | **5** — 357 test lines |
| M | **4** — 18 lines + a migration | **3** — 262 lines + a migration + a gem |
| H | **2** — migration without a final newline, `return if table_exists?` inside `change` | **4** |

#### whole-wiki TXT export — ansifi 11/25 · us 0/10 (absent)

Jan dropped this (K-03) and that decision is not being reopened. Scoring only
what exists, so that the starting point is known if GEOxyz ever wants it back.

| Axis | ansifi (part of `0832bb3d0`) | us |
|---|---|---|
| C | **4** — depth-first order matching the wiki index, `page.content&.text.to_s` so a page with no content does not raise; the TXT branch returns before `respond_to`, mirroring the single-page export | **0** — absent |
| U | **2** — a new export format is a real upstream conversation and this one arrives inside another change | n/e — nothing proposed |
| G | **0** — absent | **0** — absent by decision |
| E | **3** — a routing test and controller coverage | n/e |
| M | **2** — permanent private patch | n/e |
| H | **n/e** — the 5-line view is clean; the offences in `wiki_controller.rb` are already counted under the ZIP feature, and counting them twice would be double-charging | n/e |

## 2. Per-axis totals — where each side is actually stronger

This is the part worth acting on: it says *where* one side is ahead, not just
that it is. The denominators differ because `n/e` cells are removed from the
side that has them.

| Axis | ansifi | us | reading |
|---|---|---|---|
| **Correctness** | 44 / 75 (59%) | 64 / 75 (85%) | three measured defects on ansifi's side, one of ours (the `/queries/filter` 500, fixed today) |
| **Upstream acceptability** | 22 / 50 (44%) | 36 / 45 (80%) | the widest gap, and expected: ansifi was porting to a company branch, not proposing to trunk. Scoring it is still fair, because it is the axis the whole exercise exists for |
| **GEOxyz fitness** | 49 / 75 (65%) | 66 / 75 (88%) | **the narrowest gap of the four substantive axes.** Most of ours comes from locales and from failure-path handling, not from doing more |
| **Evidence** | 41 / 75 (55%) | 63 / 70 (90%) | ansifi's own suite is red, two features have no tests at all, and the largest test file group tests a re-implementation. Against that, ansifi has the one thing we do not: a live OAuth fetch |
| **Maintenance cost** | 54 / 75 (72%) | 54 / 70 (77%) | **effectively a draw.** Ours is bigger code for the same features; ansifi's private surface is bigger because less of it is heading upstream |
| **Hygiene** | 38 / 70 (54%) | 60 / 70 (86%) | 73 added lint offences, one-locale i18n, `Object` pollution |
| **Total** | **248 / 420 (59%)** | **343 / 405 (85%)** | |

**15 of the 180 cells are `n/e`** (8%): ten because neither side proposes the
five company-local features upstream, and five on the TXT export, which only one
side has.

## 3. The headline, with the caveat that matters

**ansifi 59%, us 85%.**

**The six axes are not equally important to Jan, and the per-axis table above is
what to reweigh.** If the weight is "what does GEOxyz run in production", the two
sides are 65% against 88% and much of our margin is Dutch, French, German and
Spanish labels plus behaviour on paths nobody hits daily. If the weight is "what
can be submitted to redmine.org", it is 44% against 80% and the comparison is
barely meaningful, because ansifi never set out to submit anything — the PR body
says "forward-port selected GEOxyz customisations", and it is a draft whose last
unchecked box is "Full branch review before marking Ready for merge". Judged
against *that* goal, ansifi's work is considerably better than 59% suggests.

## 4. What we forgot

Most important first.

1. **There is no operator documentation on the branch GEOxyz deploys.** ansifi
   ships `doc/GMAIL_IMAP_OAUTH.md` and `doc/O365_IMAP_OAUTH.md` — 92 lines that
   walk an administrator from the Google Cloud console to a working
   `receive_imap_oauth2` cron line. Our equivalent is in
   `docs/features/imap-oauth/dossier.md`, on `geoxyz/framework`, an orphan branch
   that is not checked out anywhere near a production Redmine. Whoever sets this
   up at GEOxyz has, on our side, a rake task's `--describe` text and nothing
   else. This is finding **F01**.
2. **Nobody has driven our IMAP OAuth against a real mailbox.** ansifi has:
   "Live test: Gmail OAuth fetch from clean inbox created issue #7 in
   `geoxyz-learn`." Our dossier is explicit that the consent flow cannot be
   tested, which is true, but the *result* of a real consent can be: one run
   against a real mailbox, once, with the output pasted in. Finding **F02**.
3. **We never enumerated the nine inherited bugs**, and the claim has been
   load-bearing in `docs/DECISIONS.md` and `docs/STATE.md` since 2026-09-01. On
   my reconstruction the split is about four inherited to five introduced, not
   "alle negen uit de originele 5.1-commits". Finding **F03**.
4. **The `/queries/filter` 500 was ours too, for five weeks.** Both
   implementations called `build_from_params` on unvalidated request parameters;
   ours was found this morning, in round 4, by a reviewer rather than by a test.
   It is fixed, and the lesson is the one already in the traps file: a new
   controller entry point needs a probe with hostile parameters before it is
   called done. No new finding — round 4 `version-subprojects` F01 covers it.
5. **A knob GEOxyz had is gone.** `search_token_limit` existed on 5.1 and we
   removed it (K-04, Jan's own choice). Our replacement makes text filters
   unlimited, which is almost certainly what the knob was set to — but if anyone
   at GEOxyz ever wanted a *finite, higher* limit, that is now unavailable. Worth
   one question to the person who set it, not a change.

## 5. Where ansifi is better

Required to be non-empty or to say what I checked. It is non-empty.

1. **`issue.closed` has no timestamp window.** ansifi triggers on the status
   transition (`saved_change_to_status_id?` plus a previous-status lookup), so
   close → reopen → re-close inside the same clock tick fires twice. Ours keys on
   `saved_change_to_closed_on?` and misses the second closing when the new
   timestamp equals the stored one — round 4's own `webhook-issue-closed` F01,
   which we resolved by documenting the window rather than closing it. **On this
   one point ansifi's design is simply better than ours**, at the cost of one
   extra query per issue update. Their version has the mirror-image gap (an issue
   created directly in a closed status never fires), which ours covers.
2. **Operator documentation in the repository.** See F01. This is not a small
   thing: it is the difference between a feature that can be deployed by someone
   who was not in the conversation and one that cannot.
3. **A live, end-to-end OAuth verification.** The one kind of evidence that
   cannot be manufactured, and they have it and we do not.
4. **`.html_safe` was fixed, not carried.** Where 5.1 wrote
   `links_to_branches.join(', ').force_encoding("UTF-8").html_safe`, the port
   uses `safe_join`. Our own rulebook lists that construct in a table introduced
   as defects found "in the existing GEOxyz code or its 2026 port"; on this row
   the port is the side that got it right.
5. **Minimality in two places where the 5.1 commit was not minimal.** 5.1's
   `cf826e3fd` reindented the whole surrounding block of
   `_changesets.html.erb` while adding four lines; ansifi's port adds the lines
   and leaves the indentation alone. That is INV-1 behaviour, arrived at without
   an INV-1.
6. **Reusing `label_nobody`.** Both sides use the existing key rather than
   inventing one — worth saying because it is the discipline INV-5 is about, and
   ansifi did it without the rule.

**What I checked and did *not* find in ansifi's favour:** a feature of the 5.1
branch that our register misses (all 17 own commits of `5.1-stable-GEOxyz` map to
register rows); a place where their reading of 7.0 beats ours on a filter, a
webhook or an export; a test of theirs that catches something ours does not; a
lint offence of ours that they avoided (they add 73, we add 0 on the same
measurement); and a locale of theirs that is better derived than ours (their
German `Zweige` is correctly patterned on Redmine's own `label_branch: Zweig`,
but it is three locales against our five).

---

### F01 — the IMAP OAuth walkthrough exists only on a branch production never sees

- **Status:** open
- **Severity:** major
- **Confidence:** confirmed
- **Category:** operability
- **Where:** `docs/features/imap-oauth/dossier.md`; nothing on `7.0-stable-GEOxyz`
- **Invariant touched:** none — but it is the gap between "the feature works" and "the feature can be deployed"

**What is wrong**

Our IMAP OAuth design deliberately keeps every provider specific out of Redmine
and in an operator-owned YAML file. That is the right call for upstream and it is
why `patch/imap-oauth` is submittable. The consequence is that **the knowledge of
what goes in that file lives entirely in our documentation**, and our
documentation is on `geoxyz/framework`, an orphan branch with no Redmine code,
which nobody checks out on a server.

ansifi solved the same problem by shipping `doc/GMAIL_IMAP_OAUTH.md` and
`doc/O365_IMAP_OAUTH.md` on the branch itself: 92 lines that take an
administrator from creating an OAuth client through the scope, the init task, the
receive task and revoking consent.

A GEOxyz administrator setting this up from our branch has the `--describe` text
of two rake tasks. That text names the YAML keys but not where to get the values
for Google or for Microsoft, which is the part that actually costs an afternoon.

**Why a committer would push back**

They would not, and that is the point: this belongs on the **GEOxyz** side, not
in the patch. Redmine's convention is that provider walkthroughs live on the wiki
(`EmailConfiguration`), which is exactly what our rake description already points
at — so the upstream half is already right. The gap is ours alone.

**How I verified it**

`git show origin/7.0-stable-GEOxyz --stat` over the five `imap-oauth` commits:
no file under `doc/`. `wc -l doc/GMAIL_IMAP_OAUTH.md doc/O365_IMAP_OAUTH.md` on
ansifi's head: 49 and 43.

**Suggested direction**

One file on `7.0-stable-GEOxyz` only — `doc/imap_oauth2.md` or a section in the
existing GEOxyz ops notes — holding the two provider walkthroughs and a filled-in
example of the credentials YAML. It must **not** go into `patch/imap-oauth`
(INV-1, and upstream keeps this on the wiki), so it is a deliberate, recorded
divergence: one line in `docs/features/imap-oauth/symmetry-allow.txt` with the
reason, exactly like the GEOxyz-only webhook test. Alternatively, write it as a
draft of the redmine.org wiki page and link it from the dossier — but then it
still has to reach the branch, or this finding stands.

---

### F02 — nobody has run our IMAP OAuth against a real mailbox

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** evidence
- **Where:** `docs/features/imap-oauth/status.md`, the verification section
- **Invariant touched:** G9 in spirit; INV-8 is satisfied as written

**What is wrong**

Our dossier is right that the consent flow cannot be a test: it needs a human, a
browser and real credentials. What it does not say is that the *rest* can be
verified once by hand — obtain a refresh token for one real mailbox, run
`receive_imap` with `oauth2_credentials=`, and show that a message became an
issue. ansifi did exactly that and recorded it in one line of the PR body.

Our evidence for the feature is 478 test lines, all of them against a mocked
IMAP. The round-4 addition (asking `Net::IMAP::SASL` itself what `XOAUTH2`
produces) closes the biggest gap in that mocking, but the end-to-end path —
credentials file → token endpoint → XOAUTH2 → `select` → `uid_fetch` →
`MailHandler` — has never run.

**Why a committer would push back**

They will ask "has anyone actually received mail with this?", because that is the
first question about any inbound-mail change, and the honest answer today is no.

**How I verified it**

`docs/features/imap-oauth/status.md` and the dossier's verification table: every
row is a unit test or a screenshot of a settings page. No row records a live
fetch.

**Suggested direction**

This one needs Jan, not a session: it requires a real mailbox and a real consent.
One run, the output pasted into `status.md`, and the dossier gains the sentence
that most changes the reception of an inbound-mail patch. Until then, say in the
dossier that it has not been done — an unstated absence reads as an oversight,
a stated one reads as scope.

---

### F03 — "the nine inherited bugs" is a claim our documents make and never support

- **Status:** open
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** documentation
- **Where:** `docs/DECISIONS.md` (2026-09-01 row); `docs/STATE.md`, "Voorgeschiedenis, kort"
- **Invariant touched:** none

**What is wrong**

Two of our documents state that ansifi's commits carry nine inherited functional
bugs, and `docs/STATE.md` adds that **all nine** came from the original 5.1
commits. Neither enumerates them, and there is no findings file from the
2026-09-01 review that produced them — the earliest is 2026-09-03.

The decision that rests on the claim (start fresh rather than build on PR #1) is
Jan's, is settled, and is not reopened by this: the features had to be redesigned
for upstream regardless, so the restart cost nothing either way. But an unsourced
number in the file that records decisions is the kind of thing a later session
quotes as if it were measured.

My own reconstruction (the table above) finds roughly four inherited defects and
five introduced by the port — so the "all nine from 5.1" half of the sentence is
the part that looks wrong.

**Why a committer would push back**

Not applicable; this never leaves the framework branch. The reason it matters is
internal: the same document tells future sessions not to re-litigate decisions,
which is right, and that protection works only if the reasons attached to them
are checkable.

**How I verified it**

`grep -rn "negen geërfde\|nine inherited" docs/` → two hits, both the claim
itself. `ls docs/review/findings/` → nothing before 2026-09-03.

**Suggested direction**

Append one block to `docs/DECISIONS.md` (via `tools/append-note.sh`) that keeps
the decision exactly as it stands and replaces the *evidence* sentence with
either the enumerated list from this review or an honest "the nine were never
written down; this review found four inherited and five introduced". Do not
change the decision row's outcome — only what it cites.

---

## Evidence I measured, with the commands

| Claim | What I ran | Result |
|---|---|---|
| ansifi's suite | `tools/test-env.sh /home/user/wt/pr1 bundle exec ruby bin/rails test:all`, on a database built from ansifi's own migrations | **5865 runs, 31066 assertions, 4 failures, 0 errors, 41 skips** |
| the fork's suite, for attribution | the same on a worktree at `a7fe622f92` | **5808 runs, 30824 assertions, 3 failures, 0 errors, 39 skips** — all three in `MailerTest` |
| which of ansifi's failures are theirs | comparing the two failure lists | `MailerTest` is unstable in this image at this revision (three failures at the base, a different single one on ansifi's head, none touching a changed file) — **not attributable to either side**. The other three are: `QueryTest#test_assigned_to_values_should_be_sorted_by_status_and_name` and `QueriesControllerTest#test_assignee_filter_should_return_active_and_locked_users_grouped_by_status`, both **existing tests broken by the `<< nobody >>` line**, and `EmailOauthTokenRefreshTest#test_logs_expiration_times_on_refresh`, **ansifi's own new test** |
| our suite, for comparison | `tools/test-env.sh /home/user/wt/geoxyz …` earlier today | **6169 runs, 32534 assertions, 0 failures, 0 errors, 39 skips** |
| ansifi's lint | `rubocop --cache false --force-exclusion` (1.90.0, with a `Gemfile.lock` present so the version-gated `Rails/*` cops fire) on the 48 changed `.rb`/`.rake` files | **81 offences**; the same files at the fork: **8** → **73 added** |
| our lint | `tools/check-geoxyz-branch.sh` | **8 on the branch, 8 on `origin/7.0-stable`, 0 added** |
| the `Object` pollution | `rails runner` that `load`s `lib/tasks/email_oauth.rake` and inspects `Object` | **9 private methods + the constant `PERMITTED`**; `Issue.new.respond_to?(:mask_token, true)` → `true` |
| whether `require_relative` breaks Zeitwerk here | `bin/rails zeitwerk:check` on ansifi's head | **"All is good!"** — the claim in our table does not hold for this file |
| `/queries/filter` with a scalar `f` | `get :filter, params: {..., f: 'status_id', op: {'status_id' => '='}}` | ansifi: **`NoMethodError: undefined method 'each' for an instance of String`**. Ours: **HTTP 200** (fixed today in `43246a900`) |
| assignee `<< nobody >>` with "is not" | `IssueQuery` with `add_filter('assigned_to_id', '!', ['none'])` | ansifi: **`PG::InvalidTextRepresentation: invalid input syntax for type integer: "none"`**. Ours: **OK, 2 issues** |
| the target-version list for project 1 | `available_filters['fixed_version_id'][:values]` against `project.shared_versions` | ansifi: offers `["1","2","3","4"]`, **misses `["6","7"]`**. Ours: offers all six, misses none |
| the wiki ZIP with two titles that sanitise alike | `wiki_pages_to_zip` on a 10-page wiki containing `Foo*` and `Foo"`, read back through both `Zip::File` (central directory) and `Zip::InputStream` (sequential) | ansifi: **9 central-directory entries, 7 sequential** — one page lost, and the stream truncated. Ours: **10 and 10**, `Foo_/Foo_.txt` and `Foo_(1)/Foo_(1).txt` |
| `Net::IMAP::XOauth2Authenticator` exists, so `gmail_xoauth` is dead weight | `ruby -e` against net-imap 0.6.7 | constant defined, `.class == Class` → ansifi's guard **always skips the require** |
| the host regexp is anchored | reading `ActionDispatch::HostAuthorization::Permissions#sanitize_regexp` in actionpack 8.1.3.1 | `/\A#{host}#{PORT_REGEX}?\z/` — **anchored**, so neither side has a host-matching hole; only case sensitivity differs |
| the HABTM migration shape | `db/migrate/20251007073256_create_webhooks.rb` on both branches | upstream's own `projects_webhooks` has the same implicit `id`; **not a defect on either side** |
| the register is complete against 5.1 | `git log origin/5.1-stable..origin/5.1-stable-GEOxyz --no-merges` | **17 commits, all 17 map to rows in `docs/REGISTER.md`** |
| AI trailers | `git log a7fe622f92..5693540cd` | **3 of 14** commits carry `Co-authored-by: Cursor`; author and committer are human on all fourteen |

## Where I disagree with the previous rounds

Read after writing everything above.

**Our rulebook is fair about ansifi's work in aggregate and wrong in two
particulars, and the particulars are the ones a reader remembers.** The
forbidden-constructs table is introduced as "every row below is a real defect
found in the existing GEOxyz code **or** its 2026 port", which is accurate — but
of the six rows I could trace, one (`.html_safe`) is true only of the 5.1 code
that ansifi **fixed**, and one (`require_relative` breaking Zeitwerk) does not
produce the stated consequence in the only instance we have. Both rows earn
their place as rules. Neither should be cited as something this PR did.

**"73 lint offences" is the single most accurate number in our documents about
this PR**, and I want that on the record next to the two corrections: measured
independently five weeks later with a different RuboCop, the answer is 73 added,
to the unit. The "half of them whitespace" gloss is the part that drifted.

**The decision to start fresh was right for a reason our documents do not give.**
They give lint and inherited bugs. The stronger reason is visible in the score:
ansifi scores 44% on upstream acceptability and 65% on GEOxyz fitness — that is
the shape of a competent port to a private branch, which is what it was asked to
be. Building nine upstream submissions on top of it would have meant undoing
`receive_imap_oauth2`, the `search_token_limit` setting, the token files, the
provider-specific tasks and the `Object` pollution first. Not because they are
bad, but because they are answers to a different question.

**One thing the previous rounds never checked, and it cost us:** our own
`/queries/filter` entry point had the same 500 as ansifi's, and it survived
round 1, round 2, round 3 and three Codex rounds. It took until round 4 —
and reading the *other* side's code makes it obvious why it survived: both
implementations were derived from the same 5.1 change, and every review since has
read them one at a time.
