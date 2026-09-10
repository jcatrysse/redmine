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

## Uitgevoerd — g06 en g18 voor `assignee-nobody` (2026-09-05)

Alle negen bevindingen van de review van 2026-09-03 zijn afgehandeld en hebben
een `Resolution:`-regel in
`docs/review/findings/2026-09-03-assignee-nobody-claude-opus5.md`.

- **g06 uitgevoerd.** Het gevouwen NULL-fragment komt nu tussen haakjes terug,
  zodat `Query#sql_for_field` een zelfstandige clausule teruggeeft voor al zijn
  31 aanroepers. De aanleiding was `UserQuery#sql_for_is_member_of_group_field`,
  dat het fragment achter een `AND` binnen een `EXISTS` plakt: de `OR`
  ontsnapte daar en het gebruikersfilter gaf alle gebruikers in plaats van de
  leden van de gekozen groep. Twee nieuwe tests in `test/unit/user_query_test.rb`
  pinnen dat vast, en het voor/na-paar in de browser
  (`shots/regression-group-filter-nobody.png` tegen `shots/group-filter-nobody.png`)
  laat drie gebruikers tegen één zien.
- **g18 uitgevoerd** voor deze slug: de acht kleinere punten zijn allemaal
  gedaan, niet alleen de feitelijke correcties. Twee poorttests, een test op een
  tweede `list_optional`-filter, volledige id-lijsten voor de drie
  historie-operatoren, een niet-leeg-assertie in de twee equivalentietests, de
  positionele slice eruit, "63 localebestanden" naar 50, en de screenshottekst
  die vijf identieke 500-pagina's beschreef alsof er een filterformulier op
  stond.
- **g05 en g10 uitgevoerd** voor deze slug: de patchbranch is opnieuw op trunk
  r25037 gezet en de bewijscijfers zijn in dezelfde beweging opnieuw gedraaid,
  inclusief de volledige suite mét systeemtests op drie kanten (patch, schone
  trunk, `7.0-stable-GEOxyz`).
- **F09 vervalt als vraag voor Jan.** Die vroeg of de patch ingediend mocht
  worden met de fout erin; g06 beantwoordde hem al met "eerst repareren", en dat
  is nu gebeurd, op beide branches.

### K-11 — wat gebeurt er met een webhook als zijn laatste tracker verwijderd wordt? (webhook-tracker-filter)

Opgekomen in ronde 2 bij bevinding F02. Jans keuze g07 is uitgevoerd: `Tracker`
heeft nu de omgekeerde koppeling, dus een verwijderde tracker neemt zijn rijen in
`trackers_webhooks` mee in plaats van ze te laten liggen. Dat lost de rommel op,
maar niet het gedrag dat de bevinding als kop had: een hook die op precies één
tracker stond en die tracker kwijtraakt, houdt een **lege** selectie over — en
leeg betekent in deze feature "alle trackers". De hook vuurt daarna dus weer voor
elk issue in zijn projecten.

Hoe erg is dat echt: na de verwijdering bestaat er geen enkel issue meer met die
tracker (Redmine weigert een tracker met issues te verwijderen), dus er komt
niets bij op díe tracker. Wat er wél bij komt is de rest van het project: issues
van de andere trackers gaan weer naar het endpoint. Dat is precies het lek dat de
feature zou dichten, alleen nu na een beheerdersactie in plaats van door een
verkeerde instelling.

- **Keuze:** laten zoals het is en het opschrijven, of Redmine de verwijdering
  laten tegenhouden zolang er nog een hook naar die tracker wijst?
- **Opties:**
  A) **Opschrijven** (nu gebouwd). Het dossier zegt op twee plaatsen wat er
     gebeurt en waarom. Nul extra code, en het volgt dezelfde regel als de rest
     van de feature.
  B) **Verwijdering blokkeren** via `Tracker#check_integrity`, zoals Redmine dat
     al doet voor een tracker met issues. De beheerder krijgt dan een foutmelding
     en moet eerst de hook aanpassen. Extra code in een kernmodel, en een
     beheerder die een tracker opruimt kan gestuit worden door een webhook van
     iemand anders die hij niet mag zien.
  C) **De hook deactiveren** als zijn laatste tracker verdwijnt. Niemand krijgt
     te veel, maar er stopt stil een integratie, en dat is een verrassing van een
     andere soort.
- **Aanbeveling:** A. Het is de enige optie die geen nieuw gedrag verzint voor een
  zeldzame beheerdersactie, en upstream neemt een patch met minder verrassingen
  eerder aan. B is verdedigbaar maar hoort dan als eigen wijziging op `Tracker`,
  niet in deze patch.
- **Haast?** nee — we bouwden verder met A, en het staat als afgewogen positie in
  de bezwarentabel van het dossier.

## Beslist (Jan) — K-11, 2026-09-05

- **K-11 `webhook-tracker-filter`: een hook waarvan de laatste tracker
  verwijderd wordt, wordt gedeactiveerd** (optie C), tegen mijn advies in — ik
  had A aanbevolen, laten zoals het is en het opschrijven.

  Achteraf is C het betere argument, ook upstream, en dat maakt mijn aanbeveling
  zwak in plaats van C riskant: een hook waarvan het laatste **project**
  verdwijnt vuurt vanzelf al niet meer, want `hooks_for` joint op
  `projects_webhooks`. De trackerkant was daarmee de enige associatie waar
  verwijderen een hook juist **verbreedde** in plaats van hem stil te zetten.
  Deactiveren maakt de twee gelijk, en dat is precies het soort symmetrie waar
  een Redmine-committer op let.

  Uitgevoerd als `before_destroy :check_integrity, :deactivate_webhooks` op
  `Tracker`. Die methode zet alleen hooks uit waarvan deze tracker de énige
  selectie was; een hook met nog een andere tracker houdt zijn filter en blijft
  actief, en een hook die nooit een tracker aanvinkte wordt niet aangeraakt.
  `update_column` en niet `update!`: de validaties van `Webhook` raken de
  URL-blocklist en herfilteren de projecten van de hook, en die horen niet
  middenin een trackerverwijdering — een validatiefout daar zou de verwijdering
  afbreken.

  Drie tests, één per geval; de middelste staat rood zonder de callback. Het
  voor/na-paar `shots/{before-,}tracker-destroyed.png` laat de kolom Actief van
  `Yes` naar `No` gaan.

  **Wat we ermee accepteren, expliciet:** er stopt stil een integratie. De
  beheerder die de tracker verwijdert krijgt geen melding, en alleen de
  webhooklijst laat zien dat de hook uit staat. Het alternatief (de verwijdering
  blokkeren zolang er een hook naar de tracker wijst) is afgewezen omdat een
  beheerder die trackers opruimt dan gestuit wordt door een hook van iemand
  anders die hij niet eens mag zien. K-11 is hiermee gesloten.

## Uitgevoerd — g08, g05, g10 en g18 voor `search-token-limit` (2026-09-05)

Alle negen bevindingen van de review van 2026-09-03 zijn afgehandeld en hebben
een `Resolution:`-regel in
`docs/review/findings/2026-09-03-search-token-limit-claude-opus5.md`.

- **g08 uitgevoerd.** Het filter "Any searchable text" is gerepareerd in plaats
  van alleen in de tekst rechtgezet. `Redmine::Search::Fetcher` heeft er een
  optie `:token_limit` bij, standaard 5; `IssueQuery#sql_for_any_searchable_field`
  geeft `nil` mee. Het zoekvak rechtsboven verandert niet, en een plugin die
  zelf een `Fetcher` bouwt ook niet — K-04 blijft dus staan zoals hij is.
- **Bevinding F02 vroeg om een keuze en die is genomen.** De knop "Apply issues
  filter" onder de zoekresultaten gaf de hele vraag door aan een filter dat na
  deze patch niet meer afkapt, terwijl de pagina erboven met vijf woorden
  gezocht had: "Results (1)" met daaronder een knop naar "No data to display".
  De knop geeft nu de woorden door die de zoekmachine gebruikt heeft, waardoor
  hij zich precies gedraagt als vandaag in trunk. Er is een
  regressie-screenshot bij, genomen op de vorige versie van de patch, zodat het
  verschil te zien is in plaats van alleen te lezen.
- **g05 en g10 uitgevoerd** voor deze slug: de patchbranch is opnieuw op trunk
  r25037 gebouwd en alle bewijscijfers zijn in dezelfde beweging opnieuw
  gedraaid, inclusief de volledige suite mét systeemtests op drie kanten (patch,
  schone trunk, `7.0-stable-GEOxyz`).
- **g18 uitgevoerd** voor deze slug: ook de zes kleinere punten zijn gedaan. De
  `~`-test bewijst nu beide helften in één body, het verhuisde commentaar is
  vervangen door het waarom, de prestatiecijfers en de AND/OR-asymmetrie staan
  met getallen in het dossier, het bind-parametervraagstuk is beantwoord
  (`sanitize_sql_for_conditions` zet de waarden in de tekst, dus nul
  placeholders), en het bestandsaantal in het GEOxyz-bewijs klopt weer.
- **F09 vervalt als vraag voor Jan.** Die vroeg of de grens van vijf woorden ook
  voor het filter "Any searchable text" en voor de knop moest blijven gelden;
  g08 beantwoordde de eerste helft met "repareren" en deze sessie de tweede met
  "de knop volgt de zoekmachine".

## Uitgevoerd — ronde 2 voor `version-subprojects` (2026-09-05)

Alle twaalf bevindingen van de review van 2026-09-03 hebben een
`Resolution:`-regel. Drie ervan raakten code, de rest tekst.

- **g16g uitgevoerd.** De note begint met de regressie, en het getal is
  gecorrigeerd: **zes naar vijf** als beheerder, niet zes naar vier. Alleen
  versie 7 verdwijnt door de sharing; versie 6 verdween in het oude getal door
  `Version.visible`, wat een ander verschijnsel is.
