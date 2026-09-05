# DECISIONS — beslissingslogboek

> Append-only. Twee secties: wat autonoom beslist is (één regel per
> beslissing) en wat op Jan wacht (opties, uitleg in gewone taal, en een
> aanbeveling — zodat kiezen makkelijk is). Als Jan kiest, verhuist het item
> naar "Beslist" met datum. De bouw wacht nooit op een open keuze: er is altijd
> een veilige, omkeerbare default geïmplementeerd.

## Beslist (Jan)

| Datum | Beslissing | Waarom |
|---|---|---|
| 2026-09-01 | Framework op een **orphan branch** `geoxyz/framework` in de eigen fork, niet in een aparte repo | Redmine neemt patchbestanden aan die aan een issue hangen, geen repo's — de inhoud van de fork reist nooit mee. Een orphan heeft nul onderhoud en de scheiding is zelf-evident. Jan gaf expliciet push-toestemming voor deze branch. |
| 2026-09-01 | Sessies starten op deze branch; Jan zegt **waarover** en **waar** | Het framework is dan altijd geladen, ongeacht welke feature of doelbranch. |
| 2026-09-01 | Ansifs PR #1 wordt **niet** de basis; opnieuw beginnen vanaf `7.0-stable`, zijn branch alleen lezen | Elke feature moet toch herontworpen worden voor upstream; zijn commits dragen de negen geërfde bugs en 73 lint-fouten. Een schone reeks is wat elke commit presenteerbaar maakt. |
| 2026-09-01 | `database.yml`-ERB (`7ffcdcafc`) blijft uitgesteld | Jan: niet blokkerend, later oppakken als er een beter idee is voor versleutelde wachtwoorden in `database.yml`. |
| 2026-09-01 | `revision-branches` wordt **niet** gesplitst en krijgt **geen** DB-cache. Git-only, het commando eronder blijft, en de vier instellingen blijven staan | Jan: "alleen git, voorlopig geen db cache maar gewoon zoals het is met een commando onderliggend. We zien wel wat ze ermee doen. Ik zou de instellingen ook houden en zien of ze comments hebben." Bewust: eerst de reactie van het core-team afwachten in plaats van vooraf inbinden. Mijn splitsingsadvies (2026-09-01, eerder die dag) is hiermee vervallen. |
| 2026-09-01 | ~~INV-5: `en.yml` plus `nl.yml`~~ → **`en`, `nl`, `fr`, `de`, `es`** | Jan: "Ik zou toch graag wat meer talen hebben... zeker ook Nederlands, Frans, Duits, Spaans." Het zijn GEOxyz' werktalen. Ik had bezwaar gemaakt (onverifieerbare vertalingen kosten de patch geloofwaardigheid); Jan heeft dat gehoord en beslist. Twee mechanismen dekken het risico: elke vertaling wordt afgeleid van de dichtstbijzijnde bestaande sleutel in hetzelfde bestand en die sleutel wordt in het dossier genoemd, en de patch wordt gesplitst in feature (code + `en.yml`) en vertalingen. |
| 2026-09-01 | ~~`fr.yml` niet meesturen~~ — vervallen, zie hierboven | — |
| 2026-09-01 | **Doorgetrokken: de ZIP is altijd genest**, niet alleen bij bijlagen | Jan: "ik zou het gewoon doortrekken: dit is de structuur van de zip en die is altijd zo." Terecht. Mijn argument voor twee vormen ("zonder bijlagen is een map per pagina een leeg omhulsel") gold alleen voor de platte variant met een map ernaast, niet voor een geneste indeling — daar draagt de map de ouder/kind-relatie, en dat is informatie die de platte export weggooit. Ik had dat argument op de verkeerde optie toegepast. Winst: mijn eigen zwaarste verwachte bezwaar ("twee indelingen achter één actie") verdwijnt, en de code wordt kleiner, één ZIP-bouwer. Prijs: het verandert de export uit 7.0.0 en twee bestaande trunk-tests. |
| 2026-09-01 | **De keuze bijlagen ja/nee gaat via het exportkeuzevenster**, niet via een tweede link | Jan: "ja doe optie b". Eén ingang per formaat in "Also available in", en het is het patroon dat core zelf zes keer gebruikt voor CSV. Bijkomend voordeel: `label_export_options` (geparametriseerd op het formaat) en `button_export` bestaan al vertaald in alle vijf de talen, dus er is precies één nieuwe sleutel nodig voor het vinkje. Wat niet kon: bijlagen altijd meesturen — `bulk_download_max_size` zou de wiki-export dan helemaal kunnen laten falen voor een project met veel bestanden, zonder uitweg. Bewezen: met de limiet op 0 en het vinkje uit is het archief `cmp`-identiek aan normaal. |
| 2026-09-01 | ~~**K-02: geneste indeling (optie B).**~~ Aangescherpt door de twee regels hierboven | Het ZIP-archief mét bijlagen volgt de wikiboom: één map per pagina, genest onder de ouder, met het paginabestand en de bijlagen van die pagina erin | Jan: "keuze b". Daarmee staat een bijlage naast de paginatekst die ernaar verwijst, dus `!diagram.png!` werkt gewoon als je het archief uitpakt. Dat is de derde ontwerpvraag die Go MAEDA in #43978 openliet, en die is nu beantwoord zonder de geëxporteerde tekst aan te raken. Scoping heb ik zelf ingevuld (zie hieronder): alleen de variant mét bijlagen is genest. |
| 2026-09-01 | **K-03: de TXT-export vervalt.** `wiki-export-txt` gaat niet naar upstream en komt ook niet op de GEOxyz-branch | Jan: "we gebruiken de txt export niet". Daarmee is er geen reden om hem te bouwen of te verdedigen. De registerregel blijft staan met status vervallen, zodat volgende sessies niet opnieuw gaan afwegen. |
| 2026-09-02 | **K-04: optie A.** De grens van het globale zoekvak blijft vijf woorden; alleen de tekstfilters worden onbeperkt | Jan: "keuze a". Daarmee gaat er geen instelling mee de patch in en blijft het een bugfix in plaats van een functieverzoek. Praktisch gevolg voor GEOxyz: het veld `search_token_limit` verdwijnt uit Beheer → Configuratie → Issues, filters gebruiken altijd alle getypte woorden zonder dat iemand iets instelt, en het zoekvak rechtsboven gebruikt weer de eerste vijf woorden in plaats van het ingestelde getal. Als dat laatste ooit knelt is het een los issue dat deze patch niet ophoudt. |
| 2026-09-01 | AI-attributie (`Co-Authored-By`, `Claude-Session`) staat **wel** in commits van `geoxyz/framework`, **nooit** in commits van een `patch/<slug>`-branch of `7.0-stable-GEOxyz` (K-01, optie A) | Jan: "optie a". Jij bent de indiener en de patch is jouw werk om te verantwoorden; de herkomst staat volledig in je eigen repo. Redmine's Contribute-pagina vraagt niets over herkomst. INV-4 en `tools/check-patch-clean.sh` blijven dus ongewijzigd afdwingen, en de wachter kijkt nu ook op de `Claude-Session`-trailer. |
| 2026-09-02 | **K-05: optie A.** `<< niemand >>` komt alleen in de lijst van het toewijzingsfilter, niet in "Doelversie" en "Categorie" | Jan: "optie a". Daarmee blijft de patch precies zo breed als issue #5535 zelf, en dat is het kleinste oppervlak om op afgewezen te worden. Er verandert niets aan de code: dit is wat er al gebouwd en bewezen is. Het mechanisme in `Query#sql_for_field` blijft generiek, dus `?v[fixed_version_id][]=none` werkt al; de bezwarentabel in het dossier zegt de reviewer expliciet dat de andere twee lijsten één regel per stuk zijn en dat de keuze de zijne is. Wil hij B, dan is dat twee regels erbij zonder herontwerp. |

## Beslist (autonoom)

