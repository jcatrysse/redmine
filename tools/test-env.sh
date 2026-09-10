#!/usr/bin/env bash
# Make Redmine's system tests actually runnable here, then exec the rest.
#
#   tools/test-env.sh <worktree> bundle exec ruby bin/rails test:all
#
# Without this, `test:all` reports ~260 errors that have nothing to do with the
# patch: `driven_by :selenium, using: :chrome` needs a chrome binary on PATH and
# a chromedriver whose major version matches it. This image has Playwright's
# Chromium (no `chrome` in PATH) and a chromedriver several majors ahead, so
# every system test dies in setup — and a full-suite run that is 260 errors deep
# proves nothing (INV-8).
#
# Fix: expose Playwright's Chromium as `google-chrome`, and take the mismatched
# chromedriver off PATH so Selenium Manager fetches the matching one.

set -uo pipefail

CHROME=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)
if [ -z "$CHROME" ]; then
  # Refusing, not warning. The header above says a run that is 260 errors deep
  # proves nothing under INV-8, and then it used to let exactly that run happen
  # — and its counts get written into a dossier as evidence (round 4, tools
  # F11). Set SYSTEM_TESTS_MAY_ERROR=1 to run anyway, and then do not quote the
  # numbers.
  echo "FAIL  no Playwright Chromium under /opt/pw-browsers — every system test would error in setup," >&2
  echo "      and those counts are not suite evidence (INV-8)." >&2
  [ "${SYSTEM_TESTS_MAY_ERROR:-0}" = 1 ] || exit 2
  echo "note  SYSTEM_TESTS_MAY_ERROR=1 — continuing; the system-test errors are environmental" >&2
else
  ln -sf "$CHROME" /usr/local/bin/google-chrome
  ln -sf "$CHROME" /usr/local/bin/chrome
fi

# Drop the directory holding the mismatched chromedriver.
export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v '/opt/node22/bin' | paste -sd:)"

export RAILS_ENV="${RAILS_ENV:-test}"
export GOOGLE_CHROME_OPTS_ARGS="${GOOGLE_CHROME_OPTS_ARGS:---headless=new,--no-sandbox,--disable-dev-shm-usage}"

WORKTREE="${1:?usage: tools/test-env.sh <worktree> <command...>}"
shift
cd "$WORKTREE" || exit 2
exec "$@"
