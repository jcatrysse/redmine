# What Redmine actually requires

Every claim here has its source. Verified 2026-09-01. Do not re-derive this
every session; do update it when a source changes.

## Verified — stated by Redmine itself

| Requirement | Source |
|---|---|
| Patches are **posted to an issue** on redmine.org. Pull requests on GitHub or Bitbucket are explicitly not accepted — core developers do not monitor the GitHub mirror. | `CONTRIBUTING.md` in trunk; wiki *Contribute* |
| A patch must target **trunk** (svn trunk / git `master`), not a stable branch. | wiki *Contribute* |
| **All existing tests must pass.** | wiki *Contribute* |
| **Add tests** showing the new functionality and covering the bugs it fixes. | wiki *Contribute* |
| Translations "should be kept up-to-date alongside the development of Redmine". No rule about which locale files a patch may touch. | wiki *Contribute* |

Source: <https://www.redmine.org/projects/redmine/wiki/Contribute> and
`CONTRIBUTING.md`.

## Inferred from the codebase and its history — not documented rules

Treat these as strong conventions with evidence, not as quotable requirements.
If a committer contradicts one, they are right and this file is wrong.

**Translations arrive separately, per language, from native speakers.** Trunk's
history shows dedicated commits such as "Traditional Chinese translation update
(#44307)", "Galician translation update (#44282)", "Bulgarian translation update
(#44281)", plus periodic bulk "Updates locales" commits. Feature work does not
carry fifty translated files.

**Jan's decision (2026-09-01): `en`, `nl`, `fr`, `de`, `es` ship with the work.**
He raised the concern, heard the argument below, and chose the four languages —
they are GEOxyz's working languages and he wants them covered. Two mechanisms
keep that from costing anything:

1. **Derive, never invent.** Each new key is patterned on the closest existing
   key in the same locale file, and the dossier names that key. Redmine's files
   disagree on basic vocabulary — `issues` renders as *issues* (nl),
   *demandes* (fr), *Tickets* (de), *peticiones* (es) — so a translation
   composed from the English is plausible and wrong. Deriving it is both more
   accurate and checkable in seconds.
2. **Two patch files on one issue.** The feature (code + `en.yml`) and the
   translations, separately. A committer can take the feature without waiting
   on translations they cannot read, and the feature patch stays small. This is
   how Redmine's own history handles translations anyway.

The remaining facts, for context:

- Redmine's i18n falls back to English for a missing key, so an absent
  translation is a non-event — which is why the *bulk* 51-file approach was
  never worth its risk.
- A patch touching 51 files is materially harder to review than one touching 3,
  and a committer cannot verify a translation into a language they do not read.
  One wrong string discredits the whole patch. Five files, each derived and
  cited, is a different proposition.

**RuboCop runs in CI and the codebase is clean.** `.github/workflows/linters.yml`
runs `bundle exec rubocop --parallel` and `stylelint` on
`app/assets/stylesheets/**/*.css`. Measured on the file set touched by the 2026
port: trunk's baseline was **0** offences. A patch with lint offences fails their
CI before a human reads it.

**`lib/tasks/**/*` is excluded** in `.rubocop.yml`. Rake code is never linted, so
nothing mechanical catches a top-level method or constant there. Human review is
the only control.

**The codebase is almost comment-free.** Comments explain a non-obvious *why*,
never what a line does. A patch that adds explanatory comments reads as written
by someone unfamiliar with the codebase.

**Every new setting is permanent surface.** It must be translated, documented,
supported and migrated forever. Expect the question "can this work with one
fewer?" on any patch that adds more than one.

**Repository features must account for six SCM adapters** (Subversion, Git,
Mercurial, CVS, Bazaar, Filesystem). Changesets are cached in the database
specifically so page rendering never invokes the SCM.

**Three databases are supported** — MySQL, PostgreSQL, SQLite. PostgreSQL is the
strictest: comparing a string literal against an integer column raises there and
passes on MySQL. The 2026 port shipped exactly that bug.

## Open questions

- Whether redmine.org asks anything about the provenance of contributed code
  (AI assistance). Not found on the Contribute page. Jan submits, so it is his
  to check if he wants certainty.
- Whether a sixth language is ever worth adding. Currently no: five is what
  GEOxyz uses. One line in `tools/check-patch-clean.sh` if that changes.
