# webhook-issue-closed — Class A-beslissingen

Autonoom beslist tijdens deze feature. Eén regel per beslissing, met de reden.
Class B (keuzes voor Jan) staat in `docs/DECISIONS.md`.

- **De trigger leest `closed_on`, niet de statuswijziging.** `closed_on` wordt
  in core op precies één plek geschreven — `update_closed_on`, `if closing?` —
  en staat in geen enkele `safe_attributes`-lijst, dus geen request kan het
  zetten. "Deze save schreef `closed_on`" en "deze save sloot het issue" zijn
  daarmee dezelfde uitspraak. De 5.1-variant deed
  `IssueStatus.find_by(id: saved_change_to_status_id.first)` en betaalde dus een
  extra query per statuswijziging voor een antwoord dat core al had liggen.

- **De callback staat in `Issue::Webhookable`, niet in de `case` van
  `acts_as_webhookable`.** Die `case` mapt een actienaam op een
  Rails-lifecycle-callback; "closed" is geen lifecycle-event maar een
  toestandsovergang, en het predicaat bestaat alleen op `Issue`. De `case` heeft
  geen `else`, en trunks eigen test `should generate payload for custom event`
  (die `news.commented` registreert) leunt daarop: een event registreren zonder
  generieke callback is ondersteund gedrag. `Issue#attachment_removed` roept in
  trunk om dezelfde reden zelf `Webhook.trigger` aan.

- **`after_save_commit`, niet `after_update_commit`.** Een issue dat direct in
  een gesloten status wordt aangemaakt is volgens Redmine's eigen definitie een
  sluiting: `Issue#closing?` geeft voor een nieuw record `closed?` terug, en
  `update_closed_on` stempelt `closed_on` dus ook bij die create. Alleen op
  updates vuren zou dat geval stil laten vallen.

- **De eventvolgorde is `created updated closed deleted`.** Het formulier
  itereert over de geregistreerde array, dus dit is ook de volgorde van de
  vinkjes; "closed" hoort tussen updated en deleted en niet erachter.

- **`issue.closed` krijgt hetzelfde journaal als `issue.updated`.** Zonder dat
  is een hook die alléén op `issue.closed` abonneert slechter geïnformeerd dan
  een hook op `issue.updated` voor precies dezelfde gebeurtenis: de notitie
  waarmee iemand het issue sloot is meestal de inhoud waar het om gaat. Het is
  één regel: `%w(updated closed).include?(action)`.

- **De tijdstempel van `closed` is `updated_on`, niet `closed_on`.** Ze zijn
  op het moment van sluiten gelijk (`update_closed_on` doet
  `self.closed_on = updated_on`), en `updated_on` is nooit `nil`. Trunks
  bestaande geparametriseerde payloadtest loopt over álle geregistreerde
  events met `Issue.first`, dus met `closed_on` zou die test op een issue dat
  nooit gesloten is een `NoMethodError` op `nil` geven.

- **Geen setting.** INV-6, en webhooks zitten al achter
  `Setting.webhooks_enabled?`. Dat die schakelaar ook dit event dooft is
  nagelopen in de browser (`shots/deliveries-webhooks-disabled.png`).

- **`Version` krijgt dit event niet**, ook al heeft `Version` een gesloten
  status. INV-1: buiten scope, en het zou verdubbelen wat er te reviewen valt.
  Het ontwerp generaliseert wel: `Version::Webhookable` krijgt dan dezelfde
  drie regels met zijn eigen predicaat.

- **De testhelper `create_hook` blijft ongewijzigd.** Bij
  `webhook-tracker-filter` bleek dat die helper uitbreiden 17 bestaande tests
  op schone trunk laat erroren en daarmee het rood-bewijs verstopt. De nieuwe
  tests gebruiken een eigen helper (`generate_closed_issue`) en laten
  `create_hook` staan.