- **g09 en g10 uitgevoerd.** Elke claim in het dossier heeft nu een gemeten
  getal: 5 SQL-statements tegen trunk's 2 (6 tegen 2 koud), 665 tekens tegen
  134 in de URL van het AJAX-verzoek, volledige suite met systeemtests
  27 failures / 2 errors op beide kanten met dezelfde 29 namen.
- **g05 uitgevoerd.** De branch is opnieuw opgebouwd op `origin/master` r25037
  en alle cijfers zijn daar opnieuw gemeten. Het oude patchbestand
  (`2026-09-03-r24882-feature.patch`) is vervangen, niet bewaard: het heeft
  nooit aan het issue gehangen.
- **g18 uitgevoerd.** Ook de nits: de commitboodschap is één regel, de drie
  tests van Go MAEDA zijn als zodanig gemarkeerd, en de `c=foo`-500 is
  verdwenen omdat het endpoint `c` niet meer leest.

## Open — keuze voor Jan (toegevoegd 2026-09-05, version-subprojects)

- **K-12 Keuze:** het doelversiefilter mist nog één randgeval van precies het
  defect dat deze patch repareert. Dichten of benoemen?

  Het gaat om een versie die van een tussenliggend project naar zijn
  *afstammelingen* gedeeld is, terwijl een expliciet subprojectfilter dat
  tussenliggende project buiten de query laat maar zijn subproject erin. Zo'n
  versie kan wel aan een issue in dat subproject hangen, maar staat niet in het
  filter. Met Redmine's eigen fixtures: project 1 - 5 - 6, een
  `descendants`-versie in project 5, filter "Subproject is project 6" — de
  versie ontbreekt.

- **Opties:**
  A) **Benoemen.** Het dossier zegt precies wat de lijst wel is en noemt dit
     geval erbij, zodat een reviewer het in de note vindt en niet in de code.
     De patch blijft vier productieregels.
  B) **Dichten.** De vraag wordt "welke versies kan enig project in de query
     toewijzen", wat een bredere en ingewikkeldere SQL-voorwaarde is dan wat
     jij of Go MAEDA ooit op dit issue heeft voorgesteld.

- **Aanbeveling:** A, en dat is ook wat er nu staat. Een patch die één regel
  verandert wordt aangenomen; een patch die de deelsemantiek herdefinieert
  krijgt een discussie van maanden. Het randgeval bestaat vandaag ook al en
  wordt door deze patch niet erger.

- **Haast?** Nee — we bouwden verder met A, en het staat benoemd in het dossier.

## Beslist (Jan) — K-12, 2026-09-05

- **K-12 `version-subprojects`: het `descendants`-randgeval wordt benoemd, niet
  gedicht.** Optie A, conform het advies. De code blijft vier productieregels;
  het dossier zegt onder "Proposed change" precies wat de waardelijst wél is
  ("the versions the project can assign, plus the visible versions belonging to
  the projects the query covers") en noemt het resterende geval met de
  reproductie op Redmine's eigen fixtures erbij, plus een rij in de
  objectietabel. Er verandert dus niets aan de patch: hij stond al zo.

  Reden om het niet te dichten: de vraag "welke versies kan *enig* project in de
  query toewijzen" is een bredere SQL-voorwaarde dan wat Jan of Go MAEDA ooit op
  #43534 heeft voorgesteld, en het randgeval bestaat vandaag op kale trunk
  evengoed — de patch maakt het niet erger. Een reviewer die het vindt, vindt
  het in de note.

## Uitgevoerd — ronde 2 voor `revision-branches` (2026-09-05)

Alle elf bevindingen van de review van 2026-09-03 hebben een
`Resolution:`-regel. Zeven raakten code, vier tekst, en één was een vraag aan
jou die met g12 al beantwoord was.

- **g12 uitgevoerd, beide helften.** De uitzondering staat als **E-02** in
  `docs/exceptions.md`: welke regel bewust wordt overtreden (de SCM-aanroep per
  rij in een view-loop), waarom een cache geen alternatief is, en wat het kost.
  En de bovengrens zit erin: boven `repository_log_display_limit` revisies
  (standaard 100) toont de issuetab helemaal geen branches meer en draait hij
  dus geen enkel Git-proces. Geen vijfde instelling (INV-6) — hergebruik van
  een getal dat de beheerder toch al kent. Daarmee is ook F11 beantwoord.
- **De belangrijkste codefix was er één die niemand had voorzien (F01).** De
  patch kopieerde het instellingenpaar van de mail handler, maar niet de
  validatie die er één laag hoger bij hoort. Een beheerder kon `[` invullen als
  reguliere expressie, het werd zonder mopperen opgeslagen, en vanaf dat moment
  deed de uitsluitingslijst niets — zonder melding. Nu weigert het formulier
  het, met precies dezelfde tekst als bij de mail handler:
  *"Exclude branches by name is not a valid regular expression (premature end
  of char-class: /[/)"*. Er is een screenshot van.
- **Eén zin uit de issuetekst is verwijderd omdat hij aantoonbaar onwaar was
  (F03).** "De revisiepagina roept al drie Git-commando's aan" gaat over de
  *bladerpagina*, niet over de revisiepagina; die laatste roept er nul aan.
  Op een issue van zestien jaar oud, waar de auteur van die note zelf meeleest,
  is dat het soort zin dat de rest van het betoog meesleurt.
- **g09 en g10 uitgevoerd.** Elke claim in het dossier heeft nu een gemeten
  getal, opnieuw gedraaid tegen r25037.
- **g05 uitgevoerd.** De branch is opnieuw opgebouwd op `origin/master` r25037.
  De oude patchbestanden (`2026-09-03-r24882-*.patch`) zijn vervangen, niet
  bewaard: ze hebben nooit aan het issue gehangen.
- **g18 uitgevoerd.** Ook de kleine punten: het label noemt nu ook de
  diffpagina (die dezelfde partial rendert), de voorbeeldhint toont een glob in
  plaats van een reguliere expressie omdat glob de standaardstand is, er staat
  in woorden dat de functie alleen voor Git werkt, de permissietest test nu ook
  echt iets, een branchnaam die niet omgezet kan worden laat de pagina niet meer
  crashen, en de commitboodschap is één regel.


## Uitgevoerd — gitignore-credentials, ronde 2 (2026-09-05)

Jans keuzes g11 en g16a uitgevoerd; alle drie de bevindingen van die review
hebben nu een `Resolution:`-regel. De feature-eigen keuzes staan in
`docs/features/gitignore-credentials/decisions.md`.

- **g11 is één regel geworden, `/config/credentials/`** — de map, niet een glob
  per bestandstype. Die dekt `<env>.key` én `<env>.yml.enc` ineens, blijft
  kloppen voor een omgevingsnaam die nog niemand bedacht heeft, en past in de
  alfabetische `/config/`-rij. Gemeten met de bestanden echt op schijf: zes van
  de zes paden worden gepakt, `git add -A --dry-run` zette vóór de wijziging
  `config/credentials/production.key` klaar en erna alleen `.gitignore`, en geen
  enkel gevolgd bestand raakt verstopt. Commit `3f5eb3be2` op
  `7.0-stable-GEOxyz`; dit is de tweede commit van deze feature, volgens het
  patroon dat bij `ldap-mail-prefs` is vastgelegd.
- **g16a staat nu met zijn prijs in `status.md`**, niet alleen als keuze:
  gebruikt GEOxyz ooit Rails-credentials, dan blijft het versleutelde bestand
  achter op de machine die het maakte en geeft `Rails.application.credentials`
  op de server stil `nil`. Vandaag kost het niets — Redmine leest credentials
  nergens.
- **F02 is bewust niet gerepareerd, en dat is gemeten in plaats van aangenomen.**
  Rails' automatische aanvulling van `.gitignore` onderdrukken vereist zijn
  volledige blok inclusief commentaarregel; de vorm die de bevinding voorstelde
  (een kale `/config/*.key`) doet dat aantoonbaar niet. Vier regels ruis in een
  strak bestand, die de `.enc`-bestanden bovendien niet dekken, wegen niet op
  tegen één `git checkout -- .gitignore` na de eerste `credentials:edit`. Die
  instructie staat nu in `status.md`.


## Uitgevoerd — ronde 2 voor `webhook-issue-closed` (2026-09-05)

Alle **tien** bevindingen uit
`docs/review/findings/2026-09-03-webhook-issue-closed-claude-opus5.md` hebben nu
een `Resolution:`-regel: **drie** wijzigden code, **zeven** de begeleidende
tekst. De patch staat op **r25037** (g05), en de bewijscijfers zijn in dezelfde
beweging opnieuw gedraaid (g10). Feature-eigen keuzes staan in
`docs/features/webhook-issue-closed/decisions.md` onder "Ronde 2".

Wat hier hoort omdat het buiten die ene feature betekenis heeft:

- **Jans g16e is uitgevoerd**: de `closed_on`-bewaking draagt nu één regel
  *waarom*. Dat is meteen het eerste concrete geval van de nieuwe INV-3: één
  regel boven een callback die een niet-vanzelfsprekend waarom vastlegt, en
  géén regel binnen een methode die herhaalt wat de code doet.
- **F05 verplaatste code in plaats van het argument bij te stellen.** Het
  dossier voerde het argument dat `closed` issuespecifiek is, en zette de naam
  toch in `lib/redmine/acts/webhookable.rb`. Nu overschrijft
  `Issue::Webhookable` de tijdstempelmapping en raakt de patch **geen enkel
  bestand onder `lib/redmine/`**. Kosten: twee regels productiecode meer
  (13/2 over drie bestanden in plaats van 8/3 over vier). Voor een los
  ingediend deelstuk uit een grotere patch is een kleinere blast radius het
  betere verhaal — dat is de generaliseerbare afweging.
- **Een reviewfix kan dekking wegnemen die niemand geteld had.** F07 vroeg de
  end-to-end test de job te laten lezen die zijn eigen blok in de wachtrij
  zette in plaats van de eerste `WebhookJob` in het proces. Terecht — maar
  precies dat toeval was wat rij 1 van de overgangstabel dekte volgens F03. Na
  de fix stond die rij zonder dekking. Opgelost met een eigen bewaker; gemeten
  door de bewaking weg te muteren: **5** tests vallen nu om waar het er 4
  waren. In `docs/traps.md` gezet.
- **K-09 krijgt een tweede feitencorrectie, en die gaat de andere kant op dan
  de eerste.** `fr.yml` heeft de groep `webhook_event_*` inmiddels wél vertaald
  (tussen r24882 en r25037). Op r25037 geldt: **49** niet-Engelse bestanden
  dragen de groep, **42** letterlijk Engels, **zeven** vertaald — `bg cs fr gl
  hu ja zh-TW`. Gevolg voor de keuze: een Franse beheerder ziet nu drie
  vertaalde labels plus een Engels "Issue closed", en dat is precies de
  half-Engelse uitkomst waar optie C tegen pleitte — nu bereikt door optie A te
  nemen. De aanbeveling blijft **A** voor `nl`, `de` en `es` (daar staat de
  hele groep nog Engels, dus daar is niets half). Voor `fr` alleen is er nu een
  argument vóór B of C dat er op r24882 niet was. **Het blokkeert het indienen
  nog steeds niet**, en de cijfers dragen voortaan hun revisie mee zodat ze
  niet nog een keer stil verlopen.


## Open — keuze voor Jan (toegevoegd 2026-09-06, framework-breed)

- **K-13 — Keuze:** zestien van de drieëndertig eigen commits op
  `7.0-stable-GEOxyz` hebben `Jan Catrysse` als **auteur** maar
  `Claude <noreply@anthropic.com>` als **committer**. INV-4 en jouw eigen K-01
  verbieden een AI-spoor op die branch, dus de regel staat niet ter discussie —
  alleen wat we eraan doen. De oorzaak is mechanisch: `tools/session-push.sh`
  speelt eigen commits opnieuw af als een andere sessie eerder was, en een
  replay zet de committer op wie hem draait. Gemeten op 2026-09-06 met
  `git log --format='%cn' origin/7.0-stable..origin/7.0-stable-GEOxyz | sort | uniq -c`:
  16 Claude, 17 Jan Catrysse.
- **Opties:**
  A) Accepteren als een permanente eigenschap van deze branch, het één keer
     hier vastleggen en het niet meer per feature in elk statusbestand
     herhalen. Kost niets, maar zestien commits houden een spoor dat de regel
     verbiedt.
  B) Eén keer rechtzetten met een force-push op een moment dat er geen enkele
     sessie pusht. Schoon resultaat, maar een force-push op een branch waar
     parallelle sessies op werken kan werk van een ander wegvagen, en elke
     bestaande checkout van GEOxyz raakt van de historie los.
  C) Het verleden laten staan, maar `tools/session-push.sh` aanpassen zodat een
     replay voortaan de oorspronkelijke committer behoudt. Dan groeit het getal
     niet verder en blijft de historie intact.
