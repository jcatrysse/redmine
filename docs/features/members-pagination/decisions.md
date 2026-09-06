# members-pagination — Class A-beslissingen

- **2026-09-03 — Geen eigen patch, aanhaken op #43355.** Al vastgelegd in
  `status.md` vóór deze sessie; hier bevestigd omdat Takenori TAKAKI op
  2026-08-05 een rebase op trunk aan dat issue hing. Een tweede patch op
  hetzelfde issue verkleint de kans op allebei.
- **2026-09-03 — De verbetering gaat als tekst in de note, niet als patchbestand.**
  Een fix bovenop `0001`/`0002` applyt per definitie niet standalone op een
  schone `origin/master`, en INV-2 verbiedt zo'n bestand in `patches/`. De
  diff staat daarom letterlijk in `dossier.md`, klaar om in de note te plakken.
- **2026-09-03 — De GEOxyz-branch krijgt drie commits, niet één.** Twee die
  Takenori's `0001` en `0002` één-op-één zijn, en één losse met de clamp. Als
  upstream de clamp niet overneemt is precies één commit de afwijking, en die
  kan dan blijven staan of vervallen zonder de andere twee te raken.
- **2026-09-03 — Authorschap van de twee overgenomen commits zou op Takenori
  TAKAKI staan.** ~~Het is zijn code; `git commit --author` legt dat vast en de
  commit-boodschap noemt #43355.~~ **Onjuist gebleken op 2026-09-06.** Beide
  commits stonden op `Jan Catrysse` als auteur, vóór én na de herschrijving van
  K-13; alleen de commit-boodschap noemt #43355. `git commit --author` is dus
  nooit gebruikt. Niet alsnog rechtgezet: dat zou een tweede force-push op
  `7.0-stable-GEOxyz` kosten voor een branch die alleen GEOxyz draait, en de
  patchbestanden waar het voor uitmaakt zijn niet van ons — die van Takenori
  hangen onder zijn eigen naam aan #43355. Wél melden in de note dat het zijn
  werk is; dat doet de sectie *Confirmation, and thanks* in `dossier.md`.
- **2026-09-06 — Het commentaar in de clamp blijft staan, in beide helpers.**
  Bevinding N01 van de review noemt de twee regels commentaar en de gedupliceerde
  rekenregel; de gegeven keuze was "laten staan of één zin in plaats van twee".
  Het wordt laten staan, en één keer vastgelegd zodat de volgende sessie het niet
  opnieuw weegt. Het commentaar zegt een *waarom* en geen *wat*, wat INV-3
  toestaat en wat past bij Redmine's gemeten dichtheid (29% van de kernmethodes
  heeft een commentaarregel erboven). De duplicatie is alleen weg te halen door
  de rekenregel naar `Redmine::Pagination` te tillen, en dat is precies het
  alternatief dat het dossier bewust niet kiest. En het is een voorstel op
  andermans patch: hem verder uitkleden om twee commentaarregels te sparen kost
  een ronde en levert niets op waar een committer om vraagt.
- **2026-09-06 — De mismatch tussen adresbalk en getoonde pagina (F06) wordt
  benoemd, niet gerepareerd.** De clamp zit in de paginator, dus de rijlinks en
  de adresbalk houden het gevraagde paginanummer terwijl een andere pagina
  gerenderd wordt. Repareren zou de vier regels naar de controllers verbreden op
  andermans patch, tegen INV-1 in. In plaats daarvan staat het gevolg in één
  alinea in de note, en "redirect naar een geldige pagina" staat als vierde
  alternatief in *Alternatives considered*, met wat het kost. De committer kiest.
