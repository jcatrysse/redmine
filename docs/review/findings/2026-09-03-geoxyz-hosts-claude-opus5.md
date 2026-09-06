# Review run — 2026-09-03 — geoxyz-hosts — Claude Code (Opus 5)

- **Reviewer:** Claude Code (Opus 5)
- **Reviewed:** `7.0-stable-GEOxyz` commit `fe737441b` ("Allow development requests to the geoxyz.eu subdomains"), parent `e2c0447b6`. GEOxyz-only — no `patch/geoxyz-hosts` branch exists and none is intended (`upstream: nooit`). Judged as production/ops risk, not as an upstream submission.
- **Dossier read:** `docs/features/geoxyz-hosts/dossier.md` — no such file (deliberate: GEOxyz-only, recorded in `status.md`). `docs/features/geoxyz-hosts/decisions.md` — yes.
- **Status read:** `docs/features/geoxyz-hosts/status.md` (the "already settled" section) — yes.
- **Ran the test suite:** no. `config/environments/development.rb` is not loaded under `RAILS_ENV=test`, so no suite exercises this line; the same reason `status.md` gives. Instead I drove Rails' real `ActionDispatch::HostAuthorization::Permissions` (actionpack 8.1.3.1, the version this branch pins) over 54 host strings — that is the code path that decides 403 vs 200, so it is a stronger check than a suite run would have been.
- **Scope covered:** correctness of the regexp (exact matched set, case, newline/CR injection, port suffix, trailing-dot FQDN, apex, near-miss domains), security (whether the DNS-rebinding protection `config.hosts` provides is re-opened), environment scoping (does it leak into test/production), minimality (INV-1), conventions of the touched file, AI traces (INV-4), RuboCop.
- **Scope NOT covered:** no live browser/curl run against a dev server — `status.md` already records one and my regexp-level probe reproduces its table exactly, so I did not repeat it. I did not check Puma's or a reverse proxy's own Host-header parsing, which sits in front of this middleware and may reject some of the odd strings in F02 before Rails ever sees them; my matched set is therefore an upper bound on what reaches the app. I did not review the rest of the branch.

## Summary

This is a two-line, development-only change and it is essentially correct. The
one thing that could have gone badly wrong here — a pattern that matches
attacker-controlled domains and so re-opens the DNS-rebinding protection
`config.hosts` exists to provide — did not go wrong. I enumerated the matched
set against the real Rails middleware: every host that passes must end in the
literal, lowercase `.geoxyz.eu`, optionally followed by `:` and digits. So
`evil-geoxyz.eu`, `geoxyz.eu.attacker.com`, `notgeoxyz.eu` and the apex
`geoxyz.eu` are all still refused, and a newline cannot be smuggled in. The
settled note in `status.md` about Rails anchoring the regexp itself is accurate
— I re-derived it from the actionpack source and confirmed the anchored form is
`/\A(?-mix:.*\.geoxyz\.eu)(?-mix::\d+)?\z/`.

The scoping is also right: the line exists in exactly one file, and
`config.hosts` is initialised to `[]` outside development, where the middleware
short-circuits entirely. Nothing leaks into test or production.

Two real but small defects remain. First, the pattern is case-**sensitive**
where every other entry Rails builds for you is case-insensitive, so
`Host: redmine.GEOXYZ.eu` gets a 403 — HTTP host names are case-insensitive, so
this is a behaviour bug, not a preference (F01). Second, `.*` accepts any
non-newline byte in the prefix, so strings like `attacker.com/.geoxyz.eu` also
match; I could not turn that into an actual attack, because none of those
strings is a resolvable DNS name and Rails' own development default already
allows *every* IPv4 and IPv6 literal host, so I have filed it as an
informational nit rather than a security finding (F02). Neither is a reason to
hold this back from production.

**Counts:** blocker 0 · major 0 · minor 1 · nit 2 · question 0

**Lines in the diff not strictly required by the feature:** 0 — the diff is one
statement plus one blank separator line, matching the spacing of every other
stanza in the file.

---

### F01 — The regexp is case-sensitive, so an uppercase `Host` header is refused

- **Status:** fixed
- **Severity:** minor
- **Confidence:** confirmed
- **Category:** correctness
- **Where:** `config/environments/development.rb:63`
- **Invariant touched:** none

**What is wrong**

