---
slug: geoxyz-hosts
feature: "*.geoxyz.eu toestaan in development"
commit_51: 918f3466e
geoxyz: live
geoxyz_commit: 075c86e8a + 363686456
upstream: nooit
patch:
issue: 
---

# geoxyz-hosts — status

## Waar het staat

Af. Staat op `7.0-stable-GEOxyz` als twee commits: de oorspronkelijke regel
(`075c86e8a`) en de reviewfix van ronde 2 (`363686456`). Gaat nooit naar
upstream, dus er is geen dossier en geen patch.

> De oude SHA `fe737441b` in dit bestand wees naar de commit van vóór de
> identiteitsherschrijving van 2026-09-06 (K-13); `075c86e8a` is dezelfde
> inhoud. Zie `docs/DECISIONS.md` voor de volledige kaart oud naar nieuw.

## Wat het doet

In de ontwikkelomgeving weigert Rails standaard elk verzoek waarvan de
`Host`-header niet in `config.hosts` staat (bescherming tegen DNS rebinding).
Eén regel voegt de subdomeinen van `geoxyz.eu` toe, zodat een
ontwikkelinstantie achter bijvoorbeeld `redmine-dev.geoxyz.eu` bereikbaar is in
plaats van 403 te geven:

```ruby
config.hosts << /[a-z0-9-]+(?:\.[a-z0-9-]+)*\.geoxyz\.eu/i
```

## Bewijs

- Volledige suite op `7.0-stable-GEOxyz`, systeemtests inbegrepen
  (`tools/test-env.sh /home/user/wt/geoxyz bundle exec ruby bin/rails test:all`,
  PostgreSQL 16, serieel gedraaid): **6123 runs, 32351 assertions, 0 failures, 0 errors,
  39 skips**, exit 0, in 822 s
- RuboCop op het gewijzigde bestand: 0 (baseline 0)
- `tools/check-geoxyz-branch.sh`: PASS
- **Waarom geen test bij deze regel hoort, mechanisch aangetoond in plaats van
  beredeneerd.** `config/environments/development.rb` wordt onder
  `RAILS_ENV=test` niet geladen:

  ```
  $ RAILS_ENV=test bundle exec ruby -e 'require "./config/environment"; ...'
  RAILS_ENV      test
  config.hosts   []
  ```

  Een lege lijst laat `HostAuthorization#call` meteen doorgeven, dus de
  middleware kijkt in de testomgeving niet één keer naar de `Host`-header. Een
  test die deze regel raakt bestaat dus niet en kan niet bestaan; de suite
  hierboven is er om te bewijzen dat de commit niets anders brak.

### Wat Rails' hostcontrole echt doet, gemeten

Twee metingen, want ze beantwoorden verschillende vragen. De eerste draait
Rails' eigen `ActionDispatch::HostAuthorization::Permissions#allows?` (het stuk
code dat 403 of 200 beslist); de tweede stuurt een echte HTTP-regel over een
rauwe socket naar een draaiende dev-server, omdat `curl` sommige van deze
hostnamen zelf al opschoont.

Rails ankert een regexp uit `config.hosts` zelf. Wat er werkelijk opgeslagen
wordt:

```
oud:  /\A(?-mix:.*\.geoxyz\.eu)(?-mix::\d+)?\z/
nieuw: /\A(?i-mx:[a-z0-9-]+(?:\.[a-z0-9-]+)*\.geoxyz\.eu)(?-mix::\d+)?\z/
```

Tegen een draaiende server, `GET /login` over een rauwe socket:

| Host | Zonder de regel | Oude regel | Nieuwe regel |
|---|---|---|---|
| `redmine.geoxyz.eu` | 403 | **200** | **200** |
| `a.b.geoxyz.eu` | 403 | **200** | **200** |
| `a.b.c.geoxyz.eu` | 403 | **200** | **200** |
| `REDMINE.geoxyz.eu` | 403 | **200** | **200** |
| `redmine.GEOXYZ.eu` | 403 | 403 *(F01)* | **200** |
| `redmine.Geoxyz.EU` | 403 | 403 *(F01)* | **200** |
| `geoxyz.eu` (apex) | 403 | 403 | 403 |
| `evil-geoxyz.eu` | 403 | 403 | 403 |
| `geoxyz.eu.attacker.com` | 403 | 403 | 403 |
| `evil.example.com` | 403 | 403 | 403 |
| `attacker.com/.geoxyz.eu` | 403 | **200** *(F02)* | 403 |
| `attacker.com:8080.geoxyz.eu` | 403 | **200** *(F02)* | 403 |
| `_.geoxyz.eu` | 403 | **200** *(F02)* | 403 |
| `.geoxyz.eu` | 403 | **200** *(F02)* | 403 |
| `127.0.0.1`, `localhost` | 200 | 200 | 200 |

