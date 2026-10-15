#!/bin/bash
# redmine_user_specific_theme -> redmine_theme_changer 0.7.1, as its REDMINE7-MIGRATION.md describes
# ("Switch to redmine_theme_changer"). Users chose alternate, classic and PurpleMine2 (not installed).
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); . "$D/env.sh"
cd "$U70"
step() { local name=$1; shift; echo "== $name"; "$@" > "$LOGS/45_$name.log" 2>&1; local rc=$?; echo "   exit=$rc"; grep -v -E '^/|^\s+/|warning:|^\s*$' "$LOGS/45_$name.log" | head -12 | sed 's/^/   | /'; return 0; }
step themes_chosen psql -d r70h_upg70 -Atc "SELECT u.login, p.others FROM user_preferences p JOIN users u ON u.id = p.user_id WHERE p.others LIKE '%ui_theme%' ORDER BY 1"
[ -d plugins/redmine_theme_changer ] || git clone -q --depth 1 -b 0.7.1 https://github.com/haru/redmine_theme_changer plugins/redmine_theme_changer
step theme_changer_head git -C plugins/redmine_theme_changer log -1 --format='%h %s'
step theme_changer_migrate bundle exec rake redmine:plugins:migrate
step convert_dry env THEME_MAP=PurpleMine2:alternate DRY_RUN=1 bundle exec rake redmine_user_specific_theme:convert_to_theme_changer
step convert bundle exec rake redmine_user_specific_theme:convert_to_theme_changer THEME_MAP=PurpleMine2:alternate
step convert_again bundle exec rake redmine_user_specific_theme:convert_to_theme_changer THEME_MAP=PurpleMine2:alternate
step check psql -d r70h_upg70 -c "SELECT u.login, t.theme FROM theme_changer_user_settings t JOIN users u ON u.id = t.user_id ORDER BY 1"
# step 5 of the doc: remove redmine_user_specific_theme, restart, open a page as a user with a personal theme
mkdir -p "$U70/.aside"; rm -rf "$U70/.aside/redmine_user_specific_theme"; mv plugins/redmine_user_specific_theme "$U70/.aside/"
"$D/50_server70.sh"
python3 -I - <<'PY'
import sys, re; sys.path.insert(0, '/tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/upgrade/py')
from rmclient import Session
for login in ('alice', 'bob', 'carol'):
    s = Session('http://127.0.0.1:3200'); s.login(login, 'Upgrade-Rehearsal-2026')
    for path in ('/my/page', '/my/account', '/projects/geo-main/issues'):
        st, html, _ = s.get(path)
        theme = re.findall(r'themes/([A-Za-z0-9_-]+)/', html)
        print(login, path, st, 'theme assets:', sorted(set(theme)))
PY
