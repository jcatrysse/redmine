<!-- Copy to docs/features/<slug>.md. Do not commit changes to this template.
     The English sections below are the redmine.org issue text — write them so
     they can be pasted as-is. The Dutch block at the top is for Jan. -->

# <slug> — <feature in één regel>

## Voor Jan (Nederlands)

- **Wat het doet, in gewone taal:** <twee zinnen>
- **Waar het vandaan komt:** 5.1-commit `<sha>`, port-commit `<sha>` (indien van toepassing)
- **Doel:** upstream + GEOxyz / alleen GEOxyz
- **Afwijking GEOxyz ↔ upstream:** geen / <welke, waarom, en dat het dus een permanente eigen patch blijft>
- **Kans dat Redmine dit aanneemt:** goed / redelijk / twijfelachtig — <één regel waarom>
- **Wat jij nog moet doen:** <issue aanmaken / live test / een keuze maken>

## Trunk check (G1)

- **Trunk-revisie nagekeken:** `<sha>` van `<datum>` (mirror-datum, en of die achterliep)
- **Lost trunk dit al op?** nee / deels / ja — <wat je gelezen hebt en waar>
- **Bestaand issue op redmine.org?** <nummer + status, of "niets gevonden, gezocht op: <termen>">
- **Verandert iets in trunk het ontwerp?** <bijv. een refactor van de laag die je raakt>

---

# The problem

<Two or three paragraphs, in Redmine's terms, not GEOxyz's. What can a Redmine
administrator or user not do today, and what do they do instead? Name the
concrete limitation — a hardcoded constant, a missing filter value, a feature
that only covers part of its own domain.>

# Why this belongs in core

<Why a plugin cannot reasonably do this: it patches a private method, it
changes a query the core builds, it needs a setting on a core screen. If a
plugin *could* do it cleanly, say so honestly — that weakens the case and the
reviewer will spot it anyway.>

# Proposed change

<What the patch does, at the level of behaviour first and code second. Name
every file it touches and why.>

| File | Change |
|---|---|
| `` | |

**New setting / migration / gem / route / permission:** none
<or: name it, and justify it — INV-6's null hypothesis is that it is not
needed. Say which existing settings tab it belongs on and why.>

**Translations** (INV-5 — every row names the existing key it was patterned on):

| Key | en | nl | fr | de | es | Patterned on |
|---|---|---|---|---|---|---|
| `` | | | | | | `` |

**Backward compatibility:** <what happens to existing installations, existing
data, existing configuration. An empty list that used to mean "all" must keep
meaning "all".>

# Alternatives considered

<One short paragraph per rejected alternative, with the reason. This is the
section that stops a reviewer re-proposing something you already thought
about. If the GEOxyz implementation differs from what is proposed here, it
belongs in this section as a rejected alternative.>

# Tests

| Test | What it proves |
|---|---|
| `` | |

**Evidence (INV-8 — figures, not claims):**

- suites run: `<command>` → `<n> runs, <n> assertions, <n> failures, <n> errors`
- RuboCop on changed files: `<n>` offences (baseline at merge base: `<n>`)
- each new test verified red on the old code: <how you know>
- patch applies to pristine `origin/master` r`<rev>`: yes / no
- `tools/check-patch-clean.sh`: PASS / FAIL

# Anticipated objections

| Objection | Answer |
|---|---|
| | |

<Be honest here. An objection you cannot answer is a reason to reshape the
patch before submitting it, not to leave the row empty.>

---

## Submission

- **Issue:** <redmine.org number + link, once Jan has created it>
- **Patches attached:** `patches/<slug>/<date>-r<rev>-feature.patch` (code + `en.yml`) and `-locales.patch` (`nl`, `fr`, `de`, `es`) — or one combined file, if that was the choice
- **Made against:** `origin/master` r`<rev>` (`<date>`)
- **Status:** ingediend / feedback ontvangen / geaccepteerd / afgewezen
- **Feedback en wat ermee gebeurde:** <chronologisch, kort>

## GEOxyz

- **Commit op `7.0-stable-GEOxyz`:** `<sha>`
- **Suites daar groen:** `<figures>`
- **`nl.yml` toegevoegd:** ja / nee
- **Kan dit vervallen als de patch landt?** ja, één-op-één / nee, want <reden>
