# Review run — 2026-09-08 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** `patch/assignee-nobody` at `d0243086d` against `origin/master`
  `bee32a926` (r25037). **0 commits behind trunk**, one commit ahead, author and
  committer both Jan Catrysse.
- **Dossier read:** `docs/features/assignee-nobody/dossier.md` — yes
- **Status read:** `docs/features/assignee-nobody/status.md` — yes
- **Round-1 findings read:** **no, deliberately.**
  `docs/review/findings/2026-09-03-assignee-nobody-claude-opus5.md` was not
  opened. `docs/REGISTER.md` names Jan's g06 in one line, so I knew a major
  finding about parenthesising the folded condition existed and was fixed.
- **Ran the test suite:** yes, both sides, fresh worktrees, own PostgreSQL 16
  databases, Git fixtures extracted, **the same `Gemfile.lock` on both sides**,
  and the four runs serialised rather than concurrent. See **Suite**.
- **Scope covered:** minimality, the SQL the fold produces for every operator
  that reaches it, self-containment against all 31 `sql_for_field` call sites,
  backward compatibility of the value list and of existing saved queries, the
  journal-history operators and what `journal_details.old_value` actually holds
  for an unassigned issue, i18n, the tests as code, INV-10 against
  `7.0-stable-GEOxyz`, lint, and patch hygiene.
- **Scope NOT covered:**
  - **No browser.** The G9 screenshots were read, not reproduced.
  - **MySQL and SQLite.** PostgreSQL 16 only. The fold adds `IS NULL` and
    `IS NOT NULL`, which are portable, but I did not run the other two.
  - **No mutation run.** The dossier's per-test red-on-old-code table was read,
    not re-executed; what I did re-execute is the full suite on both sides.

## Summary

I could not find anything to report, and the dossier is the reason it took a
while to be sure: every objection I formed while reading the diff was already
in its table, with an answer better than the one I had. That includes the two I
expected to be gaps — "`sql_for_field` has 31 callers, did you check them?" and
"only the assignee filter is tested, and the change touches seven filters".

The design is tighter than it first looks. `match_null` is gated on three
things at once — not a custom filter, the value list contains `none`, and the
filter's type is `list_optional` or `list_optional_with_history` — and there is
a test for each of the two negative gates. Because the fold happens inside
`sql_for_field`, the mechanism reaches every optional list filter, while only
`assigned_to_values` grows a `<< nobody >>` entry; the dossier states plainly
that this is deliberate and #5535's scope, which is the right answer to give
before a committer asks.

The one thing I verified from first principles rather than from the dossier is
the history operators, because that is where a NULL-versus-empty-string mistake
would hide. `Journal#add_detail` passes `old_value` straight through, so an
issue that was unassigned really does store SQL NULL in
`journal_details.old_value`, and `old_value IS NULL` is the correct match. The
`!ev` case also holds up: `neg` wraps the whole parenthesised group, so
"has never been nobody" is `NOT (EXISTS(…) OR assigned_to_id IS NULL)`, not the
broken `NOT EXISTS(…) OR …` I went looking for.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0. Four files, 178
insertions, 7 deletions, and 152 of those insertions are tests. **No locale file
is touched at all** — `label_nobody: nobody` already exists in `en.yml` at line
792, which is why the patch has no locales half.

## Suite

`/home/user/wt/r3-assignee-nobody` (patch tip `d0243086d`) and
`/home/user/wt/r3-trunk` (pristine r25037), separate databases, same
`Gemfile.lock`, PostgreSQL 16, Ruby 3.3.6.

| What | Result |
|---|---|
| `test:all` with the patch | `5990 runs, 31377 assertions, 48 failures, 82 errors, 92 skips` |
| `test:all` on pristine trunk, same lock | `5977 runs, 31358 assertions, 48 failures, 82 errors, 92 skips` |
| delta | **13 runs**, and **zero extra failures and zero extra errors** |
| failing names | **87 on each side, identical** — `comm` empty in both directions |
| RuboCop 1.90.0 on the 4 changed files | `no offenses detected`; baseline on the same 4 at the merge base: `no offenses detected` |
| `tools/check-patch-clean.sh assignee-nobody --submit` | PASS — 4 files, no locale touched, no AI trace, applies to a pristine r25037 checkout, branch and file agree |

