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
- **Beslist door Jan (2026-09-03, K-08 optie B):** alle vijf de talen krijgen de
  sleutel, dus ook `nl`, `fr` en `es` — niet alleen `en` en `de`. Ik had A
  aanbevolen omdat de twee buursleutels op dit formulier
  (`webhook_url_info`, `webhook_secret_info_html`) in die drie bestanden nog
  onvertaald Engels zijn en `config.i18n.fallbacks` `true` is; Jan koos B.
  Uitgevoerd, en elke term is herleid tot een bestaande sleutel in datzelfde
  bestand — zie de vertalingstabel in `dossier.md`. Gevolg dat we accepteren:
  op het Nederlandse, Franse en Spaanse formulier staat de nieuwe hint nu wél
  vertaald en de twee erboven niet. Zichtbaar in `shots/webhook-form-es.png`.
- **Beslist (autonoom):** de vertalingen gaan in een **apart** patchbestand
  (`-locales.patch`), niet in het feature-patchbestand. Zo kan een committer die
  vertalingen liever aan de taalteams laat de feature aannemen en de andere
  weggooien, zonder dat er iets herschreven hoeft te worden.
- **Ingetrokken (2026-09-05, ronde 2, bevinding F03):** hierboven stond dat
  `événements` in het Frans het enige niet-herleide woord was omdat `fr.yml` het
  nergens bevat. Dat was gewoon onwaar: `label_user_mail_option_all` bevatte het
  al op r24882, en op r25037 staat het in `label_webhook_events: Événements` en
  in het vertaalde `webhook_url_info` — dat laatste is de zin die pal boven de
  nieuwe hint op hetzelfde formulier staat, dus de sterkst denkbare bron. Elke
  term in het Frans is nu herleid en het dossier noemt de sleutel. Wat wél klopt
  en blijft staan: de enige bestaande `selectionnée` in
  `text_issues_destroy_confirmation` is een tikfout zonder accent, en die is
  niet gekopieerd.
- **Beslist (autonoom):** in het Nederlands wordt "unchecked" niet letterlijk
  vertaald. `nl.yml` heeft geen enkel woord voor aanvinken (geen "aanvinken",
  geen "vinkje"), dus de tweede zin gebruikt "selecteert", wat er wél in staat.
- **Beslist (autonoom):** op `patch/<slug>` is de commit **geamendeerd** in
  plaats van er een tweede naast te zetten, en force-gepusht. Die branch bestaat
  alleen om er `git format-patch` op te draaien; twee commits geven twee
  patch-mails per bestandsgroep. Op `7.0-stable-GEOxyz` is het wél een tweede
  commit, want daar mag historie nooit herschreven worden.
- **Beslist (autonoom):** `webhooks/index.html.erb` krijgt geen Trackers-kolom.
  Een lege cel daar leest als "geen trackers" terwijl hij "alle trackers"
  betekent, en #44337 stelt voor die lijst helemaal te herbouwen.
- **Beslist (autonoom):** `create_hook` in beide testbestanden blijft
  ongewijzigd; de nieuwe tests zetten trackers met `hook.update!`. De helper
  uitbreiden liet 17 bestaande tests op trunk erroren en verstopte daarmee het
  rood-bewijs.
- **Herzien door Jan (2026-09-04, g16d):** hierboven stond dat een verzonnen
  `tracker_ids` een bestaand trunk-defect is (`project_ids` doet hetzelfde) en
  daarom niet gefixt werd, omdat het asymmetrisch zou zijn. Jan koos anders:
  `tracker_ids` wordt wél afgevangen. Uitgevoerd als een `tracker_ids=`-writer
  op `Webhook` die onbekende ids weglaat, wat de vorm is die Redmine zelf
  gebruikt voor dit soort invoer (`Member#role_ids=`,
  `User#notified_project_ids=`). Gemeten vóór en ná:
  `hook.project_ids = [999999]` geeft nog steeds
  `ActiveRecord::RecordNotFound`, `hook.tracker_ids = [999999]` geeft `[]`. De
  asymmetrie blijft dus bestaan en staat als zodanig in het dossier, met het
  trunk-defect erbij gemeld.
- **Beslist (autonoom, ronde 2):** onbekende ids worden **stil weggelaten**, niet
  als validatiefout teruggegeven. Een validatiefout vraagt dat de ongeldige ids
  bewaard blijven tot na `valid?`, dus een extra attribuut en een extra
  `validate` — machinerie voor een geval dat alleen bij een met de hand
  geschreven POST optreedt. Trunk's eigen `before_validation` op `Webhook` laat
  projecten die de gebruiker niet mag zetten ook stil vallen; dit volgt dat.
- **Beslist (autonoom, ronde 2, g07/F02):** `Tracker` krijgt
  `has_and_belongs_to_many :webhooks`, de spiegel van wat `Project` al heeft.
  Een verwijderde tracker neemt zijn jointabelrijen mee. Wat het **niet**
  verandert: een hook waarvan de laatste tracker verdwijnt houdt een lege
  selectie over, en leeg betekent alle trackers. Dat is dezelfde regel als
  overal elders in deze feature en het staat expliciet in het dossier; het
  alternatief (de verwijdering blokkeren) hoort in `Tracker#check_integrity`
  en is een andere wijziging. Zie de open keuze voor Jan in `docs/DECISIONS.md`.
- **Beslist (autonoom, ronde 2, F07):** het Trackers-blok blijft onvoorwaardelijk
  op het formulier staan, ook op een hook die geen enkel issue-event heeft. Het
  verbergen vraagt JavaScript (dat deze patch overal vermijdt) en serverzijdig
  beslissen op de opgeslagen events is verouderd tussen twee saves in. Het staat
  nu als afgewogen positie in de bezwarentabel.
- **Beslist (autonoom, ronde 2, F09):** de conditie in `hooks_for` wordt over
  twee regels gezet in plaats van één regel van 152 tekens. De twee goedkope
  controles staan op de eerste regel, de twee dure op de tweede — dat is precies
  de volgorde waar het dossier zich op beroept.