| Datum | Beslissing | Waarom |
|---|---|---|
| 2026-09-01 | Doel is per feature **beide** (upstream-vorm én GEOxyz), niet "porteren en dan aanbieden" | Afwijking tussen wat GEOxyz draait en wat upstream accepteert is precies de onderhoudslast die weg moet. Bouw de upstream-vorm en draai die intern, dan is de merge later een no-op. |
| 2026-09-01 | Cadans: **stoppen en tonen per feature**, expliciet het omgekeerde van de "keep going"-regel in `redmine_ai_triage` | Daar is autonomie het punt omdat Jan niet meekijkt. Hier is elke feature een inschatting van wat upstream accepteert, en Jan dient de issues zelf in. |
| 2026-09-01 | Het dossier is deels **Engels**: de secties die de redmine.org-issuetekst worden, met een Nederlands "Voor Jan"-blok bovenaan | Het issue moet Engels zijn. Zo is het dossier meteen half-opgesteld issue in plaats van iets wat nog vertaald moet worden. |
| 2026-09-01 | De webhook-uitbreidingen worden **twee** issues: tracker-filter en `issue.closed` | Eén patch die twee dingen doet wordt twee keer zo lang besproken en half zo vaak geaccepteerd. |
| 2026-09-01 | ~~`revision-branches` splitsen, één instelling, DB-cache later~~ — **vervallen**, zie Jans beslissing hierboven | Jan kiest bewust om het core-team eerst te laten reageren op de feature zoals hij hem gebruikt. |
| 2026-09-01 | `members-pagination` krijgt geen eigen patch; aanhaken bij bestaand issue #43355 | Het werk leeft daar al; een concurrerende patch verkleint de kans op beide. |
| 2026-09-01 | De invarianten en de forbidden-constructs-tabel zijn afgeleid van **echte** bevindingen uit de doorlichting van PR #1, niet van algemene stijlregels | Een regel waarvan je het incident kan noemen wordt gevolgd; een algemene stijlregel niet. |
| 2026-09-01 | `tools/check-patch-clean.sh` controleert ook op AI-sporen in commit-berichten en op locales buiten de vijf toegestane, niet alleen op framework-paden | Beide waren echte fouten in de bestaande port. Mechanisch afdwingen in plaats van op discipline vertrouwen. |
| 2026-09-01 | Twee patchbestanden op één issue: feature (code + `en.yml`) en vertalingen (`nl`, `fr`, `de`, `es`) | Een committer kan het eerste nemen zonder te wachten op vertalingen die hij niet kan nakijken, en de feature-patch blijft klein. Zo doet Redmine's eigen historie het ook. Wachter meldt het als een patch code en vertalingen mengt, maar faalt niet — Jans keuze. |
| 2026-09-01 | Vertalingen worden **afgeleid** van de dichtstbijzijnde bestaande sleutel in hetzelfde locale-bestand, met vermelding van die sleutel in het dossier | Redmine's bestanden zijn onderling oneens over basisvocabulaire: `issues` is *issues* (nl), *demandes* (fr), *Tickets* (de), *peticiones* (es). Een vertaling die je uit het Engels samenstelt is plausibel en verkeerd. |
| 2026-09-03 | `mypage-query-blocks`: de instelling houdt **3** als standaard, in plaats van de grens naar 5 te verhogen zoals Go MAEDA voorstelde | Dat is de hele reden dat deze patch een kans maakt. Jean-Philippe Lang parkeerde #27313 op 2018-12-08 met precies één bezwaar: "We should probably load content asynchronously before raising the number of queries that can be displayed." Trunk r24882 rendert de blokken nog steeds synchroon, dus dat bezwaar geldt onverkort — maar het gaat over *verhogen*. Met default 3 verhoogt deze patch niets voor wie niets instelt (bewezen: `select-at-default-maximum.png` is dezelfde afbeelding voor en na), en geeft alleen de beheerder de knop. Bovendien werkt hij twee kanten op: note-5 op datzelfde issue is een installatie die juist *minder* dan drie wilde kunnen instellen. |
| 2026-09-03 | `mypage-query-blocks`: `:max_occurs` mag een **instellingsnaam** zijn; opgelost in één nieuwe `Redmine::MyPage.max_occurs`, niet door `MyPage.blocks` te herschrijven zoals de 5.1-commit deed | De 5.1-aanpak zette de blokknaam `'issuequery'` midden in de generieke accessor `blocks`, en `blocks` wordt vanuit `block_options` één keer per blok aangeroepen — dus twee hash-merges per iteratie. Door `:max_occurs` op te lossen waar hij gelezen wordt blijft `blocks` wat hij was, en de literal 3 verhuist naar `config/settings.yml`, waar Redmine al zijn andere getallen van deze soort bewaart. Eén bron voor de standaard in plaats van twee. |
| 2026-09-03 | `mypage-query-blocks`: instellingsnaam `my_page_max_issuequery_blocks` (uit de 5.1-commit) en het veld op het tabblad **Algemeen** | De naam koppelt aan de blokknaam `issuequery`, waardoor de regel in `CORE_BLOCKS` zichzelf uitlegt. Algemeen is waar Redmine zijn weergavegrenzen zet: `per_page_options`, `search_results_per_page`, `activity_days_default` en `feeds_limit` staan er alle vier. |
| 2026-09-03 | `mypage-query-blocks`: **geen bovengrens** op de instelling, ondanks "certainly with some maximum" in de issuebeschrijving | Elke bovengrens is weer een willekeurig getal, en core begrenst `issues_export_limit`, `gantt_items_limit`, `attachment_max_size` en `activity_days_default` ook niet. Het staat als bezwaar in het dossier met het antwoord dat het één regel is als een committer het toch wil. |
| 2026-09-03 | `mypage-query-blocks`: het woord "blok" komt **niet** in het label voor | Het is in de dashboard-betekenis nergens vertaald in `nl.yml` of `es.yml`, dus elke formulering ermee zou verzonnen zijn (INV-5). "Custom queries" is de term die #1565 en #27313 zelf gebruiken en bestaat als `label_query_plural` in alle vijf de bestanden. |
| 2026-09-03 | Nieuwe locale-sleutels worden in `nl/fr/de/es` **onderaan het bestand** toegevoegd, in `en.yml` op zijn logische plek | Dat is mechanisch wat `rake locales:update` doet: `lib/tasks/locales.rake` opent elk niet-Engels bestand met `File.open(file, 'a')` en plakt ontbrekende sleutels eronder. Zichtbaar in trunk: `setting_reactions_enabled` staat in nl/fr/de/es onvertaald aan het eind. |
| 2026-09-03 | G9 krijgt naast de paginabrede afbeelding ook een **uitsnede van het element** wanneer het bewijs een paar pixels tekstkleur is | Gevonden door de eigen screenshots te lezen: een `disabled` `<option>` is op 1280px niet van een actieve te onderscheiden, en `getComputedStyle` geeft voor beide `rgb(33, 37, 41)` — de DOM kan het dus niet aantonen en de assertion alleen bewijst niets wat een reviewer kan zien. De uitsnede (`select-*.png`) laat grijs versus zwart onmiskenbaar zien. |
| 2026-09-01 | Geen phasing/spikes-machinerie zoals in `redmine_ai_triage` | Overkill voor tien patches; de gates en het register dekken het. |
| 2026-09-01 | Gate **G8** en `tools/check-geoxyz-branch.sh` toegevoegd voor de GEOxyz-branch | Jans vraag "wat met de commits die ik nodig heb op 7.0-stable-GEOxyz?" legde bloot dat het framework die kant alleen in de skill vermeldde, zonder gate en zonder gereedschap. De branch bleek nul eigen commits te hebben en 5 achter te lopen — dus geen enkele feature loopt op 7.0. |
| 2026-09-01 | Register krijgt **twee** statuskolommen: GEOxyz en upstream | Eén status kon niet uitdrukken dat een feature in productie kan staan terwijl de patch nog hangt, of omgekeerd. |
| 2026-09-01 | Upstream 7.0-stable wordt **gemerged**, nooit gerebased, en vóór het starten van een feature | Een rebase maakt elke checkout van GEOxyz ongeldig. Vooraf mergen laat een conflict apart opduiken in plaats van vermengd met nieuw werk. |
| 2026-09-01 | Gate **G9** toegevoegd: elke feature met de hand nagelopen in een **echte draaiende Redmine**, in een echte browser, met een screenshot per functie als bewijs | Jans vraag. Een groene suite zegt dat de code doet wat de test zegt, niet dat de feature werkt: de port van 2026 leverde een link die in de DOM stond, `assert_select` passeerde, en niets deed bij klikken omdat zijn JavaScript op die pagina nooit geladen werd. |
| 2026-09-01 | **G3 verscherpt naar de volledige suite**, niet alleen de geraakte bestanden | Redmine's Contribute-pagina eist letterlijk dat alle bestaande tests slagen. Kost tientallen minuten; vroeg starten en er ander werk naast doen. |
| 2026-09-01 | Voor/na-screenshotparen verplicht, en ook de faalpaden (instelling uit, permissie afwezig, lege staat) | Een voor/na-paar is het meest overtuigende wat je op een redmine.org-issue kan zetten, en het bewijst dat de screenshot jouw wijziging toont in plaats van iets wat er al stond. |
| 2026-09-01 | Gereedschap voor G9 is **eerst gebouwd en echt gedraaid**, niet alleen opgeschreven | `tools/dev-server.sh` + `dev-seed.rb` + `verify-lib.mjs` zijn end-to-end bewezen: echte Redmine 7.0 op poort 3000, ingelogd als admin, drie screenshots gemaakt en gelezen. Vond zes valkuilen en twee bugs in de scripts zelf; alle zes staan in `docs/runbook.md`. |
| 2026-09-01 | De registerregel `wiki-export` is **gesplitst** in `wiki-export-attachments` (deze sessie) en `wiki-export-txt` (later) | De 5.1-commit deed twee losse dingen: bijlagen in de ZIP, en één samengevoegd TXT-bestand van de hele wiki. Redmine wil één issue per onderwerp; samen ingediend wordt het twee keer zo lang besproken. De bijlagen-helft is bovendien veruit de sterkste kandidaat: Go MAEDA heeft die zelf uitgesteld in #43978. |
| 2026-09-01 | `wiki-export-attachments` bouwt **voort op** trunks bestaande `wiki#export` `format.zip`, niet op een tweede actie `export_attachments` zoals 5.1 | Die trunk-feature bestond nog niet toen 5.1 gebouwd werd. Voortbouwen scheelt een route, een permissie-regel, een tweede ZIP-bouwer en een tweede archief dat de gebruiker met de hand moet samenvoegen. |
| 2026-09-01 | Bijlagen zijn **opt-in** via de queryparameter `with_attachments`, en de platte indeling van 7.0.0 blijft ongewijzigd | `bulk_download_max_size` moet gelden zodra er bijlagen in gaan. Onvoorwaardelijk meesturen zou de wiki-export laten falen voor een project met veel bijlagen — een regressie op wat vandaag werkt. Bewezen: met de limiet op 0 levert de gewone ZIP nog steeds hetzelfde bestand. |
| 2026-09-01 | Bijlagen worden gefilterd op `readable?`, niet op `visible?` | Precies wat `Attachment.archive_attachments` doet. De controller heeft het verzoek al geautoriseerd op `:export_wiki_pages`, en de bestaande export geeft dezelfde gebruiker toch al de volledige tekst van elke pagina. `readable?` houdt een rij waarvan het bestand van schijf verdwenen is buiten het archief én buiten `File.binread`. |
| 2026-09-01 | Commits op `patch/<slug>` en `7.0-stable-GEOxyz` worden geschreven als **Jan Catrysse <jan.catrysse@geoxyz.eu>** | `git format-patch` zet de auteur in de `From:`-regel van het bestand dat aan het issue hangt. Een tool-identiteit daar is net zo goed een AI-spoor als één in het bericht (INV-4). Gevonden door de patch te exporteren en te lezen; `tools/check-patch-clean.sh` controleert het nu mechanisch. |
| 2026-09-01 | ~~De geneste indeling geldt **alleen** voor `with_attachments=1`~~ — **vervallen**, Jan trok het door naar altijd genest, zie "Beslist (Jan)" | Jan koos B maar niet de scoping, en ik had er twee genoemd met elk een prijs. Dit is de enige die niets breekt: een export die vier maanden geleden is uitgekomen verandert niet voor mensen die nooit om bijlagen vroegen. Het bezwaar "twee indelingen achter één actie" is echt, en het antwoord staat in het dossier: de mappen bestaan om bijlagen naast hun pagina te zetten, dus zonder bijlagen zouden het lege omhulsels rond één bestand zijn. Aantoonbaar: de gewone ZIP van een gepatchte instance is `cmp`-identiek aan die van een schone trunk. |
| 2026-09-01 | `tools/dev-server.sh` wijst elke worktree naar **één** map voor bijlagen (`/tmp/redmine-dev-files`) | De dev-database is gedeeld tussen worktrees, `files/` niet. Een bijlage die je uploadt terwijl worktree A draait, is onleesbaar vanuit worktree B en verdwijnt stil uit alles wat `Attachment#readable?` controleert. Dit kostte precies één valse "de feature werkt niet" tijdens G9 — het bewijs dat G9 zijn geld waard is. |
| 2026-09-02 | `search-token-limit` wordt **geen instelling** maar het terugzetten van de vijf-tokenlimiet naar `Redmine::Search::Fetcher` | De limiet is in r21238 (2021) per ongeluk van de zoekmachine naar de gedeelde `Tokenizer` gereisd toen dat blok woordelijk werd verplaatst zodat filters het tokeniseren konden hergebruiken. Een instelling vraagt een beheerder om te configureren hoeveel van de zoekwoorden van zijn gebruikers stil weggegooid worden; niemand kan daar een goed getal voor noemen. De eerste inzending (#43701, januari 2026, de instelling-variant) kreeg in zeven maanden geen reactie. |
| 2026-09-02 | Geen `max_tokens:`-keyword op `Tokenizer`; de vijf staat als `.first(5)` bij de enige caller die hem nodig heeft | INV-6: de nulhypothese is dat nieuwe API niet nodig is. De 5.1-patch en de port hebben die parameter wel, en geen enkele caller geeft hem ooit door — dode API. Zonder parameter is de diff vier regels. |
| 2026-09-02 | `tools/dev-seed.rb` krijgt één issue met een onderwerp van zeven woorden | Geen enkel bestaand gezaaid onderwerp is lang genoeg om een tekstfilter meer dan vijf bruikbare tokens te geven, dus G9 kon de fout niet laten zien. Idempotent toegevoegd. |
| 2026-09-02 | Deze patch gaat als note op het **bestaande** issue #43701, niet op een nieuw issue | Het issue is van Jan, staat in de juiste categorie (Filters) en heeft de verwante issues al gelinkt. Een tweede issue voor hetzelfde probleem splitst de discussie. |
| 2026-09-01 | Het dossier vraagt **wanneer** een GEOxyz-commit kan vervallen, niet of | Redmine backportt geen features naar een stable branch; een geaccepteerde patch komt in 7.1 of later. De commit blijft dus nodig tot GEOxyz die release haalt. |
| 2026-09-02 | `assignee-nobody` wordt **generiek** afgehandeld in `Query#sql_for_field`, niet in een eigen `sql_for_assigned_to_id_field` op `IssueQuery` | De eigen methode was het eerste ontwerp en is de voor de hand liggende naad (`statement` zoekt er zelf naar), maar hij zou de vijftien regels journal-subquery van de historie-operatoren moeten dupliceren en voor altijd in de pas houden. De generieke vorm is niet groter en heeft geen kopie. Bijkomend: het is letterlijk wat Jean-Baptiste Barth in 2010 in #5535 vroeg ("liever een generieke oplossing … assigned to, target version, category"), en dat is het enige inhoudelijke bezwaar van een committer dat in zestien jaar op dat issue is gemaakt. |
| 2026-09-02 | Alle **zeven** operatoren van het toewijzingsfilter worden gedekt, ook `ev`, `!ev` en `cf` | Het filter biedt ze aan; de waardelijst is dezelfde voor elke operator. Vier ervan gaven een HTTP 500 op PostgreSQL met de bestaande patches, en `cf` gaf stil een lege lijst — erger dan de 500, want niets wijst de gebruiker erop. Een pseudo-waarde die maar bij één operator werkt is geen feature maar een val. |
| 2026-09-02 | Geen nieuwe locale-sleutel: `label_nobody` en de waarde `'none'` worden hergebruikt | Beide bestaan al in trunk en betekenen daar exact dit: `bulk_edit.html.erb` en het contextmenu gebruiken `assigned_to_id => 'none'` voor "haal de toewijzing weg", en `label_nobody` staat in alle 63 locale-bestanden die Redmine meelevert. Dus geen vertaalpatch en geen tweede patchbestand. |
| 2026-09-02 | De pseudo-waarde wordt **alleen** in de toewijzingslijst gezet, niet in doelversie en categorie | INV-6: de nulhypothese is dat het niet nodig is. Het mechanisme dekt ze al (`?v[fixed_version_id][]=none` werkt met deze patch), dus toevoegen is één regel per lijst. #5535 gaat over de toewijzing; de rest is de keuze van de reviewer, en dat staat zo in het dossier. |
| 2026-09-02 | Custom fields zijn uitgesloten via `is_custom_filter` | Een lijst-custom-field mag "none" gewoon als echte waarde hebben. Nagekeken: elk niet-custom `list_optional`-filter in core houdt numerieke ids of een korte vaste woordenlijst, en de `cf_<id>.<attribuut>`-filters zijn `:date` en `:list`, dus buiten de poort. |
| 2026-09-02 | Twee bestaande trunk-tests **aangepast**, niet verzwakt | `test_assigned_to_values_should_be_sorted_by_status_and_name` telt met `[1..]` de pseudo-waarden weg die vóór de echte gebruikers staan; dat wordt `[2..]`. `QueriesControllerTest#test_assignee_filter_should_return_active_and_locked_users_grouped_by_status` telt de JSON-waarden: 6 wordt 7, met één `assert_include` erbij zodat de reden in de test zelf staat. Beide assertions houden hun oorspronkelijke bedoeling. Die tweede is alleen gevonden doordat G3 de **volledige** suite eist — de aangeraakte bestanden waren groen. |
| 2026-09-02 | `tools/dev-seed.rb` krijgt twee extra issues: één toegewezen aan `tester`, en één dat van niemand naar `dev` ging met een journal | Zonder de eerste heeft "niemand of dev" niets om uit te sluiten en bewijst de screenshot niets; zonder de tweede hebben de historie-operatoren geen journalregel om te vinden. Idempotent op de toewijzing, niet op het bestaan van het issue — de eerste versie sloeg de journal over zodra het issue er al stond. |
| 2026-09-03 | `version-subprojects` wordt een **vereniging** van `project.shared_versions` en `Version.visible.where(project_statement)`, geen vervanging | Beide patches die aan #43534 hangen — die van Jan én `43534-v2.patch` van kerncommitter Go MAEDA — vervangen. Dat verliest elke versie die van buiten de bevraagde boom naar het project gedeeld is. Met Redmine's eigen fixtures zakt het filter van project 1 van zes naar vier waarden: de systeembreed gedeelde versie 7 en de gedeelde versie 6 verdwijnen zonder waarschuwing. De vereniging kost één extra query en kan per definitie niets afnemen. |
| 2026-09-03 | De wijziging staat in `Query#fixed_version_values`, niet als override op `IssueQuery` zoals in de 5.1-commit | De methode is sinds r16170 (#24787, 2017) generiek. Een override zou hem dupliceren en het filter `issue.fixed_version_id` van `TimeEntryQuery` op de oude lijst laten staan. |
| 2026-09-03 | `q.build_from_params(params)` komt **ná** de `raise Unauthorized`, niet ervoor | Beide bestaande patches zetten hem ervoor. Het bouwen van de query evalueert `available_filters` en draait daarmee meerdere queries voor een verzoek dat op het punt staat geweigerd te worden. Verplaatsen kost niets en is de juiste volgorde. |
| 2026-09-03 | De JavaScript zoekt het formulier via `$('#filters-table').closest('form')`, niet via een lijst formulier-id's | De 5.1-patch noemde vijf id's, `43534-v2.patch` noemt er één (`#query_form`). Beide missen `#query-form` (met streepje) van `queries/new` en `queries/edit` — precies de pagina waar je een query mét subprojectfilter opslaat. De partial rendert `#filters-table` altijd binnen het formulier, dus één selector dekt alle pagina's. |
| 2026-09-03 | `tools/dev-seed.rb` krijgt een tweede subproject, een project buiten de boom met een systeembreed gedeelde versie, en een subproject-issue op de eigen versie van dat subproject | Zonder het tweede subproject kun je niet laten zien dat één gekozen subproject de versie van het ándere subproject uitsluit; zonder de gedeelde versie van buiten kan de screenshot de regressie niet weerleggen; zonder het issue geeft het filter nul rijen en bewijst het niets. |
| 2026-09-03 | Deze patch gaat als note op het **bestaande** issue #43534 | Zelfde reden als bij #43701 en #5535: het issue is van Jan, staat in de juiste categorie, en een kerncommitter heeft er al aan gewerkt. Een tweede issue splitst de discussie. |
| 2026-09-03 | `test_fixed_version_filter_should_respect_selected_subprojects` draait met `display_subprojects_issues => '0'`, en de correctie staat op `7.0-stable-GEOxyz` in een **tweede** commit | Jans vraag: werkt dit ook als subproject-issues standaard niet getoond worden? Ja — `project_statement` leest het `subproject_id`-filter vóór de instelling. De test bewees dat niet: op de standaardinstelling zat het subproject toch al in scope, dus hij toonde alleen dat het filter versmalt, niet dat het verbreedt. Met de instelling uit is hij rood op trunk (`"8" not found in [...]`). Op de patchbranch ge-amend (moet één commit blijven voor `format-patch`), op de GEOxyz-branch een tweede commit omdat daar niet gerebased wordt. |

## Open — keuze voor Jan

Geen open keuzes.

### Gesloten

- **K-01** — AI-attributie in patchcommits. Beslist 2026-09-01: optie A (zie "Beslist (Jan)").
- **K-02** — indeling van het ZIP-archief. Beslist 2026-09-01: genest naar de wikiboom, en doorgetrokken naar altijd, niet alleen bij bijlagen. De keuze bijlagen ja/nee zit in het exportkeuzevenster.
- **K-03** — de TXT-export van de hele wiki. Beslist 2026-09-01: vervalt, GEOxyz gebruikt hem niet.
- **K-04** — meer dan vijf zoekwoorden in het globale zoekvak. Beslist 2026-09-02: optie A, alleen de filters (zie "Beslist (Jan)").
- **K-05** — `<< niemand >>` ook in "Doelversie" en "Categorie". Beslist 2026-09-02: optie A, alleen de toewijzing (zie "Beslist (Jan)").
## Beslist (autonoom) — vervolg, na de opsplitsing van 2026-09-03

Vanaf 2026-09-03 staan **feature-specifieke** Class A-beslissingen in
`docs/features/<slug>/decisions.md`, niet meer in de tabel hierboven. Dit
bestand houdt wat het al had (de historie blijft staan, die is niet verplaatst)
en krijgt alleen nog Jans beslissingen, de open keuzes K-nn, en beslissingen
over het framework zelf. Reden: twee parallelle sessies die allebei een rij aan
één tabel plakken conflicteren; per feature schrijven doet dat niet.

Voeg hier alleen toe met `tools/append-note.sh docs/DECISIONS.md` — die haalt
eerst binnen wat een andere sessie toevoegde.

| Datum | Beslissing | Waarom |
|---|---|---|
| 2026-09-03 | Het geheugen gaat van één overschreven `docs/STATE.md` naar `docs/features/<slug>/status.md` per feature, met een afgeleid `docs/REGISTER.md` | Jan vroeg om parallelle sessies. Eén overschreven bestand is precies wat dat onmogelijk maakte: de tweede push verloor het geheugen van de eerste. Eén schrijver per bestand is de enige vorm die git conflictvrij samenvoegt. |
| 2026-09-03 | Het slot is één bestand per sessie (`docs/claims/<slug>--<sessie>`), niet een regel in een gedeeld bestand | Een gedeeld pad conflicteert op de replay in plaats van een winnaar op te leveren. Met aparte paden landen beide claims en breken beide kanten de knoop op dezelfde manier: vroegste datum, dan sessie-id. Dat is deterministisch zonder dat de sessies elkaar kennen. |
| 2026-09-03 | `docs/traps.md` en dit bestand blijven **één** gedeelde lijst, met een tool dat conflictvrij toevoegt, in plaats van opgesplitst per feature | Een valkuilenlijst is meer waard als één leesbaar bestand dan als veertig fragmenten. `tools/append-note.sh` doet de append ná de fetch, dus er is niets te mergen. |
| 2026-09-03 | Op `7.0-stable-GEOxyz` wordt de eigen, nog niet gepushte commit **wel** opnieuw afgespeeld op de tip | "Nooit rebasen" gaat over gepubliceerde historie — dat maakt checkouts van GEOxyz ongeldig. Een commit die nog niemand heeft, is het omgekeerde, en het houdt de branch één lineaire commit per feature in plaats van een woud aan mergecommits uit parallelle sessies. |

## Open — keuze voor Jan (toegevoegd 2026-09-03, webhook-tracker-filter)

- **K-06 — Keuze:** krijgt de nieuwe hint bij het trackerfilter een eigen
  Nederlandse, Franse en Spaanse vertaling, of alleen Engels en Duits?
- **Waarom dit een vraag is:** in `nl.yml`, `fr.yml` en `es.yml` staan de twee
  buurhints op datzelfde webhookformulier (`webhook_url_info` en
  `webhook_secret_info_html`) nog **onvertaald in het Engels**. Alleen `de.yml`
  heeft dat blok vertaald. INV-5 zegt: vertaal door de dichtstbijzijnde
  bestaande sleutel in hetzelfde bestand na te volgen — en die is daar Engels.
- **Opties:**
  A) Alleen `en` en `de`. Nederlands, Frans en Spaans laten Redmine's
     terugval-mechanisme (`config.i18n.fallbacks = true`) de Engelse tekst
     tonen, precies zoals bij de twee hints er direct boven.
  B) Ook `nl`, `fr` en `es` met de hand schrijven. Dan staat er één Nederlandse
     zin tussen twee Engelse op hetzelfde scherm, en een Redmine-committer
     haalt zulke regels er meestal weer uit omdat vertalingen per taal via een
     eigen issue van het taalteam binnenkomen (#43423 Japans, #43468 Bulgaars,
     #43471 en #43847 Chinees, #44323 Frans — allemaal webhookstrings).
- **Aanbeveling:** A. De gebruiker ziet in beide gevallen exact dezelfde tekst,
  want de terugval levert het Engels; optie B voegt dus geen zichtbare
  verbetering toe en maakt de patch minder waarschijnlijk om aangenomen te
  worden.
- **Haast?** nee — we bouwden verder met A. Optie B is later drie regels werk.

### K-06 — de `client_credentials`-grant erbij, of niet (imap-oauth)

- **Keuze:** moet `oauth2_credentials=` naast de `refresh_token`-grant ook de
  `client_credentials`-grant kunnen doen?
- **Waar het over gaat, in gewone taal:** er zijn twee manieren waarop een
  programma bij een Microsoft 365-mailbox mag. Bij de eerste doet een **mens**
  één keer "ja, ik geef dit programma toegang tot mijn mailbox", en het
  programma houdt daar een langlevend bewijsje van over (het refresh token).
  Bij de tweede krijgt het **programma zelf** rechten op de mailbox van een
  beheerder, en heeft het helemaal geen mens nodig — dat is wat Microsoft
  aanraadt voor een postbus die van een dienst is en niet van een persoon
  (`support@`, `helpdesk@`). Vandaag doet de patch alleen de eerste.
- **Opties:**
  A) Zo laten. Wie de tweede manier gebruikt, maakt het token met zijn eigen
     scriptje en geeft het aan Redmine met `oauth2_token=`. Werkt vandaag al.
  B) Erbij bouwen: staat er geen `refresh_token` in het credentialsbestand, dan
     doet Redmine automatisch de tweede manier. Ongeveer zes regels code, één
     extra test.
