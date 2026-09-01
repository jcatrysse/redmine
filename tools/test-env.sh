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
if [ -n "$CHROME" ]; then
  ln -sf "$CHROME" /usr/local/bin/google-chrome
  ln -sf "$CHROME" /usr/local/bin/chrome
else
  echo "note  no Playwright Chromium found — system tests will error" >&2
fi

# Drop the directory holding the mismatched chromedriver.
export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v '/opt/node22/bin' | paste -sd:)"

export RAILS_ENV="${RAILS_ENV:-test}"
export GOOGLE_CHROME_OPTS_ARGS="${GOOGLE_CHROME_OPTS_ARGS:---headless=new,--no-sandbox,--disable-dev-shm-usage}"

WORKTREE="${1:?usage: tools/test-env.sh <worktree> <command...>}"
shift
cd "$WORKTREE" || exit 2
exec "$@"
