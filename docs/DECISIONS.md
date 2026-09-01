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
| 2026-09-01 | Het dossier vraagt **wanneer** een GEOxyz-commit kan vervallen, niet of | Redmine backportt geen features naar een stable branch; een geaccepteerde patch komt in 7.1 of later. De commit blijft dus nodig tot GEOxyz die release haalt. |

## Open — keuze voor Jan

### K-01 — Mag de AI-attributie in de commits van een patchbranch staan?

- **Waar het over gaat:** de sessie-omgeving vraagt sinds 2026-09-01 om
  `Co-Authored-By: Claude Opus 5` plus een sessielink onderaan elk commit-bericht
  dat ik maak. Op deze framework-branch is dat prima: het is jouw interne
  geheugen en het is eerlijk. Maar een patchbestand voor redmine.org wordt
  gemaakt met `git format-patch`, en dat neemt het **commit-bericht mee**. Dan
  staat die attributie in wat jij onder je eigen naam indient.
- **Waarom het botst:** INV-4 verbiedt AI-sporen in alles wat een patch bereikt,
  en `tools/check-patch-clean.sh` weigert zo'n patch actief. Dat is dus geen
  toeval maar een regel die we samen hebben gezet.
- **Opties:**
  - **A) Framework-branch wél, patchbranches niet.** De attributie staat in je
    interne historie; de patch is schoon. INV-4 en de wachter blijven zoals ze
    zijn.
  - **B) Overal wel.** Volledig transparant, ook op redmine.org. Dan moeten
    INV-4 en de wachter aangepast worden, en jij dient in met die regels erin.
  - **C) Overal niet.** Ook geen attributie op de framework-branch.
- **Aanbeveling: A.** Het is niet verbergen — jij bent de indiener en de patch is
  jouw werk om te verantwoorden; de herkomst staat volledig in je eigen repo
  vastgelegd. En de Contribute-pagina van Redmine vraagt niets over herkomst
  (nagekeken, zie `docs/redmine-requirements.md`), dus er is geen verplichting
  die de andere kant op wijst.
- **Haast?** Nee — er is nog geen patchbranch. We bouwden verder met A: deze
  framework-commit draagt de attributie, de wachter blijft patches weigeren die
  hem bevatten. Blokkeert niets, maar beslis het vóór de eerste patch.
