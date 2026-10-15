#!/bin/bash
# Admin password, then every plugin settings form saved through the 5.1 UI (server on 3201 must run).
. "$(dirname "$0")/env.sh"
export PATH=/opt/rbenv/versions/3.2.6/bin:$PATH
cd "$U51"
bundle exec rails runner 'u = User.find_by_login("admin"); u.password = u.password_confirmation = "Upgrade-Admin-2026"; u.must_change_passwd = false; u.save!; puts "admin ok"' 2>&1 | grep -v warning
python3 -I "$S/py/settings_roundtrip.py" http://127.0.0.1:3201 admin Upgrade-Admin-2026 | tee "$LOGS/22_settings51.log"
