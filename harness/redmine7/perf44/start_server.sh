#!/bin/bash
# start_server.sh <label> <port> <all|core|without:a,b,c> [trace 0|1]   (re-runnable: stops whatever listens on that port first)
#   all          = redmine_c with its 44 plugins and the full bundle
#   core         = same checkout, no plugins (empty plugins dir) and a bundle without the plugin Gemfiles
#   without:a,b  = all plugins except the listed ones (config/initializers/29-perf44-exclude.rb skips them; nothing moves)
source /tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/perf44/env.sh
label=$1; port=$2; mode=$3; trace=${4:-0}
[ "$port" = 3000 ] && { echo "refusing port 3000"; exit 1; }
pg_lsclusters | grep -q online || bash /home/user/r70h/kit/resume.sh >/dev/null 2>&1
for pid in $(lsof -t -iTCP:$port -sTCP:LISTEN 2>/dev/null); do kill $pid; done
for i in $(seq 1 30); do lsof -t -iTCP:$port -sTCP:LISTEN >/dev/null 2>&1 || break; sleep 1; done
cp $P/zz_perf44.rb $RC/config/initializers/zz_perf44.rb
cp $P/29-perf44-exclude.rb $RC/config/initializers/29-perf44-exclude.rb
cp $P/additional_environment.rb $RC/config/additional_environment.rb
rm -rf $P/cache-$label; mkdir -p $P/cache-$label
export PERF44_CACHE_DIR=$P/cache-$label PERF44_TRACE=$trace PERF44_TRACE_FILE=$P/logs/trace-$label.jsonl RAILS_LOG_TO_STDOUT=1
unset PERF44_PLUGINS_DIRECTORY BUNDLE_GEMFILE PERF44_EXCLUDE
case "$mode" in
  core) export BUNDLE_GEMFILE=$P/core_bundle/Gemfile PERF44_PLUGINS_DIRECTORY=$P/core_bundle/plugins ;;
  without:*) export PERF44_EXCLUDE="${mode#without:}" ;;
esac
cd $RC
setsid nohup bundle exec puma -e production -b "tcp://127.0.0.1:$port" -t 1:1 -w 0 config.ru > $P/logs/server-$label.log 2>&1 < /dev/null &
for i in $(seq 1 180); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$port/login)" = 200 ] && { echo "$label up on $port ($mode, trace=$trace) after ${i}s"; exit 0; }
  sleep 1
done
echo "$label did not come up"; tail -30 $P/logs/server-$label.log; exit 1
