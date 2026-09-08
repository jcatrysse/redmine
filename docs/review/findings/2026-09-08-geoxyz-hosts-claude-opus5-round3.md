# Review run — 2026-09-08 — claude-opus5-round3

- **Reviewer:** Claude Code (Opus), round-3 blind re-review
- **Reviewed:** the `geoxyz-hosts` change on `7.0-stable-GEOxyz`, commits
  `075c86e8a` and `363686456`. No patch branch, and there never will be —
  `upstream: nooit`.
- **Dossier read:** none exists, by design (a local-only item gets no dossier)
- **Status read:** `docs/features/geoxyz-hosts/status.md`, including "wat er al
  bekend is" — yes
- **Round-1 findings read:** **no, deliberately.**
  `docs/review/findings/2026-09-03-geoxyz-hosts-claude-opus5.md` was not opened.
  `status.md` refers to round-1 findings by number (F01, F02, F03) in its
  evidence tables, so the pass is blind to the round-1 reasoning but not to the
  fact that three findings existed and what two of them were about.
- **Ran the test suite:** **no.** The change is one line in
  `config/environments/development.rb`, a file that is not loaded under
  `RAILS_ENV=test`, so no suite can reach it. Instead I drove Rails' own
  decision code directly — see below.
- **Scope covered:** what the regexp actually permits and refuses (35 host
  strings through Rails' own `Permissions#allows?`), how Rails stores it,
  whether the alternatives the status file rejects really are worse, the
  placement of the line, whether anything else in the tree sets `config.hosts`,
  and the record of the change.
- **Scope NOT covered:**
  - **No browser and no running server.** The G9 screenshots and the raw-socket
    table in `status.md` were read, not reproduced. What I re-ran is the
    matching logic, which is the part that decides 403 or 200.
  - **Production.** The line is development-only and I did not check what the
    GEOxyz reverse proxy in front of production allows.

## Summary

Clean. I set out to find a hole in the regexp and instead reproduced the status
file's own table, host for host, including the two round-2 fixes it claims. The
one-line change is correctly scoped, sits in the only environment file that can
use it, and nothing else in the tree touches `config.hosts`.

The part worth saying out loud, because it is the part that looks wrong at a
glance: the regexp is **not** unanchored. Rails wraps whatever you put in
`config.hosts` as `/\A…(?::\d+)?\z/`, so `geoxyz.eu.attacker.com` is refused —
I confirmed the stored form is
`/\A(?i-mx:[a-z0-9-]+(?:\.[a-z0-9-]+)*\.geoxyz\.eu)(?-mix::\d+)?\z/`. Anyone
tempted to "harden" this to the string form `".geoxyz.eu"` should look at the
measurement first: the string form admits the **apex** `geoxyz.eu` and refuses
`a.b.geoxyz.eu`, which is strictly worse in both directions.

**Counts:** blocker 0 · major 0 · minor 0 · nit 0 · question 0

**Lines in the diff not strictly required by the feature:** 0. One line plus one
blank, in a file of one-line configuration settings.

## What I ran

Rails' `ActionDispatch::HostAuthorization::Permissions` from actionpack 8.1.3.1,
loaded directly, with three candidate host lists: the current regexp, the
pre-round-2 regexp, and the string form the status file says was rejected.
35 host strings, including the ones a browser will not send.

| host | current | pre-round-2 | string form |
|---|---|---|---|
| `redmine.geoxyz.eu` | **200** | 200 | 200 |
| `a.b.geoxyz.eu` | **200** | 200 | **403** |
| `a.b.c.geoxyz.eu` | **200** | 200 | **403** |
| `redmine.GEOXYZ.eu` | **200** | **403** | 200 |
| `redmine.Geoxyz.EU` | **200** | **403** | 200 |
| `geoxyz.eu` (apex) | 403 | 403 | **200** |
| `geoxyz.eu:3000` | 403 | 403 | **200** |
| `evil-geoxyz.eu` | 403 | 403 | 403 |
| `geoxyz.eu.attacker.com` | 403 | 403 | 403 |
| `attacker.com/.geoxyz.eu` | 403 | **200** | 403 |
| `attacker.com:8080.geoxyz.eu` | 403 | **200** | 403 |
| `_.geoxyz.eu` | 403 | **200** | 403 |
| `.geoxyz.eu` | 403 | **200** | 403 |
| `a..geoxyz.eu` | 403 | **200** | 403 |
| `%2e.geoxyz.eu` | 403 | **200** | 403 |
| `user@a.geoxyz.eu` | 403 | **200** | 403 |
| `" redmine.geoxyz.eu"` (leading space) | 403 | **200** | 403 |
| `redmine.geoxyz.eu\n`, `…\r\nX: 1` | 403 | 403 | 403 |
| `redmine.geoxyz.eu:3000` | 200 | 200 | 200 |
| `xn--gexyz-0ya.eu` (punycode homograph) | 403 | 403 | 403 |

The two round-2 fixes are visible in that table as the only columns that move:
case-insensitivity (five rows the old pattern refused) and the eight junk-prefix
forms the old `.*` admitted. Both claims in `status.md` hold as written.

**Hypotheses driven and cleared:**

| Hypothesis | Outcome |
|---|---|
| the regexp is unanchored and `geoxyz.eu.attacker.com` gets in | clean — Rails anchors it itself; the stored form is `/\A(?i-mx:…)(?-mix::\d+)?\z/` and that host is refused |
| the trailing-dot FQDN `redmine.geoxyz.eu.` is admitted, which would widen the surface | clean, and refused — and refused by Rails' own string form too, so the behaviour is consistent with core rather than a quirk of this pattern |
| a label of only hyphens (`-.geoxyz.eu`, `--.geoxyz.eu`) is admitted, and is not a valid hostname | admitted, and **not a finding**: the character class is character-for-character Rails' own `SUBDOMAIN_REGEX = /(?:[a-z0-9-]+\.)/i`, so this pattern is exactly as permissive as core's, and the host is still under `geoxyz.eu` either way |
| a port outside 1..65535 (`a.geoxyz.eu:65536`) is admitted | admitted, and upstream's — `PORT_REGEX = /(?::\d+)/` is Rails', appended after the pattern, so it is not this line's to fix (INV-1) |
| something else in the tree also sets `config.hosts` or `host_authorization`, so the two interact | clean — `grep -rn` over `config/ lib/ app/` returns this one line and nothing else |
| the line leaks into production or test | clean — it is in `config/environments/development.rb`, which is tracked (not ignored) and is not loaded under any other `RAILS_ENV` |
| the recorded commit shas are stale, as they are for ten other features | clean here, and `status.md` is the file that *documents* the K-13 rewrite — both `075c86e8a` and `363686456` are on the branch, with Jan as author and committer |

**No findings.** Reported as such rather than padded: the change is one line, it
does what it says, and the two things a reviewer would reach for first (the
apparent lack of an anchor, and the string form as a "safer" alternative) are
both answered by measurement in the file already.
