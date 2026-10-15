#!/bin/bash
# Leave-one-out sweep: for each plugin, a production server on :3100 with all plugins except that one
# (symlink set, nothing moved), median of 5 per page. Re-runnable: variants with a result are skipped.
source /tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/perf44/env.sh
PU="issues_25@member1,issues_100@admin,my_page@member1,issue_show@member1,issue_new@member1,project_settings@admin,gantt@member1,search_word@member1,context_menu@member1,project_overview@member1,wiki@member1,api_issues_100@admin"
mkdir -p $P/results/loo
variants="none"
for d in $RC/plugins/*/; do n=$(basename $d); [ "$n" = redmine_contacts_helpdesk ] && continue; variants="$variants $n"; done
variants="$variants none2"
for v in $variants; do
  [ -f $P/results/loo/$v.json ] && continue
  case $v in
    none|none2) mode="without:__none__" ;;
    redmine_contacts) mode="without:redmine_contacts,redmine_contacts_helpdesk" ;;
    *) mode="without:$v" ;;
  esac
  bash $P/start_server.sh loo 3100 "$mode" 0 >> $P/logs/loo.out 2>&1 || { echo "$v: server failed" >> $P/logs/loo.out; grep -iE "error|exception" $P/logs/server-loo.log | head -5 >> $P/logs/loo.out; continue; }
  echo "== $v $(date +%T)" >> $P/logs/loo.out
  ruby $P/measure.rb --targets loo=3100 --pu "$PU" --reps 5 --warm 1 --out $P/results/loo/$v >> $P/logs/loo.out 2>&1
done
echo "SWEEP DONE $(date +%T)" >> $P/logs/loo.out
