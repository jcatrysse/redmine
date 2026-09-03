# STATE — de index

> **Dit bestand wordt niet meer per sessie overschreven.** Dat was precies wat
> parallel werken onmogelijk maakte: twee sessies die elk hun eigen versie van
> "waar staan we" schreven, en de tweede push verloor het geheugen van de
> eerste. Het geheugen zit nu **per feature** in
> `docs/features/<slug>/status.md`, waar precies één sessie aan schrijft.
>
> Verander dit bestand alleen als Jan om een framework-wijziging vraagt.

## Begin hier, elke sessie

```sh
git fetch origin geoxyz/framework
git checkout geoxyz/framework && git merge --ff-only origin/geoxyz/framework
```

Doe dit **eerst**. De omgeving mint per sessie een eigen branch en je checkout
kan een oude commit zijn — dat is één keer gebeurd en die sessie begon aan een
feature die al af was.

Dan:

1. `cat docs/REGISTER.md` — alle achttien features, hun status, en wat er voor
   Jan openstaat.
2. Feature van Jan gekregen? Neem die. Anders de bovenste `todo`-regel.
3. **`tools/claim.sh <slug>`** — dit is verplicht, ook als je denkt dat je
   alleen werkt. Het is het enige dat voorkomt dat twee sessies dezelfde feature
   bouwen.
4. `cat docs/features/<slug>/status.md` — het geheugen van die feature: wat er
   al bekend is, en welke afwegingen je **niet** opnieuw hoort te maken.
5. `cat docs/traps.md` — wat er hier al een keer misging.
6. Bouwen: de skill `upstream-patch`. Reviewen: de skill `patch-review`.

## Waar alles staat, en wie eraan schrijft

Parallelle sessies lopen elkaar niet in de weg omdat ze **verschillende
bestanden** aanraken, niet omdat ze het onthouden. `tools/check-ownership.sh
<slug>` maakt dat mechanisch.

| Pad | Wat het is | Wie schrijft |
|---|---|---|
| `docs/features/<slug>/status.md` | het geheugen van één feature + de registerregels | de sessie die de slug claimde |
| `docs/features/<slug>/dossier.md` | de inzending, Engels vanaf "The problem" | idem |
| `docs/features/<slug>/decisions.md` | Class A-beslissingen van die feature | idem |
| `docs/features/<slug>/shots/` | het G9-bewijs | idem |
| `patches/<slug>/` | precies wat aan het issue hangt | idem |
| `verify/<slug>.mjs` | het G9-script | idem |
| `docs/claims/<slug>--<sessie>` | het slot, één bestand per sessie | `tools/claim.sh` |
| `docs/review/findings/<datum>-<slug>-<reviewer>.md` | één reviewronde | de reviewsessie |
| `docs/REGISTER.md` | **gegenereerd** uit alle `status.md` | `tools/register.sh --write` |
| `docs/traps.md` | gedeelde valkuilenlijst | iedereen, **alleen** via `tools/append-note.sh` |
| `docs/DECISIONS.md` | Jans beslissingen en open keuzes (K-nn) | iedereen, **alleen** via `tools/append-note.sh` |
| `docs/redmine-requirements.md` | wat Redmine echt eist, met bron | iedereen, **alleen** via `tools/append-note.sh` |
| `CLAUDE.md`, `docs/STATE.md`, `docs/runbook.md`, `tools/**`, `.claude/**` | het framework zelf | alleen een sessie die Jan daar expliciet om vroeg |

## De gereedschappen

| Tool | Waarvoor |
|---|---|
| `tools/claim.sh <slug>` | de feature claimen. `--list` toont wie wat heeft, `--release` geeft hem terug, `--force` neemt een dode claim over |
| `tools/session-push.sh [branch]` | pushen als er parallelle sessies zijn: fetch, jouw commits erbovenop, vier keer opnieuw proberen. Gebruik dit in plaats van `git push`, ook op `7.0-stable-GEOxyz` |
| `tools/append-note.sh <bestand>` | een blok toevoegen aan een gedeeld bestand zonder ooit te conflicteren (blok op stdin) |
| `tools/register.sh [--write]` | `docs/REGISTER.md` opnieuw opbouwen uit de statusbestanden |
| `tools/check-ownership.sh <slug>` | weigert een push die bestanden van iemand anders aanraakt |
| `tools/check-patch-clean.sh patch/<slug>` | G6 |
| `tools/check-geoxyz-branch.sh` | G8 |
| `tools/dev-server.sh`, `tools/dev-seed.rb`, `tools/verify-lib.mjs` | G9 |
| `tools/test-env.sh <worktree> <cmd>` | `test:all` bruikbaar maken (zonder dit ~260 systeemtestfouten) |

## Parallel werken — de vier regels

1. **Claim eerst.** `tools/claim.sh <slug>` pusht een bestand met jouw sessie-id
   in de naam. Twee sessies schrijven dus twee verschillende paden: de pushes
   conflicteren nooit, ze landen allebei, en daarna breken beide kanten de knoop
   op dezelfde manier door (vroegste datum, dan sessie-id). De verliezer trekt
   zijn claim in en neemt een andere regel.
2. **Schrijf alleen wat je bezit.** Zie de tabel hierboven, en laat
   `tools/check-ownership.sh <slug>` het controleren vóór elke push.
3. **Push met `tools/session-push.sh`.** Een gewone `git push` wordt geweigerd
   zodra iemand eerder was; deze speelt jouw commits erbovenop en probeert het
   opnieuw.
4. **Gedeelde bestanden alleen via `tools/append-note.sh`.** Die voegt jouw blok
   toe *nadat* hij binnengehaald heeft wat de ander toevoegde.

Wat dan nog kan conflicteren, en alleen dat: twee features die elk een sleutel
onder aan `config/locales/{nl,fr,de,es}.yml` zetten op `7.0-stable-GEOxyz`.
Oplossing is altijd **beide kanten houden**; er is niets te kiezen.
`tools/session-push.sh` zegt dat ook als het gebeurt.

## Wat er nog nooit gebeurd is

Er heeft nog geen sessie met een andere sessie tegelijk gelopen. Alles hierboven
is ontworpen en de tools zijn getest met een gesimuleerde tweede sessie, maar de
eerste echte parallelle run is nog niet gedaan. Als er iets misgaat, hoort dat
in `docs/traps.md`.

## Voorgeschiedenis, kort

Het framework begon 2026-09-01 na een volledige doorlichting van PR #1 (Ansifs
port van `5.1-stable-GEOxyz` naar 7.0). Wat daar uitkwam bepaalt waarom de
invarianten zijn zoals ze zijn:

- Negen functionele bevindingen, **alle negen uit de originele 5.1-commits**,
  ongemerkt meegereisd in de port. De porter toetste "werkt het nog" in plaats
  van "is dit goed".
- Twee bestaande Redmine-tests stonden rood op **beide** branches, nooit
  opgemerkt omdat de volledige suite nooit gedraaid was.
- De port introduceerde 73 RuboCop-fouten op een bestandsset die er 0 had.
- Er was **nul CI** gelopen op die PR, terwijl de repo `linters.yml` en
  `tests.yml` heeft.

Vandaar INV-8 (bewezen groen) en G1 (trunk-check) als harde regels — en vandaar
dat de trunk-check bij vier van de vijf afgeronde features beslissend bleek: er
bestond telkens al een issue, en één keer had een kerncommitter er zelf al aan
gewerkt.
