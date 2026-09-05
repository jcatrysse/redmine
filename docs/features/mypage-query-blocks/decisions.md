# mypage-query-blocks — Class A-beslissingen

Ronde 1 (2026-09-03) staat in `docs/DECISIONS.md`: standaard 3, `:max_occurs`
mag een instellingsnaam zijn, naam en tabblad van de instelling, geen "blok" in
het label, en — inmiddels door Jan zelf herzien met g16b — geen bovengrens.
Hieronder ronde 2, 2026-09-05.

- **Beslist (autonoom, 2026-09-05):** de grens wordt **geweigerd in het
  formulier**, niet stilzwijgend bijgeknipt. `Setting.validate_all_from_params`
  is waar Redmine dit al doet — `default_issue_due_date_offset` weigert daar een
  negatief getal met `activerecord.errors.messages.greater_than_or_equal_to` —
  en die drie foutteksten bestaan in alle vijftig localebestanden, dus er komt
  geen vertaalwerk bij (INV-5, INV-6). Het alternatief, klemmen zoals
  `MyHelper#render_timelog_block` doet, laat het formulier iets anders tonen dan
  wat er draait; dat was precies review-F03.
- **Beslist (autonoom, 2026-09-05):** de ondergrens is **0**, niet 1. Nul is de
  waarde die note-5 op #27313 vraagt ("geen nieuwe eigen zoekopdrachten meer")
  en hij verwijdert niets: renderen leest `max_occurs` nergens, dus blokken die
  er al staan blijven staan. Bewezen door
  `test_add_issuequery_block_with_the_maximum_set_to_zero_should_error` plus
  `select-zero-maximum.png`.
- **Beslist (autonoom, 2026-09-05):** de bovengrens staat als constante
  `Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS` in `lib/redmine/my_page.rb`, naast de
  blokkentabel die hij begrenst, en niet als los getal in `setting.rb`. Zo staan
  de validatie en de blokdefinitie op één plek. **Welk getal** het moet zijn is
  geen Class A-keuze; die staat als open keuze voor Jan in `docs/DECISIONS.md`.
- **Beslist (autonoom, 2026-09-05):** `MyPage.max_occurs` gebruikt
  `blocks.fetch(block, {})` in plaats van `blocks[block]`. Het is nu publieke
  API en een blok-*id* (`issuequery__1`, de vorm die `find_block` wel accepteert)
  gaf een `NoMethodError` (review F06). Eén woord verschil, en het zet de `|| 1`
  die er al stond in zijn recht.
- **Beslist (autonoom, 2026-09-05):** het niet-discriminerende
  `test_page_should_render_issuequery_blocks_over_a_lowered_maximum` blijft
  staan en wordt in het dossier **als bewaker gelabeld**, met een tweede test
  ernaast die de verlaagde grens wél vastpint. Weghalen zou de bescherming tegen
  een toekomstige wijziging die blokken wél laat verdwijnen weggooien; hem als
  bewijs presenteren was de fout (review F05).
- **Beslist (autonoom, 2026-09-05):** de meettabel voor note-9 wordt opnieuw
  gemeten op **Redmine's eigen testfixtures** in plaats van op
  `tools/dev-seed.rb`. Een committer die het nameet heeft die fixtures, niet
  onze seed; absolute getallen die hij niet reproduceert kosten de hele note
  geloofwaardigheid (review F04).
- **Beslist (autonoom, 2026-09-05):** de commitboodschap wordt kort. Van de
  laatste veertig trunk-commits hebben er 23 alleen een onderwerpregel en de
  rest vier tot zeven regels; de oorspronkelijke boodschap van 22 regels viel
  daar ver buiten, en de uitleg hoort in de note op het issue.
