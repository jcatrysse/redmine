#!/bin/bash
# The "before" side, on the seeded 5.1: counts, snapshot, workflow fingerprint, view_issue_description roles,
# then a dump of r70h_upg (the production stand-in that 7.0 upgrades).
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); . "$D/env.sh"
export PATH=/opt/rbenv/versions/3.2.6/bin:$PATH
cd "$U51"
"$D/30_counts.sh" r70h_upg > "$S/counts51.tsv"
OUT=$S/snap51.json bundle exec rails runner "$S/31_snapshot.rb" 2>&1 | grep -v warning
SETS_OUT=$S/wf_sets.json OUT=$S/wf51.json bundle exec rails runner "$S/32_wf_fingerprint.rb" 2>&1 | grep -v warning
bundle exec rails runner 'Role.sorted.each { |r| next unless r.has_permission?(:view_issues); t = r.permissions_all_trackers?(:view_issue_description) ? "all" : r.permissions_tracker_ids(:view_issue_description).join(","); puts [r.name, r.has_permission?(:view_issue_description) ? "view_issue_description: #{t}" : "NO view_issue_description", r.has_permission?(:view_watched_issues) ? "view_watched_issues" : "-"].join(" | ") }' 2>&1 | grep -v warning > "$S/vid_roles51.txt"
cat "$S/vid_roles51.txt"
pg_dump -Fc r70h_upg > "$S/r70h_upg-51-seeded.dump" && ls -la "$S/r70h_upg-51-seeded.dump"
