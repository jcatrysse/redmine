<!-- Copy to docs/review/findings/YYYY-MM-DD-<reviewer>.md and fill it in.
     Do not commit changes to this template itself. -->

# Review run — YYYY-MM-DD — <reviewer>

- **Reviewer:** <tool + model, e.g. "Claude Code (Opus)" or "ChatGPT Codex">
- **Reviewed:** `patch/<slug>` at `<short sha>` against `origin/master` `<short sha>`
- **Dossier read:** `docs/features/<slug>.md` — yes / no
- **Ran the test suite:** yes / no — <if no, say why; it changes how findings should be read>
- **Scope covered:** <which dimensions from the patch-review skill you actually got to>
- **Scope NOT covered:** <be explicit — an unstated gap reads as "clean">

## Summary

<Three to eight sentences in plain language. Would a Redmine committer accept
this patch as it stands? What is the single biggest reason they would not?
What surprised you positively? Jan reads this part — no jargon without a
one-line explanation.>

**Counts:** blocker <n> · major <n> · minor <n> · nit <n> · question <n>

**Lines in the diff not strictly required by the feature:** <n> — <which>

---

### F01 — <one-line title, the claim itself>

- **Status:** open
- **Severity:** blocker | major | minor | nit | question
- **Confidence:** confirmed | probable | speculative
- **Category:** minimality | scope | correctness | security | performance | portability | scm-symmetry | backward-compat | settings-surface | conventions | i18n | ui | test-quality | test-pollution | dossier
- **Where:** `path/to/file.rb:123`
- **Invariant touched:** INV-1..10 / none

**What is wrong**

<One paragraph. State the defect, not the symptom.>

**Why a committer would push back**

<A concrete failure path — these inputs or this state produce this wrong
outcome — or, for a minimality or scope finding, why this line costs them more
than it gives. If you cannot write this sentence, the finding is a nit or
speculative; mark it so rather than inflating it.>

**How I verified it**

<The command and its output, the test you wrote, or plainly: "read-only, not
executed". Never imply verification you did not do.>

**Suggested direction**

<What good would look like — not a patch. The fixing session owns the design.>

**Resolution:** <left empty by the reviewer; the fixing session fills this in>

---

### F02 — ...

<!-- Status values:
     open       not yet acted on                      (reviewer sets)
     fixed      changed, with a test red on old code  (fixer)
     invalid    factually wrong — say why, with evidence (fixer)
     wont-fix   real but deliberately not changed — reason required, and a line
                in docs/DECISIONS.md if user-visible (fixer)
     duplicate  same as another finding — name it     (fixer)
     deferred   real, out of scope — name what it waits on (fixer)
     question   needs Jan, not code                   (either)

     A fixer leaves no finding at `open` without a Resolution line.
     "Ran out of time" is acceptable; silence is not. -->
