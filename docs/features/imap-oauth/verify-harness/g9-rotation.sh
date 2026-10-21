#!/usr/bin/env bash
# G9 for refresh token rotation (Jan's decision of 2026-10-21): drive the real
# rake task, as an unprivileged user the way cron runs it, against a real HTTPS
# token endpoint and a real IMAP socket, and show what happens to the
# credentials file.
#
#   g9-rotation.sh <worktree> <label>
#
# Needs: a user `redmine`, login.example.net resolving to 127.0.0.1
# (/etc/hosts), and a development database with the dev seed (project
# geoxyz-verify, user dev@example.net) — tools/dev-server.sh.
#
# The tokens in this harness are fake, so the transcript shows the
# refresh_token line of the file. That is the evidence here; it is not
# something a real run would ever print.
set -uo pipefail

WT="$1"; LABEL="$2"
H=/home/user/redmine/docs/features/imap-oauth/verify-harness
TMP=$(mktemp -d)
chmod 755 "$TMP"
IMAP_PORT=11143
PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT

cat > "$TMP/message.eml" <<'EOF'
From: dev@example.net
To: redmine@example.net
Subject: Fetched with a rotated refresh token

Sent through the IMAP harness.
EOF

ruby "$H/imap_server.rb" $IMAP_PORT redmine@example.net an-access-token "$TMP/message.eml" > "$TMP/imap.log" 2>&1 &
PIDS+=($!)

# endpoint <port> <ROTATE value or empty>
endpoint() {
  ROTATE="$2" ruby "$H/token_endpoint.rb" "$1" "$TMP/cert-$1.pem" a-refresh-token an-access-token > "$TMP/token-$1.log" 2>&1 &
  PIDS+=($!)
}
endpoint 11443 revoke
endpoint 11444 ''
endpoint 11445 keep
endpoint 11446 keep
until grep -q listening "$TMP/imap.log" 2>/dev/null && [ -f "$TMP/cert-11446.pem" ]; do sleep 0.3; done
sleep 2

# credentials <dir> <port>: the file as an administrator writes it by hand
credentials() {
  cat > "$1/imap_oauth2.yml" <<EOF
# Redmine support mailbox, Microsoft 365 (verification harness)
authorize_url: https://login.example.net:$2/oauth2/v2.0/authorize
token_url: https://login.example.net:$2/oauth2/v2.0/token
client_id: a-client-id
client_secret: a-client-secret   # expires 2027-01
refresh_token: a-refresh-token

scope: https://outlook.office.com/IMAP.AccessAsUser.All offline_access
redirect_uri: http://localhost
EOF
  cp "$1/imap_oauth2.yml" "$TMP/original-$2.yml"
}

state() {
  local f="$1/imap_oauth2.yml"
  echo "    file: $(stat -c '%U:%G %a' "$f")  sha256 $(sha256sum "$f" | cut -c1-16)  mtime $(stat -c '%y' "$f" | cut -c12-23)"
  echo "    $(grep '^refresh_token' "$f")"
}

# fetch <dir> <port>: what cron runs, as the redmine user
fetch() {
  local out status
  out=$(cd "$WT" && runuser -u redmine -- env HOME=/tmp/redmine-home SSL_CERT_FILE="$TMP/cert-$2.pem" \
    RAILS_ENV=development bundle exec ruby bin/rails redmine:email:receive_imap \
    host=127.0.0.1 port=$IMAP_PORT username=redmine@example.net \
    oauth2_credentials="$1/imap_oauth2.yml" project=geoxyz-verify 2>&1)
  status=$?
  echo "    exit $status"
  echo "$out" | grep -vE '^\s+/|^Tasks:|^\(See full trace|bundled_gems|^$' | sed 's/^/    stderr: /'
  last_issue
}

last_issue() {
  (cd "$WT" && RAILS_ENV=development bundle exec ruby bin/rails runner \
    'i = Issue.order(:id).last; puts "    newest issue: ##{i.id} \"#{i.subject}\" created #{i.created_on.strftime("%H:%M:%S")}"' 2>/dev/null)
}

echo "===== $LABEL ====="

echo
echo "--- A. provider rotates and revokes the old refresh token (ROTATE=revoke) ---"
echo "    directory redmine 700, file redmine:redmine 640"
A=$TMP/a; install -d -o redmine -g redmine -m 700 "$A"
credentials "$A" 11443; chown redmine:redmine "$A/imap_oauth2.yml"; chmod 640 "$A/imap_oauth2.yml"
state "$A"
for run in 1 2 3; do
  echo "  run $run"
  fetch "$A" 11443
  state "$A"
done
echo "  token endpoint log:"
grep -E 'issued|not accepted' "$TMP/token-11443.log" | sed 's/^/    /'
echo "  diff between the file as written and the file now:"
diff "$TMP/original-11443.yml" "$A/imap_oauth2.yml" | sed 's/^/    /'

echo
echo "--- B. provider returns no refresh token (Google's behaviour) ---"
B=$TMP/b; install -d -o redmine -g redmine -m 700 "$B"
credentials "$B" 11444; chown redmine:redmine "$B/imap_oauth2.yml"; chmod 600 "$B/imap_oauth2.yml"
state "$B"
sleep 1
echo "  run 1"
fetch "$B" 11444
state "$B"
echo -n "  file byte-identical to the one written: "
cmp -s "$TMP/original-11444.yml" "$B/imap_oauth2.yml" && echo YES || echo NO

echo
echo "--- C. provider rotates (ROTATE=keep), directory not writable by redmine ---"
echo "    directory root 755, file redmine:redmine 600"
C=$TMP/c; install -d -o root -g root -m 755 "$C"
credentials "$C" 11445; chown redmine:redmine "$C/imap_oauth2.yml"; chmod 600 "$C/imap_oauth2.yml"
state "$C"
echo "  run 1"
OUT=$(fetch "$C" 11445); echo "$OUT"
state "$C"
echo -n "  a token in what the run printed: "
echo "$OUT" | grep -qE 'rotated-refresh-token|a-refresh-token|an-access-token|a-client-secret' && echo YES || echo "none"

echo
echo "--- D. provider rotates (ROTATE=keep), file owned by root, readable by group redmine ---"
echo "    directory redmine 700, file root:redmine 640"
D=$TMP/d; install -d -o redmine -g redmine -m 700 "$D"
credentials "$D" 11446; chown root:redmine "$D/imap_oauth2.yml"; chmod 640 "$D/imap_oauth2.yml"
state "$D"
echo "  run 1"
fetch "$D" 11446
state "$D"
echo
