# EXCEPTIONS — bewust overtreden regels, met de prijs erbij

> Gedeeld tussen alle sessies. Append-only, en **altijd via
> `tools/append-note.sh docs/exceptions.md`** — die haalt eerst binnen wat een
> andere sessie toevoegde en zet jouw blok eronder.
>
> Vastgelegd op 2026-09-05 (Jans keuze g13, punt 4).

Een invariant of een verboden constructie mag één keer per feature bewust
overtreden worden. Wat niet mag is dat stil doen. Ronde 1 vond dat twee keer:
`revision-branches` roept Git aan per rij in een view-loop — een regel uit de
verbodstabel — en `mypage-query-blocks` laat een instelling zonder bovengrens
staan. Beide zijn verdedigbaar, beide stonden nergens als keuze opgeschreven,
en een reviewer moest dus zelf uitzoeken of het een beslissing was of een
vergissing.

Dit bestand is die plek. Eén regel per uitzondering.

## Wanneer een uitzondering geldig is

Alle vier, anders is het geen uitzondering maar een defect:

1. **Precies één regel** wordt genoemd — een INV-nummer of een rij uit de
   verbodstabel in `CLAUDE.md`. "De code is nu eenmaal zo" is geen regel.
2. **Het alternatief staat erbij, met wat het kost.** Gemeten waar dat kan.
   Zonder alternatief is er niets afgewogen.
3. **Wie het besliste staat erbij.** Class A mag je zelf, mits de kosten
   gemeten zijn; alles wat Jan later ziet in de issuetekst is Class B en dus
   van hem.
4. **Het dossier verwijst ernaar**, in "Anticipated objections", met hetzelfde
   antwoord. Een reviewer op redmine.org leest dit bestand niet — hij leest het
   issue, en daar hoort het bezwaar al beantwoord te staan.

Een uitzondering geldt voor **één feature**, nooit in het algemeen. Wordt
dezelfde uitzondering voor de derde keer aangevraagd, dan klopt de regel niet
en is het een framework-wijziging in plaats van een uitzondering.

Deze twee kunnen nooit: **INV-7** (een test uitzetten of verzwakken om groen te
worden) en **INV-8** (bewijs zonder cijfers). Daar bestaat geen afweging voor.

## De regels

| Id | Regel | Slug | Wat er bewust gebeurt | Alternatief en wat het kost | Beslist | Datum |
|---|---|---|---|---|---|---|
| — | — | — | *nog geen uitzonderingen vastgelegd* | — | — | — |

Eerstvolgende die hier hoort: `revision-branches` (Jans keuze g12) — de
SCM-aanroep per rij in een view-loop, met de bovengrens die daarbij hoort.
Die regel schrijft de sessie die die slug claimt, niet deze.
| E-01 | INV-1 (minimal diff: no moving of adjacent code) | `wiki-export-attachments` | `wiki_pages_to_zip` en `archived_wiki_page_filename`, twee bestaande methodes uit #43978, verhuizen ongewijzigd van `WikiController` naar `lib/redmine/export/zip/wiki_zip_helper.rb`, en de `(n)`-lus van `Attachment.archive_attachments` wordt `Attachment#archived_filename` | Alles in de controller laten: kleinere diff, maar zes private methodes met een boomwandeling en ZIP-tijdstempels in een controller waar Redmine dat onder `lib/redmine/export/` bewaart; de kans op "verplaats dit naar lib/" als reviewfeedback kost een tweede verificatieronde. De lus kopiëren: 14 regels, twee eigenaren van dezelfde regel, en de botsingsfix op één van de twee plekken | Jan, g16c (verhuizing); Class A voor de lus, review F04 | 2026-09-05 |
