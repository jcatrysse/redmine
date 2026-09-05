# gitignore-credentials — Class A-beslissingen

- **Beslist (autonoom, 2026-09-03):** alleen `/config/credentials.yml.enc` en
  `/config/master.key` zijn overgenomen. De 5.1-commit voegde er een derde regel
  `/.github/` aan toe; die is **weggelaten**. Die map bevat de CI van de
  repository zelf (`.github/workflows/linters.yml`, `.github/workflows/tests.yml`,
  `.github/actions/setup-redmine/action.yml`) en negeren betekent dat een nieuw of
  gewijzigd workflowbestand onzichtbaar wordt in `git status`. Dat heeft niets met
  credentials te maken (INV-1) en is bovendien schadelijk.
- **Beslist (autonoom, 2026-09-03):** de twee regels staan alfabetisch in het
  bestaande `/config/`-blok, niet onderaan het bestand zoals in 5.1. Het blok is
  al alfabetisch en zo blijft het dat.
- **Beslist (autonoom, 2026-09-05, binnen Jans keuze g11):** de derde regel is
  de **map** `/config/credentials/` en niet een glob per bestandstype. Reden: de
  map dekt zowel `<env>.key` als `<env>.yml.enc` in één regel, hij blijft
  kloppen voor een omgevingsnaam die nog niemand bedacht heeft, en hij past in
  de alfabetische `/config/`-rij (`credentials.yml.enc` < `credentials/`, want
  `.` sorteert voor `/`). Gemeten: alle zes de paden die er in kunnen liggen
  worden gepakt, en geen enkel gevolgd bestand raakt erdoor verstopt.
- **Beslist (autonoom, 2026-09-05):** Rails' eigen ignore-blok is **niet**
  overgenomen om F02 te sluiten. Het onderdrukken van Rails' automatische
  aanvulling vereist het hele blok letterlijk, commentaarregel incluis
  (`File.read(".gitignore").include?(ignore)` in
  `EncryptionKeyFileGenerator#ensure_key_files_are_ignored_silently`) — een kale
  `/config/*.key` is niet genoeg. Dat is uitgeprobeerd op railties 8.1.3.1:
  kale regel → Rails plakt zijn blok er alsnog achter; het hele blok → Rails
  laat het bestand met rust. De prijs (vier regels ruis, en de `.enc`-bestanden
  blijven ongedekt) weegt niet op tegen een eenmalige `git checkout --
  .gitignore`, die nu in `status.md` staat.
