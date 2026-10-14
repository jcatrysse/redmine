#!/usr/bin/env bash
# Upgrade rehearsal of the webhook and settings migrations, on a real
# `bin/rails db:migrate`:
#
#   rehearse.sh <7.0-stable-GEOxyz worktree> <database url> [--without]
#
# Builds the database up to 20250611092227 (the last 7.0 migration before the
# webhook tables), seeds the 5.1-stable-GEOxyz state with seed51.rb, migrates
# the rest and prints what verify.rb finds. --without moves the three
# GEOxyz upgrade migrations aside first, which reproduces F1.
set -uo pipefail
WT=${1:?worktree}; export DATABASE_URL=${2:?database url}; WITHOUT=${3:-}
HERE=$(cd "$(dirname "$0")" && pwd)
export RAILS_ENV=test
cd "$WT" || exit 2
MIG="db/migrate/20251007073255_set_aside_geoxyz51_webhooks.rb db/migrate/20260903081501_restore_geoxyz51_webhooks.rb db/migrate/20261014120000_copy_geoxyz51_settings.rb"
STASH=$(mktemp -d)
restore() { for f in $MIG; do [ -f "$STASH/$(basename "$f")" ] && mv "$STASH/$(basename "$f")" "$f"; done; rm -f db/schema.rb; }
trap restore EXIT
rm -f db/schema.rb
bundle exec ruby bin/rails db:drop db:create >/dev/null 2>&1 || exit 2
bundle exec ruby bin/rails db:migrate VERSION=20250611092227 >/dev/null || exit 2
bundle exec ruby bin/rails runner "$HERE/seed51.rb" || exit 2
if [ "$WITHOUT" = --without ]; then for f in $MIG; do mv "$f" "$STASH/"; done; fi
bundle exec ruby bin/rails db:migrate 2>&1 | grep -iE '^==|error|search_token_limit|not copied|aborted' | grep -vE 'migrated|^== *$'
echo "db:migrate exit ${PIPESTATUS[0]}"
[ "$WITHOUT" = --without ] && exit 0
bundle exec ruby bin/rails runner "$HERE/verify.rb"
