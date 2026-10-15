#!/bin/bash
# The "after" side on the upgraded 7.0: counts, snapshot, workflow fingerprint (same sets as 5.1), and the
# comparisons with the 5.1 "before" files.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); . "$D/env.sh"
cd "$U70"
"$D/30_counts.sh" r70h_upg70 > "$S/counts70.tsv"
OUT=$S/snap70.json bundle exec rails runner "$S/31_snapshot.rb" 2>&1 | grep -v warning
SETS=$S/wf_sets.json OUT=$S/wf70.json bundle exec rails runner "$S/32_wf_fingerprint.rb" 2>&1 | grep -v warning
echo "== row counts (tables present on both sides whose count changed; tables only on one side)"
join -t $'\t' -a1 -a2 -e MISSING -o 0,1.2,2.2 "$S/counts51.tsv" "$S/counts70.tsv" | awk -F'\t' '$2!=$3' | tee "$S/counts-diff.tsv"
echo "== workflow fingerprint 5.1 vs 7.0"
python3 -I - "$S/wf51.json" "$S/wf70.json" <<'PY'
import json, sys
a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
diff = [k for k in sorted(set(a) | set(b)) if a.get(k) != b.get(k)]
print(f"answers 5.1={len(a)} 7.0={len(b)} different={len(diff)}")
for k in diff[:40]: print(k, '5.1:', a.get(k), '7.0:', b.get(k))
PY
echo "== snapshot 5.1 vs 7.0"
python3 -I "$S/py/snap_diff.py" "$S/snap51.json" "$S/snap70.json"
