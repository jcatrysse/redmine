# search-token-limit — text filters stop ignoring every keyword after the fifth

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** als je in een tekstfilter (bijvoorbeeld
  "Onderwerp bevat") meer dan vijf woorden typt, gebruikte Redmine alleen de
  eerste vijf en gooide de rest stil weg. Je kreeg dus een verkeerde lijst
  zonder dat iets dat meldde. Nu gebruikt het filter alle woorden die je typt.
  Dat geldt sinds deze ronde ook voor het filter **"Any searchable text"**, dat
  in hetzelfde uitklapmenu staat maar via de zoekmachine loopt: dat bleef in de
  eerste versie van de patch stilletjes bij vijf woorden steken.
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
- **Wat er in ronde 2 bij is gekomen (jouw keuze g08):** het filter
  "Any searchable text" wordt nu óók gerepareerd, en niet alleen in de tekst
  rechtgezet. De grens zit sinds deze patch in `Fetcher` in plaats van in de
  tokenizer, dus er hoefde alleen een optie bij zodat de aanroeper beslist: het
  zoekvak houdt vijf, het filter krijgt alle woorden. Daarbij hoort één ding dat
  de reviewer vond en dat we meteen dichtgezet hebben: de knop **"Apply issues
  filter"** onder de zoekresultaten gaf de héle vraag door aan het filter,
  terwijl de zoekpagina er maar vijf woorden van gebruikt had. Met een filter
  dat niet meer afkapt zou die knop dus een lege lijst openen onder een pagina
  die net "Results (1)" zei. De knop geeft nu de woorden door die de zoekmachine
  echt gebruikt heeft, waardoor hij zich precies gedraagt als vandaag in trunk.
