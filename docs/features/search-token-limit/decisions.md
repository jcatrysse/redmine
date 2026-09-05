# search-token-limit — Class A-beslissingen

Eén regel per beslissing die de sessie zelf mocht nemen: best practice, een
gevestigde Redmine-conventie, of het framework besliste het al.

## 2026-09-05, ronde 2

- **De optie heet `:token_limit` en heeft 5 als standaard, in plaats van een
  vlag die de grens opheft.** Zo verandert er niets voor een plugin die zelf een
  `Fetcher` bouwt, en staat het verschil tussen de twee aanroepers als getal in
  de code in plaats van als vermoeden.
- **De optie wordt uit `options` verwijderd (`delete`), net als `:cache`.** Wat
  erin blijft staan gaat mee in de cachesleutel en naar
  `search_result_ranks_and_ids`; een Fetcher-eigen optie hoort daar niet in.
- **De knop "Apply issues filter" krijgt de tokens die de zoekmachine gebruikt
  heeft, niet de hele vraag.** Dat is het enige antwoord dat de knop laat doen
  wat hij vandaag in trunk doet; de andere kant op (het filter weer aan vijf
  woorden binden) is precies de bug. Bevinding F02 liet de keuze aan deze
  sessie.
- **De hersamenstelling zit in een helper (`tokens_to_question`) en niet in de
  handtekening van `issues_filter_path`.** Die handtekening staat in zes
  bestaande assertions in `search_helper_test.rb`; hem veranderen zou zes regels
  ruis in de diff zetten zonder dat er iets beter van wordt (INV-1).
- **Een token met een spatie erin wordt weer tussen aanhalingstekens gezet.**
  `Tokenizer` maakt van `"phrase one"` één token; zonder de aanhalingstekens
  terug zou het filter twee losse woorden zoeken en dus iets anders vragen dan
  de zoekpagina.
- **De `~`-test bewijst nu beide helften in één body** (vijf woorden vindt issue
  12, zes woorden vindt niets), in plaats van alleen de lege verzameling —
  bevinding F05.
- **Het commentaar dat bij de limiet hoorde is vervangen door het waarom, niet
  meeverhuisd.** `# no more than 5 tokens to search for` boven een regel die
  `first(5)` zegt, herhaalt de regel; wat een lezer nodig heeft is waarom de
  grens juist in `Fetcher` hoort. Bevinding F06; INV-3 staat een commentaar dat
  een niet-vanzelfsprekend waarom vastlegt uitdrukkelijk toe.
