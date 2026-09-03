---
slug: members-pagination
feature: Paginatie op projectleden en groepsleden
commit_51: 455f5753c
geoxyz: live
geoxyz_commit: 351fe9e54 + 55ae9d1dd + 885f04097
upstream: nooit
patch:
issue: 43355
---

# members-pagination — status

## Waar het staat

Af, met één ding voor Jan. De upstream-kant is **niet van ons**: Takenori
TAKAKI heeft op 2026-08-05 Jans eigen issue
[#43355](https://www.redmine.org/issues/43355) opgepakt, de 5.1-patch op de
huidige trunk gerebased, hem in twee losse patches gesplitst
(`0001-members-pagination.patch` voor de projectleden,
`0002-groups-pagination.patch` voor de groepsleden) en er meteen een bug uit
gehaald die in Jans versie zat. Beide patches zijn hier nagelopen, ze applyen
schoon op r24882, en de suites blijven groen. Er komt dus **geen eigen
inzending** — dat zou alleen de kans op allebei verkleinen.

Wat wél nog te doen is: bij het narekenen kwam er één echte fout uit Takenori's
patches boven water. Verwijder je de laatste rij van de laatste pagina, dan
blijft het tabblad op een paginanummer staan dat niet meer bestaat en toont het
"No data to display" op een project dat gewoon leden heeft, zonder link om
terug te navigeren. Dat is bereikbaar zonder aan de URL te komen. De fix is vier
regels; GEOxyz draait hem al, en hij hoort als note aan #43355.

De GEOxyz-branch draait alle drie de stukken: Takenori's twee patches
één-op-één, plus de clamp als losse derde commit, zodat die apart kan
vervallen zodra upstream hem overneemt.

## Wat het doet

De tab *Leden* in de projectinstellingen en de tab *Gebruikers* van een groep
tonen één pagina tegelijk in plaats van alle leden. Een project met duizenden
leden opent daardoor in een fractie van de tijd, en de paginakeuze blijft staan
als je een lid toevoegt, bewerkt of verwijdert.

## Bewijs

- Geraakte suites op schone trunk r24882: `169 runs, 803 assertions, 0 failures, 0 errors, 0 skips`
- Geraakte suites met `0001` + `0002`: `180 runs, 844 assertions, 0 failures, 0 errors, 0 skips`
- Geraakte suites met de clamp erbij: `183 runs, 855 assertions, 0 failures, 0 errors, 0 skips`
- Volledige suite met patch (`patch/members-pagination`): `5931 runs, 31493 assertions, 27 failures, 2 errors, 92 skips`
- Volledige suite op schone trunk r24882: `5920 runs, 31455 assertions, 27 failures, 2 errors, 92 skips`
- Volledige suite op `7.0-stable-GEOxyz`: `6000 runs, 31988 assertions, 0 failures, 0 errors, 39 skips`
- Faalnamen identiek met de schone run: ja — 29 namen, exact dezelfde verzameling. Alle betrokken tests zijn
  Subversion-repositorytests; `svn` zit niet in dit image (zie
  `docs/runbook.md`). Geen enkele raakt leden of groepen.
- RuboCop op de 10 gewijzigde Ruby-bestanden: `0` (baseline op dezelfde 10
  bestanden op r24882: `0`)
- Elk van de drie nieuwe tests is rood gezien zonder de clamp: de twee
  helpertests melden `Expected: 2, Actual: 9`, de controllertest meldt
  `"nodata" found in ...`. De clamp is uit beide helpers gehaald, de tests zijn
  gedraaid, alle drie faalden, daarna is de clamp teruggezet.
- `tools/check-patch-clean.sh patch/members-pagination`: PASS ·
  `tools/check-geoxyz-branch.sh`: PASS
- Screenshots: 11, gelezen: ja

## Wat Jan nog moet doen

Eén note aan **https://www.redmine.org/issues/43355** — geen nieuw issue, en
geen patchbestand van ons erbij. Bedank Takenori TAKAKI (user:takenory) voor de
rebase en de splitsing, bevestig dat zijn `0002-groups-pagination.patch` de
groepsledenlijst en de gescheiden `members_page`/`users_page`-parameters dekt
(dat was precies wat GEOxyz bovenop het oorspronkelijke issue nodig had, dus er
ontbreekt niets), en meld dan de ene bevinding:

> Removing the last row of the last page leaves the tab on a page that no
> longer exists — "No data to display" on a project that has members, with no
> pagination links to get back with.

De Engelse tekst staat kant-en-klaar in `dossier.md` onder **"The finding"** en
**"Suggested fix"**: de reproductie in drie stappen, de diff van vier regels
voor `members_helper.rb` en `groups_helper.rb`, en de drie tests die zonder die
diff rood staan. Hang er
`docs/features/members-pagination/shots/defect-empty-page-after-delete.png` bij
— dat is een screenshot van een project met zes leden waar "No data to display"
staat, en dat overtuigt sneller dan de uitleg.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Geen eigen patch, en geen nieuw issue.** #43355 is Jans eigen issue en er
  ligt een rebase van een actieve bijdrager op. Een tweede patch op hetzelfde
  issue verkleint de kans op allebei.
- **De GEOxyz-toevoeging bovenop het originele issue is gedekt.** De
  groepsledenlijst zit in `0002`, en de gescheiden `members_page` /
  `users_page`-parameters zitten in beide patches — Takenori noemt die keuze
  zelf in zijn note. Er is dus geen verschil meer om als note te melden; alleen
  de bevinding hierboven.
- **De clamp gaat als tekst, niet als patchbestand.** Een fix bovenop
  `0001`/`0002` applyt per definitie niet standalone op een schone
  `origin/master`, en INV-2 verbiedt zo'n bestand in `patches/`. Vandaar de
  diff in het dossier.
- **De drie afgewezen alternatieven voor de clamp staan in het dossier** onder
  *Alternatives considered* (paginatielinks buiten de lege tak renderen; in
  `Redmine::Pagination::Paginator` zelf clampen; het paginanummer bij een
  delete gewoon weggooien). Niet opnieuw wegen.
- **De 27 failures + 2 errors in de volledige suite zijn niet van deze
  wijziging.** Het zijn Subversion-repositorytests en ze staan identiek rood op
  een schone trunk-checkout. `svn` ontbreekt in dit image.
- **`patches/members-pagination/` bevat Takenori's twee bestanden, niet die van
  ons.** Ze staan er om een latere revisie tegen af te kunnen zetten; zie de
  README in die map.

## Volgende stap voor een sessie

Af — niets te doen, behalve dat Jan de note plaatst. Komt er reactie van
Takenori of een committer op de bevinding, dan is de volgende stap die reactie
verwerken in `dossier.md` en, als de clamp upstream landt, de derde
GEOxyz-commit laten vervallen zodra GEOxyz naar die release gaat.
