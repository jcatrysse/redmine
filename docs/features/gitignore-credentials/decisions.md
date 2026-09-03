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