`ActionDispatch::HostAuthorization::Permissions#sanitize_regexp` wraps the
regexp as `/\A#{host}#{PORT_REGEX}?\z/` and adds **no** flags; interpolating a
`Regexp` into a literal carries the original object's options through as
`(?-mix:…)`, so the result is case-sensitive. Its sibling
`sanitize_string` — the code path Rails uses for the `".geoxyz.eu"` string form
— explicitly ends in `/i`. Nothing in `HostAuthorization#call` or
`blocked_hosts` downcases the header first: it reads `HTTP_HOST` raw. So the
literal `geoxyz` and `eu` in this pattern must arrive in lowercase or the
request is blocked. HTTP host names are case-insensitive (RFC 9110 / RFC 3986),
so refusing on case is wrong regardless of how the header was produced.

**Why a committer would push back / why this would bite GEOxyz**

`curl -H "Host: redmine.GEOXYZ.eu" http://127.0.0.1:3000/login` returns 403 with
Rails' "Blocked hosts" debug page, while the identical request with
`redmine.geoxyz.eu` returns 200. Browsers normalise the authority to lowercase,
so a developer typing the URL will not hit it; the people who will are anyone
scripting against the dev instance with `curl`/`wget`/an HTTP library, a health
check, or a proxy that passes through what it was configured with. The failure
mode is a confusing 403 on a host that *is* in the allowlist, and the debug page
prints the blocked host looking correct, so it costs someone real time before
they notice the capital letters.

Note the asymmetry this creates, which is what makes it a bug rather than a
policy: `REDMINE.geoxyz.eu` **is** accepted (the `.*` prefix is unconstrained)
while `redmine.GEOXYZ.eu` is not.

**How I verified it**

Read `actionpack-8.1.3.1/lib/action_dispatch/middleware/host_authorization.rb`
(`sanitize_regexp` vs `sanitize_string`, and `blocked_hosts`), then ran the real
`Permissions` object over the cases:

```
HOST                          regexp form   string form (".geoxyz.eu")
"redmine.geoxyz.eu"           true          true
"REDMINE.geoxyz.eu"           true          true
"redmine.GEOXYZ.eu"           false         true
"redmine.Geoxyz.EU"           false         true
"redmine.geoxyz.EU"           false         true
```

The anchored pattern Rails actually stores, printed from the same source:
`/\A(?-mix:.*\.geoxyz\.eu)(?-mix::\d+)?\z/`.

**Suggested direction**

Whatever pattern is chosen has to carry its own case-insensitivity, because
`sanitize_regexp` will not add it. Do **not** reach for the string form
`".geoxyz.eu"` to get `/i` for free: `sanitize_string` builds
`/\A(?:[a-z0-9-]+\.)?geoxyz\.eu(?::\d+)?\z/i`, which allows the apex
`geoxyz.eu` and only *one* subdomain label, so `a.b.geoxyz.eu` would stop
working — exactly the trade-off `status.md` already warns about. This is the
same conclusion from the opposite direction: the settled decision to keep a
regexp is right, it just needs the flag.

**Resolution:** fixed, 2026-09-06, together with F02 in one line.
`config/environments/development.rb:63` now reads
`config.hosts << /[a-z0-9-]+(?:\.[a-z0-9-]+)*\.geoxyz\.eu/i`. The `/i` is on
the pattern itself, as this finding requires — `sanitize_regexp` does not add
it, and the string form was not used, for the reason the finding gives (it
allows the apex and only one subdomain level). Measured against the real
`ActionDispatch::HostAuthorization::Permissions` and against a running dev
server: the five case variants of `redmine.geoxyz.eu` that this finding lists
went from two passing / three blocked to five passing, and no host that was
refused before is accepted now. The anchored form Rails stores is
`/\A(?i-mx:[a-z0-9-]+(?:\.[a-z0-9-]+)*\.geoxyz\.eu)(?-mix::\d+)?\z/`.
The measured table is in `docs/features/geoxyz-hosts/status.md`.

---

### F02 — The matched set is wider than "hostnames", but not in a way that re-opens DNS rebinding

- **Status:** fixed
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** security
- **Where:** `config/environments/development.rb:63`
- **Invariant touched:** none

**What is wrong**

`.*` matches any run of characters except a newline, so the prefix is
unconstrained — not restricted to DNS label characters. The exact set of hosts
this entry admits, against the anchored form
`/\A(?-mix:.*\.geoxyz\.eu)(?-mix::\d+)?\z/`, is:

> every string of the form **P + `.geoxyz.eu` + S**, where **P** is any sequence
> of zero or more characters that contains no `\n`, the literal `.geoxyz.eu` is
> exactly that lowercase byte sequence, and **S** is either empty or `:`
> followed by one or more ASCII digits.