- **Aanbeveling:** A voor de inzending, B zodra Redmine de patch aanneemt — één
  grant onder review houden geeft de minste discussie, en de uitbreiding past
  later zonder één bestaande optie te veranderen.
- **Haast?** nee — we bouwden verder met A, en A blokkeert niets: `oauth2_token=`
  dekt het geval al. Als GEOxyz zelf app-only wil gebruiken voor een
  servicemailbox, zeg het en dan is B een halve sessie werk.

## Open — keuze voor Jan (toegevoegd 2026-09-03, revision-branches)

- **K-07 — Keuze:** willen we de groepering van branchnamen terug, en zo ja,
  waar?
- **Waarom dit een vraag is:** de 5.1-versie zette branchnamen met een
  gemeenschappelijk voorvoegsel achter één klikbare `[voorvoegsel...]`-link, met
  een heuristiek die op cijfers en op `-`, `.` en `_` splitste. In de patch zit
  die groepering **niet**, en dat is niet in de eerste plaats een inperking: de
  klikhandler zat in `public/javascripts/repository_navigation.js`, en dat
  bestand wordt alleen ingeladen door
  `app/views/repositories/_navigation.html.erb` — een partial die op de
  revisiepagina noch op de issuepagina staat. De link deed dus op beide plekken
  niets; dat is nagelopen in de code en in een browser. Wat de groepering in de
  praktijk moest oplossen (een onleesbaar lange lijst) doet nu de instelling
  `revision_branches_excluded`, met een patroon in plaats van een heuristiek.
