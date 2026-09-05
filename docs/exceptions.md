# EXCEPTIONS — bewust overtreden regels, met de prijs erbij

> Gedeeld tussen alle sessies. Append-only, en **altijd via
> `tools/append-note.sh docs/exceptions.md`** — die haalt eerst binnen wat een
> andere sessie toevoegde en zet jouw blok eronder.
>
> Het blok, vijf velden, in deze volgorde:
>
>     ### E-nn — <slug>
>     - **Regel:** <INV-nummer of rij uit de verbodstabel>
>     - **Wat er bewust gebeurt:** ...
>     - **Alternatief en wat het kost:** ...
>     - **Beslist:** <Jan, gNN | Class A, met de meting>
>     - **Datum:** YYYY-MM-DD
>
> Vastgelegd op 2026-09-05 (Jans keuze g13, punt 4).

Een invariant of een verboden constructie mag één keer per feature bewust
overtreden worden. Wat niet mag is dat stil doen. Ronde 1 vond dat twee keer:
`revision-branches` roept Git aan per rij in een view-loop — een regel uit de
verbodstabel — en `mypage-query-blocks` laat een instelling zonder bovengrens
staan. Beide zijn verdedigbaar, beide stonden nergens als keuze opgeschreven,
en een reviewer moest dus zelf uitzoeken of het een beslissing was of een
vergissing.

Dit bestand is die plek. Eén blok per uitzondering, onderaan toegevoegd met
`tools/append-note.sh docs/exceptions.md` — een tabel past niet bij een
append-only bestand (de eerste rij, E-01, kwam op 2026-09-05 onder de
slotalinea terecht in plaats van in de tabel), dus de vorm is een blok met
vaste velden. Neem het hoogste E-nummer dat in het bestand voorkomt en tel er
één bij op; fetch eerst.

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

## De uitzonderingen

Eerstvolgende die hier hoort: `revision-branches` (Jans keuze g12) — de
SCM-aanroep per rij in een view-loop, met de bovengrens die daarbij hoort.
Die schrijft de sessie die die slug claimt.

### E-01 — wiki-export-attachments
- **Regel:** INV-1 (minimal diff: no moving of adjacent code)
- **Wat er bewust gebeurt:** `wiki_pages_to_zip` en `archived_wiki_page_filename`,
  twee bestaande methodes uit #43978, verhuizen ongewijzigd van
  `WikiController` naar `lib/redmine/export/zip/wiki_zip_helper.rb`, en de
  `(n)`-lus van `Attachment.archive_attachments` wordt
  `Attachment#archived_filename`.
- **Alternatief en wat het kost:** alles in de controller laten: kleinere diff,
  maar zes private methodes met een boomwandeling en ZIP-tijdstempels in een
  controller waar Redmine dat onder `lib/redmine/export/` bewaart; de kans op
  "verplaats dit naar lib/" als reviewfeedback kost een tweede
  verificatieronde. De lus kopiëren: 14 regels, twee eigenaren van dezelfde
  regel, en de botsingsfix op één van de twee plekken.
- **Beslist:** Jan, g16c (de verhuizing); Class A voor de lus, review F04
- **Datum:** 2026-09-05

### E-02 — revision-branches
- **Regel:** de rij "an SCM call per row inside a view loop" uit de
  verbodstabel in `CLAUDE.md` (N subprocessen per paginaweergave)
- **Wat er bewust gebeurt:** `app/views/issues/tabs/_changesets.html.erb`
  roept `Changeset#branches` aan per gerenderde revisie, en die vorkt één
  `git branch --no-color --contains`. Eén Git-proces per rij dus. Dat is niet
  te vermijden zonder het antwoord te bewaren, en bewaren is precies wat de
  notes 4 en 17 van #5386 verwerpen: een Git-branch is een pointer, dus een
  verwijderde of force-gepushte branch laat een opgeslagen kopie voorgoed
  verkeerd staan zonder gebeurtenis die dat corrigeert. Sinds 2026-09-05 is de
  lus wél begrensd: `RepositoriesHelper#display_changeset_branches?` laat de
  hele weergave vallen boven `Setting.repository_log_display_limit` revisies
  (standaard 100), en de weergave staat standaard uit.
- **Alternatief en wat het kost:** (a) een databasecache — verworpen door de
  reviewer van het issue zelf, en de reden dat zeven eerdere patches strandden;
  (b) één commando voor de hele pagina — bestaat niet, `git log --format=%h%d`
  beantwoordt een andere vraag (welke refs *op* een commit wijzen), dus het is
  alsnog `--contains` per commit of de graaf in Ruby lopen; (c) de issuetab
  helemaal niet ondersteunen — dat is juist de helft die note 18 als voorbeeld
  noemt (#61) en waar de vraag "zit deze fix al op de releasebranch?" gesteld
  wordt. Gemeten op een fixture-repository van 29 commits: de tab gaat van
  0 subprocessen en 466 ms naar 29 subprocessen en 1007 ms; met de bovengrens
  van 100 is dat het slechtste geval dat nog gerenderd wordt.
- **Beslist:** Jan, g12 (de uitzondering vastleggen plus de bovengrens);
  Class A voor het hergebruiken van `repository_log_display_limit` in plaats
  van een vijfde instelling (INV-6), met de meting hierboven
- **Datum:** 2026-09-05