De volledige set van 47 hostnamen (inclusief de newline- en CR-varianten, de
trailing-dot-FQDN, de punycode- en homograafvormen en de poortachtervoegsels)
loopt door `Permissions#allows?` en geeft dezelfde uitkomsten.

### G9 — in een echte browser

`verify/geoxyz-hosts.mjs`, tegen de dev-server, één keer zonder en één keer met
de fix. De hostnamen staan in `/etc/hosts` op `127.0.0.1`.

| Host | Voor | Na | Screenshot | Wat het toont |
|---|---|---|---|---|
| `redmine.geoxyz.eu` | 200 | 200 | `{before-,}single-label-subdomain.png` | de alledaagse ontwikkelhostnaam, ongewijzigd |
| `a.b.geoxyz.eu` | 200 | 200 | `{before-,}multi-label-subdomain.png` | twee subdomeinniveaus blijven werken — dat is wat de strengere prefix had kunnen kosten |
| `geoxyz.eu` | 403 | 403 | `{before-,}apex-refused.png` | het apexdomein blijft geweigerd; de pagina noemt de host zelf |
| `_.geoxyz.eu` | **200** | **403** | `{before-,}junk-prefix-label.png` | F02, en het is het enige paar dat verschilt |

**Twee dingen die een browser níét kan aantonen, en dat is geen tekortkoming
van het script maar van HTTP-clients.** Chromium zet de authority in kleine
letters vóór het de `Host`-header bouwt, dus F01 (hoofdletters) is in een
browser onzichtbaar; en het weigert een header met een schuine streep, een
spatie of een poort ín de naam te sturen, dus de meeste F02-vormen ook. Daarom
staat de rauwe-sockettabel hierboven: die is het bewijs voor *welke* host, de
screenshots zijn het bewijs dat de pagina echt rendert.

**En één ding om te weten bij het lezen van de screenshots:** een toegelaten
host levert de gewone loginpagina op, en daar is niet aan te zien welke
hostnaam gevraagd werd — er staat geen adresbalk in het beeld. Het script
vergelijkt de paren daarom met SHA-256 en drukt af of ze identiek zijn: drie
paren identiek, en `_.geoxyz.eu` het enige dat verschilt. De geweigerde host is
wél zelfaanwijzend: Rails' pagina zet "Blocked hosts: `_.geoxyz.eu:3000`" in de
titel.

## Wat Jan nog moet doen

niets

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- Gaat **nooit** naar upstream: `*.geoxyz.eu` is een bedrijfsdomein, dat hoort
  niet in Redmine core.
- **De regexp is niet onveilig, ook al ziet hij er ongeankerd uit.** Rails
  ankert een regexp in `config.hosts` zelf: `sanitize_regexp` maakt er
  `/\A<jouw regexp>(?::\d+)?\z/` van. `geoxyz.eu.attacker.com` wordt daardoor
  geweigerd — nagemeten, zie de tabel. Verander hem dus niet "voor de
  veiligheid" in de stringvorm `".geoxyz.eu"`: die laat het apexdomein wél toe
  en tegelijk maar één subdomeinniveau, dus `a.b.geoxyz.eu` zou wegvallen.
- **De `i`-vlag hoort op het patroon zelf.** `sanitize_regexp` voegt geen
  vlaggen toe; een geïnterpoleerde `Regexp` draagt zijn eigen opties mee als
  `(?i-mx:…)`. Haal die vlag er dus niet af — dan komt F01 terug.
- **De prefix is met opzet `[a-z0-9-]+(?:\.[a-z0-9-]+)*` en niet `.*`.** Dat is
  precies wat Rails' eigen geblokkeerde-hostpagina als eis formuleert ("valid
  hostnames (containing only numbers, letters, dashes and dots)"), en het houdt
  meerdere subdomeinniveaus heel. Maak er geen `[a-z0-9-]+\.` van: dan valt
  `a.b.geoxyz.eu` weg, en dat is de reden dat de stringvorm destijds al afviel.
- **De regel blijft in `config/environments/development.rb`** (bevinding F03,
  bewust niet opgelost). `config/additional_environment.rb` wordt in élke
  omgeving geladen en zou `HostAuthorization` in productie aanzetten met alleen
  `*.geoxyz.eu` toegestaan; `RAILS_DEVELOPMENT_HOSTS` loopt door
  `sanitize_string` en levert maar één subdomeinniveau. Een mergeconflict in
  dit bestand los je op door de regel te behouden.
- Alleen `development`. `production.rb` raken we niet aan: daar hoort de
  hostcontrole van de reverse proxy te komen, en Redmine zet in productie
  standaard geen `config.hosts`.

## Volgende stap voor een sessie

af — niets te doen.