- **Opties:**
  A) Zo laten. Lange lijsten kort je in met een uitsluitingspatroon
     (`dependabot/*`, `wip/*`), en dat is een keuze van de beheerder in plaats
     van een aanname over hoe branches heten.
  B) Groepering later apart bouwen, als eigen issue, mét werkende JavaScript.
     Dan moet er ook worden besloten hoe er gegroepeerd wordt — een
     hardgecodeerde heuristiek haalt core niet, dus het wordt een vijfde
     instelling of een vast criterium zoals "alles tot de eerste `/`".
  C) Groepering als permanente eigen patch alleen op de GEOxyz-branch. Dan
     wijken GEOxyz en upstream af (INV-10) en blijft dat zo.
- **Aanbeveling:** A. Het probleem is al opgelost met een instelling die
  upstream precedent heeft, en de groepering heeft op 5.1 nooit gewerkt zonder
  dat iemand het merkte — dat is een sterk signaal dat er niemand op klikte.
- **Haast?** nee — we bouwden verder met A, en de patch is klaar om in te
  dienen zonder groepering. Kies je B of C, dan is dat een nieuwe regel op het
  register, geen wijziging van deze patch.

## Beslist (Jan) — 2026-09-03, imap-oauth

- **K-06, de `client_credentials`-grant: optie A.** Alleen de
  refresh-token-grant gaat mee in de inzending. Wie app-only wil, mint het
  token zelf en geeft het met `oauth2_token=`. K-06 is hiermee gesloten; als
  GEOxyz later een servicemailbox app-only wil laten lopen, is optie B ongeveer
  zes regels en een halve sessie.
