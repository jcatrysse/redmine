# rake-webhook-flush — Class A-beslissingen

Autonoom beslist tijdens deze feature. Eén regel per beslissing, met de reden.
Class B (keuzes voor Jan) staat in `docs/DECISIONS.md` onder K-24.

- **De fix zit in `Mailer.with_synched_deliveries`, niet in de rake-taken.** Die
  helper bestaat sinds 2012 voor precies dit probleem (proces stopt voor de
  jobs liepen), en alle drie de mail-ontvangende taken draaien er al in. Eén plek,
  geen sleep per taak — zoals de opdracht vroeg.

- **`ActiveJob::Base` omzetten, niet `WebhookJob`.** De eerste versie zette
  `WebhookJob.queue_adapter`. Active Job bewaart de adapter in een
  `class_attribute`, dus "terugzetten" pint `WebhookJob` op de geërfde waarde en
  volgt hij `ActiveJob::Base` daarna niet meer. Gemeten: `mailer_test.rb` +
  `webhook_test.rb` in één proces gaf 8 failures (0 op trunk). `ActiveJob::Base`
  is de wortel; daar terugzetten is exact. Dat het nu voor alle jobs zonder eigen
  adapter geldt is de scope-vraag van K-24.

- **De bestaande `MailDeliveryJob`-regels blijven staan.** Ze zijn met de
  `ActiveJob::Base`-regel grotendeels overbodig, maar weghalen verandert gedrag
  voor wie `MailDeliveryJob` een eigen adapter gaf, en het is opruimwerk naast de
  fix (INV-1).

- **Onvoorwaardelijk inline, ook met een echte backend.** #36393 haalde in 2022
  precies de `AsyncAdapter`-check uit deze helper ("always inline without trying
  to be clever about it"). Een check terugbrengen voor jobs en niet voor mails
  maakt de helper inconsistent. De keerzijde (Sidekiq-installaties versturen
  deze webhooks nu inline) staat in K-24.

- **Eén test, in `mailer_test.rb`, naast de bestaande test van dezelfde helper.**
  Hij zet `ActiveJob::Base` op een `TestAdapter`, zodat hij op de oude code
  deterministisch rood is (de job blijft in de wachtrij) — met de `AsyncAdapter`
  zou het resultaat van een thread-race afhangen. Een tweede test in
  `webhook_test.rb` is gebouwd en weer weggehaald: `WebhookTest` zet
  `ActiveJob::Base` op `:test`, en de bestaande `MailDeliveryJob`-regel pint
  `MailDeliveryJob` dan op die testadapter, wat daarna mailtests breekt.

- **De `ensure` van de nieuwe test zet `MailDeliveryJob` terug op inline**, net
  als de bestaande test ernaast. Anders pint de bestaande `MailDeliveryJob`-regel
  hem op de `TestAdapter` van deze test.

- **Geen vertalingen, dus één patchbestand.** Er is geen zichtbare tekst.

- **G9 met een echte webhook-ontvanger, niet met een screenshot van een
  instellingenpagina.** De feature heeft geen scherm; wat bewezen moet worden is
  dat de webhook aankomt. Het script start de ontvanger zelf, op 192.0.2.2,
  omdat Redmine loopback-adressen als webhookdoel weigert.

- **G9 ook tegen `7.0-stable-GEOxyz` (poort 3001, eigen dev-database).** Het is
  goedkoop en het is de kant die in productie draait.
