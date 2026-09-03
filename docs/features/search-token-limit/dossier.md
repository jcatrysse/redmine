# search-token-limit — text filters stop ignoring every keyword after the fifth

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** als je in een tekstfilter (bijvoorbeeld
  "Onderwerp bevat") meer dan vijf woorden typt, gebruikte Redmine alleen de
  eerste vijf en gooide de rest stil weg. Je kreeg dus een verkeerde lijst
  zonder dat iets dat meldde. Nu gebruikt het filter alle woorden die je typt.
- **Waar het vandaan komt:** 5.1-commit `17528437d`, port-commit `cd60c0b63`
  (op `origin/ansifi/learn-and-test-7.0`)
- **Doel:** upstream + GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen
- **Kans dat Redmine dit aanneemt:** goed — het is geen nieuwe functie maar het
  terugdraaien van een neveneffect van hun eigen refactor uit 2021, zonder
  nieuwe instelling en zonder vertaling.
- **Wat is er anders dan jouw patch van januari?** Die voegde een instelling
  `search_token_limit` toe (standaard 5) op het tabblad Issues. De tokenizer las
  die instelling, en die tokenizer wordt door twee dingen gebruikt: de
  tekstfilters én het zoekvak rechtsboven. Standaard veranderde er dus niets, en
  een beheerder moest een getal invullen om meer dan vijf woorden te krijgen —
  voor filters en zoekvak tegelijk. Deze patch heeft **geen** instelling:
  tekstfilters zijn altijd onbeperkt, het zoekvak blijft precies vijf. Voor
  GEOxyz betekent dat: het veld verdwijnt uit Beheer → Configuratie → Issues,
  filters werken zonder dat iemand iets instelt, en het zoekvak gebruikt weer de
  eerste vijf woorden in plaats van het ingestelde getal. Dat laatste is K-04,
  beslist op 2026-09-02 (optie A).