- **De eenmalige toestemmingsstap moet in de patch, en doenbaar voor iedereen.**
  Jan: "we hebben wel een eenvoudige manier nodig die iedereen kan doen om stap
  1 te doen ... het mag geen stunt en vliegwerk zijn". Het eerste ontwerp van
  die sessie liet die stap volledig buiten Redmine, met twee `curl`-commando's
  in de documentatie als antwoord. Dat is teruggedraaid: er is nu één taak,
  `redmine:email:oauth2_authorize`.
  Wat **niet** terugkomt, en dat is de reden dat dit geen terugkeer naar de
  oude patch is: geen twee provider-specifieke init-taken, geen scope-lijsten
  of endpoint-paden in Redmine's code, geen tokencache op schijf, geen nieuwe
  gem. De taak weet niets over Microsoft of Google; die kennis staat in het
  credentialsbestand van de beheerder en in de walkthroughs die op de
  `EmailConfiguration`-wikipagina horen.

## Beslist (Jan) — vervolg

- **K-08, welke talen de nieuwe webhook-hint krijgen: optie B.** Jan: "b".
  Alle vijf de talen krijgen `webhook_trackers_info`, dus ook `nl`, `fr` en
  `es`, niet alleen `en` en `de`. Ik had A aanbevolen (terugval op Engels, zoals
  de twee buurhints op datzelfde formulier die in die drie bestanden nog
  onvertaald zijn); Jan koos B en dat is uitgevoerd.

  **Nummering:** deze keuze stond eerst als K-06 in dit log. Een parallelle
  sessie gebruikte op dezelfde dag K-06 voor de `client_credentials`-grant van
  `imap-oauth`, en `revision-branches` had K-07 al. Om het log eenduidig te
  houden heet de vertalingskeuze vanaf nu **K-08**; het oudere blok onder K-06
  dat begint met "krijgt de nieuwe hint bij het trackerfilter" is dezelfde
  vraag. Zie `docs/features/webhook-tracker-filter/`.

  Wat de uitvoering veilig maakt: elke term is herleid tot een bestaande
  sleutel in datzelfde locale-bestand, en de tabel in het dossier noemt per
  taal welke. Twee vondsten die dat opleverde en die bewijzen dat de regel
  nodig is: in `es.yml` is een tracker een **tipo**
  (`label_tracker_plural: Tipos de peticiones`), dus een uit het Engels
  gecomponeerde zin had "trackers" gezegd en gebotst met de legenda erboven; en
  `nl.yml` heeft geen enkel woord voor aanvinken, dus "leave unchecked" is
  "selecteer geen enkele tracker" geworden. Eén woord is niet herleidbaar:
  `événements` staat nergens in `fr.yml` — gebruikt en als zodanig gemeld,
  omdat het geen Redmine-vakterm is.

  De vertalingen zitten in een apart patchbestand, zodat een committer de
  feature zonder de vertalingen kan aannemen.
- **K-09, krijgen `nl`, `fr`, `de` en `es` de sleutel `webhook_event_closed`?**
  **Open — keuze voor Jan.** Bij `webhook-tracker-filter` koos je optie B van
  K-08: alle vijf de talen krijgen de nieuwe sleutel. Deze sleutel is een ander
  geval, en daarom ligt de vraag opnieuw voor: het gaat niet om een losse
  hintzin maar om één van vier vinkjes die naast elkaar in hetzelfde blok
  staan, en die andere drie (`webhook_event_created`, `_updated`, `_deleted`)
  staan in **elk** taalbestand onvertaald in het Engels — ook in `de.yml`, dat
  verder het best vertaalde van de vier is. Ze staan daar door
  `rake locales:update`, dat nieuwe `en`-sleutels letterlijk naar alle
  vijftig talen kopieert; dat is Redmine's eigen mechanisme hiervoor.

  - **Opties:**
    - **A) Alleen `en.yml`** (dit is gebouwd). `config.i18n.fallbacks` staat
      aan, dus een taal zonder de sleutel toont exact dezelfde Engelse tekst
      als wanneer we die er met de hand in zouden zetten. Nul verschil op het
      scherm, één bestand in de patch.
    - **B) De Engelse string kopiëren naar `nl`, `fr`, `de`, `es`.** Vier
      bestanden erbij in de patch, geen enkele pixel anders, en een reviewer
      vraagt terecht waarom juist die vier van de vijftig.
    - **C) Echt vertalen.** Dan leest het blok *Issue created / Issue updated /
      Ticket geschlossen / Issue deleted*, want de drie buren blijven Engels
      **en** `_form.html.erb` vult `object_name` met een Engelse klassenaam
      (`type.to_s.humanize`). Eén vertaald label van de vier is slechter dan
      vier Engelse.
  - **Aanbeveling:** **A**, omdat het op het scherm identiek is aan B en omdat
    C alleen zin heeft als je de hele groep in één keer aanpakt.
  - **Wat C wel waard is, als losse patch:** de vier `webhook_event_*`-sleutels
    in vijf talen én `object_name` localiseren (de legenda erboven doet dat al
    met `l(:"label_#{type}_plural")`). Dat is een eigen issue op redmine.org,
    geen onderdeel van dit event. Zeg maar of je dat wil, dan zet ik het in het
    register.
  - **Haast?** nee — we bouwden verder met A. Het blokkeert het indienen niet;
    het is één regel bijwerken als je B of C wil.
