# STATE — de index

> **Dit bestand wordt niet meer per sessie overschreven.** Dat was precies wat
> parallel werken onmogelijk maakte: twee sessies die elk hun eigen versie van
> "waar staan we" schreven, en de tweede push verloor het geheugen van de
> eerste. Het geheugen zit nu **per feature** in
> `docs/features/<slug>/status.md`, waar precies één sessie aan schrijft.
>
> Verander dit bestand alleen als Jan om een framework-wijziging vraagt.

## Huidige fase — ronde 3, blinde herreview (sinds 2026-09-06)

**Lees dit voordat je `docs/REGISTER.md` opent.** Het werk gaat niet over nieuwe
features. Alle achttien staan in het register en negen patches zijn klaar; dat
is de *uitkomst van ronde 1* en geen todo-lijst meer. Er staat dus geen
`todo`-regel in het register, en dat betekent niet dat er niets te doen is.

Jan sprak op 2026-09-04 een cyclus van drie rondes af:

| Ronde | Wat | Waar het staat |
|---|---|---|
| 1, **af** | veertien onderdelen gereviewd, 129 bevindingen | `docs/review/findings/`, gebundeld in `docs/review/FINDINGS.md` |
| 2, **af** (2026-09-06) | elke bevinding een `Resolution:`-regel — 127 stuks, geen enkele blijven liggen | `tools/findings.sh --open` was de werklijst en is leeg gedraaid |
| 3, **nu** | blinde herreview: een verse sessie leest de gefixte patch koud, **zonder de bevindingen van ronde 1 eerst te lezen**, en pas daarna vergelijken we | `docs/review/findings/*-round3.md` |

**Hoever ronde 3 is, vraag je op — dat staat hier met opzet niet als getal**,
want een getal in dit bestand veroudert en dat is vandaag al drie keer misgegaan:

```sh
ls docs/review/findings/*round3*        # de onderdelen die al blind gedaan zijn
ls docs/review/findings/ | grep -v round3 | grep -v TEMPLATE   # de veertien uit ronde 1
```

Wat nog moet, is het verschil tussen die twee lijsten. Neem daaruit een onderdeel
dat je zelf nog niet gelezen hebt.

**Wat een ronde-3-sessie doet, en wat ze juist niet doet.** Lezen: de patch, het
dossier, `status.md` (inclusief "al bekend", zodat je niets heropent wat beslist
is) en `docs/DECISIONS.md`. **Niet** lezen: het ronde-1-bevindingenbestand van
diezelfde slug — dat is het hele punt van blind. Schrijven: één bestand,
`docs/review/findings/<datum>-<slug>-<reviewer>-round3.md`. De skill is
`patch-review`.

Een bevinding uit ronde 3 wordt daarna gefixt zoals in ronde 2: **geen enkele
bevinding blijft op `open` zonder `Resolution:`-regel.** "Geen tijd gehad" is een
geldige reden, stilte niet. Dat fixen is gewoon werk voor een volgende sessie,
met `tools/claim.sh` erbij als er code aan te pas komt.

Jans twintig keuzes uit ronde 1 staan in `docs/DECISIONS.md` onder **"Beslist
(Jan) — reviewronde 1, 2026-09-04"**, met een groepsnummer (g01..g18) per keuze,
en zijn latere keuzes eronder per datum. **Re-litigeer die niet**; ze zijn stuk
voor stuk aan hem voorgelegd.

## Begin hier, elke sessie

```sh
git fetch origin geoxyz/framework
git checkout geoxyz/framework && git merge --ff-only origin/geoxyz/framework
```

Doe dit **eerst**. De omgeving mint per sessie een eigen branch en je checkout
kan een oude commit zijn — dat is één keer gebeurd en die sessie begon aan een
feature die al af was.

Dan:

1. `tools/findings.sh --open` — bevindingen die nog geen `Resolution:`-regel
   hebben, uit welke ronde dan ook. **Staat daar werk, dan is dát je werk**:
   fixen gaat voor nieuw reviewen. Lees er `docs/DECISIONS.md` bij vanaf
   "Beslist (Jan) — reviewronde 1".
2. Is die lijst leeg, dan is het de blinde herreview van ronde 3 — zie "Huidige
   fase" hierboven voor de twee commando's die zeggen welke onderdelen al gedaan
   zijn en welke niet. Feature van Jan gekregen? Neem die.
3. **`tools/claim.sh <slug>`** — verplicht zodra je iets van een feature
   verandert, ook als je denkt dat je alleen werkt; het is het enige dat
   voorkomt dat twee sessies hetzelfde bouwen. **Een reviewsessie claimt juist
   niet**: die schrijft één bevindingenbestand en raakt de feature niet aan.
