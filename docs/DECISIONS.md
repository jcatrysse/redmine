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
| 2026-09-01 | AI-attributie (`Co-Authored-By`, `Claude-Session`) staat **wel** in commits van `geoxyz/framework`, **nooit** in commits van een `patch/<slug>`-branch of `7.0-stable-GEOxyz` (K-01, optie A) | Jan: "optie a". Jij bent de indiener en de patch is jouw werk om te verantwoorden; de herkomst staat volledig in je eigen repo. Redmine's Contribute-pagina vraagt niets over herkomst. INV-4 en `tools/check-patch-clean.sh` blijven dus ongewijzigd afdwingen, en de wachter kijkt nu ook op de `Claude-Session`-trailer. |

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
| 2026-09-01 | `tools/dev-server.sh` wijst elke worktree naar **één** map voor bijlagen (`/tmp/redmine-dev-files`) | De dev-database is gedeeld tussen worktrees, `files/` niet. Een bijlage die je uploadt terwijl worktree A draait, is onleesbaar vanuit worktree B en verdwijnt stil uit alles wat `Attachment#readable?` controleert. Dit kostte precies één valse "de feature werkt niet" tijdens G9 — het bewijs dat G9 zijn geld waard is. |
| 2026-09-01 | Het dossier vraagt **wanneer** een GEOxyz-commit kan vervallen, niet of | Redmine backportt geen features naar een stable branch; een geaccepteerde patch komt in 7.1 of later. De commit blijft dus nodig tot GEOxyz die release haalt. |

## Open — keuze voor Jan

### K-02 — indeling van het ZIP-archief met bijlagen

- **Keuze:** hoe ziet het archief eruit als je de bijlagen meestuurt?
- **Opties:**
  - **A) Plat (nu gebouwd).** De paginabestanden blijven exact waar ze nu
    staan, en elke pagina met bijlagen krijgt er een map naast:
    `Child_one.txt` plus `Child_one/diagram.txt`.
  - **B) Genest naar de wikiboom.** `Wiki/Wiki.txt`,
    `Wiki/Child_one/Child_one.txt`, met de bijlagen naast hun eigen
    paginabestand. Dan klopt de mappenstructuur met de wiki, én een
    afbeeldingsverwijzing als `!diagram.png!` werkt gewoon als je de map in
    een markdown-editor opent, omdat het bestand ernaast staat.
- **Aanbeveling:** A voor de patch, B als apart voorstel later. B verandert de
  indeling van een export die vier maanden geleden in 7.0.0 is uitgekomen, en
  verandert die ook voor mensen die helemaal geen bijlagen willen. Dat maakt
  het een aparte discussie, geen onderdeel van deze.
- **Haast?** nee — we bouwden verder met A, en A en B sluiten elkaar niet uit.

### K-03 — de TXT-export van de hele wiki

- **Keuze:** dienen we de tweede helft van de 5.1-commit (één samengevoegd
  `.txt`-bestand van de hele wiki) ook in bij Redmine, of alleen op GEOxyz?
- **Opties:**
  - **A) Ook indienen**, als eigen issue.
  - **B) Alleen op GEOxyz** houden.
- **Aanbeveling:** A, maar met lage verwachting. Sinds april 2026 heeft trunk
  de ZIP-export die per pagina een `.txt` geeft; een reviewer zal vragen wat
  één samengevoegd bestand daar nog aan toevoegt. Het antwoord "je plakt het
  in één keer in een AI-tool of grept erdoorheen" is echt, maar dun.
- **Haast?** nee — het staat als eigen regel `wiki-export-txt` in het register
  en komt aan de beurt na deze feature.

### Gesloten

- **K-01** — AI-attributie in patchcommits. Beslist 2026-09-01: optie A (zie "Beslist (Jan)").
