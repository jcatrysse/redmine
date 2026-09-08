# Review run — 2026-09-08 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** `patch/mypage-query-blocks` at `6af3b35c4` against
  `origin/master` `bee32a926` (r25037). 0 commits behind trunk, one commit
  ahead.
- **Dossier read:** `docs/features/mypage-query-blocks/dossier.md` — yes
- **Status read:** `docs/features/mypage-query-blocks/status.md` — yes
- **Round-1 findings read:** **no, deliberately.**
  `docs/review/findings/2026-09-03-mypage-query-blocks-claude-opus5.md` was not
  opened. `docs/REGISTER.md` names Jan's K-10 (the upper bound), so I knew the
  number 20 was his and did not re-litigate it.
- **Ran the test suite:** yes, both sides, fresh worktrees, own PostgreSQL 16
  databases, Git fixtures extracted, **the same `Gemfile.lock` on both sides**,
  and the four runs serialised rather than concurrent. See **Suite**.
- **Scope covered:** minimality, the settings surface and where the field sits,
  the conventions of both touched files, backward compatibility for existing
  installations and for plugins that register blocks, whether the limit is
  enforced server-side or only in the dropdown, i18n against the keys the five
  translations derive from, the tests as code, INV-10 against
  `7.0-stable-GEOxyz`, lint, patch hygiene, and the commit object itself.
- **Scope NOT covered:**
  - **No browser.** The G9 screenshots were read, not reproduced.
  - **MySQL and SQLite.** PostgreSQL 16 only. The patch adds no SQL.
  - **No plugin.** The backward-compatibility claim for a plugin registering
    `:max_occurs => 5` is read from the code path, not exercised against a real
    plugin.

## Summary

The change itself is clean and I have nothing to report about it. Thirteen lines
of production Ruby, a setting that defaults to the number that was hard-coded
before it, and the validation block is a near-verbatim copy of the
`default_issue_due_date_offset` block immediately above it in the same file —
same `to_s.strip`, same `unless value.blank?`, same `Integer(value, 10)`, same
`rescue ArgumentError`, same message keys. That is what "match the conventions
of the touched file" looks like.

Two things I checked because they are where this kind of feature usually goes
wrong, and both hold. The limit is enforced **server-side**, not just in the
dropdown: `UserPreference#add_block` gates on `Redmine::MyPage.valid_block?`,
which reads the same `max_occurs`, and there is a test that posting past the
maximum errors. And lowering the setting does not destroy blocks users already
have — `block_options` only disables *adding*, existing layouts keep rendering,
and that too has a test.

The finding is not in the diff. It is in the commit that carries it:
**`6af3b35c4` has committer `Claude <noreply@anthropic.com>`.** It is the only
one of the nine `patch/*` branches with an AI identity, `check-patch-clean`
cannot see it because `git format-patch` writes only the author into the file,
and `check-geoxyz-branch.sh` does not look at identity fields at all.

**Counts:** blocker 1 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0. Twelve files,
229 insertions, 2 deletions; 183 of those insertions are tests.

## Suite

`/home/user/wt/r3-mypage-query-blocks` (patch tip `6af3b35c4`) and
`/home/user/wt/r3-trunk` (pristine r25037), separate databases, same
`Gemfile.lock`, PostgreSQL 16, Ruby 3.3.6.

| What | Result |
|---|---|
| `test:all` with the patch | `5992 runs, 31410 assertions, 48 failures, 82 errors, 92 skips` |
| `test:all` on pristine trunk, same lock | `5977 runs, 31358 assertions, 48 failures, 82 errors, 92 skips` |
| delta | **15 runs**, and **zero extra failures and zero extra errors** |
| failing names | **87 on each side, identical** — `comm` empty in both directions |
| RuboCop 1.90.0 on the 5 changed Ruby files | `no offenses detected`; baseline on the 4 that exist at the merge base: `no offenses detected` |
| `tools/check-patch-clean.sh mypage-query-blocks --submit` | PASS — 12 files, locales `de,en,es,fr,nl`, no AI trace in header or message, applies to a pristine r25037 checkout, branch and file agree |

The 15 extra runs are exactly the 15 new tests: 6 in `my_controller_test.rb`,
4 in `settings_controller_test.rb` and 5 in `my_page_test.rb`.

**Why the totals are 48/82.** json 3.0.1 now breaks
`ActiveSupport::JSON.decode` and about a hundred core tests with it, measured on
pristine trunk, so it affects both sides equally. See `docs/traps.md`.

**Hypotheses driven and cleared:**

