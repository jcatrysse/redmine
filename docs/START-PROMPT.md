# Startprompts voor een nieuwe sessie

De omgeving start de sessie **niet** op de framework-branch, en je checkout kan
verouderd zijn. Daarom begint elke prompt met de checkout.

Sessies mogen parallel lopen, elk op een eigen feature. Wat dat veilig maakt
staat in `docs/STATE.md` onder "Parallel werken"; de sessie regelt het zelf met
`tools/claim.sh`.

## Standaard — volgende feature uit het register

```
Dit is de GEOxyz Redmine upstream-opdracht.

Ga eerst naar de framework-branch:
  git fetch origin geoxyz/framework && git checkout geoxyz/framework
  git merge --ff-only origin/geoxyz/framework

Lees dan CLAUDE.md en docs/STATE.md, en doe verder.
```

## Met een feature erbij — dit is wat je gebruikt voor parallelle sessies

```
Dit is de GEOxyz Redmine upstream-opdracht.

Ga eerst naar de framework-branch:
  git fetch origin geoxyz/framework && git checkout geoxyz/framework
  git merge --ff-only origin/geoxyz/framework

Lees dan CLAUDE.md en docs/STATE.md.

Feature deze sessie: <slug>
Doel: beide (upstream-patch + GEOxyz).
```

Start twee of drie van deze naast elkaar, elk met een andere `<slug>`. Slugs
staan in `docs/REGISTER.md`. Laat "Doel" weg tenzij het afwijkt — beide is de
norm.

Je hoeft de sessies niets over elkaar te vertellen: de eerste handeling van elk
is `tools/claim.sh <slug>`, en twee sessies die per ongeluk dezelfde slug
krijgen lossen dat zelf op — één van de twee stapt terug en zegt het in zijn
rapport.

## Voor een review in plaats van bouwen

```
Dit is de GEOxyz Redmine upstream-opdracht.

Ga eerst naar de framework-branch:
  git fetch origin geoxyz/framework && git checkout geoxyz/framework
  git merge --ff-only origin/geoxyz/framework

Lees CLAUDE.md, dan de skill patch-review, en review patch/<slug>.
Schrijf de bevindingen naar docs/review/findings/.
```

Doe dit in een **nieuwe** sessie, niet in de sessie die de patch bouwde: wie de
fix al geschreven heeft, stopt met zoeken naar redenen waarom hij fout is. Dit
is de combinatie waar parallel lopen het meeste oplevert: bouwen en reviewen
tegelijk, en een reviewsessie schrijft maar één bestand dus hij botst nergens.

## Voor het verwerken van bevindingen

```
Dit is de GEOxyz Redmine upstream-opdracht.

Ga eerst naar de framework-branch:
  git fetch origin geoxyz/framework && git checkout geoxyz/framework
  git merge --ff-only origin/geoxyz/framework

Lees CLAUDE.md en docs/review/findings/<bestand>. Verwerk elke open bevinding:
fix hem, of vul een Resolution-regel in met waarom niet.
```

## Voor een wijziging aan het framework zelf

```
Dit is de GEOxyz Redmine upstream-opdracht.

Ga eerst naar de framework-branch:
  git fetch origin geoxyz/framework && git checkout geoxyz/framework
  git merge --ff-only origin/geoxyz/framework

Lees CLAUDE.md en docs/STATE.md. Framework-wijziging: <wat>.
```

Alleen zo'n sessie mag `CLAUDE.md`, `docs/STATE.md`, `docs/runbook.md`,
`tools/**` en `.claude/**` aanraken, en dan liefst niet naast een bouwsessie —
die leest die bestanden terwijl je ze verandert.
