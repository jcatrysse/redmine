# Startprompt voor een nieuwe sessie

De omgeving start de sessie **niet** op de framework-branch. Daarom begint elke
prompt met de checkout.

## Standaard — volgende feature uit het register

```
Dit is de GEOxyz Redmine upstream-opdracht.

Ga eerst naar de framework-branch:
  git fetch origin geoxyz/framework && git checkout geoxyz/framework

Lees dan CLAUDE.md en docs/STATE.md, en doe verder.
```

## Met een feature erbij

```
Dit is de GEOxyz Redmine upstream-opdracht.

Ga eerst naar de framework-branch:
  git fetch origin geoxyz/framework && git checkout geoxyz/framework

Lees dan CLAUDE.md en docs/STATE.md.

Feature deze sessie: <slug>
Doel: beide (upstream-patch + GEOxyz).
```

Slugs staan in het register in `docs/STATE.md`. Laat "Doel" weg tenzij het
afwijkt — beide is de norm.

## Voor een review in plaats van bouwen

```
Dit is de GEOxyz Redmine upstream-opdracht.

Ga eerst naar de framework-branch:
  git fetch origin geoxyz/framework && git checkout geoxyz/framework

Lees CLAUDE.md, dan de skill patch-review, en review patch/<slug>.
Schrijf de bevindingen naar docs/review/findings/.
```

Doe dit in een **nieuwe** sessie, niet in de sessie die de patch bouwde: wie de
fix al geschreven heeft, stopt met zoeken naar redenen waarom hij fout is.

## Voor het verwerken van bevindingen

```
Dit is de GEOxyz Redmine upstream-opdracht.

Ga eerst naar de framework-branch:
  git fetch origin geoxyz/framework && git checkout geoxyz/framework

Lees CLAUDE.md en docs/review/findings/<bestand>. Verwerk elke open bevinding:
fix hem, of vul een Resolution-regel in met waarom niet.
```
