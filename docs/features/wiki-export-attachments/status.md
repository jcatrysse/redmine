---
slug: wiki-export-attachments
feature: Wiki-ZIP genest naar de wikiboom + bijlagen als exportoptie
commit_51: 3c3e9368e
geoxyz: live
geoxyz_commit: c077d96df + 1fd3343ff + 6078281ff
upstream: patch klaar
patch: patches/wiki-export-attachments/2026-09-09-r25063-{feature,locales}.patch
issue:
---

# wiki-export-attachments — status

## Waar het staat

**Ververst tegen verse trunk op 2026-09-09 (g05, INV-2), en dat was nodig.**
Toen Jan de trunk-mirror synchroniseerde bleek deze patch als enige van de negen
niet meer te applyen: trunk had in `e0e38cb9b` (#44396) een regel toegevoegd aan
dezelfde acroniemhash in `config/initializers/zeitwerk.rb` waar wij
`'zip' => 'ZIP'` in zetten. Beide kanten voegen een regel toe op precies dezelfde
plek, dus er was niets te kiezen: beide gehouden, met onze regel achteraan zodat
de diff tegen de nieuwe trunk minimaal blijft. De branch is opnieuw gebaseerd op
**r25063** (`8de368193`) als één commit **`eed205828`**, en de inhoud is
ongewijzigd — de enige verandering in onze diff is dat het zeitwerk-blok nu om
trunks nieuwe regel heen valt.

**Waarom dat meer werk was dan een rebase.** Diezelfde trunkronde zette
**Rubyzip op 3.6** (`a41077d2a`, #44388), en deze feature *is* de ZIP-export.
Applyen is dan niet genoeg: de helper gebruikt vijf Rubyzip-API's die tussen 2.x
en 3.x konden breken (`Zip.unicode_names=`, `Zip::OutputStream.write_buffer`,
`Zip::Entry.new`, `Zip::DOSTime` en `entry.extra[:universaltime]`). Alle vijf
doen het nog; zie "Bewijs — refresh op r25063".

Ronde 2 af (2026-09-05). De review van 2026-09-03 vond twaalf punten
(`docs/review/findings/2026-09-03-wiki-export-attachments-claude-opus5.md`),
waaronder twee blockers; alle twaalf hebben een `Resolution:`-regel. De
patchbranch is opnieuw opgebouwd uit het gekozen ontwerp op trunk r25037
(één commit, `f434bff64` — sindsdien ververst, zie boven), de twee
patchbestanden zijn daaruit geëxporteerd, en
`7.0-stable-GEOxyz` heeft dezelfde fix als tweede commit (`1fd3343ff`, bovenop
`c077d96df`). Er is nog **geen issue** op redmine.org: dit wordt een follow-up
van [#43978](https://www.redmine.org/issues/43978), en dat issue moet Jan
aanmaken. Ronde 3 (blinde herreview) is nog niet gedaan.

**Ronde 3 is af (2026-09-08).** De blinde herreview
(`docs/review/findings/2026-09-08-wiki-export-attachments-claude-opus5-round3.md`)
vond **geen defect in wat de patch doet**: nul blockers, nul majors, twee minors
en vier nits. Alle zes hebben een `Resolution:`-regel en drie ervan wijzigden
code:

- de overbodige `include ActionView::Helpers::NumberHelper` is weg —
  `ApplicationController` heeft `Redmine::I18n`, en dat brengt `NumberHelper`
  al mee, gemeten op **kale** trunk
- de methodes van `WikiZipHelper` staan op `private`, zodat
  `WikiController.action_methods` weer op trunks eigen **171** staat en
  `wiki_pages_to_zip` en `archived_wiki_page_filename` de zichtbaarheid houden
  die ze in de controller hadden
- de Nederlandse string is **`Met bijlagen`** (Jans keuze K-14, optie A),
  afgeleid uit `label_cross_project_descendants` ("Met subprojecten") — dezelfde
  sleutel waar het Duits al op gebaseerd was

De andere drie waren tekst: een rij over padlengte onder Windows in de
objectietabel, de correctie dat Info-ZIP een `..`-component **hernoemt** naar
`__` in plaats van hem over te slaan, en een blijven staan `SHORT`-token in dit
bestand.

De branch is één commit, en de G9-verificatie is na de codewijzigingen opnieuw
door de browser gereden — inclusief het botsingsgeval, dat nog steeds de
paginatekst op `Wiki/Wiki.txt` zet en de bijlage naar `Wiki/Wiki(1).txt`
hernoemt. De patchbestanden van die ronde
(`2026-09-08-r25037-{feature,locales}.patch`) zijn op 2026-09-09 vervangen door
de r25063-export; zie hierboven.

## Wat het doet

De ZIP-export van een wiki volgt nu de wikiboom — één map per pagina, genest
onder zijn ouder — in plaats van alles plat naast elkaar te zetten. Een vinkje
in het exportkeuzevenster stopt de bijlagen van elke pagina in diezelfde map,
zodat een verwijzing als `!diagram.png!` klopt zodra je het archief uitpakt.
Een bijlage die heet als de pagina zelf of als een kindpagina krijgt een
`(1)`-suffix in plaats van de paginatekst of de kindmap te verdringen.

## Bewijs — refresh op r25063 (2026-09-09)

**Rubyzip 3.6 is het echte risico van deze refresh, dus dat is eerst
uitgezocht.** Een groene suite zegt hier weinig: de helper leunt op vijf
Rubyzip-API's die tussen 2.x en 3.x konden breken. Er is dus een **echt archief
gebouwd** met de helper tegen Redmine's eigen fixtures op rubyzip 3.6.0 en de
inhoud is uitgelezen:

```
entries: 9  (6 of the 9 listed below; the three omitted are the remaining
             fixture pages, each one <page>/<page>.txt like the ones shown)
  Another_page/Another_page.txt                        117 bytes  mtime=2007-03-07 23:18:07
  Another_page/Child_1/Child_1.txt                      38 bytes  mtime=2007-03-07 23:18:07
  Another_page/Child_1/Child_1_1/Child_1_1.txt          25 bytes  mtime=2007-03-07 23:18:07
  CookBook_documentation/CookBook_documentation.txt    101 bytes  mtime=2007-03-06 23:10:51
  CookBook_documentation/ecookbook-gantt.pdf         31620 bytes  mtime=2019-05-11 05:18:19
  Этика_менеджмента/Этика_менеджмента.txt               24 bytes  mtime=2007-03-07 23:18:07
```

Dat dekt alle vijf in één keer: de **hiërarchie** gaat drie niveaus diep, de
**bijlage** staat naast zijn pagina en komt er met de juiste 31620 bytes weer
uit, de **Cyrillische** namen werken (dus `Zip.unicode_names = true` doet het
nog), en de **tijdstempels** zijn de `updated_on` van de pagina's, wat betekent
dat `Zip::DOSTime` en `entry.extra[:universaltime]` het ook nog doen.

**En het downloadpad ook, niet alleen de buffer.** `verify/wiki-export-attachments.mjs`
in `MODE=modal` klikt in een echte browser beide varianten aan en pakt uit:

```
zip-without-attachments.zip        zip-with-attachments.zip
  Wiki/Wiki.txt                      Wiki/Wiki.txt
  Wiki/Child_one/Child_one.txt       Wiki/notes.txt
  Wiki/Child_two/Child_two.txt       Wiki/Child_one/Child_one.txt
  3 files                            Wiki/Child_one/diagram.txt
                                     Wiki/Child_one/diagram(1).txt
                                     Wiki/Child_two/Child_two.txt
                                     6 files
```

De botsingsnaam `diagram(1).txt` staat er nog, dus ook dat gedrag overleeft de
nieuwe gem. **De schermafbeeldingen zijn niet vervangen**: de interface is niet
gewijzigd, dus de bestaande shots kloppen nog en opnieuw nemen zou alleen ruis
in de historie geven. Wat nieuw is aan dit bewijs is de archiefinhoud op
rubyzip 3.6, en dat is tekst.

**RuboCop op r25063:** 7 gewijzigde Ruby-bestanden **0 offences**; baseline op
de 5 die op `origin/master` al bestaan ook **0**.

`tools/check-patch-clean.sh wiki-export-attachments --submit`: **PASS** op
r25063 — 15 bestanden, locales `de,en,es,fr,nl`, geen AI-spoor, applyt op een
schone r25063, branch en bestand zijn dezelfde wijziging, en geen AI-identiteit
in auteur of committer.

**INV-10: `7.0-stable-GEOxyz` verandert hier niet, en dat is juist.** De enige
verschuiving in de patch is dat `'zip' => 'ZIP'` nu ná trunks nieuwe
`'itcpdf' => 'ITCPDF'` staat, en die regel bestaat op `origin/7.0-stable`
helemaal niet — nagekeken: `grep -c itcpdf` geeft daar 0. GEOxyz heeft dus
`'imap' => 'IMAP', 'zip' => 'ZIP'`, wat voor zijn eigen basis de juiste vorm is.
INV-10 gaat over gedrag, niet over de letterlijke vorm van een hunk die van de
basis afhangt, en het gedrag is aan beide kanten hetzelfde.

**Suite op r25063**, beide kanten met een **identieke `Gemfile.lock`** (de lock
staat in `.gitignore`, dus die is van de patchkant naar de trunkkant gekopieerd
vóór het bundelen — zonder dat vergelijk je twee verschillende Redmines):

| Wat | Uitkomst |
|---|---|
| `test:all` met patch (`eed205828`) | **5995 runs, 31777 assertions, 27 failures, 2 errors, 92 skips** |
| `test:all` op schone trunk r25063, zelfde lock | **5981 runs, 31724 assertions, 27 failures, 2 errors, 92 skips** |
| verschil | **14 runs**, en **nul extra failures, nul extra errors** |
| faalnamen | **29 aan elke kant, identiek** — `diff` van de gesorteerde lijsten is leeg in beide richtingen |

De 14 extra runs zijn de 12 nieuwe functionele tests en de 2 nieuwe unittests.
De 29 falende tests zitten in `RepositoriesControllerTest` (14),
`Redmine::ApiTest::RepositoriesTest` (8), `SysControllerTest` (5), `UserTest`
(1) en `Redmine::ApiTest::IssuesTest` (1) — geen enkele raakt de wiki of de
export.

**En let op het verschil met de meting van 2026-09-08:** die stond op
`48 failures, 82 errors`, dit op `27 failures, 2 errors`. Dat is geen
verbetering van onze kant — trunk heeft in `9a74cdf20` (#44428) de json-gem
onder 3.0 gepind, precies de fout die in `docs/traps.md` staat. Na de sync is
die weg, en daarmee zijn deze cijfers een stuk beter leesbaar dan de vorige.

## Bewijs — ronde 3 op r25037

**Opnieuw gemeten op 2026-09-08, na de ronde-3 wijzigingen**, tegen trunk
r25037 met een gelijke `Gemfile.lock` aan beide kanten:

- Volledige suite met patch (`8121846be`): **5991 runs, 31410 assertions,
  48 failures, 82 errors, 92 skips**
- Volledige suite op schone trunk r25037: **5977 runs, 31357 assertions,
  48 failures, 82 errors, 92 skips**
- Verschil **14 runs**, **nul extra failures en nul extra errors**, en de 87
  faalnamen zijn aan beide kanten identiek (`comm` leeg in beide richtingen)
- De hoge aantallen komen van **json 3.0.1**, dat
  `ActiveSupport::JSON.decode` breekt en ongeveer honderd kerntests raakt. Dat
  is gemeten op **kale** trunk, dus het treft beide kanten gelijk en de
  vergelijking blijft geldig. `Gemfile.lock` staat in `.gitignore`, dus de lock
  van de patchkant is naar de trunkkant gekopieerd voor het bundelen — zonder
  dat zijn de twee regels niet vergelijkbaar.
- Volledige suite op `7.0-stable-GEOxyz` (`6078281ff`): **6128 runs,
  32368 assertions, 0 failures, 0 errors, 39 skips** — volledig groen
- Geraakte suites samen: **173 runs, 814 assertions, 0 failures, 0 errors,
  4 skips** — onveranderd door de fixes
- RuboCop 1.90.0 op de 7 gewijzigde bestanden: **0**, baseline **0**
- `tools/check-patch-clean.sh --submit`: **PASS** ·
  `tools/check-geoxyz-branch.sh`: **PASS**

De cijfers hieronder zijn de ronde-2 meting van 2026-09-05.


- Geraakte suites samen, op de patch: 173 runs, 814 assertions, 0 failures,
  0 errors, 4 skips (ImageMagick en pandoc ontbreken in het image)
- Volledige suite met patch (`test:all`): 5991 runs, 31764 assertions, 27 failures, 2 errors, 92 skips in 875 s
- Volledige suite op schone trunk r25037: 5977 runs, 31710 assertions, 27 failures, 2 errors, 92 skips in 855 s, faalnamen identiek: The 29 failing test names are identical on both runs (`diff` of the sorted lists is empty): all of them are the `Repository::Subversion` validation failures of an image without `svn`, `hg`, `bzr` or `cvs` (see "Found but not fixed"). The 14 extra runs on the patch are the 12 new functional tests and the 2 new unit tests.
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
- `tools/check-patch-clean.sh`: PASS (5 checks, waaronder branch = patchbestand) ·
  `tools/check-geoxyz-branch.sh`: PASS — het lintblok meet sinds 2026-09-05 een
  baseline op `origin/7.0-stable`; de ene melding op `wiki_controller.rb:369`
  (`Rails/StrongParametersExpect`) staat op een regel van upstream en telt
  daardoor niet meer als fout van de branch (1 op de bestanden, baseline 1)
- Screenshots: 12 in `shots/`, gelezen: ja. Archieven naast het dossier: 4,
  waaronder het voor/na-paar `before-fix-zip-with-attachments.zip` /
  `zip-with-attachments.zip` voor de naambotsing

## Wat Jan nog moet doen

Maak een nieuw issue op redmine.org als follow-up van
[#43978](https://www.redmine.org/issues/43978) en hang er
`patches/wiki-export-attachments/2026-09-09-r25063-feature.patch` en
`-locales.patch` aan. Draai vlak daarvoor
`tools/check-patch-clean.sh wiki-export-attachments --submit`; als trunk
intussen verder is, ververst een sessie de patch eerst (g05) — en controleer
dan ook of `origin/master` zelf nog actueel is, want dat is een mirror
(K-19). De Engelse
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
