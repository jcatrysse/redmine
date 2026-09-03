---
slug: webhook-issue-closed
feature: Apart issue.closed-event op de webhook
commit_51: 25220b45d (deel)
geoxyz: todo
geoxyz_commit:
upstream: todo
patch:
issue: 
---

# webhook-issue-closed — status

## Waar het staat

Nog niet begonnen.

## Wat het doet

Een apart `issue.closed`-event op de webhook, zodat een ontvanger niet elke
issuewijziging hoeft te filteren om te weten dat er iets gesloten is.

## Wat Jan nog moet doen

niets

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Andere helft van de 5.1-commit `25220b45d`, bewust een eigen issue. Niet
  samenvoegen met `webhook-tracker-filter`.
- Zelfde trunk-check als daar: zit de webhookcode in core of in een plugin?

## Volgende stap voor een sessie

Doe `webhook-tracker-filter` eerst — die trunk-check beantwoordt ook deze.
