# webhook-tracker-filter — Class A-beslissingen

Autonoom genomen, met de reden erbij. Een volgende sessie hoort deze niet
opnieuw te wegen. Class B-keuzes staan in `docs/DECISIONS.md`.

- **Beslist (autonoom):** de hele webhookfunctie wordt níet opnieuw ingediend —
  upstream heeft die al (#29664, 25 commits sinds 2025-10-07). Alleen het
  trackerfilter blijft over van 5.1-commit `25220b45d`.
- **Beslist (autonoom):** leeg = alle trackers. De 5.1-code eiste minstens één
  tracker zodra er een issue-event aanstond; dat maakt elke bestaande hook
  ongeldig bij een upgrade en is upstream niet verdedigbaar.
- **Beslist (autonoom):** het formulier biedt `Tracker.sorted`, dus alle
  trackers, niet alleen die van de gekozen projecten. Zes bestaande
  Redmine-views doen het zo, het vermijdt JavaScript, en het vermijdt een
  associatiewandeling in precies het model waar #44386 net een N+1 uit haalde.
- **Beslist (autonoom):** `preload(:trackers)` in `hooks_for`. Zonder de preload
  is het één query per hook (gemeten: 20 hooks → 23 queries in plaats van 5).
- **Beslist (autonoom):** `respond_to?(:tracker_id)` in plaats van
  `is_a?(Issue)`. De webhooklaag is generiek over vijf modeltypes; alleen
  `Issue` heeft vandaag een tracker (nagemeten), en een toekomstig
  webhookable model zonder tracker wordt zo nooit per ongeluk gefilterd.
- **Beslist (autonoom):** `matches_tracker?` staat vóór `object.visible?` in de
  conditie van `hooks_for`. Het is de goedkoopste van de twee, en een
  niet-matchende tracker slaat daarmee de visibility-query over.
- **Beslist (autonoom):** de migratie kopieert de vorm van `projects_webhooks`
  uit `CreateWebhooks` (impliciete primary key, `null: false`, index per kolom)
  in plaats van Redmine's oudere `:id => false`-jointabellen. Twee jointabellen
  op hetzelfde model horen identiek te zijn; dat is wat een reviewer vergelijkt.
- **Beslist (autonoom):** geen instelling, geen permissie, geen route. Het
  filter is per hook, en Redmine heeft geen permissie per tracker om er een aan
  te hangen. Het filter versmalt alleen, dus het kan niemands toegang verbreden.
- **Beslist (autonoom):** één nieuwe locale-sleutel, `webhook_trackers_info`.
  `label_tracker_plural` bestaat al en wordt hergebruikt voor de legenda.
- **Beslist (autonoom):** `webhook_url_info` blijft ongewijzigd, ook al noemt
  die alleen projecten. Die zin herschrijven betekent hem in alle ~50
  locale-bestanden verouderd achterlaten; de nieuwe hint staat naast het veld
  dat hij beschrijft.
- **Beslist (autonoom):** alleen `en` en `de` krijgen de sleutel. In `nl.yml`,
  `fr.yml` en `es.yml` staan de twee buursleutels op dit formulier
  (`webhook_url_info`, `webhook_secret_info_html`) nog onvertaald in het Engels;
  `config.i18n.fallbacks` is `true`, dus die drie talen tonen de Engelse tekst
  hoe dan ook. Redmine's eigen proces is dat taalteams vertalingen per taal in
  een eigen issue aanleveren. Zie ook de open keuze K-06 in `docs/DECISIONS.md`.
- **Beslist (autonoom):** `webhooks/index.html.erb` krijgt geen Trackers-kolom.
  Een lege cel daar leest als "geen trackers" terwijl hij "alle trackers"
  betekent, en #44337 stelt voor die lijst helemaal te herbouwen.
- **Beslist (autonoom):** `create_hook` in beide testbestanden blijft
  ongewijzigd; de nieuwe tests zetten trackers met `hook.update!`. De helper
  uitbreiden liet 17 bestaande tests op trunk erroren en verstopte daarmee het
  rood-bewijs.
- **Beslist (autonoom):** `ActiveRecord::RecordNotFound` op een verzonnen
  `project_ids`/`tracker_ids` (een 500, want er is geen globale rescue) is een
  bestaand trunk-defect dat `project_ids` net zo raakt. Niet gefixt in deze
  patch — dat zou asymmetrisch zijn en het is een eigen bugrapport. Gemeld in
  het dossier.
