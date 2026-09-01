# verify/

One script per feature: `verify/<slug>.mjs`, built on `tools/verify-lib.mjs`.

    SHOT_DIR=docs/features/<slug>/shots PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers \
      node verify/<slug>.mjs

Run it twice per feature: once against the unpatched instance for the
`before-*.png` shots, once after. See G9 in CLAUDE.md and the traps in
docs/runbook.md.
