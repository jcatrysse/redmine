---
slug: gitignore-credentials
feature: master.key en credentials.yml.enc negeren
commit_51: 8ec9951d3
geoxyz: live
geoxyz_commit: e2c0447b6
upstream: nooit
patch:
issue: 
---

# gitignore-credentials — status

## Waar het staat

Af. Staat op `7.0-stable-GEOxyz` als één commit van twee regels. Gaat nooit
naar upstream, dus geen dossier en geen patch.

## Wat het doet

`config/master.key` en `config/credentials.yml.enc` staan in `.gitignore`, zodat
de Rails-encryptiesleutel niet per ongeluk mee te committen is. Dat is dezelfde
gedachte als de regels die er al staan voor `config/database.yml` en
`config/secrets.yml`.

## Bewijs

- Volledige suite: n.v.t. — `.gitignore` is geen code.
- RuboCop: n.v.t.
- `tools/check-geoxyz-branch.sh`: PASS
- Echt nagelopen: beide bestanden aangemaakt, `git status --porcelain` bleef
  leeg, en `git check-ignore -v` wijst de twee nieuwe regels aan
  (`.gitignore:11` en `.gitignore:14`). Daarna weer verwijderd.
- Ook nagelopen dat `.github/` **niet** genegeerd is: `git check-ignore`
  meldt niets voor `.github/workflows/tests.yml` en `git ls-files .github` toont
  de drie CI-bestanden nog.

## Wat Jan nog moet doen

niets

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Gaat **nooit** naar upstream: Redmine core gebruikt geen Rails credentials,
  dus `master.key` en `credentials.yml.enc` bestaan daar niet.
- **De derde regel van de 5.1-commit (`/.github/`) is bewust weggelaten.** Die
  map bevat de CI van de repository zelf; negeren betekent dat een nieuw of
  gewijzigd workflowbestand onzichtbaar wordt in `git status`. Voeg hem niet
  opnieuw toe.

## Volgende stap voor een sessie

af — niets te doen.
