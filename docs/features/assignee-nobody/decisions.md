# assignee-nobody — Class A-beslissingen

Ronde 1 (2026-09-02) staat in `docs/DECISIONS.md`: K-05, optie A — alleen de
toewijzingslijst krijgt `<< niemand >>`, doelversie en categorie niet. Hieronder
ronde 2, 2026-09-05, na de review van 2026-09-03.

- **Beslist (autonoom, 2026-09-05):** F01 wordt opgelost door het **fragment
  zelfstandig te maken** (haakjes om de gevouwen `OR` en `AND`), niet door
  `UserQuery#sql_for_is_member_of_group_field` zelf te laten wrappen. Dat is
  Jans keuze g06, en de reden dat het zo en niet andersom moet: `sql_for_field`
  heeft 31 aanroepers en een plugin mag er ook een filter op enten. Eén
  aanroeper repareren laat de volgende dezelfde fout maken. Elke andere tak van
  de methode geeft al een enkele of een omhaakte clausule terug, dus dit is de
  bestaande conventie volgen en niet een nieuwe invoeren.
- **Beslist (autonoom, 2026-09-05):** de contractregel komt als **één
  commentaarregel boven `sql_for_field`**, niet als een `raise` of een test op
  de vorm van de string. Redmine schrijft dit soort afspraken nergens af als
  code, en INV-3 (29% van de kernmethoden heeft een regel erboven) zegt dat een
  regel boven de methode normaal is.
- **Beslist (autonoom, 2026-09-05):** de drie historie-tests krijgen een
  **volledige id-lijst op Redmine's eigen fixtures**, zoals `test_operator_has_been`
  en `test_operator_changed_from` ernaast, in plaats van `Issue.generate!` plus
  `assert_include`. Reden: de reviewer kon de helft van `sql_ev` weghalen zonder
  dat één test rood werd. Met issue 1 (matcht via het journaal) en issue 4
  (matcht via de huidige waarde) is elke helft afzonderlijk vastgepind; beide
  mutaties zijn gedraaid en geven nu rood.
- **Beslist (autonoom, 2026-09-05):** de type-poort wordt getest **op de
  gegenereerde SQL** (`priority_id` mag geen `IS NULL` opleveren) en de
  `is_custom_filter`-poort **op het resultaat** (een lijst-aangepast-veld met
  `none` als echte waarde). De eerste heeft geen zichtbaar gedrag om op te
  asserten — zonder poort geeft `:list` op een integerkolom een 500 — en trunk
  test `test_operator_none` op precies die manier.
- **Beslist (autonoom, 2026-09-05):** `test_assigned_to_values_should_be_sorted_by_status_and_name`
  telt **geen posities meer**. De reviewer liet zien dat de uitleg bij `[1..]`
  onjuist was; een `reject` op de pseudo-waarden zegt wat de test bedoelt en
  overleeft de volgende vaste regel die iemand toevoegt.
- **Beslist (autonoom, 2026-09-05):** F05 krijgt **één test op een tweede
  poortfilter** (`fixed_version_id`) en een alinea in het dossier die alle zeven
  geraakte velden noemt — geen code. K-05 blijft: alleen de toewijzingslijst
  krijgt de waarde in de UI.
