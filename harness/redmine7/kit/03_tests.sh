#!/bin/bash
# Each plugin's own suite with all GEOxyz plugins installed: minitest (test/**/*_test.rb without
# system/ and ui/, one process, as Redmine's rake task loads them) and rspec (spec/), RAILS_ENV=test.
# Logs per plugin in logs/test-<id>.log, one summary line per plugin in tests.tsv.
set -uo pipefail
H=${H:-/home/user/r70h}; R=$H/redmine; L=$H/logs; cd "$R"
export SHIM=/tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/r7/kit/shim_reporter.rb RAILS_ENV=test LANG=C.UTF-8 LC_ALL=C.UTF-8
touch "$H/tests.tsv"; sed -i "/^DONE$/d" "$H/tests.tsv"
ids=${IDS:-$(cut -f2 "$H/heads.tsv")}
for id in $ids; do
  grep -q "^$id	" "$H/tests.tsv" && continue
  pg_isready -q -h 127.0.0.1 || { echo "PostgreSQL down, stopping before $id" >> "$L/03_tests.out"; exit 3; }
  # A fresh, fully migrated test database per suite: a spec that calls maintain_test_schema!
  # (db:test:prepare) or leaves data behind must not decide the next plugin's result.
  su postgres -c "dropdb --if-exists r70h_test && createdb -O redmine -T r70h_test_tpl r70h_test" || exit 4
  [ -f db/schema.rb ] || cp "$H/kit/schema.rb" db/schema.rb
  P=plugins/$id; log=$L/test-$id.log; : > "$log"; mt="-"; rs="-"; t0=$(date +%s)
  mapfile -t files < <(find "$P/test" -name '*_test.rb' ! -path '*/system/*' ! -path '*/ui/*' 2>/dev/null | sort)
  if [ ${#files[@]} -gt 0 ]; then
    echo "== minitest ${#files[@]} files" >> "$log"
    timeout 2400 bundle exec ruby -Itest -e 'ARGV.each { |f| require File.expand_path(f) }; require ENV.fetch("SHIM")' "${files[@]}" >> "$log" 2>&1; mrc=$?
    mt=$(grep -E '^[0-9]+ (runs|tests), ' "$log" | tail -1); mt="${mt:-no summary (exit $mrc)}"
  fi
  if [ -d "$P/spec" ]; then
    echo "== rspec" >> "$log"
    timeout 2400 bundle exec ruby -e 'load Gem.bin_path("rspec-core", "rspec")' -- -I "$P/spec" "$P/spec" >> "$log" 2>&1; rrc=$?
    rs=$(grep -E '^[0-9]+ examples?, ' "$log" | tail -1); rs="${rs:-no summary (exit $rrc)}"
  fi
  pg_isready -q -h 127.0.0.1 || { echo "PostgreSQL went down during $id, not recorded" >> "$L/03_tests.out"; exit 3; }
  printf '%s\t%s\t%s\t%ss\n' "$id" "$mt" "$rs" "$(( $(date +%s) - t0 ))" | tee -a "$H/tests.tsv"
done
echo DONE >> "$H/tests.tsv"
