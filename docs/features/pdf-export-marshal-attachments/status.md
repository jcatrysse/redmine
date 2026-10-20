---
slug: pdf-export-marshal-attachments
feature: issue-PDF met een tabel geeft 500 ("can't dump hash with default proc") zodra rollen van een gebruiker van het issue gecachet zijn
commit_51: -
geoxyz: todo
geoxyz_commit: f59238143
upstream: ontworpen
patch: patches/pdf-export-marshal-attachments/2026-10-20-r25262-feature.patch
issue:
---

# pdf-export-marshal-attachments — status

## Waar het staat

In uitvoering (2026-10-20). Fix en tests staan op `patch/pdf-export-marshal-attachments`
(gepusht) en als commit `f59238143` lokaal op `7.0-stable-GEOxyz` (nog niet gepusht:
de volledige suites lopen nog). G1, G4, G6 en G9 zijn af; G3 en G8 wachten op de suites.

## Wat het doet

Een issue of wikipagina met een tabel kan weer naar PDF geëxporteerd worden, ook als
de rollen van de auteur of toegewezene in hetzelfde verzoek al berekend werden.

## Bewijs

- Volledige suites: lopen nog
- `pdf_test.rb`: 7 runs, 53 assertions, 0 failures, 0 errors (patch en GEOxyz); zonder fix 2 errors
- RuboCop op de gewijzigde bestanden: 0 (baseline 0), op beide kanten
- `tools/check-patch-clean.sh`: PASS
- Screenshots: 9, gelezen: ja

## Wat Jan nog moet doen

Nog niets: de feature is niet af.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

Zie `decisions.md` en het dossier.

## Volgende stap voor een sessie

Suites afwachten, GEOxyz pushen, gates G3/G8 en symmetrie afronden.