| Hypothesis | Outcome |
|---|---|
| the setting is only a UI hint and a crafted POST adds unlimited blocks | clean — `UserPreference#add_block` returns early unless `Redmine::MyPage.valid_block?(block, …)`, which goes through `block_options` and therefore through `max_occurs`. `test_add_issuequery_block_over_the_configured_maximum_should_error` pins it, and `order_blocks` intersects with the existing layout (`& my_page_layout.values.flatten`) so it cannot inject either |
| lowering the setting destroys blocks users already have | clean — `block_options` only sets `disabled` for *adding*; `test_page_should_render_issuequery_blocks_over_a_lowered_maximum` asserts the existing ones still render |
| a plugin that registers `:max_occurs => 5` breaks on the Symbol | clean — `max_occurs.is_a?(Symbol) ? Setting[max_occurs].to_i : max_occurs`, so an Integer passes straight through, and there is a test for each branch |
| something else in core reads `blocks[…][:max_occurs]` and now gets a Symbol | clean — `grep -rn max_occurs` over `app/` and `lib/` returns the definition, the one call site, and nothing else |
| an unknown block raises | clean — `blocks.fetch(block, {})[:max_occurs] \|\| 1`, with `test_max_occurs_should_return_one_for_an_unknown_block` covering both `'issuequery__1'` and a name that does not exist |
| an existing installation changes behaviour on upgrade | clean — `config/settings.yml` defaults to 3, which is the number `:max_occurs => 3` hard-coded before |
| clearing the field is silently 0 rather than the default | true, and it is core's own behaviour for an `int` setting — `default_issue_due_date_offset` treats blank the same way, and the validation block was copied from it. Not a deviation, so not a finding |
| the validation does not match how core validates settings | clean — it is the same shape as the block above it, down to the `activerecord.errors.messages.*` keys |
| the five translations were invented rather than derived (INV-5) | clean, and checked key by key — nl "eigen zoekopdrachten"/"Mijn pagina", fr "rapports personnalisés"/"Ma page", de "Abfragen"/"Meine Seite", es "consultas personalizadas"/"Mi página" all match `label_query_plural` and `label_my_page` in their own files |
| INV-10: GEOxyz has drifted | clean — all 43 added lines are present verbatim on `7.0-stable-GEOxyz`, no removed line survives, and `Redmine::MyPage.max_occurs` is byte-identical on both branches |

---

### F01 — the commit carries `Claude <noreply@anthropic.com>` as its committer

- **Status:** open
- **Severity:** blocker
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `origin/patch/mypage-query-blocks` at `6af3b35c4`, the commit object's `committer` header
- **Invariant touched:** **INV-4**

**What is wrong**

```
$ git cat-file commit origin/patch/mypage-query-blocks | head -5
tree 1474fc51a506e111203ede91ec2665f7d1fc182d
parent bee32a9268738308a0c45acc316ec7b1499e66e3
author Jan Catrysse <jan.catrysse@geoxyz.eu> 1788420358 +0000
committer Claude <noreply@anthropic.com> 1788606522 +0000
gpgsig -----BEGIN SSH SIGNATURE-----
```

INV-4 says this in terms: it "covers the author and committer fields, not just
the message", and calls those fields "the half that bites", because a commit
made without an explicit identity override already carries the session's own.
K-13 was the cleanup for exactly this on `7.0-stable-GEOxyz`, where sixteen of
thirty-three commits had to be force-pushed away on 2026-09-06. This branch was
not part of that pass.

**It is the only one.** I checked every commit of every `patch/*` branch:

```
patch/assignee-nobody          d0243086d  Jan Catrysse / Jan Catrysse
patch/imap-oauth               10efe8761  Jan Catrysse / Jan Catrysse
patch/mypage-query-blocks      6af3b35c4  Jan Catrysse / Claude <noreply@anthropic.com>   <-- INV-4
patch/revision-branches        53faa9a0f  Jan Catrysse / Jan Catrysse
patch/search-token-limit       587d9a11b  Jan Catrysse / Jan Catrysse
patch/version-subprojects      a6d7b7392  Jan Catrysse / Jan Catrysse
patch/webhook-issue-closed     f3234c1ec  Jan Catrysse / Jan Catrysse
patch/webhook-tracker-filter   cb4972a5c  Jan Catrysse / Jan Catrysse
patch/wiki-export-attachments  8121846be  Jan Catrysse / Jan Catrysse
```

**Why a committer would push back**

They would not see it, and that is the uncomfortable part rather than a reason
to relax. `git format-patch` writes only `From:` — the **author** — into the
`.patch` file, so the two files Jan attaches to
[#27313](https://www.redmine.org/issues/27313) are clean, and
`tools/check-patch-clean.sh` correctly reports `no AI trace in the header or the
commit message`. The trace is in the commit object on the branch.

That still matters here, for two reasons the framework already decided:

1. INV-4 is about the repository, not only about what a committer downloads.
   The branch is pushed to `origin`, it is what a reviewer is pointed at, and it
   is what a future `git format-patch` will be re-run from.
2. The gate that would have caught it does not exist. `check-patch-clean.sh`
   reads the patch file; `check-geoxyz-branch.sh` greps commit *messages* only
   and does not run on `patch/*` at all; `session-push.sh` refuses such an
   identity only since K-13, and this commit predates that guard. So nothing in
   the toolchain contradicts a "PASS" that is, for this particular property,
   uninformed. That gap is written up separately as F02 of
   `docs/review/findings/2026-09-08-gitignore-credentials-claude-opus5-round3.md`.

Marked blocker rather than major because INV-4 has no grey area — it is one of
the ten refusal conditions, and the whole point of a patch branch is that it is
submittable as it stands.

**How I verified it**

`git cat-file commit` on the tip of every `patch/*` branch, printing `%an <%ae>`
and `%cn <%ce>` for each of their own commits against `origin/master`. Then
`head -4` on both exported `.patch` files to confirm the trace does **not** reach
them, and re-ran `tools/check-patch-clean.sh mypage-query-blocks --submit` to
confirm it passes — both of which are true and neither of which contradicts the
finding.

**Suggested direction**

Re-commit the branch with the identity spelled out and force-push it. A patch
branch may be rewritten — unlike `7.0-stable-GEOxyz`, nothing checks it out —
so this is `git -c user.name="Jan Catrysse" -c user.email="jan.catrysse@geoxyz.eu"
commit --amend --no-edit --reset-author` and a `--force-with-lease`, exactly as
`wiki-export-attachments` was handled on 2026-09-08. Re-export the two patch
files afterwards so the header sha in them matches the branch, and re-run
`--submit`; the content does not change, so the evidence figures above stand.

The commit also carries an SSH signature made by whoever committed it. Amending
drops or replaces it; that is fine, since nothing in the framework depends on
the signature.

**Resolution:**