- **Wat jij nog moet doen:** het issue bestaat al —
  [#43701](https://www.redmine.org/issues/43701), door jou aangemaakt op
  2026-01-21, zeven maanden zonder reactie. Hang de nieuwe patch daar als note
  aan en leg in één alinea uit waarom deze vorm anders is dan de eerste, en
  benoem de oude bijlage als achterhaald.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `2563fa6a5` = SVN r24882 van 2026-08-03. De
  mirror liep één maand achter op de dag van dit werk (2026-09-02).
- **Lost trunk dit al op?** Nee. `lib/redmine/search.rb:145` in trunk is nog
  steeds `tokens.uniq.select{…}.first 5`, en geen enkele test in trunk legt die
  vijf vast.
- **Bestaand issue op redmine.org?** Ja:
  [#43701](https://www.redmine.org/issues/43701) — *"Redmine::Search::Tokenizer
  limited to 5 => problem for 'contains any of', 'starts with' and 'ends with'
  filter operators"*, categorie Filters, status Open, geen target version, geen
  enkele note in zeven maanden. Auteur is Jan Catrysse; de bijlage is precies
  de 5.1-patch (`Patch__override_search_limit_due_to_Redmine__Search__Tokenizer.patch`,
  51,6 kB, waarvan 48 locale-bestanden). Verwant: #38435 ("contains any of",
  gefixt in 5.1.0) en #38456. Ook gezocht op: *token limit*, *tokenizer*,
  *search limit*, *first 5*.
- **Verandert iets in trunk het ontwerp?** Ja, en dit is de kern van de zaak.
  De vijf-tokenlimiet is niet voor filters bedacht. Tot r21238 (2021-10-05,
  #35148, patch van Jens Krämer) stond het tokeniseren inline in
  `Redmine::Search::Fetcher#initialize` en eindigde het op
  `@tokens.slice! 5..-1` — een grens van de **zoekmachine**, die per token een
  LIKE over elke scope legt. Die commit verplaatste het blok woordelijk naar de
  nieuwe klasse `Tokenizer`, zodat tekstfilters en de issue-autocomplete het
  tokeniseren konden hergebruiken. De limiet ging mee. Sindsdien geldt een
  performancegrens van de zoekmachine ook voor een filter dat één kolom van één
  tabel bekijkt. Dat is geen ontwerpkeuze geweest, en die vaststelling is een
  ander verhaal dan de eerste inzending: die vroeg een instelling om een
  bewuste limiet te overrulen, deze haalt een limiet weg waar hij nooit hoorde.

---

# The problem

`Redmine::Search::Tokenizer` truncates its result to the first five tokens.
Since r21238 (#35148) that class is also what text filters and the issue
autocomplete use to split a filter value into terms, so every text filter
silently ignores whatever the user typed after the fifth word. Five operators
are affected: `~` *contains*, `!~` *doesn't contain*, `*~` *contains any of*,
`^` *starts with* and `$` *ends with*.

The result is wrong either way, and nothing on the page says so:

- `~` and `!~` combine their terms with `AND`. Dropping terms makes the filter
  *less* selective, so the list contains issues the user excluded. Filter
  Subject `~` `closed issue on locked version nomatch` and Redmine returns
  "Closed issue on a locked version" — an issue that does not contain
  `nomatch`.
- `*~`, `^` and `$` combine their terms with `OR`. Dropping terms makes the
  filter *more* selective, so matching issues are missing. Filter Subject `*~`
  with six keywords and only the first five are looked for; an issue that
  matches the sixth is not in the list.

The five-token limit itself belongs to the search engine, where it was written:
`Redmine::Search::Fetcher` runs one `LIKE` per token against every searchable
class in every selected project, so an unbounded token count there is a real
cost. A text filter is one column of one table. The limit reached filters only
because r21238 moved the tokenizing code into a shared class and the `.first 5`
travelled with it.

The `OR` operators make it easy to hit. `*~` *contains any of* was added in
5.1.0 (#38435) precisely so that users could list several keywords, and listing
several keywords is exactly what runs into the cap.

# Why this belongs in core

The truncation happens inside `Redmine::Search::Tokenizer#tokens`, which
`Query.tokenized_like_conditions` calls to build the `LIKE` clauses of a core
filter. A plugin can only reach it by reopening the class and redefining
`tokens`, which is the whole method and would silently fight any core change to
the tokenizing rules. There is no seam. And a wrong result set from a core
filter operator is core's own bug, not a feature to opt into.

# Proposed change

Move the five-token limit from the shared tokenizer to the one caller it was
written for, the search engine. `Redmine::Search::Fetcher` keeps taking the
first five tokens; text filters and the issue autocomplete now use every token
the user typed.

| File | Change |
|---|---|
| `lib/redmine/search.rb` | `Fetcher#initialize` truncates to five tokens; `Tokenizer#tokens` no longer does |
| `test/unit/search_test.rb` | the search engine still uses no more than five tokens |
| `test/unit/lib/redmine/search_test.rb` | the tokenizer returns every token |
| `test/unit/query_test.rb` | `~` and `*~` filters honour the sixth keyword |

`app/models/query.rb` and `app/models/issue.rb` are not touched: they call
`Tokenizer.new(value).tokens` already, and that call now returns everything.

**New setting / migration / gem / route / permission:** none.

**Translations** (INV-5): none — the change adds no user-visible string.

**Backward compatibility:** the global search behaves exactly as before, and
the unit test above pins that. Text filters return different results than in
7.0.0 — they now answer the question that was asked. Saved queries and the API
are unaffected: the stored filter value is untouched, only the SQL built from
it changes. A saved query with more than five words in a text filter starts
returning the set its own definition describes. No existing test in trunk
asserts the old behaviour.

# Alternatives considered

**A configurable limit, `Setting.search_token_limit`, with `0` for unlimited.**
This is what was attached to #43701 in January 2026 and what GEOxyz runs on
5.1: a new int setting, a field with a hint on the *Issues* settings tab, and
`Tokenizer` reading `Setting.search_token_limit`. Rejected on three counts.
It asks an administrator to configure a bug: nobody can name the right value
for "how many of my keywords should be ignored". It is permanent API and
translation surface for every one of Redmine's 48 locales, which is what makes
the original patch 51 kB for a four-line fix. And it puts the field on the
Issues tab while the same setting also changes the global search engine, so the
label is wrong wherever it is put. The `max_tokens:` keyword argument in that
patch is also never passed by any caller.

**Removing the limit from the search engine too.** That is the one place where a
per-token cost multiplies: tokens × searchable classes × projects, each a
`LIKE` on a text column, cached per query. The cap there is a deliberate,
long-standing guard and this patch keeps it.

**A higher fixed number for filters, say 20.** It moves the same silent
truncation to a less likely place instead of removing it. A user who pastes 25
words into a filter still gets a wrong list and still no warning.

**Warning the user that the value was truncated.** More code and a new string
in every locale, to explain a limitation rather than lift it.

# Tests

| Test | What it proves |
|---|---|
| `SearchTest#test_fetcher_should_use_no_more_than_five_tokens` | the search engine keeps its cap — the regression guard for this patch |
| `Redmine::Search::Tokenize#test_tokenize_should_not_limit_the_number_of_tokens` | the tokenizer itself no longer truncates |
| `QueryTest#test_sql_contains_should_not_limit_the_number_of_tokens` | `~` with six words no longer returns an issue that lacks the sixth |
| `QueryTest#test_sql_contains_should_not_limit_the_number_of_tokens_for_contains_any_of` | `*~` with six words finds the issue that matches only the sixth |

**Evidence (INV-8 — figures, not claims):**

- **full** suite on the patch, `tools/test-env.sh … bundle exec ruby bin/rails test:all`
  → 5924 runs, 31456 assertions, 27 failures, 2 errors, 92 skips
- **full** suite on a pristine `origin/master` r24882, same command
  → 5920 runs, 31452 assertions, 27 failures, 2 errors, 92 skips
- the 27 failures and 2 errors are **identical in both runs**, test for test —
  the two lists of 29 names `diff` clean. All 29 are repository or changeset
  tests that need `svn`, `hg`, `bzr` or `cvs`, none of which is installed on
  this machine (`RepositoriesControllerTest`, `SysControllerTest`,
  `Redmine::ApiTest::RepositoriesTest`,
  `UserTest#test_destroy_should_nullify_changesets`). The patch adds exactly
  4 runs and 4 assertions and changes nothing else. See "Found but not fixed".
- **confirmation run on the exact commit that was exported** (the two new
  `QueryTest` methods were moved to sit after the existing
  `test_sql_contains_should_tokenize*` group, so the earlier figures were
  measured one line-position apart) → 5924 runs, 31452 assertions,
  27 failures, **3** errors, 92 skips. The extra error is
  `OauthProviderSystemTest#test_application_creation_and_authorization`,
  `Selenium::WebDriver::Error::UnknownError: unhandled inspector error: Node
  with given id does not belong to the document` — a driver-level race in
  Chrome while two full suites shared four cores, in a test this patch does not
  touch. Re-run on its own on the same commit: **1 run, 13 assertions,
  0 failures, 0 errors**. The other 29 are the same 29.
- **full** suite on `7.0-stable-GEOxyz` with the same change, on the exported
  commit → 5925 runs, 31738 assertions, 0 failures, 0 errors, 39 skips
- RuboCop on the four changed files: **0** offences (baseline at
  `origin/master`, same four files: **0**). On `7.0-stable-GEOxyz`: **0**
  offences on the 6 changed Ruby files (baseline at `origin/7.0-stable`,
  the same four files: **0**)
- each new test verified red on the old code: `git stash push lib/redmine/search.rb`,
  then the same four tests in one process → `4 runs, 4 assertions, 3 failures`.
  The three that fail are the three new behavioural tests; the failure text of
  the `~` case names issue 12 "Closed issue on a locked version" as the wrong
  row the old code returns. The fourth,
  `test_fetcher_should_use_no_more_than_five_tokens`, passes before *and* after
  by design — it is the guard that the search engine's cap survived, so a green
  result on the old code is what it is supposed to give.
- patch applies to pristine `origin/master` r24882: yes
- `tools/check-patch-clean.sh`: PASS

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`. Screenshots in `docs/features/search-token-limit/shots/`.

The seed now creates one issue whose subject has seven distinct words, "Pump
alignment survey report northern wind farm", because none of the existing
seeded subjects is long enough to give a filter more than five useful tokens.

Every case below uses a six-token filter value in which the **sixth** token is
the one that decides the answer — the first one the old code throws away.
`verify/search-token-limit.mjs` asserts the count on the page, in `MODE=before`
the wrong one and in `MODE=after` the right one, so a picture alone is never
the evidence.

| Function | Screenshot | What it shows |
|---|---|---|
| Subject `~` six words, sixth matches nothing | `before-filter-contains.png` | 1 issue — the old code returns "Pump alignment…" although it does not contain `zzz` |
| Subject `~` six words, sixth matches nothing | `filter-contains.png` | 0 issues, "No data to display" |
| Subject `*~` six words, only sixth matches | `before-filter-contains-any-of.png` | 0 issues — the matching one is missing |
| Subject `*~` six words, only sixth matches | `filter-contains-any-of.png` | 1 issue |
| Subject `^` six words, only sixth matches | `before-filter-starts-with.png` | 0 issues |
| Subject `^` six words, only sixth matches | `filter-starts-with.png` | 1 issue |
| Subject `$` six words, only sixth matches | `before-filter-ends-with.png` | 0 issues |
| Subject `$` six words, only sixth matches | `filter-ends-with.png` | 1 issue |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| Global search, six words, "all words", sixth is nonsense | `before-search-still-capped.png` | 1 result: the cap drops the sixth token | 1 result |
| The same search after the change | `search-still-capped.png` | still 1 result, still the same five highlighted tokens | 1 result, five tokens highlighted |
| Filter present but with no match at all (`~ zzz`) | covered by `filter-contains.png` | empty list, not an error | empty list |

The script also fails if the subject filter is not actually on the page, so an
empty list caused by a filter that never applied cannot pass as a fix.

Screenshots read, not just generated: yes. Looked for, in each: the filter row
with the right operator label ("contains", "contains any of", "starts with",
"ends with"), the full six-word value still in the text box (so the form did
not truncate it either), the pager, and the subject column.

Two things the images show that the numbers do not:

- `before-filter-contains.png` puts the defect on one screen. The filter reads
  "Subject contains: pump alignment survey report northern zzz" and the list
  below it is `(1-1/1)` — issue #7 "Pump alignment survey report northern wind
  farm", an issue that does not contain `zzz`. `filter-contains.png` is the
  same page after the change: "No data to display".
- the two search screenshots highlight the tokens the search engine used, and
  in both of them exactly five words are highlighted — Pump, alignment, survey,
  report, northern — while "wind" and "farm" are not. That is the cap, visible,
  unchanged before and after.

# Anticipated objections

| Objection | Answer |
|---|---|
| "The five-token limit is there for performance." | It is, for the search engine, and it stays there. This patch moves it to `Fetcher`, which is where it was written and where the cost is tokens × classes × projects. A text filter is one `LIKE` per token on one column of one table. |
| "Unbounded tokens in a filter can be slow." | The number of terms is what the user typed into their own filter, on a query they wait for themselves. Redmine puts no such cap on any other filter input. And the alternative is not "fast" but "fast and wrong": today the same filter returns a different set than its definition, silently. |
| "This changes behaviour in a stable release." | It changes behaviour in trunk. Text filters with more than five words return a different set than in 7.0.0, and that is the point of the fix. No test in trunk asserts the old behaviour, and the global search is pinned unchanged by a new test. |
| "Then make it configurable, so administrators can choose." | An administrator cannot sensibly choose how many of a user's keywords to ignore. A setting also has to sit on one settings tab while affecting both the filters and the global search — the earlier patch on #43701 put it on Issues, which is wrong for the search engine half. See "Alternatives considered". |
| "Was the limit not deliberate for filters?" | No. Before r21238 the tokenizing and the `slice! 5..-1` were inline in `Fetcher#initialize`; that commit moved the block verbatim into `Tokenizer` so filters and the autocomplete could reuse the tokenizing. Nothing in #35148 discusses a term limit for filters. |
| "Why not fix it in `Query.tokenized_like_conditions` instead?" | That would leave a shared tokenizer whose contract is "the search engine's first five", and the next reuse would inherit the same surprise. `Issue.like`, used by the issue autocomplete, is already the second such caller. |

---

## Submission

- **Issue:** [#43701](https://www.redmine.org/issues/43701) — exists since
  2026-01-21, open, no notes. This patch replaces the attachment there; the
  note should say why the shape changed.
- **Patches attached:** `patches/search-token-limit/2026-09-02-r24882-feature.patch`.
  One file only: the change adds no user-visible string, so there is no
  locales patch.
- **Made against:** `origin/master` r24882 (2026-08-03)
- **Status:** patch klaar, nog niet ingediend
- **Feedback en wat ermee gebeurde:** de eerste inzending (januari 2026, de
  instelling-variant) kreeg in zeven maanden geen enkele reactie.

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `1c85728aa`
- **Suites daar groen:** 5925 runs, 31738 assertions, 0 failures, 0 errors, 39 skips — helemaal groen
- **`nl.yml` toegevoegd:** n.v.t. — geen nieuwe strings
- **`tools/check-geoxyz-branch.sh`:** PASS
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus: pas als GEOxyz naar de release gaat
  die deze fix bevat, ten vroegste 7.1.0.

## Found but not fixed

- **29 repository- en changeset-tests falen op deze machine, met en zonder
  patch.** `svn`, `hg`, `bzr` en `cvs` staan niet in het image. Exact dezelfde
  27 failures en 2 errors in beide volledige trunk-runs, test voor test
  hetzelfde; niets ervan raakt `lib/redmine/search.rb`. Op de GEOxyz-branch
  (7.0-stable) falen diezelfde bestanden niet — dat verschil is een
  trunk-wijziging (`Setting.enabled_scm`), niet iets van ons.
- **De `max_tokens:` keyword-parameter in de 5.1-patch en in de port
  (`cd60c0b63`) wordt door geen enkele caller doorgegeven.** Dode API. Niet
  gerepareerd maar vervallen: dit ontwerp heeft de parameter niet nodig.
- **`Query.tokenized_like_conditions` valt terug op `[value]` als het
  tokeniseren niets oplevert** (`tokens = [value] unless tokens.present?`).
  Dat betekent dat een filter op één teken (`~ a`) de ruwe waarde gebruikt in
  plaats van geen enkele voorwaarde. Correct gedrag, maar het staat los van
  deze patch en is niet aangeraakt (INV-1).
