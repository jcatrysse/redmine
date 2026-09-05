---
slug: wiki-export-attachments
feature: Wiki-ZIP genest naar de wikiboom + bijlagen als exportoptie
commit_51: 3c3e9368e
geoxyz: live
geoxyz_commit: 7006c4f00
upstream: patch klaar
patch: patches/wiki-export-attachments/2026-09-05-r25037-{feature,locales}.patch
issue:
---

# wiki-export-attachments — status

## Waar het staat

Ronde 2 af (2026-09-05). De review van 2026-09-03 vond twaalf punten
(`docs/review/findings/2026-09-03-wiki-export-attachments-claude-opus5.md`),
waaronder twee blockers; alle twaalf hebben een `Resolution:`-regel. De
patchbranch is opnieuw opgebouwd uit het gekozen ontwerp op trunk r25037
(één commit, `f434bff64`), de twee patchbestanden zijn daaruit geëxporteerd, en
`7.0-stable-GEOxyz` heeft dezelfde fix als tweede commit (`7006c4f00`, bovenop
`28c618860`). Er is nog **geen issue** op redmine.org: dit wordt een follow-up
van [#43978](https://www.redmine.org/issues/43978), en dat issue moet Jan
aanmaken. Ronde 3 (blinde herreview) is nog niet gedaan.

## Wat het doet

De ZIP-export van een wiki volgt nu de wikiboom — één map per pagina, genest
onder zijn ouder — in plaats van alles plat naast elkaar te zetten. Een vinkje
in het exportkeuzevenster stopt de bijlagen van elke pagina in diezelfde map,
zodat een verwijzing als `!diagram.png!` klopt zodra je het archief uitpakt.
Een bijlage die heet als de pagina zelf of als een kindpagina krijgt een
`(1)`-suffix in plaats van de paginatekst of de kindmap te verdringen.

## Bewijs

- Geraakte suites samen, op de patch: 173 runs, 814 assertions, 0 failures,
  0 errors, 4 skips (ImageMagick en pandoc ontbreken in het image)
- Volledige suite met patch (`test:all`): 5991 runs, 31764 assertions, 27 failures, 2 errors, 92 skips in 875 s
- Volledige suite op schone trunk r25037: 5977 runs, 31710 assertions, 27 failures, 2 errors, 92 skips in 855 s, faalnamen identiek: The 29 failing test names are identical on both runs (`diff` of the sorted lists is empty): all of them are the `Repository::Subversion` validation failures of an image without `svn`, `hg`, `bzr` or `cvs` (see "Found but not fixed"). The 14 extra runs on the patch are the 12 new functional tests and the 2 new unit tests.SHORT
- Volledige suite op `7.0-stable-GEOxyz`: 6088 runs, 32244 assertions, 0 failures, 0 errors, 39 skips in 889 s — volledig groen, gemeten op de gepushte tip
- RuboCop op de 7 gewijzigde Ruby-bestanden: 0 (baseline 0). Op de
  GEOxyz-branch: 1, baseline 1 — `Rails/StrongParametersExpect` op
  `wiki_controller.rb:369`, een regel die niet in de diff zit en op
  `7.0-stable` al zo staat.
- `bin/rails zeitwerk:check`: schoon op beide branches
- Rood op oude code: 10 van de 14 functionele zip-tests rood op schone trunk
  (7 failures, 3 errors); op de eerste versie van de patch precies de twee
  botsingstests (1 failure, 1 error); beide unit tests rood op trunk
  (`NoMethodError`, `NameError`)
- `tools/check-patch-clean.sh`: PASS (5 checks, waaronder branch = patchbestand) · `tools/check-geoxyz-branch.sh`: FAIL op lint alleen — 1 offence, `Rails/StrongParametersExpect` op `wiki_controller.rb:369`, een regel van upstream die al vóór deze sessie op `origin/7.0-stable-GEOxyz` faalde (baseline 1, na 1; niet in de diff); merge met upstream, AI-traces en locales: ok
- Screenshots: 12 in `shots/`, gelezen: ja. Archieven naast het dossier: 4,
  waaronder het voor/na-paar `before-fix-zip-with-attachments.zip` /
  `zip-with-attachments.zip` voor de naambotsing

## Wat Jan nog moet doen

Maak een nieuw issue op redmine.org als follow-up van
[#43978](https://www.redmine.org/issues/43978) en hang er
`patches/wiki-export-attachments/2026-09-05-r25037-feature.patch` en
`-locales.patch` aan. Draai vlak daarvoor
`tools/check-patch-clean.sh wiki-export-attachments --submit`; als trunk
intussen verder is, ververst een sessie de patch eerst (g05). De Engelse
issuetekst staat kant-en-klaar in `dossier.md` vanaf "The problem". Het
argument dat erbij hoort: de indiener van #43978 liet bijlagen bewust weg
omdat ze drie ontwerpvragen opwerpen (archiefstructuur, naamconflicten,
verwijzingen in de tekst) — het dossier beantwoordt die drie, en het
voor/na-archiefpaar toont het naamconflict dat de geneste indeling zelf
oplevert.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Trunk heeft sinds r24605 (#43978, april 2026) al een **platte** ZIP-export.
  Daarop voortbouwen, niet ernaast bouwen.
- De ZIP is **altijd** genest, ook zonder bijlagen (Jans beslissing 2026-09-01,
  K-02). Niet opnieuw wegen of er twee indelingen moeten zijn.
- De keuze bijlagen ja/nee gaat via het **exportkeuzevenster**, niet via een
  tweede link (Jans beslissing, optie B). Bijlagen altijd meesturen kon niet:
  `bulk_download_max_size` zou de wiki-export dan helemaal kunnen laten falen.
- **Geen `attachments_visible?`-controle** op de export (Jan, g14): binnen een
  project is er geen leesrecht per pagina, `:export_wiki_pages` op het project
  volstaat. Het dossier legt uit waarom `download_all` die controle wél doet en
  dit niet.
- **De archiefopbouw staat in `lib/redmine/export/zip/`** als
  `Redmine::Export::ZIP::WikiZipHelper` (Jan, g16c). Verplaatst, niet
  herschreven; de twee methodes van #43978 verhuizen mee. Dat is de ene plek
  waar de patch regels raakt die de feature niet strikt nodig had, vastgelegd
  in `docs/exceptions.md`.
- **`Attachment#archived_filename`** is de `(n)`-lus uit `archive_attachments`,
  uitgelicht zodat beide archieven dezelfde regel gebruiken. Niet terugdraaien
  naar een kopie in de wiki-export.
- Een bijlage met bestandsnaam `..` is een gat in `Attachment#sanitize_filename`,
  niet in deze patch, en staat in het dossier onder "Found but not fixed".
- De TXT-export van de hele wiki (`wiki-export-txt`) is vervallen — GEOxyz
  gebruikt hem niet.

## Volgende stap voor een sessie

Af tot ronde 3 — niets te doen behalve Jans handeling hierboven. Bij ronde 3:
een verse reviewer leest `patch/wiki-export-attachments` koud, zonder eerst de
ronde-1-bevindingen te lezen.
