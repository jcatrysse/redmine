---
slug: imap-oauth
feature: IMAP inbound mail via OAuth 2.0 (Gmail / O365)
commit_51: bbf5c0eb3
geoxyz: todo
geoxyz_commit:
upstream: todo
patch:
issue: 
---

# imap-oauth — status

## Waar het staat

Nog niet begonnen. Herschrijving nodig, en er zit een blokkade in: de
OAuth-autorisatieflow heeft een mens en echte credentials nodig, dus die kan
nooit een test zijn.

## Wat het doet

Inkomende mail via IMAP ophalen met OAuth 2.0 in plaats van een wachtwoord, voor
Gmail en Office 365.

## Wat Jan nog moet doen

niets — maar reken erop dat de autorisatieflow op een moment jouw handen en
echte credentials vraagt.

## Wat er al bekend is, en niet opnieuw afgewogen moet worden

- De bestaande 5.1-rake is 435 regels met tien methodes en een constante op
  `Object`, en print het access token **volledig** bij `imap_debug=1`.
- Hij trekt `gmail_xoauth` binnen terwijl `Net::IMAP::XOauth2Authenticator` al
  in de gepinde `net-imap` zit — nagekeken: 0.6.6 heeft hem, en 5.1's 0.4.24 had
  hem al. Dus geen nieuwe gem (INV-6).
- Upstream-vorm is vermoedelijk **geen nieuwe taakfamilie** maar opties op de
  bestaande `receive_imap` plus configuratie in `configuration.yml`.
- `lib/tasks/**/*` is uitgesloten in Redmine's `.rubocop.yml`, dus rake-code
  wordt niet gelint. Daar is menselijke review de enige controle.

## Volgende stap voor een sessie

`tools/claim.sh imap-oauth`, dan de trunk-check op `receive_imap` en
`configuration.yml`.
