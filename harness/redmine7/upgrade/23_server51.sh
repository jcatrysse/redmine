#!/bin/bash
# Start (or restart) the 5.1 tree in production mode on 127.0.0.1:3201. "stop" stops it.
. "$(dirname "$0")/env.sh"
export PATH=/opt/rbenv/versions/3.2.6/bin:$PATH
cd "$U51"
pid=$U51/tmp/pids/upg51-3201.pid
[ -f "$pid" ] && kill "$(cat "$pid")" 2>/dev/null && sleep 3
rm -f "$pid"; pkill -f "tcp://127.0.0.1:3201) \[upg51\]" 2>/dev/null; sleep 1
[ "${1:-}" = stop ] && exit 0
mkdir -p tmp/pids log
setsid nohup bundle exec rails server -e production -b 127.0.0.1 -p 3201 -P "$pid" >> "$LOGS/server51.log" 2>&1 < /dev/null &
for i in $(seq 1 90); do
  c=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3201/login); [ "$c" = 200 ] && { echo "5.1 up on 3201"; exit 0; }; sleep 2
done
echo "5.1 server did not come up"; tail -20 "$LOGS/server51.log"; exit 1
