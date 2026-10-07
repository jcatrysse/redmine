---
slug: back-url-array
feature: Geen HTTP 500 meer als back_url als lijst (back_url[]=...) binnenkomt
commit_51: -
geoxyz: live
geoxyz_commit: 0f4317246
upstream: patch klaar
patch: patches/back-url-array/2026-10-07-r25136-feature.patch
issue:
---

# back-url-array — status

## Waar het staat

Af, op het issue na. Eén regel in `ApplicationController#back_url` plus twee
tests, op trunk (`patch/back-url-array`) en letterlijk dezelfde commit op
`7.0-stable-GEOxyz`. Alle gates gedraaid, cijfers hieronder. Het enige wat
`check-patch-clean.sh --submit` tegenhoudt is de mirror: `origin/master` loopt
41 commits achter echte trunk (K-19/K-20). Met de hand nagegaan dat de patch
ook op echte trunk r25215 (`713d29813`) applyt.

## Wat het doet

Een verzoek met `back_url[]=...` of `back_url[x]=...` gaf HTTP 500 op vier
plekken in Redmine 7, zonder plugins: het contextmenu van de ticketlijst ging
niet open, en de formulieren voor een nieuwe tijdregistratie, een nieuwe versie
(en elk formulier met `back_url_hidden_field_tag`/`cancel_button_tag`) crashten.
Nu telt zo'n waarde als "geen back_url", en valt Redmine terug op de referer.

## Bewijs

- Volledige suite met patch: `test:all` 6102 runs, 32303 assertions, 27 failures, 2 errors, 82 skips
- Volledige suite op schone trunk: 6100 runs, 32296 assertions, 27 failures, 2 errors, 82 skips; faalnamen identiek: ja (29 namen, `diff` leeg). Allemaal repository/changeset-tests: de bekende baseline van de verouderde mirror (json-gem, #44428, zie `docs/runbook.md`)
- Volledige suite op `7.0-stable-GEOxyz`: `test:all` 6190 runs, 32656 assertions, 0 failures, 0 errors, 28 skips (op `eb4847a34`; na de replay boven `6abebe886` als `0f4317246` de geraakte suites plus `asset_path_test.rb` opnieuw: 150 runs, 0 failures, 0 errors)
- Nieuwe tests rood op de oude code, op trunk én op GEOxyz:
  `NoMethodError: undefined method 'start_with?' for an instance of Array`
  (contextmenu) en `TypeError: no implicit conversion of Array into String`
  (timelog); groen met de fix.
- RuboCop op de drie gewijzigde bestanden: 0 (baseline 0)
- `tools/check-patch-clean.sh`: PASS · `--submit`: FAIL, alleen op de mirror
  (41 commits achter) ·
  `tools/check-geoxyz-branch.sh`: alles ok voor deze feature (lint 8 = baseline 8, `0f4317246` geregistreerd); de run faalt op één punt dat niet van ons is: `6abebe886` van de parallelle sessie `asset-paths-gem-order`, die zijn eigen `status.md` nog moet schrijven ·
  `tools/check-symmetry.sh`: PASS
- Screenshots: 8 (4 before, 4 after), gelezen: ja. Dezelfde after-run ook
  tegen `7.0-stable-GEOxyz`: 7 van 7 checks ok.

## Wat Jan nog moet doen

Mirror syncen (`docs/runbook.md`, 41 commits achter), dan op redmine.org een
**Defect** aanmaken: titel "Error 500 when back_url is passed as an array",
tekst = de Engelse secties van `docs/features/back-url-array/dossier.md` (The
problem t/m Tests), met `patches/back-url-array/2026-10-07-r25136-feature.patch`
en de screenshots `before-context-menu-array.png` / `context-menu-array.png`
erbij. Daarna het issuenummer in de front matter zetten.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **De fix hoort in core** — Jans keuze core-q3 optie A, 2026-10-07. De
  plugin `redmine_inline_edit_issues` ving het al op; dat blijft zo tot GEOxyz
  deze commit heeft.
- **In `back_url`, niet per aanroeper**: één regel dekt alle vier de 500's.
- **Niet-string = afwezig**, niet `.to_s` (zou `nil` → `""` maken en de
  referer-terugval overal uitzetten) en niet "eerste element" (gokken).
- **Bewust niet meegenomen (INV-1)**, want geen 500: plekken die
  `params[:back_url]` rechtstreeks lezen — `redirect_back_or_default` (doet al
  `.to_s`, dus een array valt door de validatie en de default wordt gebruikt),
  `AccountController` (2FA bewaart `params[:back_url]` in de sessie en geeft het
  terug aan `redirect_back_or_default`), `IssuesController#redirect_after_create`
  (`.presence`, wordt als URL-parameter doorgegeven), `issues/_form.html.erb`
  (zet een array als waarde van het verborgen veld) en `issues/new.html.erb`
  (alleen een aanwezigheidscheck). `issues/new` en `issues/:id/edit` met
  `back_url[]` live geprobed: 200. Kandidaat voor een aparte opruimpatch, niet
  voor deze.
- **Oorsprong**: zichtbaar sinds #35616 (r23938, 2025-09-04), dat `back_url` aan
  `recognize_path` gaf; de helper-500's bestonden al eerder.
- **Wanneer kan de GEOxyz-commit weg?** Als GEOxyz een release draait met de
  trunk-fix. Als defect kan hij naar 7.0-stable gebackport worden; dan bij de
  eerste 7.0.x die hem bevat, anders bij 7.1.

## Volgende stap voor een sessie

Af — niets te doen tot Jan het issue heeft aangemaakt; dan alleen het nummer
invullen en, als trunk intussen bewoog, `check-patch-clean.sh --submit` opnieuw.
