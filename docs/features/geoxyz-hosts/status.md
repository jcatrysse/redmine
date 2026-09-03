---
slug: geoxyz-hosts
feature: "*.geoxyz.eu toestaan in development"
commit_51: 918f3466e
geoxyz: live
geoxyz_commit: fe737441b
upstream: nooit
patch:
issue: 
---

# geoxyz-hosts — status

## Waar het staat

Af. Staat op `7.0-stable-GEOxyz` als één commit. Gaat nooit naar upstream, dus
er is geen dossier en geen patch.

## Wat het doet

In de ontwikkelomgeving weigert Rails standaard elk verzoek waarvan de
`Host`-header niet in `config.hosts` staat (bescherming tegen DNS rebinding).
Eén regel voegt de subdomeinen van `geoxyz.eu` toe, zodat een
ontwikkelinstantie achter bijvoorbeeld `redmine-dev.geoxyz.eu` bereikbaar is in
plaats van 403 te geven.

## Bewijs

- Volledige suite met patch: n.v.t. — `config/environments/development.rb`
  wordt in de testomgeving niet geladen. De branchsuite staat wel groen, zie
  `docs/features/ar-sessions/status.md`.
- RuboCop op de gewijzigde bestanden: 0 (baseline 0)
- `tools/check-geoxyz-branch.sh`: PASS
- **Echt nagelopen tegen een draaiende server** (`curl -H "Host: ..."` op
  `http://127.0.0.1:3000/login`):

  | Host | Zonder de regel | Met de regel |
  |---|---|---|
  | `redmine.geoxyz.eu` | 403 | **200** |
  | `a.b.geoxyz.eu` | 403 | **200** |
  | `geoxyz.eu` | 403 | 403 |
  | `evil.example.com` | 403 | 403 |
  | `geoxyz.eu.attacker.com` | 403 | 403 |
  | `127.0.0.1`, `localhost` | 200 | 200 |

  De "zonder"-kolom is gemeten met Rails' eigen
  `ActionDispatch::HostAuthorization::Permissions` op alleen
  `ALLOWED_HOSTS_IN_DEVELOPMENT`; de "met"-kolom ook echt met `curl` tegen de
  dev-server.

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
- Alleen `development`. `production.rb` raken we niet aan: daar hoort de
  hostcontrole van de reverse proxy te komen, en Redmine zet in productie
  standaard geen `config.hosts`.

## Volgende stap voor een sessie

af — niets te doen.
