#!/bin/bash
# Stage 2 leave-one-out, interleaved: baseline (all plugins) on :3101 and the variant on :3100, requests alternate
# between them so background load hits both alike. loo2.sh <outdir> <page@user list> <reps> <variant...>
# A variant is a comma separated list of plugin directories to leave out. Re-runnable: done variants are skipped.
source /tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/perf44/env.sh
out=$1; PU=$2; reps=$3; shift 3
mkdir -p $P/results/$out
log=$P/logs/$out.out
if [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3101/login)" != 200 ] || [ "$(cat $P/logs/base3101.mode 2>/dev/null)" != all ]; then
  bash $P/start_server.sh base 3101 "without:__none__" 0 >> $log 2>&1 && echo all > $P/logs/base3101.mode
fi
for v in "$@"; do
  name=${v//,/+}
  [ -f $P/results/$out/$name.json ] && continue
  bash $P/start_server.sh loo 3100 "without:$v" 0 >> $log 2>&1 || { echo "$name: server failed" >> $log; continue; }
  echo "== $name $(date +%T)" >> $log
  ruby $P/measure.rb --targets loo=3100,base=3101 --pu "$PU" --reps $reps --warm 1 --out $P/results/$out/$name >> $log 2>&1
done
echo "STAGE DONE $(date +%T)" >> $log