- **Aanbeveling:** C, en pas daarna eventueel B als je die zestien oude commits
  toch schoon wil hebben. C haalt de oorzaak weg zonder iets te riskeren; B is
  het enige dat het verleden repareert en tegelijk het enige dat werk van een
  parallelle sessie kan kosten.
- **Haast?** Nee. Het raakt **geen enkele patch**: `git format-patch` neemt de
  **auteur** mee en niet de committer, en de `patch/<slug>`-branches hebben
  beide velden op Jan staan.

Zolang K-13 openstaat wordt dit **niet** meer per feature in een statusbestand
uitgeschreven; `docs/features/members-pagination/status.md` verwijst er sinds
2026-09-06 alleen nog naar. Dat was de vraag van bevinding Q01 van de
reviewronde: één keer beslissen in plaats van het bij elke feature opnieuw
melden.


## Uitgevoerd — K-13, optie B (2026-09-06)

Jans keuze: **optie B**, één keer rechtzetten met een force-push. Uitgevoerd op
een moment dat `tools/claim.sh --list` "no open claims" gaf, dus geen enkele
parallelle sessie kon werk verliezen.

**Wat er is herschreven.** Alle 33 eigen commits op `7.0-stable-GEOxyz` hebben
nu `Jan Catrysse <jan.catrysse@geoxyz.eu>` als auteur én als committer. Oude tip
`7e92b5596` → nieuwe tip `465d326aa`.

**Twee dingen die in de vraag van K-13 niet stonden, en die er wel in horen.**

1. Vier commits hadden `Claude` niet alleen als committer maar ook als
   **auteur**: `113f32117`, `030aaf471`, `47eec6f1d` en `1b4a29a0b`. Dat is de
   ernstiger helft, want `git format-patch` neemt de auteur mee en de committer
   niet. Ze zijn in dezelfde herschrijving meegenomen; anders had B precies het
   spoor laten staan waar hij over ging.
2. Er is **niets naar redmine.org gelekt.** Alle dertien patchbestanden onder
   `patches/` hadden al `From: Jan Catrysse <jan.catrysse@geoxyz.eu>`.

**Wat er bewijsbaar niet is veranderd.** Het tree-object van de tip is
`2966954c35fa39307656390e3fb8421d1a07bba9` vóór en na — de inhoud is dus byte
voor byte gelijk. Commit-boodschappen letterlijk gelijk en in dezelfde volgorde,
alle 33 auteur- en committerdatums ongewijzigd, de merge-commit nog steeds een
merge met beide ouders, en `git log | grep -i 'claude\|anthropic'` geeft nul.

**Waarom geen enkel ander featurebestand hoefde mee te veranderen** — Jans eis
bij deze uitvoering. Elke oude SHA blijft oplosbaar, ook in een verse kloon,
want de oude historie staat als volwaardige branch op de remote:

    archive/7.0-stable-GEOxyz-identities-before-20260906   (7e92b5596)
    backup/7.0-stable-GEOxyz-pre-identity-fix-20260906     (7e92b5596)

**Verwijder die archive-ref nooit.** Doe je dat, dan wordt `geoxyz_commit` in
achttien statusbestanden alsnog een verwijzing naar het niets.

`docs/features/<slug>/status.md` van een andere feature is dus **niet**
aangeraakt. Alleen `members-pagination` is bijgewerkt, want die is van deze
sessie. Werk je aan een andere slug, zet dan zijn `geoxyz_commit` om met de
tabel hieronder en draai daarna `tools/register.sh --write`. Tot dat gebeurt
wijst de regel naar een commit die klopt maar niet meer op de branch staat.

**Wat hiermee níét is opgelost:** de oorzaak. `tools/session-push.sh` zet bij
een replay de committer nog steeds op wie hem draait, dus het groeit opnieuw
zodra een sessie moet replayen. Dat was optie C, en die is niet gekozen.

### De SHA-kaart, oud → nieuw

