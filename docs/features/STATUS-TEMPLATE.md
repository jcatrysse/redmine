---
slug: <slug>
feature: <één regel, Nederlands, wat het doet>
commit_51: <sha van de 5.1-commit, of ->
geoxyz: todo
geoxyz_commit:
upstream: todo
patch:
issue:
---

<!-- Dit bestand is het geheugen van ÉÉN feature, en precies één sessie schrijft
     eraan: de sessie die de slug geclaimd heeft. Daarom kunnen sessies parallel
     lopen. De front matter hierboven wordt door tools/register.sh in
     docs/REGISTER.md gezet — houd de veldnamen intact.

     geoxyz:   todo | live | n.v.t.
     upstream: todo | ontworpen | patch klaar | ingediend | geaccepteerd |
               afgewezen | nooit | vervallen
-->

# <slug> — status

## Waar het staat

<Twee tot zes zinnen gewone taal. Welke fase, wat er ligt, wat bewezen is.
Schrijf het alsof de volgende sessie niets weet.>

## Wat het doet

<Twee zinnen. Wat een Redmine-gebruiker of -beheerder erdoor kan.>

## Bewijs

- Volledige suite met patch: <aantallen>
- Volledige suite op schone trunk: <aantallen>, faalnamen identiek: ja/nee
- Volledige suite op `7.0-stable-GEOxyz`: <aantallen>
- RuboCop op de gewijzigde bestanden: <n> (baseline <n>)
- `tools/check-patch-clean.sh`: PASS/FAIL · `tools/check-geoxyz-branch.sh`: PASS/FAIL
- Screenshots: <aantal>, gelezen: ja/nee

## Wat Jan nog moet doen

<Eén concrete handeling, of "niets". Deze sectie komt letterlijk in
docs/REGISTER.md onder "Openstaand voor Jan" te staan, dus schrijf hem zo dat
hij los leesbaar is: welk patchbestand, aan welk issue, met welke uitleg.>

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

<De vertrekpunten en de doodlopende wegen. Een beslissing die hier staat is
genomen; een volgende sessie hoort hem niet opnieuw te wegen. Noem waarom.>

## Volgende stap voor een sessie

<Eén concrete zin, of "af — niets te doen".>
