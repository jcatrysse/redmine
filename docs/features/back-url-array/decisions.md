# back-url-array — Class A-beslissingen

Opdracht van Jan: 2026-10-07, keuze core-q3 optie A (de fix hoort in core, niet
alleen in de plugin `redmine_inline_edit_issues`).

- **Beslist (autonoom, 2026-10-07):** de fix zit in `ApplicationController#back_url`
  en niet in de aanroepers. Eén regel dekt vier HTTP 500's met dezelfde oorzaak
  (contextmenu van tickets, `back_url_hidden_field_tag`, `cancel_button_tag`,
  `attachments/edit_all`); een guard per aanroeper laat de volgende aanroeper
  dezelfde fout maken.
- **Beslist (autonoom, 2026-10-07):** een niet-string `back_url` geldt als
  **afwezig** (dus terugval op de referer), niet als `.to_s` en niet als "eerste
  element". `.to_s` zou `nil` in `""` veranderen en de referer-terugval voor
  elk verzoek uitzetten; het eerste element nemen is gokken. Een lege string
  houdt zijn huidige betekenis (INV-1).
- **Beslist (autonoom, 2026-10-07):** twee tests, niet één. De contextmenutest
  bewijst het gemelde defect; de timelogtest bewijst dat de fix op het juiste
  niveau zit (de helperpaden), en staat naast de bestaande
  `test_get_edit_should_validate_back_url`.
- **Beslist (autonoom, 2026-10-07):** **niet** meegenomen (INV-1), wel genoteerd
  in `status.md`: de plekken die `params[:back_url]` rechtstreeks lezen
  (`redirect_back_or_default`, `AccountController` 2FA-sessie,
  `IssuesController#redirect_after_create`, `issues/_form.html.erb`,
  `issues/new.html.erb`). Geen ervan geeft een 500 met een array — nagelopen in
  de code en voor `issues/new` en `issues/:id/edit` live geprobed (200).
- **Beslist (autonoom, 2026-10-07):** één patchbestand, geen `-locales.patch`:
  er is geen enkele string.
- **Beslist (autonoom, 2026-10-07):** `7.0-stable-GEOxyz` liep 8 commits achter
  `origin/7.0-stable`; eerst los gemerged en gepusht (`37d718169`), daarna pas de
  featurecommit, zoals CLAUDE.md voorschrijft.
