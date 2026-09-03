# claims/

Het slot dat voorkomt dat twee parallelle sessies dezelfde feature bouwen. Eén
bestand per sessie:

    docs/claims/<slug>--<sessie-id>

Twee sessies die dezelfde slug claimen schrijven dus twee **verschillende**
paden. De pushes conflicteren daardoor nooit — ze landen allebei, en daarna
breken beide kanten de knoop op dezelfde manier: vroegste datum wint,
lexicografisch kleinste sessie-id bij gelijke datum. De verliezer verwijdert zijn
eigen bestand en neemt een andere regel uit `docs/REGISTER.md`.

Beheer dit niet met de hand. `tools/claim.sh <slug>` neemt, `--release` geeft
terug, `--list` toont wie wat heeft, `--force` neemt een claim over waarvan de
sessie niet meer bestaat.
