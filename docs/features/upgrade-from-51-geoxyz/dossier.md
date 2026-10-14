# upgrade-from-51-geoxyz — dossier

**Local-only, nooit upstream.** Dit lost een probleem op dat alleen bestaat op
een database die op `5.1-stable-GEOxyz` heeft gedraaid: eigen migraties en
eigen instellingsnamen die 7.0 onder andere namen of in een andere vorm
heeft. Upstream heeft die database nooit gezien. Er is geen patch, geen
issue en geen trunk-check (G1 is n.v.t.: trunk kent de 5.1-GEOxyz-migraties
niet). Alles wat er te weten valt staat in `status.md`, de afwegingen in
`decisions.md`, de repetitie in `rehearsal/`.

**Kan weg:** nooit vanzelf. De drie migraties blijven nodig zolang er nog een
database bestaat die rechtstreeks van 5.1-stable-GEOxyz komt. Zijn alle
GEOxyz-omgevingen (productie, test, kopieën) eenmaal over op 7.0, dan doen ze
niets meer, maar ze moeten blijven staan zodat `schema_migrations` klopt.
