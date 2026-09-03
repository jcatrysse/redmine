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
- **2026-09-03 — Authorschap van de twee overgenomen commits staat op Takenori
  TAKAKI.** Het is zijn code; `git commit --author` legt dat vast en de
  commit-boodschap noemt #43355.
