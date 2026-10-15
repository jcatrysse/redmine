#!/bin/bash
# Start (or restart) the upgraded 7.0 tree in production mode on 127.0.0.1:3200. "stop" stops it.
. "$(dirname "$0")/env.sh"
cd "$U70"
pid=$U70/tmp/pids/upg70-3200.pid
[ -f "$pid" ] && kill "$(cat "$pid")" 2>/dev/null && sleep 3
rm -f "$pid"; pkill -f "tcp://127.0.0.1:3200) \[upg70\]" 2>/dev/null; sleep 1
[ "${1:-}" = stop ] && exit 0
mkdir -p tmp/pids log
setsid nohup bundle exec rails server -e production -b 127.0.0.1 -p 3200 -P "$pid" >> "$LOGS/server70.log" 2>&1 < /dev/null &
for i in $(seq 1 120); do
  c=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3200/login); [ "$c" = 200 ] && { echo "7.0 up on 3200"; exit 0; }; sleep 2
done
echo "7.0 server did not come up"; tail -30 "$LOGS/server70.log"; exit 1
