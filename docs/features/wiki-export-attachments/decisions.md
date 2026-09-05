# wiki-export-attachments — Class A-beslissingen

Ronde 1 (2026-09-01/02) staat in `docs/DECISIONS.md` (K-02 en de keuze voor
het exportkeuzevenster). Hieronder ronde 2, 2026-09-05.

- **Beslist (autonoom, 2026-09-05):** de namespace is
  `Redmine::Export::ZIP::WikiZipHelper`, met `'zip' => 'ZIP'` in
  `config/initializers/zeitwerk.rb`. Dat is de vorm van
  `Redmine::Export::PDF::WikiPdfHelper` en
  `Redmine::Export::Text::VersionsTextHelper`, en het hoofdletteracroniem is
  ook nodig: een map `zip/` zou anders `Redmine::Export::Zip` autovivificeren
  en elke `Zip::…`-verwijzing binnen `Redmine::Export` naar die lege module
  laten wijzen in plaats van naar de gem. `PDF` en `CSV` krijgen in dezelfde
  initializer dezelfde behandeling.
- **Beslist (autonoom, 2026-09-05):** `wiki_page_attachments` en
  `wiki_attachments_too_big?` blijven in de controller. Ze lezen `params` en
  een instelling en beslissen; `AttachmentsController#find_downloadable_attachments`
  houdt dezelfde beslissing ook in de controller. Alleen de archiefopbouw
  verhuist (g16c: "verplaatsen, niet herschrijven").
- **Beslist (autonoom, 2026-09-05):** de `(n)`-lus wordt uit
  `Attachment.archive_attachments` gelicht naar `Attachment#archived_filename`
  in plaats van gekopieerd naar de wiki-export (review F04). Gedragsbehoudend:
  de drie bestaande `archive_attachments`-tests blijven groen zonder wijziging.
  Een kopie zou de botsingsfix (F02/F03) op één van de twee plekken hebben
  gezet.
- **Beslist (autonoom, 2026-09-05):** de gereserveerde namen per map zijn het
  paginabestand plus de kindmappen, gezaaid in de lijst vóór de eerste bijlage
  hernoemd wordt (g03). Eén regel `(n)` voor drie soorten namen, geen aparte
  helper.
- **Beslist (autonoom, 2026-09-05):** een pagina waarvan de ouder niet in de
  meegegeven verzameling zit wordt als wortel behandeld (review F07): één regel
  in `wiki_pages_to_zip`, met een unit test op de helper met een deelverzameling
  van pagina's. Een `parent_id`-cyclus blijft onbehandeld; `validate_parent_title`
  maakt hem onbereikbaar en het dossier noemt hem.
- **Beslist (autonoom, 2026-09-05):** `.sort_by(&:title)` weg (review F08); de
  volgorde is die van de `pages`-associatie (`LOWER(title)`), net als in
  `render_page_hierarchy`.
- **Beslist (autonoom, 2026-09-05):** `test_export_to_zip` asserteert de acht
  letterlijke paden van de fixture-wiki als gesorteerde array (review F05), niet
  een herafleiding; `test_export_to_zip_with_attachments` hangt de bijlage aan
  het kleinkind `Child_1_1` (review F06).
- **Beslist (autonoom, 2026-09-05):** de oude patchbestanden
  `2026-09-01-r24882-*.patch` zijn verwijderd, niet bewaard: ze hebben nooit aan
  een issue gehangen, en `tools/check-patch-clean.sh` vergelijkt élk bestand
  onder `patches/<slug>/` met de branch.
- **Beslist (autonoom, 2026-09-05):** de oude branchtip `2cb6231c7` (het
  afgewezen ontwerp) is met een force push vervangen. Op `patch/<slug>` mag dat
  (`docs/traps.md`, "Op `patch/<slug>` amendeer je"); op `7.0-stable-GEOxyz`
  is de fix een tweede commit.