Concretely that means these are **admitted** beyond the intended subdomains:
`.geoxyz.eu` and `..geoxyz.eu` (empty/dot-only label),
`attacker.com/.geoxyz.eu`, `attacker.com@.geoxyz.eu`,
`attacker.com#.geoxyz.eu`, `attacker.com:8080.geoxyz.eu`,
`attacker.com\r.geoxyz.eu`, `%00.geoxyz.eu`, `_.geoxyz.eu`, `*.geoxyz.eu`,
`[.geoxyz.eu`, and forms containing spaces or tabs.

And these are **refused**, which is the part that matters:
`geoxyz.eu` (apex), `geoxyz.eu:3000`, `evil-geoxyz.eu`, `evilgeoxyz.eu`,
`notgeoxyz.eu`, `geoxyz.eux`, `geoxyz.eu.attacker.com`,
`geoxyz.eu.attacker.com:3000`, `redmine.geoxyz.eu.` (trailing-dot FQDN),
`attacker.com\n.geoxyz.eu`, `redmine.geoxyz.eu\n`,
`redmine.geoxyz.eu\nevil.com`, `redmine.geoxyz.eu:` (no digits),
`redmine.geoxyz.eu:abc`, `redmine.xn--geoxyz-abc.eu`, and the Cyrillic-`е`
homograph `redmine.gеoxyz.eu`.

**Why a committer would push back / why this would bite GEOxyz**

It would not, and I want to be explicit about that rather than inflate it. I
tried to build the failure sentence and could not: DNS rebinding needs a
hostname that *resolves* to the dev machine and is then echoed in the `Host`
header, and every string above ends in the literal `.geoxyz.eu`, which only
someone controlling `geoxyz.eu` DNS can make resolve. None of the junk-prefixed
strings is a registrable or resolvable name, so the only way to present one is
to hand-craft the header — which requires already being able to reach the dev
server directly, and at that point Rails' own development default
(`ALLOWED_HOSTS_IN_DEVELOPMENT` = `.localhost`, `.test`, `IPAddr 0.0.0.0/0`,
`IPAddr ::/0`) already lets you through with `Host: 10.0.0.5`. I confirmed that:
`127.0.0.1`, `1.2.3.4` and `localhost` pass with or without this line. So the
marginal exposure this line adds is zero against a threat model that Rails'
default already declines to defend in development.

The residual, honest concern is not security but drift: `.*` documents "we did
not think about the shape of the prefix", and if this pattern is ever
copy-pasted into `production.rb` — where `config.hosts` is `[]` and the
middleware is therefore the only host check — the loose prefix stops being
harmless. That is a reason to tighten it while it is cheap, not a reason to
block.

**How I verified it**

Ran Rails' real `Permissions` over 54 host strings in four configurations
(regexp alone, string form alone, development defaults alone, development
defaults plus this regexp) and read the middleware source for how `HTTP_HOST`
and the last `X-Forwarded-Host` are checked. The refusals above are measured,
not reasoned: the newline cases fail because `.` does not cross `\n` and Rails
anchors with `\z` (not `\Z`), so no trailing-newline or header-injection variant
slips through. My probe reproduces every row of the table in
`status.md` including `geoxyz.eu.attacker.com` → 403.

**Suggested direction**

If it is tightened at all, the goal is "one or more DNS labels, then
`.geoxyz.eu`", case-insensitively, and it must still admit multi-level
subdomains such as `a.b.geoxyz.eu` (the point of choosing a regexp over the
string form) while still refusing the apex. Any replacement should be re-run
through `ActionDispatch::HostAuthorization::Permissions#allows?` — not eyeballed
— because `sanitize_regexp` changes the pattern before it is used. Leaving it as
it stands is a defensible call for a development-only file; if it is left, the
matched set above is worth pasting into `status.md` so nobody has to re-derive
it.

**Resolution:** fixed, 2026-09-06, in the same line as F01. The prefix is no
longer `.*` but one or more DNS labels: `[a-z0-9-]+(?:\.[a-z0-9-]+)*`. All
thirteen junk-prefixed strings this finding lists (`.geoxyz.eu`,
`..geoxyz.eu`, `attacker.com/.geoxyz.eu`, `attacker.com@.geoxyz.eu`,
`attacker.com#.geoxyz.eu`, `attacker.com:8080.geoxyz.eu`,
`attacker.com\r.geoxyz.eu`, `%00.geoxyz.eu`, `_.geoxyz.eu`, `*.geoxyz.eu`,
`[.geoxyz.eu`, and the space and tab forms) are now refused, measured — not
reasoned — through `Permissions#allows?` as the finding asks, and four of them
also against a running server over a raw socket. Multi-level subdomains
(`a.b.geoxyz.eu`, `a.b.c.geoxyz.eu`) still pass and the apex `geoxyz.eu` is
still refused, so the trade-off the finding warns about was not taken. Worth
noting because it settles the "is this the right shape" question: Rails' own
blocked-host page states the rule as "make sure they are valid hostnames
(containing only numbers, letters, dashes and dots)", which is exactly the
matched set now. The finding was filed as a nit and the fix was taken because
the line had to be touched for F01 anyway, so the drift argument (a
copy-paste into `production.rb`) is closed for free rather than left standing.

