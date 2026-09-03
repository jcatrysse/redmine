---
slug: ldap-mail-prefs
feature: Rake: mailvoorkeuren dempen voor LDAP-only users
commit_51: 9e2c38e2d
geoxyz: todo
geoxyz_commit:
upstream: nooit
patch:
issue: 
---

# ldap-mail-prefs — status

## Waar het staat

Alleen-GEOxyz. Nog niet op de 7.0-branch gezet.

## Wat Jan nog moet doen

niets

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Gaat **nooit** naar upstream: de rake-taak heeft een hardcoded groepsnaam.
- Let op de forbidden constructs: geen top-level `def` en geen top-level
  constante in een `.rake`-bestand — die belanden op `Object` voor de hele
  app. Een module of klasse onder `lib/redmine/`.

## Volgende stap voor een sessie

Meepakken in een sessie die toch al op de GEOxyz-branch werkt.
