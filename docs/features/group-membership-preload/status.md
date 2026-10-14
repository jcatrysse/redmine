---
slug: group-membership-preload
feature: Een groep met veel gebruikers aan een project toevoegen met minder queries per gebruiker
commit_51: -
geoxyz: live
geoxyz_commit: 2b9700a9c
upstream: patch klaar
patch: patches/group-membership-preload/2026-10-14-r25236-feature.patch
issue:
---

# group-membership-preload — status

## Waar het staat

Patch klaar op `patch/group-membership-preload` (trunk r25236) en dezelfde commit
op `7.0-stable-GEOxyz`. Opdracht van Jan van 2026-10-14 via de coördinator van de
Redmine 7-migratie: de "zuinige core"-helft van "cache + zuinige core". De
cache-helft zit in `redmine_custom_workflows` en is van een andere sessie.
`MemberRole#add_role_to_group_users` en `#add_role_to_subprojects` laden de
bestaande lidmaatschappen nu één keer per niveau en bouwen nieuwe uit objecten in
plaats van ids; elk lidmaatschap wordt nog met `save!` en alle callbacks
bewaard. Eindtoestand identiek (checksum). Geen issue op redmine.org voor deze
richting; #43946 is de omgekeerde richting en blijft apart.

## Wat het doet

Een groep van 1000 gebruikers aan een project toevoegen kost 3 tot 5 in plaats
van 7 tot 13 queries per gebruiker, en met 5 overervende subprojecten 36 in
plaats van 70 (twee rollen). Voor de gebruiker verandert er niets behalve de
wachttijd.

## Bewijs

- Volledige suite met patch (`test:all`, met systeemtests): 6220 runs, 32807 assertions, 27 failures, 2 errors, 87 skips
- Volledige suite op schone trunk r25236: de 29 zitten in vijf SCM-testbestanden (geen `svn` in de container); die vijf op schone trunk: 288 runs, 27 failures, 2 errors, faalnamen identiek: ja
- Volledige suite op `7.0-stable-GEOxyz` (`2b9700a9c`): 6196 runs, 32670 assertions, 0 failures, 0 errors, 28 skips
- Nieuwe tests rood op de oude code: ja (`Expected 35 to be <= 15`, `Expected 100 to be <= 55`)
- RuboCop op de gewijzigde bestanden: 0 (baseline 0)
- `tools/check-patch-clean.sh`: PASS (zonder `--submit`, mirror 11 achter) · `tools/check-symmetry.sh`: PASS · `tools/check-geoxyz-branch.sh`: voor deze feature ok, de run als geheel 2 FAIL die er al waren (26 commits achter `origin/7.0-stable`, mergeconflict in 8 bestanden van andere features)
- Live (development, 1000 gebruikers, 1 rol): 7.021 → 3.022 queries en 17,5 → 9,1 s zonder subprojecten; 38.046 → 20.037 queries en 95,1 → 60,8 s met 5 overervende subprojecten; eindtoestand identiek (checksum `bb7f7984f7d8c111`)
- Screenshots: 10, gelezen: ja

## Wat Jan nog moet doen

De mirror syncen (op 2026-10-14 11 commits achter echte trunk r25249; de patch
applyt daar al wel op), `tools/check-patch-clean.sh group-membership-preload
--submit` draaien, en een issue aanmaken met
`patches/group-membership-preload/2026-10-14-r25236-feature.patch` en de
Engelse tekst uit `dossier.md` vanaf "The problem", met de voor/na-screenshots.
Eén patchbestand: er zijn geen vertalingen.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Geen bulk-insert** (`insert_all`): Jan koos daar bewust niet voor omdat het
  de callbacks per gebruiker overslaat. Niet heropenen.
- **Apart issue, niet in #43946**: dat is `Group#user_added` (gebruiker aan
  groep). De twee patches verdragen elkaar (#43946 applyt erna met fuzz 1).
- **Geen vlag zoals `skip_subproject_propagation`**: de preload per niveau in
  `add_role_to_subprojects` haalt het grootste deel met twee regels; de
  children-query per gebruiker blijft bewust.
- **Verwijderen is niet sneller** (8 queries per gebruiker): buiten deze patch,
  zie #43203 en #22850.
- **`7.0-stable-GEOxyz` loopt 26 commits achter op `origin/7.0-stable`**, en de
  merge conflicteert in 8 bestanden van andere features (webhooks,
  `git_adapter_test.rb`, de vijf locales). Niet in deze feature opgelost; de
  commit staat op `1d8c2a3`, de revisie die de coördinator mat.

## Volgende stap voor een sessie

Af tot Jan het issue indient — niets te doen.
