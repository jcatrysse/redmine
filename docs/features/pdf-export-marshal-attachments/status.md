---
slug: pdf-export-marshal-attachments
feature: issue-PDF met een tabel geeft 500 ("can't dump hash with default proc") zodra rollen van een gebruiker van het issue gecachet zijn
commit_51: -
geoxyz: live
geoxyz_commit: f59238143
upstream: patch klaar
patch: patches/pdf-export-marshal-attachments/2026-10-20-r25262-feature.patch
issue:
---

# pdf-export-marshal-attachments — status

## Waar het staat

Af op 2026-10-20, klaar om in te dienen. Een defect, geen feature: rbpdf kopieert bij
een tabelkop het hele PDF-object met Marshal, en via de bijlagen ging daar het issue
met zijn auteur en toegewezene mee. Zodra die gebruikers rollen gecachet hebben
(`Hash.new {...}` in `User#membership`), faalt de kopie en wordt de export een 500.
De fix (`ITCPDF#objclone`) deelt de bijlagen met de kopie in plaats van ze te kopiëren.
Patch op `patch/pdf-export-marshal-attachments` (`a9ec91a73`), dezelfde wijziging op
`7.0-stable-GEOxyz` (`f59238143`), beide gepusht. Geen redmine.org-issue gevonden.

## Wat het doet

Een issue (ook in de issuelijst-PDF met omschrijving) of wikipagina met een tabel kan
weer naar PDF, ook als in hetzelfde verzoek de rollen van een gebruiker van het issue
al berekend werden (core doet dat via `Issue#notified_users`, plugins vaak ook).

## Bewijs

- Volledige suite met patch (`test:all`, trunk r25262): 6331 runs, 33062 assertions, 29 failures, 2 errors, 159 skips in 753 s
- Volledige suite op schone trunk r25262: 6329 runs, 33055 assertions, 29 failures, 2 errors, 159 skips in 714 s. Faalnamen identiek op twee systeemtests na, één per kant (`StickyIssueHeaderSystemTest#test_sticky_issue_header_appears_on_scroll` alleen op de patch, `IssuesSystemTest#test_update_issue_with_form_update_should_keep_newly_added_attachments` alleen op schoon); beide apart opnieuw gedraaid en groen (2/2 en 1/1): timingflakes, drie suites liepen tegelijk. De overige 29 zijn de bekende repository-, API- en CommonMark-fouten van dit image. De 2 extra runs zijn de 2 nieuwe tests.
- Volledige suite op `7.0-stable-GEOxyz` (`f59238143`): 6354 runs, 33097 assertions, 0 failures, 0 errors, 99 skips in 755 s
- `pdf_test.rb`: 7 runs, 53 assertions, 0 failures op beide kanten; zonder fix 2 errors (`RBPDFError: writeHTMLCell Error`) op beide kanten; met halve fix (kopie zonder `@attachments`) faalt de tweede test
- RuboCop 1.91.0 op de gewijzigde bestanden: 0 (baseline 0), op beide kanten
- `tools/check-patch-clean.sh`: PASS · `tools/check-geoxyz-branch.sh`: PASS
- `tools/check-symmetry.sh`: FAIL op één punt dat het script niet kan uitdrukken: `itcpdf.rb` bestaat niet op 7.0-stable (trunk r25047 verplaatste `ITCPDF`). Met de hand gecontroleerd: de toegevoegde regels in `itcpdf.rb` (patch) en `pdf.rb` (GEOxyz) zijn identiek, de testregels ook (`diff` van beide `git diff`-uitvoeren is leeg)
- Patch past op echte trunk r25284 (mirror 18 commits achter, geen ervan raakt de PDF-laag)
- Screenshots: 9 (before, after, geoxyz), gelezen: ja

## Wat Jan nog moet doen

Op redmine.org een Defect aanmaken (categorie PDF export) met de Engelse tekst uit
`docs/features/pdf-export-marshal-attachments/dossier.md` en
`patches/pdf-export-marshal-attachments/2026-10-20-r25262-feature.patch` erbij,
met `before-issue-pdf.png` en `issue-pdf.png` als voor/na. Vooraf de mirror syncen
(18 commits achter) en `tools/check-patch-clean.sh --submit pdf-export-marshal-attachments` draaien.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Ontwerp: `objclone` overriden, niet `marshal_dump`/`marshal_load` + `rollbackTransaction` (het voorstel van de coördinator). Eén haak, alleen de transactiekopie, en rbpdf's eigen rollback herstelt `@attachments` omdat de kopie dezelfde referentie draagt. Beide doorstaan dezelfde tests.
- `attachments.to_a` helpt niet: de records houden hun `container`.
- Core alleen triggert dit niet in een kale PDF-request; wel na `Issue#notified_users` of `visible?(user)` op een niet-admin auteur/toegewezene. Een admin vult de rollencache nooit (`allowed_to?` kortsluit).
- De tweede test hangt aan `set_y(270)`: 266–270 geeft precies één rollback, vanaf 272 geen. `assert_equal 2, pdf.get_page` bewaakt dat.
- G9 gebruikt een wegwerp-plugin (niet gecommit, broncode in het dossier) die `@issue.notified_users` aanroept in `IssuesController#show`; `?no_prime=1` slaat dat over.
- 5.1 krijgt een hotfix-initializer van de coördinator; niet het werk van deze feature.

## Volgende stap voor een sessie

Af — niets te doen tot Jan het issue aanmaakt.
