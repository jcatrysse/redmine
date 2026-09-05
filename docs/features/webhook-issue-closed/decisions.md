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

## Ronde 2 (2026-09-05)

- **De tijdstempelmapping van `closed` verhuist naar `Issue::Webhookable`
  (F05).** De eerste versie zette `when 'updated', 'closed'` in
  `webhook_payload_timestamp` in `lib/redmine/acts/webhookable.rb` — één woord,
  en het werkte. Het sprak wel het eigen argument van het dossier tegen: dat
  argument zegt dat `closed` issuespecifiek is en dat het predicaat alleen op
  `Issue` bestaat, en zette de naam vervolgens tóch in de generieke laag. Nu
  overschrijft de concern `webhook_payload_timestamp`. Dat kost twee regels
  meer en levert op dat de patch **geen enkel bestand onder `lib/redmine/`**
  meer raakt — voor een los ingediend deelstuk is dat het betere verhaal.
  Nagelopen dat het niets verandert: de generieke tak was alleen bereikbaar bij
  een sluiting zonder journaal, en de payloadtest die precies dat geval vastzet
  (`should use the issue timestamp when there is no journal`) blijft groen.

- **De `closed_on`-bewaking krijgt één regel waarom (F10 / Jans g16e).** Het is
  een niet-vanzelfsprekend *waarom* — waarom het sluitveld en niet de status —
  en daar is INV-3 niet tegen. De hele correctheidsredenering van de patch
  hangt aan die vijf woorden, en de volgende persoon die `update_closed_on`
  aanraakt leest dit dossier niet.

- **De end-to-end test leest de job die zijn eigen blok in de wachtrij zette
  (F07).** Hij nam eerst de eerste `WebhookJob` in de procesbrede wachtrij. Dat
  was vandaag dezelfde job, maar bij een regressie precies niet: toen de
  bewaking bij wijze van proef werd weggehaald, viel de test om op de
  payload van de *create* in plaats van op de aflevering van de sluiting. Nu
  wordt de lengte van de wachtrij vóór het blok onthouden.

- **Een notitie op een gesloten issue krijgt een eigen assertie (F03).** Dat
  geval staat bij *The problem* met name genoemd als een van de dingen die
  ontvangers fout doen, en het was het enige zo genoemde geval zonder test.
  Rij "deleted" krijgt er géén: de trigger is een `after_save_commit`, dus een
  destroy kan hem niet bereiken — een test daarop zou een eigenschap van Rails
  vastleggen en niet van deze patch.

- **F02 wordt beschreven, niet gerepareerd.** Wordt hetzelfde issue twee keer
  gesaved binnen één omsluitende transactie, dan ziet `after_save_commit`
  alleen de dirty state van de tweede save en valt `issue.closed` stil weg
  (gemeten: `["issue.updated"]`, met `closed_on` wél gezet). Geen enkel pad in
  core doet dat; het dichtstbijzijnde risico is een plugin die het issue
  opnieuw opslaat vanuit `controller_issues_edit_after_save`, dat binnen de
  transactie van `save_issue_with_child_records` draait. Het repareren vraagt
  een tweede callback plus per-instance state die na commit én na rollback
  gereset moet worden — meer machinerie dan het gemeten risico rechtvaardigt
  (INV-1). Het staat nu bij "Backward compatibility", zodat het benoemd en
  vindbaar is in plaats van stil.

- **`acts_as_webhookable` krijgt de volledige lijst, niet een optelling
  (F08).** `Issue` is daarmee het enige model dat niet meebeweegt als de
  default ooit een generieke actie krijgt. Dat als optelling schrijven vraagt
  om de default uit `Redmine::Acts::Webhookable` naar buiten te halen — een
  wijziging in juist die generieke laag die deze patch verder met rust laat.
  De afweging staat als één zin in het dossier.