- **K-09, correctie op de feiten (de keuze zelf staat en de aanbeveling
  verandert niet).** Het blok hierboven zegt dat de drie zustersleutels
  `webhook_event_created` / `_updated` / `_deleted` in **elk** taalbestand
  onvertaald Engels staan. Dat is te ruim geformuleerd en het is nagemeten:
  ze staan in **alle 49** niet-Engelse taalbestanden, en in **43** daarvan is de
  waarde nog de letterlijke Engelse string. **Zes** talen hebben die groep wél
  vertaald: `bg`, `cs`, `gl`, `hu`, `ja` en `zh-TW`.

  Waarom de keuze daardoor niet verandert: `nl`, `fr`, `de` en `es` — de vier
  die wij meeleveren — zitten **niet** bij die zes. Daar staat nog steeds
  `"%{object_name} created"` en zo verder, `de.yml` inbegrepen. De aanbeveling
  blijft dus **A** (alleen `en.yml`).

  Wat de correctie er wél aan toevoegt, en het is een argument vóór A: die zes
  talen hebben **alle drie** de sleutels in één keer vertaald. Dat is de
  eenheid van werk in deze groep — een taalteam pakt het blok op, niet één
  label. Eén van de vier vertalen is dus niet alleen lelijk op het scherm, het
  is ook niet hoe Redmine's vertalers met deze sleutels omgaan.
## Beslist (Jan) — reviewronde 1, 2026-09-04

Twintig keuzes, één voor één voorgelegd na de eerste volledige reviewronde
(129 bevindingen, `docs/review/FINDINGS.md`). De groepsnummers verwijzen naar
het managementrapport dat bij die ronde hoort.

### Productiecode

- **g01 `ldap-mail-prefs`, doel gecorrigeerd door Jan.** De taak zette op
  *productie* alle notificatie-instellingen op Jans gewenste standaard voor
  LDAP-gebruikers na een import. Niet voor een testomgeving en niet om
  robotaccounts te dempen. Eenmalig, geen cron — er staat er ook geen in de
  repo, dus de eerdere formulering "op een cron schedule" was onterecht.
- **g01a De taak blijft, hernoemd, met alle drie de waarden als parameter.**
  Reden om alle drie te houden terwijl 7.0 er twee als default kent
  (`default_users_no_self_notified`, `default_users_auto_watch_on`): die staan
  in `user_preference.rb` binnen `if new_record?` en gelden dus alleen bij het
  aanmaken van een gebruiker. Bestaande gebruikers worden er niet door geraakt.
  Voor `mail_notification` bestaat geen default-instelling. Daarnaast worden de
  twee Redmine-instellingen eenmalig goed gezet.
- **g01b Selecteren op echte LDAP-accounts (`auth_source_id`), niet op groep.**
  Sluit het lokale beheerdersaccount automatisch uit, blijft kloppen als
  groepen herindeeld worden, en haalt de "en in geen andere groep"-eis weg die
  na de eerste import vrijwel iedereen oversloeg.
- **g01c Proefstand als standaard, plus een logbestand.** Alleen tonen wat hij
  zou doen; wijzigen pas met een expliciete vlag; de oude waarden per gebruiker
  wegschrijven zodat een run terug te draaien is.
- **g01d De mailwaarde wordt een parameter**, niet een vaste `only_assigned`.
  Feit dat daaraan ten grondslag ligt: `only_assigned` dempt niet volledig —
  `notify_about?` laat mail door bij toewijzing aan de gebruiker of een groep
  van de gebruiker, en geeft voor `News` onvoorwaardelijk `true` terug. Alleen
  `none` zet alles uit.
- **g02 `ar-sessions`: een controlestap in de deploy.** Die stelt vast dat de
  `sessions`-tabel bestaat en beide indexen heeft, en faalt luid als dat niet
  zo is. Plus de opruimtaak in de cron met een gekozen bewaartermijn.
  `db:migrate` kan de controle niet zijn: op de database die het uitmaakt staat
  versie `20240929111106` al in `schema_migrations`, dus de migratie draait
  daar nooit en de guard erin wordt niet bereikt.
- **g11 `gitignore-credentials`: de uitsluiting compleet maken** met
  `config/credentials/`, zodat ook de sleutels per omgeving gedekt zijn. In het
  statusbestand komt dat het voorzorg is en niet iets dat nu in gebruik is.
- **g16a `config/credentials.yml.enc` blijft genegeerd, met uitleg erbij.**
  Tegen mijn advies in (Rails bedoelt dat het versleutelde bestand juist wél
  gecommit wordt); Jan wil bewust niets van credentials in de repo. De reden
  komt in het statusbestand, zodat niemand er later over valt.

### Het framework zelf

- **g13 Alle vier de achterlopende regels worden bijgewerkt, vóór ronde 2.**
  1. de patch-regel wordt gekoppeld aan het moment van indienen in plaats van
     een permanente eigenschap; hij faalt nu op 9 van 9 branches puur door 88
     trunk-commits, en meet dus verval en geen kwaliteit
  2. de commentaarregel neemt Redmine's eigen dichtheid als maat; trunk heeft
     wél methodecommentaar, bijvoorbeeld boven
     `MailHandler.extract_options_from_env`
  3. `tools/check-patch-clean.sh` gaat het **patchbestand** controleren in
     plaats van de branch; door die keuze bleef de branch/bestand-drift bij
     `wiki-export-attachments` onzichtbaar
  4. er komt een vaste plek voor bewust geaccepteerde uitzonderingen
- **g12 `revision-branches`: de uitzondering vastleggen plus een bovengrens.**
  Vastleggen wélke regel bewust wordt overtreden (de SCM-aanroep per rij in een
  view-loop), waarom, en wat het alternatief kost. Plus een maximum aantal
  revisies waarvoor branches worden opgehaald. Gemeten: 29 revisies is 29
  git-processen, 466 ms wordt 1007 ms, en niets begrensde N. Een grens bewaart
  niets, dus de keuze van 2026-09-01 tegen een db-cache blijft ongemoeid.
- **g05 Patches verversen wordt de laatste stap vóór het indienen**, niet een
  losse onderhoudstaak. Dan kan het niet meer verlopen. De bewijscijfers worden
  op dat moment opnieuw gedraaid tegen de nieuwe basis.

### De patches

- **g03 `wiki-export-attachments`: het paginabestand meenemen in de bestaande
  dubbelencontrole**, plus een test met precies dat geval. Nu verdwijnt de
  wikitekst uit het archief als een bijlage net zo heet als de pagina, zonder
  dat `unzip -t` klaagt.
- **g04 De branch opnieuw opbouwen uit het gekozen ontwerp**, zodat branch,
  patchbestand, dossier en GEOxyz-commit weer gelijk zijn. De branch droeg nog
  het ontwerp dat K-02 juist afwees.
- **g06 `assignee-nobody`: haakjes om het teruggegeven SQL-fragment**, met een
  test op `UserQuery#sql_for_is_member_of_group_field`. Van de dertig aanroepers
  van `sql_for_field` is die de enige onveilige; de rest wrapt zelf of geeft
  nooit `none` mee.
- **g07 `webhook-tracker-filter`: de omgekeerde koppeling op `Tracker`**, zoals
  `Project` die al heeft, plus een test dat het verwijderen van een tracker de
  verwijzingen opruimt.
- **g08 `search-token-limit`: ook het filter `any_searchable` repareren**, niet
  alleen de claim bijstellen. **Dit heropent K-04 niet**, en dat is nagekeken:
  `Redmine::Search::Fetcher` heeft exact twee aanroepers —
  `search_controller.rb:71` (de globale zoekpagina, houdt zijn vijf woorden) en
  `issue_query.rb:907` (het filter, wordt onbegrensd). De grens staat na de
  patch al in `Fetcher` in plaats van in `Tokenizer`, dus er hoeft alleen een
  optie bij zodat de aanroeper beslist.
