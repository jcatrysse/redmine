#!/bin/bash
# Dump the upgraded schema to $S/schema70-<label>.rb and diff it against the fresh 7.0 install
# (${REF:-/home/user/r70h/kit/schema.rb}): raw diff without the version line, and the semantic diff.
. "$(dirname "$0")/env.sh"
label=${1:-upgraded}
cd "$U70"
SCHEMA=$S/schema70-$label.rb bundle exec rake db:schema:dump > "$LOGS/44_dump_$label.log" 2>&1 || { tail "$LOGS/44_dump_$label.log"; exit 1; }
diff <(grep -v 'ActiveRecord::Schema' "$S/schema70-$label.rb") <(grep -v 'ActiveRecord::Schema' ${REF:-/home/user/r70h/kit/schema.rb}) > "$S/schema70-$label.rawdiff"
echo "raw diff lines: $(wc -l < "$S/schema70-$label.rawdiff")"
diff <(grep 'ActiveRecord::Schema' "$S/schema70-$label.rb" | tr ',' '\n' | sed 's/^ *//') <(grep 'ActiveRecord::Schema' ${REF:-/home/user/r70h/kit/schema.rb} | tr ',' '\n' | sed 's/^ *//') | grep '^[<>]' | sed 's/^/version line: /'
python3 -I "$S/py/schema_diff.py" "$S/schema70-$label.rb" ${REF:-/home/user/r70h/kit/schema.rb} upgraded fresh | tee "$S/schema70-$label.semdiff"
