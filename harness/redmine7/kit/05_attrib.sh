#!/bin/bash
# Attribution runs in the second checkout (redmine_b, own test DB r70h_test_b): the given suites with the
# given plugins moved out of plugins/. Usage: 05_attrib.sh <label> "<plugins to remove>" "<suite ids>"
# Results in attrib-<label>.tsv; plugins are moved back at the end.
set -uo pipefail
H=/home/user/r70h; R=$H/redmine_b; L=$H/logs; label=$1; remove=$2; ids=$3
export SHIM=$H/kit/shim_reporter.rb RAILS_ENV=test LANG=C.UTF-8 LC_ALL=C.UTF-8
# /opt/node22/bin carries chromedriver 147, which does not match the cached Chrome 155; without it
# Selenium Manager picks a matching driver and the browser specs run.
PATH=$(echo "$PATH" | tr ':' '\n' | grep -vx '/opt/node22/bin' | paste -sd:); export PATH
mkdir -p "$H/aside-b"; cd "$R"
for p in $remove; do mv "plugins/$p" "$H/aside-b/$p"; done
: > "$H/attrib-$label.tsv"
for id in $ids; do
  su postgres -c "dropdb --if-exists r70h_test_b && createdb -O redmine -T r70h_test_tpl r70h_test_b" || break
  P=plugins/$id; log=$L/attrib-$label-$id.log; : > "$log"; mt="-"; rs="-"
  mapfile -t files < <(find "$P/test" -name '*_test.rb' ! -path '*/system/*' ! -path '*/ui/*' 2>/dev/null | sort)
  if [ ${#files[@]} -gt 0 ]; then
    timeout 2400 bundle exec ruby -Itest -e 'ARGV.each { |f| require File.expand_path(f) }; require ENV.fetch("SHIM")' "${files[@]}" >> "$log" 2>&1
    mt=$(grep -E '^[0-9]+ (runs|tests), ' "$log" | tail -1)
  fi
  if [ -d "$P/spec" ]; then
    timeout 2400 bundle exec ruby -e 'load Gem.bin_path("rspec-core", "rspec")' -- -I "$P/spec" "$P/spec" >> "$log" 2>&1
    rs=$(grep -E '^[0-9]+ examples?, ' "$log" | tail -1)
  fi
  printf '%s\t%s\t%s\n' "$id" "${mt:-no summary}" "${rs:-no summary}" >> "$H/attrib-$label.tsv"
done
for p in $remove; do mv "$H/aside-b/$p" "plugins/$p"; done
echo DONE >> "$H/attrib-$label.tsv"
