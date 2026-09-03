---
slug: webhook-tracker-filter
feature: Webhook beperken tot gekozen trackers
commit_51: 25220b45d (deel)
geoxyz: todo
geoxyz_commit:
upstream: todo
patch:
issue: 
---

# webhook-tracker-filter — status

## Waar het staat

Nog niet begonnen. Dit is de volgende regel in het register.

## Wat het doet

Beperkt de uitgaande webhook tot de trackers die je kiest, in plaats van bij
elke issuewijziging te vuren.

## Wat Jan nog moet doen

niets

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- De 5.1-commit `25220b45d` doet **twee** dingen; die zijn bewust in twee
  issues gesplitst (deze en `webhook-issue-closed`). Eén patch die twee dingen
  doet wordt twee keer zo lang besproken en half zo vaak geaccepteerd.
- Doe de trunk-check eerst op de **herkomst** van de webhookcode zelf: zit die
  überhaupt in Redmine core, of is het een plugin op de GEOxyz-branch? Dat
  bepaalt of er een upstream-patch bestaat om te maken.
- Zoek op redmine.org met **één** trefwoord. Vier features op rij bleek er al
  een issue te bestaan, en één keer had een kerncommitter er zelf al aan
  gewerkt.

## Volgende stap voor een sessie

`tools/claim.sh webhook-tracker-filter`, dan de trunk-check op de herkomst van
de webhookcode.
