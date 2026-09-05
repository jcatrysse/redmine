---
slug: gitignore-credentials
feature: master.key, de credentials-map en credentials.yml.enc negeren
commit_51: 8ec9951d3
geoxyz: live
geoxyz_commit: e2c0447b6 + 3f5eb3be2
upstream: nooit
patch:
issue: 
---

# gitignore-credentials — status

## Waar het staat

Af, ronde 2 verwerkt. Staat op `7.0-stable-GEOxyz` als twee commits:
`e2c0447b6` (de twee oorspronkelijke regels) en `3f5eb3be2` (de derde regel uit
ronde 2, keuze g11). Gaat nooit naar upstream, dus geen dossier en geen patch.

## Wat het doet

Drie regels in `.gitignore`:

| Regel | Wat hij afdekt |
|---|---|
| `/config/master.key` | de standaardsleutel |
| `/config/credentials/` | de map met de sleutels per omgeving, `production.key` voorop |
| `/config/credentials.yml.enc` | het versleutelde bestand zelf (bewuste keuze, zie hieronder) |

Zo is de Rails-encryptiesleutel niet per ongeluk mee te committen, in geen van
de twee indelingen die Rails kent. Dat is dezelfde gedachte als de regels die er
al staan voor `config/database.yml` en `config/secrets.yml`.

**Dit is voorzorg, niet iets dat nu in gebruik is.** Redmine gebruikt geen
Rails-credentials: `config.require_master_key` staat uitgecommentarieerd in
`config/environments/production.rb:23`, nergens in `app/`, `lib/` of `config/`
wordt `Rails.application.credentials` gelezen, en `secret_key_base` komt uit
`config/initializers/secret_token.rb`. Er staat op dit moment dus geen enkel
credentials-bestand op de server. De regels staan er voor de dag dat iemand
`bin/rails credentials:edit` draait.

## Bewijs

- Volledige suite: n.v.t., met reden — de commit wijzigt één regel in
  `.gitignore` en niets anders (`git show --stat 3f5eb3be2`: 1 bestand,
  1 regel). Geen enkele test leest `.gitignore`, en er is geen code- of
  configuratiepad dat naar `config/credentials/` schrijft
  (`grep -rn "config/credentials\|Rails.application.credentials" app lib config
  test Rakefile` geeft alleen de uitgecommentarieerde regel in
  `production.rb:23`).
- RuboCop: n.v.t. — geen Ruby gewijzigd.
- `tools/check-geoxyz-branch.sh` (2026-09-05, `REF=7.0-stable-GEOxyz`): **PASS**
  — gelijk met upstream `7.0-stable`, geen AI-sporen, locales binnen de vijf.
- **Gemeten met de bestanden echt op schijf** (2026-09-05, commit `3f5eb3be2`),
  `git check-ignore -v`:

  | Pad | Regel die hem pakt |
  |---|---|
  | `config/master.key` | `.gitignore:15` |
  | `config/credentials.yml.enc` | `.gitignore:11` |
  | `config/credentials/production.key` | `.gitignore:12` |
  | `config/credentials/production.yml.enc` | `.gitignore:12` |
  | `config/credentials/staging.key` | `.gitignore:12` |
  | `config/credentials/some-new-env-2027.key` | `.gitignore:12` |

  De laatste rij is de reden dat het een map is en geen lijst met namen: een
  omgevingsnaam die nog niemand bedacht heeft, is meteen gedekt.

- **Voor en na, met `git add -A --dry-run`.** Zonder de nieuwe regel:
  `add 'config/credentials/production.key'` — de sleutel voor productie werd
  dus door een gewone `git add -A` klaargezet. Met de regel: alleen
  `add '.gitignore'`.
- **Niets dat gevolgd wordt raakt verstopt:**
  `git ls-files -z | git check-ignore -z --stdin -v` geeft geen enkele regel, en
  `git ls-files | grep -iE "master\.key|credentials"` is leeg.
- Ook nagelopen dat `.github/` **niet** genegeerd is: `git check-ignore`
  meldt niets voor `.github/workflows/tests.yml` en `git ls-files .github` toont
  de drie CI-bestanden nog.

## Wat Jan nog moet doen

niets

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- **`config/credentials.yml.enc` blijft genegeerd — dat is Jans keuze g16a
  (2026-09-04), tegen het advies in.** Rails bedoelt het omgekeerde: dat bestand
  is versleuteld en hoort juist wél in git, zodat een deploy de sleutel en de
  inhoud samen meeneemt. Jan wil bewust geen enkel credentials-bestand in de
  repo. Prijs, voor wie er later over valt: gaat GEOxyz ooit Rails-credentials
  gebruiken, dan staat het `.enc`-bestand alleen op de machine waar het gemaakt
  is en geeft `Rails.application.credentials.foo` op de server stil `nil`.
  Vandaag kost het niets, want Redmine gebruikt het mechanisme niet.
  Verander deze regel niet zonder Jan.
- **Rails plakt er zijn eigen regel achteraan, en dat is niet te voorkomen.**
  Wie `bin/rails credentials:edit` draait terwijl de sleutel nog niet bestaat,
  krijgt van Rails' `EncryptionKeyFileGenerator` een blok onder aan `.gitignore`
  gezet: een lege regel, `# Ignore key files for decrypting credentials and
  more.` en `/config/*.key` (of `/config/credentials/*.key` met
  `--environment`). `.gitignore` staat daarna als gewijzigd in `git status`.
  **Draai dat terug** (`git checkout -- .gitignore`); de regel is overbodig
  naast de drie die er staan. Gemeten op railties 8.1.3.1: Rails test met
  `File.read(".gitignore").include?(ignore)` op het **hele** blok inclusief de
  commentaarregel, dus alleen dat blok letterlijk overnemen onderdrukt het —
  een kale `/config/*.key`-regel doet dat niet (beide varianten uitgeprobeerd).
  Dat blok overnemen is bewust niet gedaan: het is vier regels ruis in een
  strak alfabetisch bestand, het dekt de `.enc`-bestanden niet, en g11 koos de
  vorm hierboven.
- Gaat **nooit** naar upstream: Redmine core gebruikt geen Rails credentials,
  dus `master.key` en `credentials.yml.enc` bestaan daar niet.
- **De derde regel van de 5.1-commit (`/.github/`) is bewust weggelaten.** Die
  map bevat de CI van de repository zelf; negeren betekent dat een nieuw of
  gewijzigd workflowbestand onzichtbaar wordt in `git status`. Voeg hem niet
  opnieuw toe.

## Volgende stap voor een sessie

af — niets te doen.
