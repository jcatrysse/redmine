---
slug: mypage-query-blocks
feature: Max. eigen zoekopdrachten op Mijn pagina instelbaar, standaard 3
commit_51: 0214f3ecc
geoxyz: live
geoxyz_commit: 198cbfb63
upstream: patch klaar
patch: patches/mypage-query-blocks/2026-09-03-r24882-{feature,locales}.patch
issue: "27313"
---

# mypage-query-blocks — status

## Waar het staat

Af. Twee patchbestanden tegen trunk r24882, dezelfde wijziging als commit
`198cbfb63` op `7.0-stable-GEOxyz`, dossier compleet, twaalf screenshots. Het
issue bestaat sinds 2017 en is door de projectleider geparkeerd:
[#27313](https://www.redmine.org/issues/27313).

## Wat het doet

Op "Mijn pagina" mag je maximaal drie blokken met een eigen zoekopdracht
zetten; dat getal stond sinds 2017 hard in `Redmine::MyPage::CORE_BLOCKS`. Het
is nu een instelling in Beheer → Configuratie → Algemeen, met **3 als
standaard**, dus voor wie niets instelt verandert er niets.

## Bewijs

- Volledige suite met patch (op de gecommitte boom): 5926 runs,
  31483 assertions, 27 failures, 2 errors, 92 skips
- Schone trunk r24882: 5920 runs, 31455 assertions, 27 failures, 2 errors,
  92 skips — dezelfde 29 faalnamen, `diff` leeg
- Volledige suite op `7.0-stable-GEOxyz`: 5945 runs, 31800 assertions,
  0 failures, 0 errors, 39 skips
- RuboCop: 0 (baseline 0)
- Vijf van de zes nieuwe tests geven op kale trunk
  `RuntimeError: There's no setting named my_page_max_issuequery_blocks`; de
  zesde is een bewaker die bewust aan beide kanten groen is en de standaard 3
  vastlegt
- `tools/check-patch-clean.sh`: PASS · `tools/check-geoxyz-branch.sh`: PASS
- Screenshots: twaalf (voor/na), gelezen: ja

## Wat Jan nog moet doen

Hang `patches/mypage-query-blocks/2026-09-03-r24882-feature.patch` en
`-locales.patch` als note aan het **bestaande** issue
[#27313](https://www.redmine.org/issues/27313) — dus geen nieuw issue — en zeg
in die note expliciet dat dit note-9 van Jean-Philippe Lang beantwoordt: de
standaard blijft 3, er wordt voor niemand iets verhoogd, en het voor/na-paar
`shots/{before-,}select-at-default-maximum.png` is dezelfde afbeelding. Neem
ook de meettabel uit "What asynchronous loading would and would not fix" mee.
De Engelse tekst staat in `dossier.md` vanaf "The problem".

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Jean-Philippe Lang parkeerde het issue op 2018-12-08** met precies één
  bezwaar: "We should probably load content asynchronously before raising the
  number of queries that can be displayed." Go MAEDA's voorstel (`max_occurs`
  3 → 5) loopt daar recht tegenaan. Een instelling met **standaard 3** niet.
  Niet opnieuw wegen of de standaard toch naar 5 moet — dat is precies de patch
  die al is afgewezen.
- **Asynchroon laden zelf bouwen: nagemeten en afgewezen.** Mijn pagina kost 10
  SQL-queries leeg en ~22 per extra issuequery-blok (6 blokken = 151 queries,
  118 KB). Asynchroon laden verdeelt diezelfde queries over zes requests — het
  totaal blijft gelijk en wordt iets hoger. Het wint *gevoelde* snelheid, niet
  belasting, en belasting is precies waar note-5 over gaat. Er zit ook geen
  goedkope N+1 in: 25 van de ~41 queries per blok zijn `issue_count` +
  `issues(:limit => 10)` zelf, en het schaalt niet met het aantal rijen.
  Bijkomend: `_issues.erb` zet een Atom-`<link>` in de `<head>` via
  `content_for :header_tags`, plugins hangen eigen blokpartials in
  `app/views/my/blocks/`, en de pagina zou leeg zijn zonder JavaScript — drie
  keuzes voor het core-team, niet voor ons. Staat uitgewerkt in `dossier.md`.
- `:max_occurs` mag een instellingsnaam zijn, opgelost in één nieuwe
  `Redmine::MyPage.max_occurs`. Niet terug naar de 5.1-vorm, die `MyPage.blocks`
  zelf herschreef en de blokknaam in de generieke accessor zette.

## Volgende stap voor een sessie

Af — niets te doen. Alleen Jans handeling hierboven.
