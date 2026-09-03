---
slug: wiki-export-attachments
feature: Wiki-ZIP genest naar de wikiboom + bijlagen als exportoptie
commit_51: 3c3e9368e
geoxyz: live
geoxyz_commit: 28c618860
upstream: patch klaar
patch: patches/wiki-export-attachments/2026-09-01-r24882-{feature,locales}.patch
issue:
---

# wiki-export-attachments — status

## Waar het staat

Af. Twee patchbestanden tegen trunk r24882, dezelfde wijziging als commit
`28c618860` op `7.0-stable-GEOxyz`, dossier compleet. Er is nog **geen issue**
op redmine.org: dit wordt een follow-up van
[#43978](https://www.redmine.org/issues/43978), en dat issue moet Jan aanmaken.

## Wat het doet

De ZIP-export van een wiki volgt nu de wikiboom — één map per pagina, genest
onder zijn ouder — in plaats van alles plat naast elkaar te zetten. Een vinkje
in het exportkeuzevenster stopt de bijlagen van elke pagina in diezelfde map,
zodat een verwijzing als `!diagram.png!` klopt zodra je het archief uitpakt.

## Bewijs

- Volledige suite met patch: 5930 runs, 31504 assertions, 27 failures, 2 errors, 92 skips
- Schone trunk r24882: dezelfde 29 faalnamen, `diff` leeg (allemaal SCM-tests
  zonder `svn`/`hg`/`bzr`/`cvs` in het image)
- Volledige suite op `7.0-stable-GEOxyz`: 5921 runs, 31735 assertions,
  0 failures, 0 errors, 39 skips
- Wiki-suite apart: 111 runs, 645 assertions, 0 failures, 0 errors
- RuboCop: 0 (baseline 0)
- `tools/check-patch-clean.sh`: PASS · `tools/check-geoxyz-branch.sh`: PASS
- Screenshots: in `shots/`, gelezen: ja

## Wat Jan nog moet doen

Maak een nieuw issue op redmine.org als follow-up van
[#43978](https://www.redmine.org/issues/43978) en hang er
`patches/wiki-export-attachments/2026-09-01-r24882-feature.patch` en
`-locales.patch` aan. De Engelse issuetekst staat kant-en-klaar in
`dossier.md` vanaf "The problem". Het argument dat erbij hoort: de indiener van
#43978 liet bijlagen bewust weg omdat ze drie ontwerpvragen opwerpen
(archiefstructuur, naamconflicten, verwijzingen in de tekst) — het dossier
beantwoordt die drie.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Trunk heeft sinds r24605 (#43978, april 2026) al een **platte** ZIP-export.
  Daarop voortbouwen, niet ernaast bouwen.
- De ZIP is **altijd** genest, ook zonder bijlagen (Jans beslissing 2026-09-01).
  Niet opnieuw wegen of er twee indelingen moeten zijn.
- De keuze bijlagen ja/nee gaat via het **exportkeuzevenster**, niet via een
  tweede link (Jans beslissing, optie B). Bijlagen altijd meesturen kon niet:
  `bulk_download_max_size` zou de wiki-export dan helemaal kunnen laten falen.
- De TXT-export van de hele wiki (`wiki-export-txt`) is vervallen — GEOxyz
  gebruikt hem niet.

## Volgende stap voor een sessie

Af — niets te doen. Alleen Jans handeling hierboven.