---

### F03 — The line lives in an upstream-tracked file, so it is a standing merge-conflict candidate

- **Status:** wontfix
- **Severity:** nit
- **Confidence:** confirmed
- **Category:** conventions
- **Where:** `config/environments/development.rb:63`
- **Invariant touched:** none

**What is wrong**

`config/environments/development.rb` is a Redmine-tracked file that upstream
does edit (it is largely regenerated Rails boilerplate). CLAUDE.md requires
`7.0-stable-GEOxyz` to merge `origin/7.0-stable` regularly, and this feature is
a one-commit, permanent private divergence with no upstream counterpart ever
(`upstream: nooit`). Every such merge therefore carries a small chance of a
conflict in a file whose contents GEOxyz does not otherwise care about.

**Why this would bite GEOxyz**

Low probability, real cost when it lands: the conflict would surface in the
middle of a 7.0.x maintenance merge, which is exactly the merge someone wants to
apply quickly. The added statement sits between a commented-out
`config.action_cable` line and the `config.after_initialize` block, so git will
merge cleanly unless upstream touches within a few lines of either — plausible
on a Rails minor upgrade, unlikely on a Redmine patch release. This is a nit,
not a defect.

**How I verified it**

`git grep -n 'config\.hosts\|host_authorization\|geoxyz'` over `config lib app
test` on `fe737441b` returns exactly one hit, `config/environments/development.rb:63`
— so the change is correctly confined to development and there is nothing else
to keep in sync. Read `Rails::Application::Configuration#initialize`
(railties 8.1.3.1, lines 39-44): `@hosts` is the development allowlist only when
`Rails.env.development?`, otherwise `[]`, and `HostAuthorization#call` returns
`@app.call(env)` immediately when the permission list is empty — so test and
production are genuinely unaffected. RuboCop on the changed file:
`1 file inspected, no offenses detected` (matches the 0/baseline-0 claim in
`status.md`). No `Co-authored-by`, no session link, no generated-by marker, no
comment restating the code — INV-3 and INV-4 clean.

**Suggested direction**

Two options, and the second has a trap worth naming before anyone reaches for
it. Leaving it where it is, is fine — it is one line and the conflict risk is
small. The alternative is Redmine's own untracked hook,
`config/additional_environment.rb`, which is already in `.gitignore` (line 9)
and is `instance_eval`'d inside the `Rails::Application` class body from
`config/application.rb:110-111`, so `config.hosts <<` works there and the branch
would carry zero diff. **The trap:** that file is loaded in *every* environment,
and `config.hosts` is empty in production — appending there would make the list
non-empty and so switch `HostAuthorization` **on** in production with only
`*.geoxyz.eu` permitted, breaking every other production hostname. It would need
an explicit `Rails.env.development?` guard, and it would move the setting out of
version control, which is a downgrade for reproducibility. `RAILS_DEVELOPMENT_HOSTS`
is a third option Rails 8 reads, but it goes through `sanitize_string`, so it
buys only one subdomain level and loses `a.b.geoxyz.eu`. Whoever picks should
know all three before choosing.

**Resolution:** not fixed, deliberate, 2026-09-06 — the line stays in
`config/environments/development.rb`. This follows the finding's own first
option: it is one line, the conflict risk is small, and both alternatives are
worse. `config/additional_environment.rb` is loaded in *every* environment, so
appending there would make `config.hosts` non-empty in production and switch
`HostAuthorization` on with only `*.geoxyz.eu` permitted — it would need an
explicit `Rails.env.development?` guard and it would move the setting out of
version control. `RAILS_DEVELOPMENT_HOSTS` goes through `sanitize_string`, so
it buys one subdomain level and loses `a.b.geoxyz.eu`, which is the trade-off
F01 and the feature's own decision record already refuse. Recorded as a Class A
decision in `docs/features/geoxyz-hosts/decisions.md` so the next merge conflict
in that file is resolved by keeping the line, not by re-opening the question.