- **g09 Alle acht dossiers nalopen en de claims bijstellen tot wat gemeten is.**
  Nieuwe vaste eis: elke claim heeft een gemeten getal bij zich of een
  expliciete afzwakking. Bij acht van de twaalf features zat het zwaarste punt
  in de begeleidende tekst en niet in de code.
- **g10 De bewijscijfers opnieuw draaien in dezelfde beweging**, inclusief de
  volledige testsuite. Dat cijfer is nu het zwakst onderbouwd: elf van de
  dertien reviewers draaiden alleen de geraakte suites en meldden dat als hiaat.
- **g14 De zichtbaarheidsvraag bij de wiki-bijlagen is uitgezocht: er is geen
  lek**, dus één regel in het dossier in plaats van code. Binnen één project
  kent Redmine geen leesrecht per wikipagina: `WikiPage#visible?` en
  `attachments_visible?` vallen beide terug op `:view_wiki_pages` op het
  project, en de exportactie eist `:export_wiki_pages` op datzelfde project.
  Het `protected`-vlaggetje gaat over bewerken, niet lezen.
- **g15 De note in Takenori's issue wordt een verbetervoorstel**, niet een
  defectmelding: het patroon valt bij de projecttabbladen harder uit dan bij de
  issuelijst, want daar kun je er niet uit klikken. Met het bedankje voor zijn
  rebase, de bevestiging dat `0002` dekt wat GEOxyz nodig had, en een screenshot
  met ledenaantal en adresbalk. Reden: onbewerkt Redmine doet dit overal —
  `/issues?page=99` geeft net zo goed "No data to display".
- **g16b `mypage-query-blocks` krijgt een bovengrens.** Nu wordt 999999
  geaccepteerd en lopen de kosten lineair op. Het is tevens een argument vóór
  bij Jean-Philippe Lang, die in note 9 juist naar de kosten vroeg.
- **g16c De archiefopbouw verhuist uit `WikiController` naar
  `lib/redmine/export/`.** Verplaatsen, niet herschrijven.
- **g16d Validatie op `tracker_ids`** in plaats van een 500 bij een verzonnen id.
- **g16e De `closed_on`-bewaking krijgt één regel waarom.** Toegestaan: het is
  een niet-vanzelfsprekend waarom (waarom het sluitveld en niet de status), en
  dat onderscheid is waar de hele feature op rust.
- **g16f Een issue dat uit een geselecteerde tracker beweegt: benoemen in het
  dossier, niet repareren.** Inherent aan een filter; repareren zou events
  versturen voor trackers die de beheerder juist uitsloot.
- **g16g De note bij `version-subprojects` begint direct met de regressie.**
  Tegen mijn advies in (ik adviseerde het compliment eerst, het is Go MAEDA's
  issue); Jan kiest zakelijk. Het gecorrigeerde getal gaat er wél in: zes naar
  **vijf** als beheerder, niet zes naar vier — versie 6 verdwijnt door
  `Version.visible` en niet door sharing.
- **g18 De 81 kleinere punten worden allemaal afgewerkt.** Tegen mijn advies in
  (ik adviseerde de 27 feitelijke correcties mee te nemen en de rest te laten
  liggen met een reden). Jan wil de lijst leeg voor ronde 3.
## Uitgevoerd — g13, de vier achterlopende regels (2026-09-05)

Jans keuze g13 (2026-09-04) uitgevoerd. Wat er is gemeten en wat er is
veranderd, zodat ronde 3 het niet opnieuw hoeft af te leiden:

| Punt | Meting op 2026-09-05 | Wat de regel nu zegt |
|---|---|---|
| 1. patchregel | alle 9 patchbranches falen "stamt af van `origin/master`" omdat trunk 88 commits verder staat (r24882 → r25037); 6 van de 9 applyen als bestand nog schoon | INV-2: standalone is permanent, "applyt op trunk" geldt op het moment van indienen. Waarschuwing, met `--submit` fataal |
| 2. commentaarregel | 1075 van 3701 methodes in `app/{models,controllers,helpers}` + `lib/redmine` hebben commentaar direct erboven (29%); 683 commentaarregels binnen een methode-body op ~55.600 regels | INV-3: commentaar boven een methode is normaal, commentaar binnen een methode dat de regel herhaalt niet. Match het bestand dat je bewerkt |
| 3. check-patch-clean | de branch/bestand-drift bij `wiki-export-attachments` was onzichtbaar: 10 bestanden verschil, waaronder `_export_options.html.erb` dat alleen in het patchbestand bestaat | het script leest `patches/<slug>/*.patch` en vergelijkt ze met `patch/<slug>`. Nieuw resultaat over de tien slugs: 7 schoon, 2 verouderd (`mypage-query-blocks`, `webhook-tracker-filter` — precies hun F01), 1 fout (`wiki-export-attachments` F01) |
| 4. uitzonderingen | ronde 1 vond twee bewuste afwijkingen die nergens als keuze stonden | `docs/exceptions.md`, gedeeld en append-only. Eén regel per feature, met het alternatief en wat het kost. INV-7 en INV-8 kennen geen uitzondering |

Autonoom ingevuld binnen g13, omdat de keuze zelf al gemaakt was:

- **`--submit` is de vorm waarin punt 1 en g05 samenvallen.** Zonder vlag is
  verouderd een waarschuwing; met de vlag is het een fout. Zo blijft er één
  script in plaats van twee, en staat de strengere variant precies op het
  moment waar g05 hem wil.
- **Het script accepteert nog steeds een branch**, maar zegt er dan bij dat het
  bestand is wat aan het issue hangt. Anders zou een oude aanroep stil iets
  anders controleren dan de aanroeper denkt.
- **De drift-vergelijking gebeurt op de merge-base van de branch**, niet op
  huidig trunk. Anders zou verval (punt 1) als drift verschijnen en waren de
  twee signalen weer door elkaar gaan lopen.

## Autonoom besloten — ldap-mail-prefs, ronde 2 (2026-09-05)

Framework-relevante keuzes van deze sessie. De feature-eigen keuzes staan in
`docs/features/ldap-mail-prefs/decisions.md`.

- **Een feature mag een tweede commit krijgen op `7.0-stable-GEOxyz`.**
  `ldap-mail-prefs` staat er nu met twee: `add935736` (2026-09-03) en
  `113f32117` (de ronde-2 herbouw). "Eén commit per feature" botst hier met
  "nooit geschiedenis herschrijven op de branch die GEOxyz draait", en die
  tweede regel weegt zwaarder: een force push maakt elke checkout van GEOxyz
  ongeldig. Het registerveld `geoxyz_commit` wijst naar de laatste.
- **`7.0-stable-GEOxyz` is bijgewerkt met upstream `7.0-stable`** (32 commits
  achter, nu gelijk). Het enige conflict zat in `config/locales/fr.yml` en is
  opgelost volgens de regel die CLAUDE.md al gaf: beide kanten houden —
  upstream's vertalingen voor de gedeelde sleutels, GEOxyz's eigen sleutels
  erbij. Dat raakt `webhook-tracker-filter` en `mypage-query-blocks`, maar
  alleen mechanisch: er is geen ontwerpkeuze gewijzigd.
- **Drie kleine gaten in het gereedschap gevonden en in `docs/traps.md` gezet**
  (de `Resolution:`-vorm die `findings.sh` niet ziet, `###` binnen een
  codeblok dat spookbevindingen oplevert, en `docs/review/FINDINGS.md` dat niet
  in de OWNED-lijst van `check-ownership.sh` staat). Niet zelf gerepareerd:
  `tools/**` hoort bij een sessie die Jan daar expliciet om vraagt.

## Autonoom besloten — ar-sessions, ronde 2 (2026-09-05)

Framework- en productierelevante keuzes. De rest staat in
`docs/features/ar-sessions/decisions.md`.

- **De bewaartermijn voor sessierijen is 7 dagen**, niet de 30 van de gem. Er
  komt een rij bij per paginaweergave en niet per login — de review mat 100
  rijen uit 100 anonieme GETs op `/login` in vijf seconden — dus 30 dagen laat
  de tabel groeien tot iets wat niemand wil opruimen. Zeven dagen begrenst hem
  op ongeveer een week paginaweergaves; een gebruiker die binnen die week
  terugkomt merkt niets, want elke request zet `updated_at` opnieuw.
- **De store weigert vanaf nu een sessie-id in leesbare vorm**
  (`:secure_session_only => true`). Dat is de enige regel die voorkomt dat een
  rij die een oudere gemversie schreef — wat een database die van 5.1 komt kan
  bevatten — een werkend inlogkoekje is voor iedereen die de tabel of een
  back-up kan lezen. Prijs: die gebruikers loggen één keer opnieuw in, wat
  samenvalt met de logout die de deploy toch al aankondigde.
