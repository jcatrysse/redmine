#!/bin/bash
# Undo everything the perf44 kit put into redmine_c and drop its database.
source /tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/perf44/env.sh
for port in 3100 3101; do for pid in $(lsof -t -iTCP:$port -sTCP:LISTEN 2>/dev/null); do kill $pid; done; done
rm -f $RC/config/initializers/29-perf44-exclude.rb $RC/config/initializers/zz_perf44.rb $RC/config/additional_environment.rb
[ -f $P/database.yml.orig ] && cp $P/database.yml.orig $RC/config/database.yml
su postgres -c "dropdb --if-exists $DB"
