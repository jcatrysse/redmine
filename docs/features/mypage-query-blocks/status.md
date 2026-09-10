---
slug: mypage-query-blocks
feature: Max. eigen zoekopdrachten op Mijn pagina instelbaar, standaard 3
commit_51: 0214f3ecc
geoxyz: live
geoxyz_commit: dc6dad120 + dd063fa8b + f5ed23c8e
upstream: patch klaar
patch: patches/mypage-query-blocks/2026-09-09-r25037-{feature,locales}.patch
issue: "27313"
---

# mypage-query-blocks — status

## Waar het staat

Af, en door ronde 2 én ronde 3 heen. Alle tien reviewbevindingen van 2026-09-03
hebben een `Resolution:`-regel en zijn gerepareerd — geen enkele "wont-fix". De
blinde herreview van 2026-09-08 vond **niets in de wijziging zelf**; haar ene
bevinding zat in de commit eromheen en is op 2026-09-09 opgelost (zie
"Bewijs"). Twee patchbestanden tegen trunk **r25037** (`bee32a926`), dezelfde
wijziging als commits `dc6dad120` + `dd063fa8b` + `f5ed23c8e` op
`7.0-stable-GEOxyz`, dossier bijgewerkt, vijftien screenshots. Het issue bestaat
sinds 2017 en is door de projectleider geparkeerd:
[#27313](https://www.redmine.org/issues/27313).

## Wat het doet

Op "Mijn pagina" mag je maximaal drie blokken met een eigen zoekopdracht zetten;
dat getal stond sinds 2017 hard in `Redmine::MyPage::CORE_BLOCKS`. Het is nu een
instelling in Beheer → Configuratie → Algemeen, met **3 als standaard**, dus voor
wie niets instelt verandert er niets. Sinds ronde 2 heeft die instelling een
**bereik van 0 tot en met 20**: daarbuiten weigert het formulier de waarde met de
gewone Redmine-foutmelding, en `0` betekent wat het zegt — er mag geen nieuw
blok met een eigen zoekopdracht meer bij. De 20 is Jans keuze (K-10, optie C):
de grens is een tikfoutbeveiliging, geen aanbeveling.

## Bewijs (opnieuw gedraaid op 2026-09-05, g10)

- Volledige suite met patch (`test:all`, inclusief systeemtests): **5992 runs,
  31762 assertions, 27 failures, 2 errors, 92 skips**
- Schone trunk r25037: **5977 runs, 31708 assertions, 27 failures, 2 errors,
  92 skips** — dezelfde 29 faalnamen, `diff` leeg, alle 29 SCM-tests waarvoor
  `svn`/`hg`/`bzr`/`cvs` in deze container ontbreken
- Volledige suite op `7.0-stable-GEOxyz`: **6097 runs, 32265 assertions,
  0 failures, 0 errors, 39 skips** — helemaal groen
- `tools/check-geoxyz-branch.sh`: **PASS**
- Geraakte suites in één proces, **met de bestandenlijst erbij** omdat het
  cijfer anders niet na te rekenen is (ronde 4, F01):
  `test/unit/lib/redmine/my_page_test.rb`, `test/unit/setting_test.rb`,
  `test/functional/my_controller_test.rb`,
  `test/functional/settings_controller_test.rb` en
  `test/system/my_page_test.rb`, gedraaid via `tools/test-env.sh` zodat de
  systeemtests echt draaien → **112 runs, 570 assertions, 0 failures, 0 errors,
  0 skips** (opnieuw gemeten 2026-09-10). De eerder genoteerde
  `135 runs, 1346 assertions` was niet te reconstrueren uit welke
  bestandsverzameling dan ook en is daarom vervangen in plaats van aangevuld;
  alleen de drie gewijzigde testbestanden samen geven 92 runs.
- RuboCop op de vijf gewijzigde Ruby-bestanden: **0** (baseline op dezelfde
  bestanden op `origin/master`: **0**)
- Rood op de oude code, in drie aparte mutaties: alle productiebestanden terug
  naar trunk → 14 errors; alleen `my_page.rb` terug → 5 failures behoudens
  errors; alleen de bovengrens weggehaald → precies die ene test rood
- `tools/check-patch-clean.sh mypage-query-blocks --submit`: **PASS**
- Screenshots: vijftien (voor/na), gelezen: ja. `fourth-block.png` toont nu vier
  échte issuelijsten in plaats van vier lege keuzeformulieren.

### Ronde 3 en de INV-4-reparatie (2026-09-09)

De blinde herreview draaide de suite aan beide kanten opnieuw, met dezelfde
`Gemfile.lock`, en kwam op **5992 tegen 5977 runs, in beide richtingen nul
extra failures en nul extra errors**, 87 identieke faalnamen. Die 48/82 in plaats
van 27/2 is de json-gem, niet de patch — zie `docs/traps.md`.

De bevinding zat niet in de diff maar in de commit: `6af3b35c4` had
`Claude <noreply@anthropic.com>` als **committer**, de laatste van de negen
patchbranches met een AI-identiteit. Opgelost op 2026-09-09:

- `patch/mypage-query-blocks` is met de juiste identiteit heropgeslagen en
  force-gepusht: **`3fc86ca5b`**, auteur én committer `Jan Catrysse`
- de **boom is byte-identiek** (`1474fc51a` voor en na, `git diff 6af3b35c4 HEAD`
  leeg), dus alle cijfers hierboven blijven staan; alleen de commit-headers
  veranderden
- de twee patchbestanden zijn opnieuw geëxporteerd als
  `2026-09-09-r25037-{feature,locales}.patch`; het **enige** verschil met de
  2026-09-05-versie is de `From <sha>`-regel, en de bestandsgroottes zijn
  gelijk (13606 en 3157 bytes)
- `tools/check-patch-clean.sh mypage-query-blocks --submit`: **PASS** — 12
  bestanden, locales `de,en,es,fr,nl`, geen AI-spoor, applyt op een schone
  r25037, branch en bestand zijn dezelfde wijziging
- de identiteitscontrole uit K-15 is **rood gedreven vóór en groen ná**, met
  het patroon uit `tools/check-geoxyz-branch.sh` maar over het juiste bereik
  (`origin/master..<tip>`): `6af3b35c4` levert
  `committer=Claude <noreply@anthropic.com>`, `3fc86ca5b` levert niets. Het
  script zelf **kan hier niet op gericht worden** — het rekent `own` als
  `origin/7.0-stable..ref`, wat voor een trunkbranch duizenden commits is. Dat
  gat is gemeld en Jan heeft het op 2026-09-09 laten repareren (**K-16**, optie
  B): `check-patch-clean.sh` heeft er een zesde controle bij die de auteur- en
  committervelden van de branch leest. Rood gedreven op een tijdelijke branch
  op `6af3b35c4`, groen op alle negen

## Wat Jan nog moet doen

Hang `patches/mypage-query-blocks/2026-09-09-r25037-feature.patch` en
`-locales.patch` als note aan het **bestaande** issue
[#27313](https://www.redmine.org/issues/27313) — dus geen nieuw issue — en zeg in
die note expliciet dat dit note-9 van Jean-Philippe Lang beantwoordt: de
standaard blijft 3 en er wordt voor niemand iets verhoogd. Het voor/na-paar
`shots/{before-,}select-at-default-maximum.png` is nu **aantoonbaar** dezelfde
afbeelding: het verificatiescript vergelijkt ze met SHA-256 en faalt als ze
verschillen. Neem de meettabel uit "What asynchronous loading would and would not
fix" mee; die is nu op Redmine's eigen testfixtures gemeten, dus een committer
kan hem naspelen.

Er staat verder niets meer voor jou open: K-10 (de bovengrens) is beslist —
optie C, 20.

De Engelse tekst voor de note staat in `dossier.md` vanaf "The problem".

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Jean-Philippe Lang parkeerde het issue op 2018-12-08** met precies één
  bezwaar: "We should probably load content asynchronously before raising the
  number of queries that can be displayed." Go MAEDA's voorstel (`max_occurs`
  3 → 5) loopt daar recht tegenaan. Een instelling met **standaard 3** niet.
  Niet opnieuw wegen of de standaard toch naar 5 moet — dat is precies de patch
  die al is afgewezen.
- **Asynchroon laden zelf bouwen: nagemeten en afgewezen.** Asynchroon laden
  verdeelt dezelfde queries over evenveel requests; het totaal blijft gelijk en
  wordt iets hoger. Het wint *gevoelde* snelheid, niet belasting, en belasting is
  precies waar note-5 over gaat. Bijkomend: `_issues.erb` zet een Atom-`<link>`
  in de `<head>` via `content_for :header_tags`, plugins hangen eigen
  blokpartials in `app/views/my/blocks/`, en de pagina zou leeg zijn zonder
  JavaScript — drie keuzes voor het core-team, niet voor ons.
- `:max_occurs` mag een instellingsnaam zijn, opgelost in één
  `Redmine::MyPage.max_occurs`. Niet terug naar de 5.1-vorm, die `MyPage.blocks`
  zelf herschreef en de blokknaam in de generieke accessor zette.
- **De klem op minimaal 1 is weg en komt niet terug** (review F03 + Jans g16b).
  Renderen leest `max_occurs` nergens, dus `0` kan niets kapotmaken wat een
  gebruiker al heeft; en `0` is juist de waarde die note-5 vraagt. De grens
  wordt in het formulier geweigerd, niet stilzwijgend bijgeknipt.
- **De niet-discriminerende test blijft staan**, als bewaker gelabeld, met een
  tweede test ernaast die de verlaagde grens wél vastpint (review F05).
- **De patchbranch is op 2026-09-09 herschreven, en dat mág hier.** Een
  `patch/*`-branch checkt niemand uit, dus force-pushen kost niets; op
  `7.0-stable-GEOxyz` zou het wel wat kosten en gebeurt het dus niet. De oude
  tip `6af3b35c4` is niet bewaard: de boom is identiek aan `3fc86ca5b`, dus er
  is niets om naar terug te kijken. `session-push.sh` kon deze push niet doen —
  dat script force-pusht principieel nooit — dus is de INV-4-identiteitscheck
  eruit met de hand gedraaid vóór de push.

## Volgende stap voor een sessie

Af — niets te doen behalve Jans twee handelingen hierboven. Ronde 3 is gedaan
(2026-09-08) en haar enige bevinding is gesloten (2026-09-09).