| Oud | Nieuw | Commit |
|---|---|---|
| `28c618860` | `c077d96df` | Preserve the wiki page hierarchy and include page attachments in the ZIP export. |
| `1c85728aa` | `6695461bd` | Text filters no longer ignore keywords after the fifth (#43701). |
| `9d28be94d` | `349fe1860` | Assigned to issuelist filter: added <nobody> value (#5535). |
| `20ed9e2d1` | `fd35bd2d1` | Target version filter offers the versions of the subprojects in the query (#43534). |
| `d157934c0` | `157c171a5` | Assert the target version filter with subproject issues hidden (#43534). |
| `198cbfb63` | `dc6dad120` | Make the maximum number of custom query blocks on My page configurable (#27313). |
| `f117ea32e` | `1a6d462a8` | Authenticate IMAP inbound mail with an OAuth 2.0 access token (#43023). |
| `f2242bd86` | `c6631e937` | Limit an outgoing webhook to the trackers selected on it. |
| `115230bc2` | `ff0d23b62` | Show the Git branches that contain a revision (#5386). |
| `21c232ce1` | `d92dff560` | Add the one-off task that obtains the IMAP OAuth 2.0 refresh token (#43023). |
| `646008041` | `86647653e` | Translate the webhook tracker hint into Dutch, French and Spanish. |
| `827e9e7d5` | `7d85538f3` | Add a separate issue.closed webhook event. |
| `351fe9e54` | `148faafb6` | Paginate the project members list (#43355). |
| `55ae9d1dd` | `02ca8b044` | Paginate the group users list (#43355). |
| `885f04097` | `22a4244c0` | Keep the members and group users lists on a page that still exists (#43355). |
| `e2c0447b6` | `af0af806d` | Ignore the Rails credentials files, so master.key can never be committed. |
| `fe737441b` | `075c86e8a` | Allow development requests to the geoxyz.eu subdomains. |
| `95bbb9750` | `8612a76f4` | Store sessions in the database instead of in the session cookie. |
| `add935736` | `2ac1de3c6` | Add the task that mutes mail notifications for LDAP-only users. |
| `113f32117` | `bc7314a62` | Replace the LDAP mail-muting task with a reversible one that sets the notification preferences of LDAP accounts. |
| `030aaf471` | `ee236190a` | Merge upstream 7.0-stable into 7.0-stable-GEOxyz. |
| `8bf6dce3e` | `bc745ce73` | Verify the database session store at deploy time, and refuse a plain-text session id. |
| `7006c4f00` | `1fd3343ff` | Rename a wiki attachment that collides with the page source or a child page directory in the ZIP export. |
| `47eec6f1d` | `dd063fa8b` | Bound the maximum number of custom query blocks on My page to a range (#27313). |
| `1b4a29a0b` | `f5ed23c8e` | Raise the upper bound of the custom query blocks setting to 20 (#27313). |
| `d8e0db501` | `9ad87a11b` | Keep the <nobody> filter condition self-contained (#5535). |
| `0fbad7c17` | `72058fa43` | Drop a destroyed tracker from its webhooks, and ignore unknown tracker ids. |
| `72a3a8e22` | `8ac09f4ff` | Deactivate a webhook when the only tracker it is limited to is deleted. |
| `f260958c6` | `1cd7091fd` | Lift the token limit for the any_searchable filter too (#43701). |
| `e2f060570` | `74f343d3d` | Send and consume only the filter parameters on the query filter endpoint (#43534). |
| `8c1fa23fb` | `755d763a8` | Validate the branch exclusion pattern and cap the branches shown per issue (#5386). |
| `3f5eb3be2` | `737b0a549` | Ignore the per-environment Rails credentials directory as well |
| `7e92b5596` | `465d326aa` | Keep the issue.closed timestamp mapping with the rest of the issue webhook code. |


## Uitgevoerd — K-13, ook optie C (2026-09-06)

Na optie B vroeg Jan ook om C, want B alleen laat de oorzaak staan.

**De diagnose in K-13 was te smal.** Daar stond dat een replay in
`tools/session-push.sh` de committer verzet. Dat klopt, maar het is niet de hele
oorzaak: de **globale git-identiteit van een sessie is
`Claude <noreply@anthropic.com>`**. Een commit die zonder expliciete override op
`7.0-stable-GEOxyz` wordt gezet is dus al fout vóór er iets gereplayed is. De
zeventien commits die het wél goed hadden kwamen van sessies die de identiteit
per commit meegaven.

**Wat er is veranderd in `tools/session-push.sh`.**

1. De replay draait nu met `GIT_COMMITTER_NAME`/`GIT_COMMITTER_EMAIL` van de
   commits die gereplayed worden, in plaats van die van wie het script draait.
   Hebben die commits meer dan één committer, dan stopt het script in plaats van
   er één overheen te stempelen.
2. Een push naar `7.0-stable-GEOxyz` of `patch/*` wordt **geweigerd** zodra een
   mee te sturen commit `anthropic` of `claude` in zijn auteur- of committerveld
   heeft. De foutmelding bevat het `filter-branch`-commando dat het rechtzet en
   de manier om het te voorkomen. `geoxyz/framework` is uitgezonderd — K-01 zet
   de attributie daar juist bewust.

Punt 2 is het belangrijkste. Punt 1 dicht één lek, punt 2 vangt ze allemaal,
ook de commit die nooit gereplayed wordt.

**Gemeten, in een wegwerprepo met een lokale remote, hetzelfde scenario twee
keer** — een parallelle sessie pusht eerst, daarna moet mijn commit gereplayed
worden. Committer vóór de replay in beide gevallen
`Jan Catrysse <jan.catrysse@geoxyz.eu>`:

| Versie | Committer na de replay | Gepusht? |
|---|---|---|
| oud | `Claude <noreply@anthropic.com>` | ja — zo zijn de zestien ontstaan |
| nieuw | `Jan Catrysse <jan.catrysse@geoxyz.eu>` | ja |

En de guard apart getest: een commit met de standaard sessie-identiteit op een
`patch/*`-branch geeft `FAIL INV-4`, exit 1, en er gaat **niets** naar de
remote. Het herstelcommando uit die foutmelding is letterlijk uitgevoerd en
daarna slaagde de push wel. Een schone branch gaat er ongehinderd doorheen —
ook `7.0-stable-GEOxyz` zelf, na de herschrijving van optie B.

`CLAUDE.md` (INV-4) en `docs/STATE.md` (de gereedschapstabel) zeggen dit nu ook,
want de oude formulering van INV-4 ging alleen over de commit-boodschap en dat
is precies de helft die níét het probleem was.


## Beslist (Jan) — 2026-09-06, imap-oauth (reviewronde 3)

- **F07, de splitsing aanbieden in de note: optie B.** De note aan
  [#43023](https://www.redmine.org/issues/43023) zegt in één zin dat de patch
  netjes in tweeën valt — het ophaalgedeelte (`oauth2_token=`,
  `oauth2_credentials=` en `Oauth2Client.access_token`) en de eenmalige
  toestemmingsstap (`oauth2_authorize`, `Oauth2Client.authorize_url` en
  `refresh_token`) — als de committer liever eerst alleen het eerste neemt.
  **De bijlage blijft één patchbestand**; het aanbod staat in de tekst, niet in
  de bestanden. Reden: op #29664 vroeg Holger Just (note 37) precies om zo'n
  splitsing, dus de reflex is te verwachten, en hem vóór zijn met een zin die
  Jan al beantwoord heeft kost niets. Wat níét verandert: de beslissing van
  2026-09-03 dat de toestemmingsstap in de patch hoort en door iedereen te doen
  moet zijn, staat en wordt hierdoor niet heropend.


## Beslist (Jan) — 2026-09-06, framework

- **`docs/review/FINDINGS.md` is eigendom van wie hem regenereert, net als
  `docs/REGISTER.md`.** Jan gaf hier op 2026-09-06 opdracht toe ("los op").
  `tools/check-ownership.sh` rekende alleen `docs/REGISTER.md` tot de bestanden
  die een sessie mag meesturen, terwijl allebei door een tool gegenereerd worden
  en allebei "regenereren, nooit mergen" in hun kop hebben staan. Gevolg: elke
  sessie die een bevinding sloot kreeg een FAIL op een bestand dat ze juist
  hoorde te regenereren — op één dag drie keer. Beide staan nu in de
  `OWNED`-verzameling, en de controle die een met de hand bewerkte
  `REGISTER.md` tegenhoudt geldt nu ook voor `FINDINGS.md`. Nagemeten op vijf
  gevallen: schone boom, een echt geregenereerde `FINDINGS.md` (PASS, "matches
  its generator"), een met de hand bewerkte (FAIL), een wijziging in `tools/**`
  (FAIL) en een in `CLAUDE.md` (FAIL). De padvergelijking gebruikt nu
  `grep -qxF` in plaats van een met de hand ge-escapete regex.


- **`docs/STATE.md` staat nu op ronde 3, en de voortgang staat er als commando
  in plaats van als getal.** Jan gaf hier op 2026-09-06 opdracht toe ("ja"). De
  fasesectie zei nog dat ronde 2 aan de beurt was terwijl die op 2026-09-06
  afliep; drie sessies op rij moesten zelf uitvogelen dat ronde 3 liep. Dat is
  dezelfde soort fout als de K-06-regel die in `imap-oauth/status.md` bleef
  staan nadat de keuze al beslist was, en als de verklaring die geraden werd in
  plaats van gemeten (zie `docs/traps.md`). De les die nu in het bestand zelf
  verwerkt zit: **zet in `docs/STATE.md` geen stand die veroudert.** Hoever
  ronde 3 is vraag je op met twee `ls`-commando's die in de fasesectie staan;
  het verschil tussen die twee lijsten is wat er nog moet. Meegenomen: de
  startstappen zeggen nu dat een openstaande bevinding fixen vóór een nieuwe
  review gaat, en dat een reviewsessie de slug juist **niet** claimt.


## Beslist (Jan) — K-14, 2026-09-08

- **K-14 `wiki-export-attachments`: de Nederlandse vertaling van
  "Include attachments" wordt optie A, `Met bijlagen`.**
  De ronde-3 review vond dat `Bijlagen meesturen` een werkwoord gebruikt dat
  nul keer in `nl.yml` voorkomt, en dat het bovendien posttaal is voor iets dat
  niets verstuurt. Optie A is afgeleid uit een sleutel die er al staat,
  `label_cross_project_descendants` ("Met subprojecten") — precies de sleutel
  waar de Duitse waarde ("Mit Anhängen") al op gebaseerd was, dus de twee regels
  volgen nu één patroon in plaats van twee.
  **Waarom dit een keuze van Jan was en geen klasse A:** INV-5 schrijft voor dat
  een vertaling afgeleid wordt, maar niet wélke van twee verdedigbare afleidingen
  wint, en de string is zichtbaar voor GEOxyz-gebruikers.
  Doorgevoerd op `patch/wiki-export-attachments` (`8121846be`) en op
  `7.0-stable-GEOxyz` (`6078281ff`), identiek aan beide kanten (INV-10), en de
  Nederlandse schermafbeelding is opnieuw genomen zodat het bewijs bij de string
  klopt.


## Beslist (Jan) — K-15, 2026-09-08

- **K-15: de 21 dode commit-SHA's in het register worden hersteld **en** het
  gereedschap gaat het voortaan bewaken. Optie B.**
  De ronde-3 review vond dat 21 van de 32 vastgelegde `geoxyz_commit`-waarden
  naar commits wezen die na de identiteitsherschrijving van K-13 (2026-09-06)
  van geen enkele branch meer bereikbaar zijn. In deze checkout bestaan die
  objecten nog, dus `git show <oude sha>` slaagt en toont een geloofwaardige
  commit — de fout is hier stil en wordt pas luid (`fatal: bad object`) in een
  verse kloon.
  **Wat er gebeurd is:** de tien statusbestanden zijn bijgewerkt uit een
  opnieuw berekende afbeelding, `docs/REGISTER.md` is opnieuw gegenereerd, en
  `tools/check-geoxyz-branch.sh` heeft er twee controles bij: het register
  tegen de branch, en de AI-identiteit in het auteur- én committerveld (dat is
  wat INV-4 vraagt en wat er niet in stond). Beide zijn eerst rood gedreven
  tegen echte data voordat ze zijn aanvaard.
  **Waarom dit Jans keuze was:** `tools/**` is framework en wijzigt alleen als
  hij erom vraagt; optie A (alleen de data repareren) liet dezelfde fout over
  een half jaar opnieuw ontstaan.
  **Wat bewust níét is aangeraakt:** alle andere oude SHA's in die bestanden.
  Patchbranchtips, de trunkrevisie `bee32a926`, gearchiveerde tips en één
  expliciet als historisch gedocumenteerde SHA zijn correct oud; zie
  `docs/traps.md` voor waarom titelgebaseerd vervangen daar misgaat.

## Open — keuze voor Jan (toegevoegd 2026-09-09, mypage-query-blocks)

### K-16 — welke gate gaat de commit-identiteit op `patch/*` bewaken?

**Waar dit uit komt.** De ronde-3 bevinding van `mypage-query-blocks` was een
blocker: de commit op die patchbranch had `Claude <noreply@anthropic.com>` als
committer. Die is op 2026-09-09 opgelost (nieuwe tip `3fc86ca5b`, boom
byte-identiek). Bij het rood drijven van de controle bleek iets dat de
bevinding zelf niet zag: **na K-15 dekt nog steeds geen enkele gate deze
eigenschap op de negen patchbranches.**

- `check-patch-clean.sh` leest het patch*bestand*, en `git format-patch` zet
  alleen de auteur in dat bestand, niet de committer. Structureel blind.
- `check-geoxyz-branch.sh` kreeg in K-15 wél de identiteitscontrole, maar
  **kan niet op een patchbranch gericht worden**: het rekent "eigen commits"
  als `origin/7.0-stable..ref`, en dat is voor een trunkbranch duizenden
  commits. `REF=patch/<slug>` levert dus onzin, geen controle.
- `session-push.sh` controleert het wél en weigert zo'n push sinds K-13 — maar
  alleen bij een gewone push. Deze reparatie moest force-pushen (een
  amend), en dat doet dat script principieel nooit, dus is de check met de
  hand gedraaid. Precies het pad waarlangs het één keer misging, is het pad dat
  ongedekt blijft.

**Waarom dit jouw keuze is en geen klasse A:** `tools/**` is framework en
wijzigt alleen als je erom vraagt. K-15 was dezelfde soort keuze.

**Opties, elk in één zin:**

- **A) Niets doen.** De negen branches zijn nu alle negen schoon, en het is
  eenmalig misgegaan; wie een patchbranch aanmaakt hoort de identiteit gewoon
  expliciet mee te geven.
- **B) `check-patch-clean.sh` de branchidentiteit laten lezen.** Dat script
  kent de branch al (het vergelijkt hem met het bestand voor check 5), dus het
  is een handvol regels: `git log --format='%an <%ae> / %cn <%ce>'` over
  `merge-base..branch` met hetzelfde nauwe patroon als in K-15, en falen als
  het raakt. Kost: één plek erbij die dezelfde regex onderhoudt.
- **C) Het patroon in één plek zetten en beide scripts eruit laten lezen.**
  Zelfde dekking als B, maar zonder de derde kopie van de regex; kost een
  extra bestand in `tools/` en dus iets meer bewegende delen.

**Aanbeveling: B.** De dekking is wat ontbreekt en die krijg je met B; C is
netter maar lost een probleem op dat er nog niet is (drie kopieën van een
regex die sinds K-15 niet veranderd is), en dat is optimaliseren zonder
aanleiding.

**Haast?** Nee. Alle negen patchbranches zijn op 2026-09-09 nagekeken en zijn
schoon in auteur én committer, dus er staat niets fout klaar om ingediend te
worden. De gate voorkomt de volgende keer, niet deze keer.

## Open — keuze voor Jan (toegevoegd 2026-09-09, ar-sessions)

### K-17 — de sessiedata staat als Marshal in de database; de reparatie logt iedereen één keer uit

**Waar dit uit komt.** De ronde-3 review van `ar-sessions` vond een echte
major: `activerecord-session_store` serialiseert standaard met **Marshal**, en
`config/application.rb` zette daar niets tegenover. Elke request deed dus
`Marshal.load` over de kolom `sessions.data`, en op die kolom staat geen
signature. Bij de cookiestore die Redmine hiervoor had, was dat onmogelijk: die
cookie was met `secret_key_base` gesigneerd en werd geweigerd vóórdat er iets
gedeserialiseerd werd.

**Waarom het erger is dan het lijkt, en waarom niet catastrofaal.** Wie in de
database kan schrijven, kan zichzelf ook gewoon beheerder maken via `users`. De
winst voor een aanvaller is dus niet "geen toegang → beheerder" maar
**"beheerder → shell"**: één `UPDATE sessions SET data = …` en de volgende
request voert zijn objectgraaf uit in het Redmine-proces. Het pad dat het echt
waard maakt: een SQL-injectie ergens in Redmine of een plugin die schrijven
toestaat maar geen commando's, is hiermee remote code execution. Daarvoor niet.

**Wat er nu staat** (gebouwd, groen, en met tests die rood staan op de oude
code): de serializer is JSON in plaats van Marshal. `Marshal.load` komt niet
meer in het requestpad voor. De optie `:hybrid` van de gem is **geen** oplossing
en is niet gebruikt: die valt terug op `Marshal.load` voor elke waarde die met
`BAh` begint, dus het gat blijft dan open.

**En dit is waarom het jouw keuze is.** JSON kan een rij die Marshal schreef
niet lezen. Elke bestaande sessie is na de deploy dus onleesbaar:

- **Iedereen die ingelogd is, wordt één keer uitgelogd.** Eenmalig, en daarna
  nooit meer.
- Om dat een schone uitlog te laten zijn in plaats van een 500-storm, is er een
  klein klasje `Redmine::SessionDataSerializer` bijgekomen: een onleesbare rij
  wordt een lege sessie in plaats van een uitzondering. Dat is precies wat de
  cookiestore doet met een cookie die hij niet kan verifiëren. **Zonder dat
  klasje** krijgt elke ingelogde gebruiker een 500 tot zijn rij weg is, en dat
  is nu getest: op de kale `:json`-variant gaf een Marshal-rij
  `JSON::ParserError` → 500, met het klasje een redirect naar `/login`.

**Opties, elk in één zin:**

- **A) Zo laten (gebouwd, aanbevolen).** JSON plus het klasje: `Marshal.load`
  weg uit het requestpad, en de bestaande sessies verdwijnen als een nette
  uitlog.
- **B) Alleen `:json`, zonder het klasje.** Eén regel minder code, maar dan is
  `bundle exec rake db:sessions:clear` vóór de eerste request **verplicht** en
  vergeten kost je een 500 voor elke ingelogde gebruiker.
- **C) Niets doen en bij Marshal blijven.** Geen uitlog, en het gat blijft; de
  reviewer noemt het terecht een verandering in soort ten opzichte van de
  cookiestore.

**Aanbeveling: A.** Het sluit het gat en de prijs is één uitlog, en met het
klasje kan die prijs niet per ongeluk een storing worden.

**Haast?** Nee, maar niet lang laten liggen: zolang C geldt, is elke
schrijfprimitief in de database een uitvoeringsprimitief. Er is niets aan
gebruikers te communiceren behalve "je moet één keer opnieuw inloggen na de
volgende deploy".

**Als je A of B kiest, hoort dit in de deploy-notitie:** draai
`bundle exec rake db:sessions:clear RAILS_ENV=production` bij de deploy. Bij A
is dat netheid (het ruimt dode rijen op); bij B is het verplicht.

## Beslist (Jan) — K-16 en K-17, 2026-09-09

- **K-16: `check-patch-clean.sh` gaat de commit-identiteit van de patchbranch
  bewaken. Optie B.**
  De ronde-3 blocker van `mypage-query-blocks` was een AI-committer op een
  patchbranch, en bij het repareren bleek dat geen enkele gate die eigenschap
  daar dekte: `git format-patch` zet alleen de auteur in het bestand, dus
  controle 3 van `check-patch-clean.sh` is er structureel blind voor, en
  `check-geoxyz-branch.sh` kan niet op een trunkbranch gericht worden omdat hij
  "eigen commits" als `origin/7.0-stable..ref` rekent. Zes dagen PASS op een
  branch die er wél een droeg.
  **Wat er gebeurd is:** `tools/check-patch-clean.sh` heeft een zesde controle,
  over `merge-base(origin/master, branch)..branch`, met hetzelfde nauwe patroon
  als in K-15 — alleen gereedschapsnamen, geen `\bai\b`, want dat vuurt op een
  medewerker die echt Ai heet. Bij een treffer noemt hij de commit en de exacte
  reparatie (amend plus `--force-with-lease`, en het patchbestand opnieuw
  exporteren).
  **Eerst rood gedreven, met echte data, zoals `docs/traps.md` voorschrijft:**
  een tijdelijke branch op de oude commit `6af3b35c4` geeft
  `FAIL  an AI identity in the author or committer of test-inv4-red (INV-4)` met
  de regel `committer=Claude <noreply@anthropic.com>` eronder — en pal daarboven
  staat `ok  no AI trace in the header or the commit message`, dus het gat is in
  één uitvoer te zien. Daarna groen op alle negen patchbranches. En de guard is
  ook gedreven: met het patroon leeggemaakt aborteert het script met exit 2 in
  plaats van `ok` te melden.
  **Waarom optie B en niet C:** C zette het patroon in één gedeeld bestand. Dat
  is netter, maar het lost een probleem op dat er niet is — het patroon staat nu
  op twee plaatsen en is sinds K-15 niet veranderd — en het kost een extra
  bewegend deel in `tools/`.
  Doorgevoerd in `tools/check-patch-clean.sh`; `CLAUDE.md` (INV-4 en G6) en
  `docs/STATE.md` verwijzen ernaar.

- **K-17 `ar-sessions`: de sessiedata wordt JSON, met het klasje erbij. Optie A.**
  De standaardserializer van `activerecord-session_store` is Marshal, dus elke
  request deed `Marshal.load` over `sessions.data` — een kolom zonder signature.
  Bij de cookiestore die Redmine hiervoor had kon dat niet: die payload was met
  `secret_key_base` gesigneerd en werd geweigerd vóórdat er iets
  gedeserialiseerd werd. Het verschil is niet toegang maar bereik: een
  schrijfmogelijkheid ergens in de database werd een uitvoeringsmogelijkheid in
  het Redmine-proces.
  **Wat er staat:** JSON, plus `Redmine::SessionDataSerializer` — de
  JSON-serializer van de gem met één verschil, namelijk dat een rij die niet te
  parsen is een lege sessie wordt in plaats van een uitzondering. Dat verschil
  is niet cosmetisch: op de kale `:json` geeft elke bestaande Marshal-rij
  `JSON::ParserError` binnen de request, en dat is een **500** voor elke
  ingelogde gebruiker tot zijn rij verdwijnt. Gemeten, niet beredeneerd.
  **De prijs, en die is onvermijdelijk:** na de deploy is iedereen één keer
  uitgelogd. Daarna nooit meer.
  **Waarom niet B:** dan wordt `db:sessions:clear` bij de deploy verplicht in
  plaats van netjes, en één keer vergeten is een storing.
  **Waarom niet C:** zolang Marshal blijft, is elke schrijfprimitief in de
  database een uitvoeringsprimitief.
  Doorgevoerd op `7.0-stable-GEOxyz` in `22daa7c96`. Volledige suite daar:
  6145 runs, 0 failures, 0 errors. `db:sessions:clear` blijft in de
  deploy-notitie staan als opruimstap.

## Open — keuze voor Jan (toegevoegd 2026-09-09, search-token-limit)

### K-18 — moet de patch zelf een grens op het aantal filtertokens leggen, of niet?

**Waar dit uit komt.** De ronde-3 review van `search-token-limit` had geen
enkele bevinding over de code, maar wel één vraag, en die is van jou. De patch
haalt `.first 5` uit `Redmine::Search::Tokenizer#tokens` — dat is de fout die
hij repareert, want daardoor negeerde een tekstfilter alles na het vijfde woord.
Diezelfde tokenizer voedt `Query.tokenized_like_conditions`, dat één `LIKE` per
token bouwt. Dus na de patch zit er **geen enkele grens** meer op het aantal
`LIKE`-condities dat iemand via de URL kan laten bouwen.

**Wat het kost, gemeten (staat al in het dossier, PostgreSQL 16, 50 000
issues, filter `Subject`, operator `*~` tegen `~`):**

```
   1 token   0,054 s / 0,051 s
   5 tokens  0,184 s / 0,053 s
  50 tokens  0,554 s / 0,032 s
 200 tokens  2,233 s / 0,046 s
1000 tokens 10,930 s / 0,123 s
```

De scheve verdeling is echt en klopt: `~` en `!~` plakken met `AND`, dus de
database geeft een rij op bij de eerste voorwaarde die faalt en de kosten
blijven vlak. `*~`, `^` en `$` plakken met `OR`, dus een rij die niet matcht
wordt tegen élke voorwaarde getest en de kosten zijn tokens × rijen. In een
requestregel van 8 KB passen ruwweg duizend tokens — de laatste regel van die
tabel — en iedereen die de issuelijst mag zien kan die versturen. Tegenover de
oude grens van vijf is dat ongeveer 60× meer databasewerk per request.

**Het tegengewicht, ook nagekeken:** `Principal.like` in
`app/models/principal.rb` bouwt al één `LIKE`-paar per token van `params[:q]`
zonder enige grens, en dat pad wordt bereikt via de autocompletes voor
watchers en leden. Onbegrensde tokenaantallen uit gebruikersinvoer zijn dus
niet nieuw in Redmine — ze zijn nieuw op *dit* pad.

**Opties, elk in één zin:**

- **A) Inzenden zoals hij is** en de meettabel in de note zetten, met het
  argument dat een grens op gebruikersinvoer thuishoort in
  `Query#validate_query_filters` — waar hij élke operator en élk filter dekt —
  en dus een aparte wijziging is.
- **B) De grens meteen aan deze patch toevoegen**, als een controle op de
  filterwaarde in `validate_query_filters`: die **weigert** de vraag in plaats
  van hem stil af te kappen, wat precies het bezwaar is dat het dossier tegen
  de oude tokenizer-grens maakt.
- **C) Alleen de `OR`-tak begrenzen** in `tokenized_like_conditions`, waar de
  kosten tokens × rijen zijn. Kleinste ingreep met het meeste effect, maar het
  kapt de vraag stil af — hetzelfde bezwaar als bij de oude grens, alleen op
  een andere plek.

**Aanbeveling: A.** Drie redenen. De patch gaat over de tokenizer, en B trekt
hem een methode in die deze feature verder niet nodig heeft (INV-1). B vraagt
bovendien om een getal, en dat is een tweede keuze voor jou. En het dossier
heeft al gelijk over *waar* de grens hoort: in de validatie, voor alle filters,
en dat is een betere wijziging als eigen issue dan als bijwagen hier.

**Maar het eerlijke risico bij A, en dat is niet nul:** 10,9 s databasewerk per
request, opvraagbaar door iedereen die de issuelijst mag zien, is precies iets
waar een committer op kan gaan staan vóórdat hij de patch aanneemt. Dat kost
één rondje. Wil je dat rondje niet, dan is **B** de juiste — niet C, want C
maakt dezelfde fout die deze patch juist repareert.

**Haast?** Nee, en er is niets stuk: `patch/search-token-limit` staat nu op A
(er is niets toegevoegd) en dat is ook de staat waarin hij ingediend kan
worden. De keuze gaat over of je het bezwaar vóór wil zijn of afwachten.

## Beslist (Jan) — K-18, 2026-09-09

- **K-18 `search-token-limit`: inzenden zoals hij is. Optie A.**
  De patch haalt de grens van vijf zoekwoorden uit de tokenizer — dat is de fout
  die hij repareert — en legt zelf geen nieuwe grens op het aantal filtertokens.
  De meettabel gaat mee in de note, met het argument dat een grens op
  gebruikersinvoer thuishoort in `Query#validate_query_filters`, waar hij élke
  operator en élk filter dekt en de vraag *weigert* in plaats van hem stil af te
  kappen — en dus een eigen issue is.
  **Wat dit betekent als een committer er toch op gaat staan:** dan is het
  antwoord optie B (de controle in de validatie, met een getal van Jan), niet
  optie C. C begrenst alleen de `OR`-tak van `tokenized_like_conditions` en kapt
  daarmee stil af, wat precies het defect is dat deze patch weghaalt.
  Er is niets aan de code veranderd; `patch/search-token-limit` stond al in de
  vorm die optie A inzendt.


## Open — keuze voor Jan (toegevoegd 2026-09-09, framework)

### K-19 — `origin/master` is een mirror die niemand bijwerkt, en de submit-gate meet daartegen

**Wat er aan de hand is.** `tools/check-patch-clean.sh --submit` beantwoordt de
vraag "applyt deze patch nog op de huidige trunk?" met een `git fetch origin
master` — en `origin` is `jcatrysse/redmine`, niet Redmine. In de branchtabel van
`CLAUDE.md` staat bij `origin/master` letterlijk "nobody" als schrijver, dus die
mirror wordt door niemand bijgewerkt. Vandaag stond hij op `bee32a926` van
**2026-09-03**, terwijl de echte trunk op `8de368193` van vandaag 07:47 staat:
**18 commits verschil**. De gate meldde voor alle negen patches "applies to a
pristine origin/master (r25037)" en dat was waar — alleen niet over de trunk waar
Jan ze op indient.

**Wat dat vandaag concreet kost.** Tegen de echte trunk gemeten applyen acht van
de negen nog schoon. Eén niet:

```
wiki-export-attachments   config/initializers/zeitwerk.rb: patch does not apply
```

Dat is precies de vorm van verval die INV-2 beschrijft — geen defect, wel stale —
maar de gate kon het niet zien. Drie van de negen raken een bestand dat die 18
commits ook aanraken: `revision-branches`
(`test/functional/issues_controller_test.rb`), `webhook-issue-closed`
(`app/models/issue.rb`) en `wiki-export-attachments`
(`config/initializers/zeitwerk.rb`).

**En twee van die 18 commits zijn inhoudelijk relevant, niet alleen mechanisch:**

- `9a74cdf20 Pin JSON gem to versions below 3.0 …(#44428)` — dat is exact de
  gem-fout uit `docs/traps.md` die de suitecijfers van `48 failures, 82 errors`
  veroorzaakte. Upstream heeft hem gepind, dus na een sync horen die cijfers
  terug te vallen naar de oude `27 failures, 2 errors`. Dat maakt het bewijs
  beter leesbaar, en het is een reden om te syncen vóór je hermeet.
- `a41077d2a Update Rubyzip to 3.6 (#44388)` — en `wiki-export-attachments`
  ís de ZIP-export. Die patch moet dus niet alleen opnieuw applyen, maar ook
  opnieuw *werken* op Rubyzip 3.6.

**Opties, elk in één zin:**

- **A) De mirror met de hand syncen vóór elke inzendronde**, en `CLAUDE.md`
  aanpassen zodat "refresh tegen trunk" begint met die sync.
- **B) De gate rechtstreeks tegen Redmine laten meten**, dus
  `check-patch-clean.sh` haalt `https://github.com/redmine/redmine.git master`
  op in plaats van `origin master` — dan kan de mirror niet meer stil verouderen.
- **C) Beide:** B voor de meting, en de mirror blijft bestaan als de basis
  waarvan patchbranches gemaakt worden, maar dan met een sync-stap die de gate
  afdwingt.

**Aanbeveling: C.** B alleen lost het meten op, maar `patch/<slug>` wordt volgens
CLAUDE.md van `origin/master` afgetakt — als de gate tegen echte trunk meet en de
branches van een oude mirror komen, dan meet je iets anders dan je bouwt. Met C
klopt beide, en de sync wordt afdwingbaar in plaats van een gewoonte.

**Haast?** Ja, in deze zin: dit blokkeert de inzending niet, maar het is de reden
dat één van de negen patches nú stale is zonder dat een gate het zei. Zolang dit
niet geregeld is, is "PASS — safe to submit" een uitspraak over de mirror en niet
over trunk.

## Feitencorrectie — de Marshal-regel van 2026-09-05 (2026-09-09)

Dit bestand is append-only, dus de oude regel blijft staan en wordt hier
gecorrigeerd in plaats van herschreven.

**Wat er hierboven staat, bij "Autonoom besloten — ar-sessions, ronde 2
(2026-09-05)":** *"De serializer blijft Marshal. `:json`/`:hybrid` zou
`session[:issue_query]` breken…"*

**Dat is achterhaald én de redenering was onjuist.** Achterhaald door **K-17**
(Jan, 2026-09-09, optie A): de serializer ís JSON. En de onderbouwing klopte
niet: het argument was dat `app/helpers/queries_helper.rb` de queryhash met
symboolsleutels bewaart en terugleest, en dat een JSON-rondgang stringsleutels
teruggeeft. `HashWithIndifferentAccess` converteert echter ook **geneste**
hashes, dus `session[session_key][:filters]` werkt na de rondgang gewoon. Er
staat nu een integratietest die de issuelijst zonder enige URL-parameter
opvraagt en filters, kolommen, groepering én sortering uit de sessierij
terugvindt. Er was dus niets te breken; de ruil die de regel beschreef bestond
niet.

**Waarom dit als losse correctie staat en niet als stille bewerking:** de
onafhankelijke Codex-review van 2026-09-09 vond (F02) dat deze regel in
`docs/features/ar-sessions/status.md` en `docs/features/ar-sessions/decisions.md`
nog stond terwijl de code al om was. Dat is een reëel defect in het
deployment-dossier: die "wat is al beslist"-secties zijn juist bedoeld om
gevolgd te worden, dus een achterhaalde regel daarin stuurt een latere
onderhoudswijziging terug naar Marshal. Beide plekken zijn nu doorgehaald met de
reden erbij; deze regel hierboven is de derde en laatste plek.

### Class A — autonoom, 2026-09-09 (Codex-ronde 2)

- **`origin/7.0-stable` ingemerged in `7.0-stable-GEOxyz` zonder eerst op Jans
  antwoord te wachten.** G8 meldde "5 commits achter" en ik had de merge aan Jan
  voorgelegd in plaats van hem te doen. Dat was de verkeerde keuze: CLAUDE.md
  schrijft de merge voor als gewoon onderhoud *vóór* featurewerk ("Do it before
  starting a feature, not after"), en de branch is niet klaar voor productie
  zolang het bewijs bij een tree hoort die niemand deployt. Uitgevoerd als
  `git merge origin/7.0-stable` (nooit rebase), commit `32659b6f7`, schone
  'ort'-merge over zes upstream-bestanden, daarna de volledige suite op de
  gemergde tree. Codex-ronde 2 `geoxyz-branch` F01 vroeg exact dit.
- **`tools/check-symmetry.sh` toegevoegd**, in antwoord op de gevraagde richting
  bij `geoxyz-branch` F02. Het is een framework-bestand en dus normaal alleen
  voor een sessie die Jan daarom vraagt; hier is het het gevraagde middel om een
  blocker te sluiten, niet een eigen initiatief. Drie ontwerpen zijn onderweg
  weggegooid omdat ze ruis geven in plaats van signaal: substring-vergelijking
  meldt een gewijzigde regel als "nog aanwezig", en tellen kan principieel niet
  omdat GEOxyz álle features tegelijk draagt. Wat overblijft is aanwezig aan de
  ene kant en afwezig aan de andere — precies het geval dat gebeurde. De grens
  staat in de header van het script zelf: een wijziging waarvan elke regel al
  elders in het bestand voorkomt, ziet hij niet.
- **`undo` van de LDAP-taak weigert een rapportagejournaal, ook zonder
  `apply=1`.** Codex-ronde 2 `ldap-mail-prefs` F01 stelde voor alleen de
  *applied* undo te weigeren. Ook rapporteren wordt geweigerd, omdat een
  "WOULD RESTORE"-lijst over een journaal dat niets geschreven heeft de
  operator vertelt dat er iets terug te nemen is terwijl dat niet zo is.

### Beslist (Jan) — K-19, 2026-09-09: optie A

**De keuze.** De mirror wordt met de hand gesynct vóór elke inzendronde, en
`CLAUDE.md` begint de "refresh tegen trunk"-stap met die sync. Niet B en niet C:
de gate blijft dus tegen `origin/master` meten en gaat *niet* zelf naar
redmine.org.

**Wat dat betekent voor een sessie.** Twee dingen, en het tweede is het hele
punt van deze keuze:

1. **Jan schrijft de mirror, jij nooit.** Geen push, geen merge, geen force naar
   `origin/master`. De branchtabel in `CLAUDE.md` zei tot vandaag "nobody" bij
   die branch, en dat is precies hoe hij achttien commits achter kon raken
   terwijl elke gate PASS meldde. Die regel staat nu goed.
2. **Het verschil meten mag en moet je wel** — het is alleen lezen, en het is de
   enige manier om te weten of een `--submit`-PASS iets over trunk zegt:
   `git fetch https://github.com/redmine/redmine.git master` en dan
   `git rev-list --count origin/master..FETCH_HEAD`. Is dat niet 0, dan meet je
   niet verder alsof het wel klopte: zeg in het sessierapport dat de gate over
   de mirror ging en hoe groot het gat is. De commando's staan in
   `docs/runbook.md`, inclusief de `--is-ancestor`-check die vooraf bewijst dat
   Jans sync een fast-forward is en niets weggooit.

**Wat A niet oplost, en waarom dat aanvaard is.** Onder A kan de mirror opnieuw
stil verouderen — niets dwingt de sync af, en dat is exact het verschil met C.
De prijs is dus dat de gate blijft afhangen van een menselijke stap. Wat het
wel wint: `patch/<slug>` wordt volgens `CLAUDE.md` van `origin/master` afgetakt,
en onder A meet de gate hetzelfde ref waarvan de branches gemaakt zijn. Onder B
zou de gate tegen echte trunk meten terwijl de branches van een oude mirror
komen, en dan meet je iets anders dan je bouwt. A houdt die twee gelijk en legt
de sync bij de enige persoon die de mirror mag schrijven. Dit is Jans keuze en
geen afwijking, dus er hoort geen blok in `docs/exceptions.md` bij.

**Stand op het moment van beslissen.** De mirror staat op `8de368193`, gelijk
aan echte trunk (`git rev-list --count origin/master..FETCH_HEAD` = 0), want Jan
heeft eerder vandaag gesynct. Alle negen patches zijn tegen die stand met
`--submit` gemeten.

### K-20 — moet `--submit` zelf bij redmine.org kijken hoe ver de mirror achterloopt?

**Beslist door Jan op 2026-09-10: optie B.**

**Wat er aan de hand is.** K-19 optie A legt het syncen van `origin/master` bij
Jan en verbiedt elke sessie die branch te schrijven. Dat staat, en dit verandert
er niets aan. Wat het wel oplost is de andere helft van hetzelfde probleem: de
gate kón het verschil niet zien. `tools/check-patch-clean.sh --submit` meldde op
2026-09-09 voor alle negen patches "applies to a pristine origin/master" terwijl
de mirror zes dagen en achttien commits achterliep, en één patch tegen echte
trunk niet meer applyde. De uitkomst was waar over de mirror en fout over de
trunk waarop Jan indient, en niets in de uitvoer zei welke van de twee je las.

**De keuze die voorlag.**

- **A) laten zoals het is.** Jan synct met de hand, en de lezer van een PASS moet
  zelf weten dat hij `git fetch https://github.com/redmine/redmine.git master`
  moet draaien om te weten of die PASS iets betekent. Dat is precies wat er op
  2026-09-09 misging: niemand wist dat hij het moest vragen.
- **B) de gate haalt zelf echte trunk op en weigert als het gat niet nul is.**

**Wat B wel en niet verandert.** Niet: wie de mirror schrijft. De fetch is alleen
lezen, hij gaat naar `FETCH_HEAD` en raakt `origin/master` niet aan, en
`patch/<slug>` blijft van `origin/master` afgetakt — de eigenschap waar K-19 A
op steunde blijft dus intact. Wel: een `--submit`-PASS is voortaan
onvoorwaardelijk een uitspraak over echte trunk. Loopt de mirror achter, dan
faalt `--submit` met het gat erbij en met de sync-commando's uit
`docs/runbook.md`, in plaats van een PASS af te geven die de lezer zelf had
moeten wantrouwen.

**Waarom dit K-19 niet heropent.** K-19 ging over *wie de mirror bijwerkt*; deze
gaat over *wat de gate mag beweren als dat niet gebeurd is*. Onder A van K-19 kon
de mirror stil verouderen — dat werd toen expliciet als de prijs aanvaard. B van
K-20 laat het verouderen toe maar maakt het luid: de gate weigert dan te
oordelen in plaats van iets anders te meten dan ze zegt.

**Wat een sessie hiervan merkt.** Zonder net (`--submit` niet meegegeven) blijft
alles zoals het was: geen netwerkeis, hoogstens een `note`. Met `--submit` is een
netwerkfout naar github.com voortaan een blokkade en geen waarschuwing, want een
`--submit` die de vraag niet kón stellen mag hem niet met ja beantwoorden. Dat is
dezelfde regel als bij de ontbrekende RuboCop (ronde 4, `tools` F02): een gate die
niet kon meten, is geen gate die geslaagd is.

### K-21 — vijf commits op de productiebranch stonden in geen enkel `status.md`

**Beslist door Jan op 2026-09-10: optie A** — aanvullen én de gate de andere
kant op laten kijken.

**Wat er aan de hand was.** `check-geoxyz-branch.sh` check 3b vraagt: bestaat
elke sha die het register noemt ook echt op `7.0-stable-GEOxyz`? Dat is de helft
van G8's eis "own commits match the register". De andere helft — staat elke
commit op de branch ook ergens in het register? — vroeg niemand. Gevolg: vijf
commits stonden op de branch die GEOxyz draait zonder dat één `status.md` ze
noemde, en het register las als compleet. Het waren telkens de **eerste** commit
van een feature, de oorspronkelijke implementatie:

| commit | datum | feature |
|---|---|---|
| `c077d96df` | 2026-09-02 | `wiki-export-attachments` |
| `7d85538f3` | 2026-09-03 | `webhook-issue-closed` |
| `8612a76f4` | 2026-09-03 | `ar-sessions` |
| `2ac1de3c6` | 2026-09-03 | `ldap-mail-prefs` |
| `1fd3343ff` | 2026-09-05 | `wiki-export-attachments` |

Gevonden bij het bouwen van de omgekeerde richting van `check-symmetry.sh`
(ronde 4, `tools` F04): een eerdere versie daarvan schreef elke niet-genoteerde
commit toe aan de feature waarvan ze een bestand raakte, en dat gaf in één run
**45 valse fouten** — omdat `7d85538f3` `test/unit/webhook_test.rb` deelt met
`webhook-tracker-filter`. De valse fouten waren het symptoom; dit was de oorzaak.

**Wat eronder zat, en het is erger dan een ontbrekend veld.** De vier
`status.md`-bestanden beschreven die eerste commits wél in hun tekst, maar met
shas van **vóór de K-13-herschrijving van 2026-09-06**: `add935736`,
`95bbb9750`, `827e9e7d5`, `28c618860`, `7006c4f00`. Die objecten bestaan alleen
nog op `archive/7.0-stable-GEOxyz-identities-before-20260906`. In een verse
clone geeft `git show` daarop `fatal: bad object` — precies het stille verval dat
de opmerking bij check 3b beschrijft, maar dan in de lopende tekst in plaats van
in het front matter, waar geen enkele gate keek. Alle tien verwijzingen zijn
omgezet naar de levende sha, geverifieerd tegen die archiefbranch op onderwerp
én datum, niet geraden.

**Wat er nu staat.** 46 genoteerde sha's, 46 eigen non-merge commits, en de gate
bevestigt beide richtingen. Merges zijn vrijgesteld: een upstream-merge hoort bij
geen enkele feature. De nieuwe check is rood gedraaid door `8612a76f4` weer uit
`ar-sessions/status.md` te halen — `FAIL own commit(s) on
origin/7.0-stable-GEOxyz that no status.md records as a geoxyz_commit`, exit 1 —
en daarna groen.

**Wat dit niet oplost.** Er staan nog meer niet-oplosbare sha's in de dossiers,
maar dat zijn er twee soorten en alleen de eerste is een fout: verwijzingen naar
`5.1-stable-GEOxyz` en naar ansifi's PR #1 horen daar en zijn hier alleen
onvindbaar omdat die branches niet opgehaald zijn. Wat overblijft zijn
`f434bff64` en `8121846be` in `wiki-export-attachments`, allebei over de
*patch*branch en niet over GEOxyz. Die zijn niet aangeraakt: een patchbranch mag
herschreven worden en heeft zijn eigen archief, dus daar geldt een ander verhaal.
Waard om na te kijken door de sessie die die feature bezit.

**Wie dit schreef.** Een frameworksessie, met `FRAMEWORK_CHANGE=1`, omdat de
wijziging vier `status.md`-bestanden van vier verschillende features raakt en
`tools/claim.sh` er maar één tegelijk kan afdekken. Jan heeft er expliciet om
gevraagd.


### K-22 — mogen de bevindingen van ronde 4 blijven liggen tot alle onderdelen gereviewd zijn?

**Beslist door Jan op 2026-09-10: ja, eerst alles reviewen, daarna in één ronde
fixen.**

**Wat er aan de hand is.** `docs/STATE.md` zei tot vandaag onvoorwaardelijk
"fixen gaat voor nieuw reviewen": zodra `tools/findings.sh --open` niet leeg is,
is dát het werk. Die regel komt uit ronde 2, waar 127 bevindingen van één ronde
open stonden en het risico was dat ze zouden verjaren. In ronde 4 werkt hij
averechts: de eerste twee onderdelen (`tools`, `wiki-export-attachments`)
leverden samen acht openstaande bevindingen op waarvan nul blockers en nul
majors op de feature, en een fixsessie ertussen kost telkens een claim en een
verificatieronde.

**De keuze die voorlag.**

- **A) laten zoals het is** — na elk bevindingenbestand eerst fixen, dan pas het
  volgende onderdeel reviewen.
- **B) eerst alle onderdelen reviewen, daarna in één ronde fixen.**

**Waarom B.** Drie redenen, in volgorde van gewicht. Een reviewsessie raakt geen
code en schrijft één bestand met een unieke naam, dus reviews kunnen elkaar
structureel niet in de weg zitten; fixen wel, dat claimt een feature. De
bevindingen herhalen zich over features heen — bij `wiki-export-attachments`
waren twee van de drie minors van het type "het dossier belooft iets dat niet
klopt" en "de vertaling is niet na te rekenen zoals beschreven" — en zoiets wil
je één keer samen beslissen in plaats van veertien keer los. En er is geen
haast: er staat nog geen enkele patch op redmine.org, dus een minor die een paar
dagen wacht kost niets.

**De uitzondering, en die is hard.** Een **blocker of een major** wordt wél
meteen gefixt. Reden: de volgende reviewsessie leest de gefixte staat, en een
blocker die blijft staan vervuilt elk oordeel daarna. Dat is precies wat er bij
het onderdeel `tools` gebeurde — twee blockers zaten in de gates zelf, en een
gate die PASS meldt over iets wat ze niet meet, is het eerste waar de volgende
sessie naar wijst in plaats van zelf te lezen.

**Wat dit niet verandert.** Geen enkele bevinding blijft uiteindelijk op `open`
zonder `Resolution:`-regel. K-22 stelt het fixen uit, het schrapt het niet, en
"geen tijd gehad" blijft een geldige reden waar stilte dat niet is.

**Reikwijdte.** Alleen ronde 4. Daarna geldt de oude regel weer, tenzij Jan dan
iets anders zegt.


### K-23 — PKCE in de OAuth-toestemmingsstap van `imap-oauth`?

**Beslist door Jan op 2026-09-10: optie A** — geen PKCE inbouwen, wél het
antwoord in de bezwarentabel zetten.

**Wat er aan de hand is.** `rake redmine:email:oauth2_authorize` draait de
authorization code grant met een `state` en zonder `code_challenge`. RFC 9700,
de OAuth 2.0 Security Best Current Practice van 2025, schrijft PKCE voor bij
elke authorization code grant, ook voor een vertrouwelijke client. Het woord
PKCE staat nergens in de patch, het dossier, `status.md` of dit bestand.
Gevonden in ronde 4 (`imap-oauth` F02); vier eerdere reviewrondes, waaronder
twee van Codex, hebben er niet naar gekeken — terwijl Codex wél de ontbrekende
`state` vond, wat de andere helft van dezelfde vraag is.

**De keuze die voorlag.**

- **A) niet inbouwen, wel beantwoorden** — één rij in "Anticipated objections"
  die uitlegt waarom PKCE hier weinig toevoegt.
- **B) inbouwen** — ongeveer tien regels: een `code_verifier` uit
  `SecureRandom`, de S256-`code_challenge` op de autorisatie-URL, en de
  verifier bij het inwisselen, meegedragen zoals de `state` nu.

**Waarom A.** PKCE beschermt tegen het onderscheppen van de authorization code
tussen de redirect en het inwisselen. Dat pad bestaat in deze flow niet: de
code verlaat de browser en de terminal van de mailboxeigenaar niet, er luistert
niets op de loopback-adres dat een lokaal proces zou kunnen aftroeven, en de
client is vertrouwelijk — een onderschepte code is zonder het client secret
onbruikbaar. Daar komt bij dat de patch al groot is voor een eerste inzending
en INV-6 de nulhypothese "niet nodig" hanteert.

**Wat A wel verplicht.** Het argument hierboven moet in de inzending staan, niet
in het hoofd van een reviewer. De kerncommitter aan wiens issue (#43023) dit
hangt zal de vraag stellen, en dan komt het antwoord als losse note in plaats
van als onderdeel van de patch — dat kost een ronde. De rij hoort dus in
`docs/features/imap-oauth/dossier.md` onder "Anticipated objections", en wordt
geschreven in de fixronde van ronde 4 (K-22), niet nu.

**Wat dit niet is.** Geen uitspraak dat PKCE overbodig is in het algemeen. Als
Redmine ooit een OAuth-flow krijgt waar de redirect wél door een luisterend
proces of een webserver wordt opgevangen, geldt deze redenering daar niet.