- **Wat jij nog moet doen:** het issue bestaat al —
  [#43701](https://www.redmine.org/issues/43701), door jou aangemaakt op
  2026-01-21, zeven maanden zonder reactie. Hang de nieuwe patch daar als note
  aan en leg in één alinea uit waarom deze vorm anders is dan de eerste, en
  benoem de oude bijlage als achterhaald.

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `bee32a926` = SVN r25037 van 2026-09-03, de tip
  op de dag van deze herziening. De eerste versie van deze patch stond op
  r24882; trunk is sindsdien 88 commits opgeschoten (7.0.1, het laten vallen van
  Ruby 3.2, RuboCop 1.90). De patch is opnieuw vanaf r25037 gebouwd (g05).
- **Lost trunk dit al op?** Nee. `lib/redmine/search.rb:145` in r25037 is nog
  steeds `tokens.uniq.select{…}.first 5`, en geen enkele test in trunk legt die
  vijf vast. Van de 88 nieuwe commits raakt er geen enkele
  `lib/redmine/search.rb`, `app/helpers/search_helper.rb` of
  `app/views/search/index.html.erb` — nul commits, nagerekend met
  `git log 2563fa6a5..bee32a926 -- <die drie bestanden>`. Drie raken
  `query.rb`/`issue_query.rb` (`3b080de2a`, `390314eff` en de RuboCop-bump
  `08f8dbe75`, die alleen `query.rb` raakt), geen ervan in de buurt van
  `sql_for_any_searchable_field`.
- **Bestaand issue op redmine.org?** Ja:
  [#43701](https://www.redmine.org/issues/43701) — *"Redmine::Search::Tokenizer
  limited to 5 => problem for 'contains any of', 'starts with' and 'ends with'
  filter operators"*, tracker *Patch*, categorie *Filters*, status *New*, geen
  target version. Auteur is Jan Catrysse; de bijlage is precies de 5.1-patch
  (`Patch__override_search_limit_due_to_Redmine__Search__Tokenizer.patch`,
  52 856 bytes; opgehaald en nageteld op 2026-09-05: 54 bestanden, waarvan
  **50 locale-bestanden** en vier echte —
  `app/views/settings/_issues.html.erb`, `config/settings.yml`,
  `lib/redmine/search.rb`, `test/unit/lib/redmine/search_test.rb`).
  Verwant: #38435 ("contains any
  of", gefixt in 5.1.0) en #38456. Ook gezocht op: *token limit*, *tokenizer*,
  *search limit*, *first 5*. Opnieuw opgehaald op 2026-09-05 via
  `https://www.redmine.org/issues/43701.json?include=journals`: **nul notes**,
  en `updated_on` staat nog steeds op `2026-01-21T14:01:20Z` — er is in ruim
  zeven maanden niets aan het issue gebeurd.
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

The `Any searchable text` filter reaches the same cap by the other route. It
sits in the same "Add filter" dropdown as `Subject` and offers `~`, `*~` and
`!~`, but `IssueQuery#sql_for_any_searchable_field` implements it by building a
`Redmine::Search::Fetcher` — so it truncates because it *is* the search engine,
not because it is a filter.

The five-token limit itself belongs to the search engine, where it was written:
`Redmine::Search::Fetcher` runs one `LIKE` per token against every searchable
class in every selected project, so an unbounded token count there is a real
cost. A text filter is one column of one table. The limit reached filters only
because r21238 moved the tokenizing code into a shared class and the `.first 5`
travelled with it.

There is one place where the two meet on a single screen. When a search returns
issues, `app/views/search/index.html.erb` renders an **Apply issues filter**
button that hands the question to the `subject` filter (with *Search titles
only*) or to `any_searchable`. While everything truncates at five the button and
the count agree. The moment the filters stop truncating and the search box does
not, the page can report `Results (1)` and the button can open "No data to
display" — so lifting the cap in the filters means adjusting that button in the
same change.

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
written for, the search engine, and let that caller decide whether it applies.
`Redmine::Search::Fetcher` keeps taking the first five tokens by default, so the
global search box behaves exactly as before and so does any plugin that builds a
`Fetcher`. `IssueQuery#sql_for_any_searchable_field` passes `token_limit: nil`,
because there the fetcher is a filter over the issues of the query's projects.
Text filters and the issue autocomplete use every token the user typed.

| File | Change |
|---|---|
| `lib/redmine/search.rb` | `Fetcher#initialize` truncates to `:token_limit` tokens, five unless the caller says otherwise; `Tokenizer#tokens` no longer truncates |
| `app/models/issue_query.rb` | the `Any searchable text` filter passes `token_limit: nil` |
| `app/helpers/search_helper.rb` | `tokens_to_question` rebuilds a question from the tokens a search used |
| `app/views/search/index.html.erb` | the *Apply issues filter* button is built from those tokens, so it keeps opening the list the page counted |
| `test/unit/search_test.rb` | the engine still uses five tokens, and `token_limit: nil` lifts that |
| `test/unit/lib/redmine/search_test.rb` | the tokenizer returns every token |
| `test/unit/query_test.rb` | `~`, `*~` and `any_searchable` honour the sixth keyword |
| `test/helpers/search_helper_test.rb` | `tokens_to_question` round-trips through the tokenizer |
| `test/functional/search_controller_test.rb` | the button carries the five tokens the search used |

`app/models/query.rb` and `app/models/issue.rb` are not touched.
`grep -rn Tokenizer app lib` in r25037 returns three hits: the class itself, the
fetcher, and `Query.tokenized_like_conditions`. So that method is the only
consumer besides the fetcher, and it picks up every token without a line of its
own — as does `Issue.like`, the issue autocomplete, which calls it.

**New setting / migration / gem / route / permission:** none.

**Translations** (INV-5): none — the change adds no user-visible string.

**Backward compatibility:** the global search behaves exactly as before, and two
unit tests pin that. `Redmine::Search::Fetcher.new` keeps its old default, so a
plugin that builds one is unaffected. Text filters return different results than
in 7.0.0 — they now answer the question that was asked. Saved queries and the
API are unaffected: the stored filter value is untouched, only the SQL built
from it changes. A saved query with more than five words in a text filter starts
returning the set its own definition describes. No existing test in trunk
asserts the old behaviour.

# Alternatives considered

**A configurable limit, `Setting.search_token_limit`, with `0` for unlimited.**
This is what was attached to #43701 in January 2026 and what GEOxyz runs on
5.1: a new int setting, a field with a hint on the *Issues* settings tab, and
`Tokenizer` reading `Setting.search_token_limit`. Rejected on three counts.
It asks an administrator to configure a bug: nobody can name the right value
for "how many of my keywords should be ignored". It is permanent API and
translation surface for every one of Redmine's 50 locale files, which is what
makes the attachment on #43701 52 856 bytes across 54 files for a change to two.
And it puts the field on the Issues tab while the same setting also changes the
global search engine, so the label is wrong wherever it is put. Its
`Tokenizer#initialize(question, max_tokens: nil)` keyword argument is dead: the
attachment adds no caller that passes it, so the value always comes from the
setting.

**Removing the limit from the search engine too.** That is the one place where a
per-token cost multiplies: tokens × searchable classes × projects, each a
`LIKE` on a text column, cached per query. The cap there is a deliberate,
long-standing guard and this patch keeps it as the default.

**Leaving `Any searchable text` capped, and only saying so.** It is defensible —
that filter really is the search engine — but it puts two filters with the same
three operators next to each other in one dropdown, one of which quietly stops
at five words. The cost of lifting it is bounded and known: the fetcher there
already searches only `['issue']` in the query's projects, never the other
searchable classes. So the patch lifts it and pins the engine's own default with
a test instead.

**A higher fixed number for filters, say 20.** It moves the same silent
truncation to a less likely place instead of removing it. A user who pastes 25
words into a filter still gets a wrong list and still no warning.

**Warning the user that the value was truncated.** More code and a new string
in every locale, to explain a limitation rather than lift it.

# Tests

| Test | What it proves |
|---|---|
| `SearchTest#test_fetcher_should_use_no_more_than_five_tokens` | the search engine keeps its cap by default — the regression guard for this patch |
| `SearchTest#test_fetcher_should_use_every_token_with_a_nil_token_limit` | a caller can lift the cap, which is what the filter does |
| `Redmine::Search::Tokenize#test_tokenize_should_not_limit_the_number_of_tokens` | the tokenizer itself no longer truncates |
| `QueryTest#test_sql_contains_should_not_limit_the_number_of_tokens` | `~` with five words finds issue 12 and with six words does not — both halves in one test |
| `QueryTest#test_sql_contains_should_not_limit_the_number_of_tokens_for_contains_any_of` | `*~` with six words finds the issue that matches only the sixth |
| `QueryTest#test_filter_any_searchable_should_not_limit_the_number_of_tokens` | the same for `Any searchable text`, the filter that goes through the engine |
| `SearchHelperTest#test_tokens_to_question` | the rebuilt question tokenizes back to the tokens it was built from, quoted phrases included |
| `SearchControllerTest#test_search_should_apply_issues_filter_on_the_tokens_the_search_used` | the *Apply issues filter* button carries five tokens, not six |

**Evidence (INV-8 — figures, not claims):**

«EVIDENCE_BLOCK»

# Live verification (G9)

Exercised by hand in a real Redmine at `http://127.0.0.1:3000`, seeded by
`tools/dev-seed.rb`. Screenshots in `docs/features/search-token-limit/shots/`.

The seed creates one issue whose subject has seven distinct words, "Pump
alignment survey report northern wind farm", because none of the other seeded
subjects is long enough to give a filter more than five useful tokens.

Every case below uses a six-token filter value in which the **sixth** token is
the one that decides the answer — the first one the old code throws away.
`verify/search-token-limit.mjs` asserts the count on the page, in `MODE=before`
the wrong one and in `MODE=after` the right one, so a picture alone is never
the evidence. `MODE=regression` runs against the first version of this patch
(`cb15bbb64`), which is where the *Apply issues filter* button broke.

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
| Any searchable text `*~` six words, only sixth matches | `before-filter-any-searchable.png` | 0 issues — the filter that goes through the search engine |
| Any searchable text `*~` six words, only sixth matches | `filter-any-searchable.png` | 1 issue |
| *Apply issues filter* after a titles-only search of six words | `apply-issues-filter.png` | the search page counts 1 result and the button opens a list with 1 issue |

Failure paths verified:

| Case | Screenshot | Expected | Observed |
|---|---|---|---|
| Global search, six words, "all words", sixth is nonsense | `before-search-still-capped.png` | 1 result: the cap drops the sixth token | 1 result |
| The same search after the change | `search-still-capped.png` | still 1 result, still the same five highlighted tokens | 1 result, five tokens highlighted |
| The *Apply issues filter* button on the **first** version of this patch | `regression-apply-issues-filter.png` | the defect F02 describes: a page reporting one result above a button that opens an empty list | "Results (1)" and 0 issues behind the button |
| Filter present but with no match at all (`~ zzz`) | covered by `filter-contains.png` | empty list, not an error | empty list |

The script also fails if the filter is not actually on the page, so an empty
list caused by a filter that never applied cannot pass as a fix.

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
| "The five-token limit is there for performance." | It is, for the search engine, and it stays there as the default. This patch moves it from `Tokenizer` to `Fetcher`, which is where it was written and where the cost is tokens × searchable classes × projects. A text filter is one `LIKE` per token on one column of one table. |
| "Unbounded tokens in a filter can be slow." | Only for the `OR` operators, and here are the figures. Measured on PostgreSQL «PGVER», «NISSUES» issues, `Subject` filter, warm: «PERFTABLE_INLINE». `~` and `!~` combine with `AND`, so PostgreSQL abandons a row at the first condition that fails and the cost does not grow with the token count. `*~`, `^` and `$` combine with `OR`, so a non-matching row is tested against every condition and the cost is tokens × rows. That asymmetry is the honest answer, not "the user waits for it themselves" — the requester waits, but the database CPU is shared. Unbounded token counts from user input are not new here: `Principal.like` (`app/models/principal.rb`) already builds one `LIKE` pair per token of `params[:q]`, with no cap, and it is reached from the watchers and members autocompletes. |
| "Can a request amplify that?" | A filter value travels in the query string, so roughly a thousand tokens fit in an 8 KB request line, and that is the 1000-token row above. The same is true today of `Principal.like`. If core wants a bound on filter input, it belongs on the filter value in `Query#validate_query_filters`, where it would apply to every operator and every filter, rather than on the tokenizer where it silently changes the answer instead of refusing the question. |
| "What about statement size and bind parameters?" | `sql_contains` builds the condition through `sanitize_sql_for_conditions`, which inlines the values, so the statement that reaches the driver carries **zero** bind parameters — PostgreSQL's and MySQL's 65,535-placeholder limits are not in play at any token count. Statement length grows about «BYTESPERTOKEN» bytes per token: «SQLLEN». Against PostgreSQL's 1 GB and MySQL's default 64 MB `max_allowed_packet` that is nowhere near a ceiling; SQLite's default `SQLITE_MAX_SQL_LENGTH` of 1,000,000 bytes would be reached at roughly «SQLITETOKENS» tokens, which does not fit in a request line and could only be stored in a saved query. |
| "This changes behaviour in a stable release." | It changes behaviour in trunk. Text filters with more than five words return a different set than in 7.0.0, and that is the point of the fix. No test in trunk asserts the old behaviour, and the global search is pinned unchanged by a new test. |
| "Then make it configurable, so administrators can choose." | An administrator cannot sensibly choose how many of a user's keywords to ignore. A setting also has to sit on one settings tab while affecting both the filters and the global search — the earlier patch on #43701 put it on Issues, which is wrong for the search engine half. See "Alternatives considered". |
| "Was the limit not deliberate for filters?" | No. Before r21238 the tokenizing and the `slice! 5..-1` were inline in `Fetcher#initialize`; that commit moved the block verbatim into `Tokenizer` so filters and the autocomplete could reuse the tokenizing. Nothing in #35148 discusses a term limit for filters. |
| "Why not fix it in `Query.tokenized_like_conditions` instead?" | That would leave a shared tokenizer whose contract is "the search engine's first five", and the next reuse would inherit the same surprise. `Issue.like`, used by the issue autocomplete, is already the second such caller. |
| "Why does `Any searchable text` get the exception and the search box not?" | Because they cost different things. `sql_for_any_searchable_field` builds a fetcher over `['issue']` in the query's own projects; the search box builds one over every registered searchable class in every project the user can see. The option makes that difference explicit at the call site instead of hiding it in a shared class. |
| "Why did the *Apply issues filter* button need to change?" | Because it hands the question to a filter that no longer truncates while the page above it still searches with five tokens. Passing the tokens the search used keeps the button doing exactly what it does in 7.0.0: opening the list that belongs to the count next to it. |

---

## Submission

- **Issue:** [#43701](https://www.redmine.org/issues/43701) — created
  2026-01-21, tracker *Patch*, status *New*, category *Filters*, no target
  version, **zero notes** (checked again on 2026-09-05 through
  `https://www.redmine.org/issues/43701.json`: `updated_on` is still
  `2026-01-21T14:01:20Z`). This patch replaces the attachment there; the note
  should say why the shape changed.
- **Patches attached:** `patches/search-token-limit/2026-09-05-r25037-feature.patch`.
  One file only: the change adds no user-visible string, so there is no
  locales patch.
- **Made against:** `origin/master` r25037 (`bee32a926`, 2026-09-03)
- **Status:** patch klaar, nog niet ingediend
- **Feedback en wat ermee gebeurde:** de eerste inzending (januari 2026, de
  instelling-variant) kreeg in zeven maanden geen enkele reactie.

## GEOxyz

- **Commits op `7.0-stable-GEOxyz`:** `1c85728aa` (het oorspronkelijke ontwerp)
  + «GEOXYZ_COMMIT» (de herziening van ronde 2: de optie op `Fetcher`, het
  filter `any_searchable`, en de knop)
- **Suites daar groen:** «GEOXYZ_SUITE»
- **`nl.yml` toegevoegd:** n.v.t. — geen nieuwe strings
- **`tools/check-geoxyz-branch.sh`:** «GEOXYZ_CHECK»
- **Wanneer kan deze commit vervallen?** Een geaccepteerde trunk-patch komt in
  7.1 of later, nooit in 7.0-stable. Dus: pas als GEOxyz naar de release gaat
  die deze fix bevat, ten vroegste 7.1.0.

## Found but not fixed

- **«FAILNOTE»**
- **De `max_tokens:` keyword-parameter in de 5.1-patch en in de port
  (`cd60c0b63`) wordt door geen enkele caller doorgegeven.** Dode API. Niet
  gerepareerd maar vervallen: dit ontwerp heeft de parameter niet nodig.
- **`Query.tokenized_like_conditions` valt terug op `[value]` als het
  tokeniseren niets oplevert** (`tokens = [value] unless tokens.present?`).
  Dat betekent dat een filter op één teken (`~ a`) de ruwe waarde gebruikt in
  plaats van geen enkele voorwaarde. Correct gedrag, maar het staat los van
  deze patch en is niet aangeraakt (INV-1).
- **Er is nergens een bovengrens op de lengte van een filterwaarde.**
  `Query#validate_query_filters` valideert geen lengte voor `:text` en
  `:string`, dus een filterwaarde van duizend woorden wordt gewoon aanvaard —
  vóór deze patch net zo goed, alleen werden de woorden na het vijfde stil
  genegeerd. Als core daar een grens op wil, hoort die op de filterwaarde en
  niet op de tokenizer: dan weigert Redmine de vraag in plaats van hem stil
  anders te beantwoorden. Buiten scope van deze patch (INV-1), maar het is het
  eerste wat een committer zal vragen, dus het staat ook in de objectietabel.
