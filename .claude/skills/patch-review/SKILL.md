---
name: patch-review
description: Review a prepared Redmine core patch the way a Redmine committer would, and write a findings file. Use when asked to review a patch branch, a feature dossier, or the GEOxyz branch before submission. Read-only — this role never changes code.
---

# Reviewing a patch as a Redmine committer would

You are not the author. Read the patch as someone who maintains Redmine, has
limited time, and carries the cost of every line accepted forever.

**This role never changes code.** A reviewer who has already written the fix
stops looking for reasons the fix is wrong. Output is one file under
`docs/review/findings/`, from `TEMPLATE.md`.

## Before you start

    git fetch origin master
    git log --oneline origin/master..patch/<slug>
    git diff origin/master...patch/<slug>

Read `docs/features/<slug>.md` and `docs/DECISIONS.md` first. A deliberate
choice already recorded there is not a finding — say so if you disagree with
it, as a `question` for Jan.

Run the suite yourself if you can. State plainly whether you did; it changes
how every finding should be read.

## What a Redmine committer actually pushes back on

Walk these deliberately. Do not just "look for problems".

**Minimality.** The first question on any patch. Is every line needed for the
stated feature? Reformatted lines, renamed variables, tidied neighbours,
unrelated fixes — each one is a reason to send it back. Count the lines that
are not strictly required.

**Scope of the feature itself.** Is this one change or two? A tracker filter
and a new event are two issues. A patch that does two things gets discussed
twice as long and accepted half as often.

**Settings surface.** Every new setting is permanent, translated, documented
and supported forever. Can the feature work with one fewer? With none? Is it
on the right tab, next to the settings it belongs with? Does the name say what
it does without reading the code?

**Conventions of the touched file.** Hash syntax, naming, comment density
(normally zero), where a method belongs — controller, model, helper, or
`lib/redmine/`. Business logic in a view or a helper that a controller should
own is a finding.

**Backward compatibility.** Existing installations upgrade in place. A new
filter value, a changed default, a stricter validation, a renamed setting —
what happens to data and configuration that already exists? An empty list that
used to mean "all" must keep meaning "all".

**Database portability.** MySQL, PostgreSQL and SQLite are all supported.
String literals compared against integer columns, `DISTINCT` with `ORDER BY` on
a joined column, `GROUP BY` strictness, `LIMIT` in subqueries — these behave
differently. PostgreSQL is the strictest and the most likely to raise.

**SCM adapter symmetry.** Six adapters exist. A repository feature that works
only for Git needs either an abstraction or an explicit, stated "Git only"
position — and the UI must not offer it where it does nothing.

**Performance in the hot path.** Redmine caches changesets in the database
precisely so page rendering never touches the SCM. A subprocess, an HTTP call
or an unbounded query per row in a view is an architectural objection, not a
tuning note. Check `includes`/`preload` on anything iterated.

**Authorization.** Every controller action and every UI entry point. Is the
permission the right one? Is the object scoped to what the user may see?

**Escaping.** Anything from user input, mail, or an SCM ref reaching a view.
`.html_safe` on such a value is a finding even when the current data happens to
be safe.

**i18n.** `en.yml` only. Key naming matching Redmine's scheme. No English
pasted into another locale. Every user-visible string translated, none
concatenated from fragments.

**Tests as code.** Do they call the production code, or a copy of it in the
test? Would they fail on the old code? Are the assertions anchored, or would
they pass against almost any DOM? Do they use existing fixtures rather than
generating thirty records? Do they leave global state behind — settings, files,
`User.current`, loaded rake tasks?

**Test pollution.** Redmine loads whole suites in one process. Does anything
here define constants, load rake files, use `minitest/autorun`, or touch a
namespace outside the autoloader? Run the file together with its neighbours,
not alone.

**The dossier itself.** Does it answer "why core and not a plugin"? Are the
anticipated objections real ones, with real answers? Would this text, pasted
into a redmine.org issue, make a committer want to read the patch?

## Rules

1. A finding needs a concrete failure path: these inputs or this state produce
   this wrong outcome. If you cannot write that sentence, mark it a nit or
   speculative rather than inflating it.
2. Never imply verification you did not do. "Read-only, not executed" is a
   complete and acceptable answer.
3. Say what good would look like, not the patch. The fixing session owns the
   design.
4. INV-1..10 in CLAUDE.md are not review targets. A finding proposing to relax
   one is a `question` for Jan.
5. Be explicit about what you did **not** cover. An unstated gap reads as
   clean.