4. `cat docs/features/<slug>/status.md` — het geheugen van die feature: wat er
   al bekend is, en welke afwegingen je **niet** opnieuw hoort te maken.
5. `cat docs/traps.md` — wat er hier al een keer misging, en
   `cat docs/exceptions.md` — welke regels bewust overtreden zijn en waarom.
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
| `docs/review/FINDINGS.md` | **gegenereerd** uit alle bevindingenbestanden | `tools/findings.sh --write` |
| `docs/traps.md` | gedeelde valkuilenlijst | iedereen, **alleen** via `tools/append-note.sh` |
| `docs/DECISIONS.md` | Jans beslissingen en open keuzes (K-nn) | iedereen, **alleen** via `tools/append-note.sh` |
| `docs/redmine-requirements.md` | wat Redmine echt eist, met bron | iedereen, **alleen** via `tools/append-note.sh` |
| `docs/exceptions.md` | bewust overtreden regels, met de prijs erbij | iedereen, **alleen** via `tools/append-note.sh` |
| `CLAUDE.md`, `docs/STATE.md`, `docs/runbook.md`, `tools/**`, `.claude/**` | het framework zelf | alleen een sessie die Jan daar expliciet om vroeg |

## De gereedschappen

| Tool | Waarvoor |
|---|---|
| `tools/claim.sh <slug>` | de feature claimen. `--list` toont wie wat heeft, `--release` geeft hem terug, `--force` neemt een dode claim over |
| `tools/session-push.sh [branch]` | pushen als er parallelle sessies zijn: fetch, jouw commits erbovenop, vier keer opnieuw proberen. Gebruik dit in plaats van `git push`, ook op `7.0-stable-GEOxyz`. Sinds K-13 behoudt de replay de committer, en weigert hij een push naar `7.0-stable-GEOxyz` of `patch/*` met een AI-identiteit in het auteur- of committerveld |
| `tools/append-note.sh <bestand>` | een blok toevoegen aan een gedeeld bestand zonder ooit te conflicteren (blok op stdin) |
| `tools/register.sh [--write]` | `docs/REGISTER.md` opnieuw opbouwen uit de statusbestanden |
| `tools/findings.sh [--write] [--open]` | `docs/review/FINDINGS.md` opnieuw opbouwen uit de bevindingenbestanden; `--open` is de werklijst van wat nog geen `Resolution:`-regel heeft |
| `tools/check-ownership.sh <slug>` | weigert een push die bestanden van iemand anders aanraakt. De twee **gegenereerde** bestanden (`docs/REGISTER.md`, `docs/review/FINDINGS.md`) mag je wél meesturen, maar ze moeten vers gegenereerd zijn — een met de hand bewerkt gegenereerd bestand faalt |
| `tools/check-patch-clean.sh <slug>` | G6 — controleert het **patchbestand** en vergelijkt het met de branch; `--submit` maakt "applyt niet meer op trunk" fataal |
| `tools/check-geoxyz-branch.sh` | G8 — lint gemeten tegen de baseline op `origin/7.0-stable`, alleen wat de branch toevoegt telt |
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

## Bewijs dat dit werkt

Er heeft nog geen sessie met een echte andere sessie tegelijk gelopen — de
eerste parallelle run is nog niet gedaan. De machinerie is wel uitgeprobeerd,
met een tweede sessie erbij verzonnen (2026-09-03):

| Wat | Uitkomst |
|---|---|
| `tools/claim.sh <slug>` | PASS, claim staat op de branch |
| tweede sessie claimt dezelfde slug | stapt terug, exit 1, verwijdert zijn eigen claimbestand — de eerste houdt hem |
| `--list`, `--release`, `--force` | alle drie doen wat ze zeggen |
| `git push` met de remote één commit voor | geweigerd, non-fast-forward |
| `tools/session-push.sh` in dezelfde situatie | speelt de eigen commit erbovenop en pusht; **beide** commits blijven, historie blijft lineair |
| `tools/append-note.sh docs/traps.md` | PASS |
| `tools/append-note.sh` op een bestand van één feature | geweigerd, met de reden |
| `tools/check-ownership.sh` op een schone boom | PASS |
| idem met een regel in `CLAUDE.md` erbij | FAIL, noemt het bestand, exit 1 |
| `tools/register.sh --write` | achttien features, klopt met het oude register |

De race is getest met **twee losse clones** op dezelfde commit, niet met twee
commits in één clone — dat laatste reproduceert de race niet. Als er in een
echte parallelle run alsnog iets misgaat, hoort dat in `docs/traps.md`.

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
