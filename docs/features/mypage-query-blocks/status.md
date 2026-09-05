---
slug: mypage-query-blocks
feature: Max. eigen zoekopdrachten op Mijn pagina instelbaar, standaard 3
commit_51: 0214f3ecc
geoxyz: live
geoxyz_commit: 198cbfb63 + 47eec6f1d + 1b4a29a0b
upstream: patch klaar
patch: patches/mypage-query-blocks/2026-09-05-r25037-{feature,locales}.patch
issue: "27313"
---

# mypage-query-blocks — status

## Waar het staat

Af, en door ronde 2 heen. Alle tien reviewbevindingen van 2026-09-03 hebben een
`Resolution:`-regel en zijn gerepareerd — geen enkele "wont-fix". Twee
patchbestanden tegen trunk **r25037** (`bee32a926`), dezelfde wijziging als
commits `198cbfb63` + `47eec6f1d` + `1b4a29a0b` op `7.0-stable-GEOxyz`, dossier bijgewerkt,
vijftien screenshots. Het issue bestaat sinds 2017 en is door de projectleider
geparkeerd: [#27313](https://www.redmine.org/issues/27313).

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
- Volledige suite op `7.0-stable-GEOxyz`: **6097 runs, 32266 assertions,
  0 failures, 0 errors, 39 skips** — helemaal groen
- `tools/check-geoxyz-branch.sh`: **PASS**
- Geraakte suites in één proces: **135 runs, 1346 assertions, 0 failures,
  0 errors**
- RuboCop op de vijf gewijzigde Ruby-bestanden: **0** (baseline op dezelfde
  bestanden op `origin/master`: **0**)
- Rood op de oude code, in drie aparte mutaties: alle productiebestanden terug
  naar trunk → 14 errors; alleen `my_page.rb` terug → 5 failures behoudens
  errors; alleen de bovengrens weggehaald → precies die ene test rood
- `tools/check-patch-clean.sh mypage-query-blocks --submit`: **PASS**
- Screenshots: vijftien (voor/na), gelezen: ja. `fourth-block.png` toont nu vier
  échte issuelijsten in plaats van vier lege keuzeformulieren.

## Wat Jan nog moet doen

Hang `patches/mypage-query-blocks/2026-09-05-r25037-feature.patch` en
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

## Volgende stap voor een sessie

Af — niets te doen behalve Jans twee handelingen hierboven. Ronde 3 (blinde
herreview) kan deze slug meenemen.