- **De serializer blijft Marshal.** `:json`/`:hybrid` zou `session[:issue_query]`
  breken (symboolsleutels overleven een JSON-rondgang niet), en dat is het
  onthouden filter op de issuelijst. De Marshal-aanval vereist
  databaseschrijfrechten; die ruil gaat niet door.
- **Twee commits per feature op `7.0-stable-GEOxyz` blijft het patroon**, ook
  hier: `95bbb9750` en `8bf6dce3e`. Zie de eerdere notitie bij
  `ldap-mail-prefs`.
- **Correctie op mijn eigen werk van vandaag:** de commits `113f32117` en
  `030aaf471` op `7.0-stable-GEOxyz` hebben `Claude <noreply@anthropic.com>` als
  auteur. Dat is een INV-4-overtreding in de commit-metadata, en
  `tools/check-geoxyz-branch.sh` ziet hem niet omdat die alleen berichten
  grept. Vanaf `8bf6dce3e` staat de identiteit goed. Rechtzetten van de twee
  oude kan alleen met een force push op een branch waar parallelle sessies op
  pushen, en `docs/traps.md` noemt dat al niet de moeite waard — maar het hoort
  hier te staan in plaats van stil te blijven.
## Autonoom besloten — wiki-export-attachments, ronde 2 (2026-09-05)

Framework-relevante keuzes van deze sessie; de feature-eigen Class A-keuzes
staan in `docs/features/wiki-export-attachments/decisions.md`.

- **Eerste rij in `docs/exceptions.md` (E-01):** INV-1 wordt bewust overtreden
  door twee bestaande methodes van #43978 mee te verhuizen naar
  `lib/redmine/export/zip/` en de `(n)`-lus uit `Attachment.archive_attachments`
  te lichten. De verhuizing is Jans keuze g16c; de extractie is Class A
  (review F04 noemde de kopie als het slechtere alternatief). Het dossier
  beantwoordt het bezwaar met hetzelfde antwoord, zoals `exceptions.md` eist.
- **Alle twaalf bevindingen van de review hebben een `Resolution:`-regel** in
  beide vormen: als `- **Resolution:**`-opsommingsregel in de kop (die
  `tools/findings.sh` leest) én als alinea onder de bevinding. Tien `fixed`,
  twee `wont-fix` (F09 per Jans g14, F11 per de reviewer zelf: het gat zit in
  `Attachment#sanitize_filename`, niet in de patch).
- **`tools/check-geoxyz-branch.sh` staat op FAIL door één lint-regel van
  upstream,** `Rails/StrongParametersExpect` op `wiki_controller.rb:369`. Die
  FAIL bestond al op `origin/7.0-stable-GEOxyz` vóór deze sessie (nagelopen
  zonder eigen commit), en de regel staat letterlijk zo in `origin/7.0-stable`.
  Niet gefixt: het is een regel van upstream, niet van de patch (INV-1). De
  baseline staat in het statusbestand (1 vóór, 1 na). Het script meet geen
  baseline; dat is een framework-wijziging en dus aan Jan.
- **Het oude ontwerp is van `patch/wiki-export-attachments` verdwenen** met een
  force push (`2cb6231c7` → `f434bff64`), en de oude patchbestanden
  `2026-09-01-r24882-*` zijn verwijderd in plaats van bewaard: ze hebben nooit
  aan een issue gehangen, en de drift-controle van `check-patch-clean.sh`
  vergelijkt élk bestand onder `patches/<slug>/` met de branch.

## Uitgevoerd — framework-punten uit wiki-export-attachments ronde 2 (Jan, 2026-09-05)

Jan vroeg beide punten uit het sessierapport meteen aan te passen.

- **`docs/exceptions.md` is geen tabel meer.** Eén blok met vijf vaste velden
  per uitzondering (`### E-nn — <slug>`, Regel, Wat er bewust gebeurt,
  Alternatief en wat het kost, Beslist, Datum), onderaan toegevoegd met
  `tools/append-note.sh`. E-01 staat er zo; de placeholder-rij is weg.
  `append-note.sh` zet nu een lege regel vóór elk blok.
- **`tools/check-geoxyz-branch.sh` meet een lint-baseline.** Dezelfde
  Ruby-bestanden worden ook op `origin/7.0-stable` gelint, met upstreams eigen
  config, en alleen wat de branch per bestand en cop méér heeft telt als fout.
  Op de huidige tip: PASS (1 melding, `Rails/StrongParametersExpect` op een
  regel van upstream, baseline 1). Op een proefbranch met één toegevoegde
  `Layout/TrailingWhitespace`: FAIL met het bestand en de cop erbij. G4 en G8
  in `CLAUDE.md` zeggen dat nu ook: een melding die upstream al op zijn eigen
  regel had is van upstream, niet van de patch.

## Autonoom besloten — mypage-query-blocks, ronde 2 (2026-09-05)

Tien reviewbevindingen van 2026-09-03 afgewerkt, alle tien gerepareerd; geen
`wont-fix`. Wat er onderweg zelf besloten is, staat per punt in
`docs/features/mypage-query-blocks/decisions.md`. Twee daarvan zijn breder dan
de feature en horen ook hier:

- **Een grens op een instelling weigeren we in het formulier, we knippen hem
  niet bij.** `Setting.validate_all_from_params` is waar Redmine dit al doet
  (`default_issue_due_date_offset`), en de drie foutteksten
  (`not_a_number`, `greater_than_or_equal_to`, `less_than_or_equal_to`) bestaan
  in alle vijftig localebestanden, dus er komt geen vertaalwerk bij. Klemmen
  laat het formulier iets anders tonen dan wat er draait; dat was precies
  bevinding F03.
- **Meetcijfers in een dossier worden op Redmine's eigen testfixtures gemeten,
  niet op `tools/dev-seed.rb`.** Een committer die het naspeelt heeft die
  fixtures. Cijfers die hij niet reproduceert kosten de hele note
  geloofwaardigheid, ook als de conclusie klopt (bevinding F04).

## Open — keuze voor Jan (toegevoegd 2026-09-05, mypage-query-blocks)

### K-10 — welk getal wordt de bovengrens van `my_page_max_issuequery_blocks`?

Je koos met g16b dát er een bovengrens komt. Welk getal het wordt is een keuze
die ik niet voor je hoor te maken, want hij is zichtbaar voor de beheerder en
hij is het eerste waar een committer over gaat praten.

- **Wat het is:** het maximum dat een beheerder in Beheer → Configuratie →
  Algemeen kan invullen voor "Maximum number of custom queries displayed on My
  page". Boven dat getal weigert het formulier de waarde. Het staat als één
  constante `Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS` in `lib/redmine/my_page.rb`.
- **Opties:**
  - **A) 10** — wat de issuebeschrijving van #27313 zelf voorstelt ("up to 10"),
    en ruim het dubbele van wat Go MAEDA vroeg. Dit is wat er nu in zit.
  - **B) 5** — precies wat Go MAEDA in note-8 voorstelde. Voorzichtiger, en
    makkelijker te verdedigen tegenover note-9 van Jean-Philippe Lang, maar het
    sluit de vraag van de oorspronkelijke melder (10) uit.
  - **C) een hoger rond getal, bijvoorbeeld 20** — de grens is dan puur een
    tikfoutbeveiliging (999999) en geen uitspraak over wat verstandig is.
- **Aanbeveling:** A. Het getal komt uit het issue zelf, dus het is niet ons
  getal maar dat van de melder; en de gemeten kosten (~17 KB HTML en enkele
  queries per blok extra) maken tien lijsten op één pagina zwaar maar niet
  onredelijk.
- **Haast?** Nee. We bouwden verder met A, en een ander getal is één regel.

## Beslist (Jan) — K-10, 2026-09-05

- **K-10 `mypage-query-blocks`: de bovengrens wordt 20** (optie C), tegen mijn
  aanbeveling in (ik adviseerde 10, het getal uit de issuebeschrijving zelf).
  Jans redenering is de betere: een bovengrens is een **tikfoutbeveiliging** en
  geen aanbeveling. Op 10 zetten zou de grens een uitspraak maken over wat
  verstandig is, en dat is precies wat we bij deze feature juist aan de
  beheerder laten. Op 20 ligt hij ruim boven elk getal dat op #27313 ter sprake
  komt — de 3 van vandaag, de 5 van note-8, de 10 van de beschrijving — dus
  niemand die erover nagedacht heeft loopt er tegenaan, terwijl `999999` er niet
  meer in kan.
- Gevolg in de code: één constante, `Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS = 20`,
  met een commentaarregel die zegt dát het een tikfoutbeveiliging is. Op
  `7.0-stable-GEOxyz` is dat commit `1b4a29a0b`, apart van `47eec6f1d` omdat die
  al gepusht was.
- **Algemene regel die hieruit volgt:** een bovengrens op een instelling die de
  beheerder juist zelf hoort af te wegen, kiezen we ruim. Hij bestaat om een
  onmogelijke waarde te weren, niet om beleid te maken.