The 13 extra runs are the 11 new tests in `query_test.rb` plus the 2 in
`user_query_test.rb`; the change to `queries_controller_test.rb` edits an
existing test and so adds no run.

**Why the totals are 48/82 rather than the dossier's figures.** A fresh
`bundle install` now resolves **json 3.0.1**, which breaks
`ActiveSupport::JSON.decode` and with it about a hundred core tests. Measured on
pristine trunk, not assumed, so it affects both sides equally and the comparison
holds. `Gemfile.lock` is gitignored, so the trunk worktree's lock was copied to
all three patch worktrees before bundling. See `docs/traps.md`.

**Hypotheses driven and cleared:**

| Hypothesis | Outcome |
|---|---|
| the folded condition is spliced into an `AND` somewhere and loses its correlation | clean — this is Jan's g06 fix and it is done: both the `=` and `!` branches now return `(… IS NULL OR (…))` / `(… IS NOT NULL AND (…))`. The one core call site that splices without parenthesising is `UserQuery#sql_for_is_member_of_group_field`, and the two new `user_query_test` cases pin exactly that: `is_member_of_group = ['none','10']` returns `[8]`, not everyone |
| `value -= ['none']` mutates the caller's array | clean — `-=` rebinds a new array; the parameter is local |
| selecting only `none` produces broken SQL | clean — `value` is then empty, the `=` branch falls to `1=0`, and the fold wraps it as `(x IS NULL OR (1=0))`, which is exactly "nobody". The `!` branch is `(x IS NOT NULL AND (1=1))`. Two tests assert these equal the `!*` and `*` operators |
| the fold leaks into custom fields or plain `:list` filters | clean, and both gates have a test — `test_filter_nobody_should_not_apply_to_list_filters` and `test_filter_nobody_should_not_apply_to_list_custom_fields` |
| `sql_for_in_or_null` can return `nil` and blow up the string concatenation | clean — it is reachable only under `value.present? \|\| match_null`, so `conditions` is never empty. It is a latent trap for a future caller, not a defect today |
| "has been nobody" misses issues because the journal stores `''` rather than NULL | clean, checked in core rather than assumed — `Journal#add_detail` passes `old_value` straight into `JournalDetail.new`, so a previously-unassigned issue stores SQL NULL, and `old_value IS NULL` matches it. Issues never assigned have no journal row at all and are caught by the `OR issues.assigned_to_id IS NULL` half |
| "has never been nobody" is `NOT EXISTS(…) OR …`, which is wrong | clean — the assembly is `"#{neg} (EXISTS (#{subquery})#{sql_ev})"`, so `NOT` wraps the whole group. Core's structure, unchanged by the patch |
| adding an entry to `assigned_to_values` breaks another query class that shares it | clean — `grep -rn assigned_to_values` over `app/` and `lib/` returns exactly one caller, `issue_query.rb:188`, and it registers the filter as `:list_optional_with_history` |
| `none` collides with a real principal id | clean — ids are integers, and `Query#validate_query_filters` does not validate list values either way |
| an existing saved query or URL with `v[…][]=none` changes behaviour | clean, and it improves — before the patch that value reached `IN ('none')` against an integer column, which PostgreSQL refuses outright; after it is a valid NULL match |
| a new locale key is needed | clean — `label_nobody` is already in `en.yml`; zero locale files touched |
| INV-10: GEOxyz has drifted | clean — every one of the 22 added lines is present verbatim on `7.0-stable-GEOxyz` and no removed line survives there |
| the UI offers `none` for only one filter while the SQL supports seven | true, deliberate, and **already in the dossier's objections table** with the list of the seven and the reason. Not a finding |

**No findings.** Said plainly rather than padded. The change is 26 lines of
production Ruby, every one of them load-bearing, and the parts most likely to be
wrong — the operator matrix, the history operators, the call sites — hold up
when driven rather than read.
