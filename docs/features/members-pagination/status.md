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

Wat wél nog te doen is: bij het narekenen kwam één randgeval boven water.
Verwijder je de laatste rij van de laatste pagina, dan blijft het tabblad op een
paginanummer staan dat niet meer bestaat en toont het "No data to display" op
een project dat gewoon leden heeft, zonder link om terug te navigeren. Dat is
bereikbaar zonder aan de URL te komen. De fix is vier regels; GEOxyz draait hem
al, en hij gaat als **verbetervoorstel** in een note aan #43355 — niet als
defectmelding, want onbewerkt Redmine doet dit overal al (jouw keuze g15, en
reviewbevinding F01 van 2026-09-03).

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
- Geraakte suites opnieuw gedraaid op 2026-09-06, op de **huidige** tip van
  `7.0-stable-GEOxyz`: `184 runs, 857 assertions, 0 failures, 0 errors, 0 skips`.
  Eén run en twee assertions meer, en dat verschil is niet van deze feature:
  een andere sessie voegde na `885f04097` een test toe aan
  `test/functional/projects_controller_test.rb`.
- Volledige suite met patch (`patch/members-pagination`, alle drie de commits): `5934 runs, 31506 assertions, 27 failures, 2 errors, 92 skips`
- Volledige suite op schone trunk r24882: `5920 runs, 31455 assertions, 27 failures, 2 errors, 92 skips`
- Volledige suite op `7.0-stable-GEOxyz`: `6000 runs, 31988 assertions, 0 failures, 0 errors, 39 skips`
- Volledige suite opnieuw gedraaid op 2026-09-06 op de huidige tip van
  `7.0-stable-GEOxyz` (859 s): `6021 runs, 31533 assertions, 0 failures,
  0 errors, 33 skips`. **Groen.** De aantallen wijken af van de regel hierboven
  omdat de branch intussen van vijftien naar drieëndertig eigen commits is
  gegaan, door andere sessies.
- Faalnamen identiek met de schone run: ja — 29 namen, exact dezelfde verzameling. Alle betrokken tests zijn
  Subversion-repositorytests; `svn` zit niet in dit image (zie
  `docs/runbook.md`). Geen enkele raakt leden of groepen.
- RuboCop op de 10 gewijzigde Ruby-bestanden, met de versie die de `Gemfile`
  pint (**rubocop 1.88.2**, rubocop-rails 2.34.3): `0` op `885f04097`, `0` op
  de r24882-baseline. Opnieuw gemeten op 2026-09-06 in twee losse worktrees.
  Met een **niet-gepinde** nieuwere RuboCop (1.90.0) meldde de reviewronde 4
  `Rails/StrongParametersExpect`-overtredingen op dezelfde bestanden; alle vier
  staan op bestaande regels die deze wijziging niet aanraakt, dus het verschil
  is 0 onder beide versies. Het absolute getal reproduceert alleen met de
  gepinde versie — vandaar dat de versie er nu bij staat.
- Elk van de drie nieuwe tests is rood gezien zonder de clamp: de twee
  helpertests melden `Expected: 2, Actual: 9`, de controllertest meldt
  `"nodata" found in ...`. De clamp is uit beide helpers gehaald, de tests zijn
  gedraaid, alle drie faalden, daarna is de clamp teruggezet.
- `tools/check-patch-clean.sh members-pagination`: PASS (2026-09-06). Het
  controleert Takenori's twee patchbestanden en meldt terecht dat er **geen**
  `patch/members-pagination`-branch is om tegen af te zetten — die hebben we
  niet, en dat is de bedoeling. Beide bestanden applyen nog schoon op de
  huidige trunk **r25037**.
- Eén restpunt, gemeld en niet stilgehouden: de drie GEOxyz-commits hebben
  `Jan Catrysse` als **auteur** maar `Claude` als **committer**, doordat
  `tools/session-push.sh` ze moest replayen en een replay de committer op wie
  hem draait zet. Dat is **niet eigen aan deze feature** — op 2026-09-06 gold
  het voor 16 van de 33 eigen commits op `7.0-stable-GEOxyz` — en het staat
  sinds die datum als **K-13** in `docs/DECISIONS.md`, met drie opties en een
  aanbeveling. Het wordt hier daarom niet meer per feature uitgeschreven. Het
  raakt geen patch: `format-patch` neemt de **auteur** mee, en
  `patch/members-pagination` heeft beide velden op Jan staan
  (`check-patch-clean.sh` PASS).
