---
slug: revision-branches
feature: Git-branches op de revisie- en de issuepagina
commit_51: cf826e3fd
geoxyz: todo
geoxyz_commit:
upstream: todo
patch:
issue: 
---

# revision-branches — status

## Waar het staat

Nog niet begonnen. Twijfelachtige kandidaat, en Jan dient hem bewust
ongewijzigd in.

## Wat het doet

Toont op een revisiepagina en op een issuepagina in welke Git-branches een
commit zit.

## Wat Jan nog moet doen

niets

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **Vier bezwaren, alle vier terecht:** een git-subproces per pageview (Redmine
  cachet changesets juist om de SCM buiten het renderen te houden), alleen de
  Git-adapter van zes, vier nieuwe instellingen, en een groeperingsheuristiek
  die een GEOxyz-branchconventie in core bakt.
- **Jan kiest bewust om dit niet vooraf in te binden** (beslissing 2026-09-01):
  Git-only, het commando eronder blijft, de vier instellingen blijven, en we
  wachten de reactie van het core-team af. Niet opnieuw wegen of we moeten
  splitsen of een DB-cache moeten bouwen — dat advies is vervallen.
- De bezwaren horen dus wél in het dossier onder "verwachte bezwaren", met per
  bezwaar het antwoord en wat het alternatief zou kosten. Dan kan het gesprek op
  redmine.org meteen inhoudelijk verder.
- Uit de ansifi-port bruikbaar: `--no-color` op `git branch --contains`.

## Volgende stap voor een sessie

`tools/claim.sh revision-branches`, dan de trunk-check op de changeset- en
revisieweergave.