- Screenshots: 11, gelezen: ja. Drie ervan zijn op 2026-09-06 opnieuw gemaakt
  mét de adresbalk van de browser erop (`MODE=note-shots`, headed Chromium op
  een Xvfb-display, `xwd` grijpt het hele scherm): `members-last-page.png`,
  `defect-empty-page-after-delete.png` en
  `members-page-clamped-after-delete.png`. Reden: de oude lege-tabschermafdruk
  was niet te onderscheiden van een project zónder leden.

## Wat Jan nog moet doen

Eén note aan **https://www.redmine.org/issues/43355** — geen nieuw issue, en
geen patchbestand van ons erbij.

De volledige Engelse tekst staat kant-en-klaar in `dossier.md` onder
**"The note to post on #43355"**. Kopieer die ene sectie van de eerste tot de
laatste regel; alles erboven en eronder is ons eigen dossier en hoort niet op
redmine.org. Die sectie doet, in deze volgorde, de drie dingen die jouw keuze
**g15** voorschrijft:

1. bedankt Takenori TAKAKI (user:takenory) voor de rebase en de splitsing;
2. bevestigt dat zijn `0002-groups-pagination.patch` de groepsledenlijst en de
   gescheiden `members_page`/`users_page`-parameters dekt — precies wat GEOxyz
   bovenop het oorspronkelijke issue nodig had, dus er ontbreekt niets;
3. brengt het punt als **verbetervoorstel** en niet als defectmelding.

Dat laatste is de kern van g15 en het is ook gewoon waar: onbewerkt Redmine
laat elke lijst zo doodlopen — `/issues?page=99` geeft net zo goed "No data to
display" zonder links. Wat de paginatie er wél aan toevoegt is dat je op het
ledentabblad met een gewone klik in die toestand komt, en dat je er daar niet
uit klikt, omdat de instellingentabbladen vooraf gerenderde divs zijn die
JavaScript omschakelt. Die asymmetrie is het argument; de beschuldiging was het
niet, en zou binnen een dag met `/issues?page=99` beantwoord zijn.

**Drie bijlagen, alle drie met de adresbalk erop** (opnieuw gemaakt op
2026-09-06, `MODE=note-shots` in `verify/members-pagination.mjs`), in deze
volgorde:

1. `docs/features/members-pagination/shots/members-last-page.png` — pagina 4
   van 4, `(7-7/7)`, één lid, URL `…/settings/members?members_page=4`. Dit
   bewijst dat het project zeven leden hád.
2. `docs/features/members-pagination/shots/defect-empty-page-after-delete.png`
   — dezelfde URL, "No data to display".
3. `docs/features/members-pagination/shots/members-page-clamped-after-delete.png`
   — dezelfde stap mét de voorgestelde fix: pagina 3 van 3, `(5-6/6)`.

Het eerste paar is nodig omdat één lege tab zonder adresbalk niet te
onderscheiden is van een project zónder leden, en dat is nu juist de claim. De
derde laat zien wat de voorgestelde vier regels doen.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **De note is een verbetervoorstel, geen defectmelding.** Beslist door Jan als
  **g15** en uitgevoerd op 2026-09-06. Onbewerkt Redmine laat elke gepagineerde
  lijst zo doodlopen; wat de paginatie toevoegt is dat je er op het ledentabblad
  met een gewone klik in komt en er niet uit klikt. Niet opnieuw omdraaien: de
  oude formulering gaf een committer een weerlegging van één regel
  (`/issues?page=99`).
- **Het commentaar in de clamp blijft, en F06 wordt benoemd en niet
  gerepareerd.** Beide op 2026-09-06 vastgelegd in `decisions.md`, met de reden.
  Niet opnieuw wegen.
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

Af — niets te doen, behalve dat Jan de note plaatst. Alle tien
reviewbevindingen van 2026-09-03 op deze feature hebben sinds 2026-09-06 een `Resolution:`-regel
in `docs/review/findings/2026-09-03-members-pagination-claude-opus5.md`. Komt er reactie van
Takenori of een committer op de bevinding, dan is de volgende stap die reactie
verwerken in `dossier.md` en, als de clamp upstream landt, de derde
GEOxyz-commit laten vervallen zodra GEOxyz naar die release gaat.
