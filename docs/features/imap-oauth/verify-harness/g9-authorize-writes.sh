#!/usr/bin/env bash
# G9 for K-26 option B (Jan, 2026-10-21): redmine:email:oauth2_authorize writes
# the refresh token into the credentials file instead of printing it. Drives
# the real interactive task as the unprivileged user `redmine`: the consent URL
# it prints is followed the way a browser follows it, and the address the
# provider redirects to is pasted back on its stdin.
#
#   g9-authorize-writes.sh <worktree> <label>
#
# Needs the same as g9-rotation.sh: a user `redmine`, login.example.net in
# /etc/hosts, and the dev database from tools/dev-server.sh.
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
Subject: Fetched with the refresh token oauth2_authorize wrote

Sent through the IMAP harness.
EOF
ruby "$H/imap_server.rb" $IMAP_PORT redmine@example.net an-access-token "$TMP/message.eml" > "$TMP/imap.log" 2>&1 &
PIDS+=($!)
for port in 11451 11452 11453; do
  ruby "$H/token_endpoint.rb" $port "$TMP/cert-$port.pem" a-refresh-token-from-consent an-access-token > "$TMP/token-$port.log" 2>&1 &
  PIDS+=($!)
done
until grep -q listening "$TMP/imap.log" 2>/dev/null && [ -f "$TMP/cert-11453.pem" ]; do sleep 0.3; done
sleep 2

# credentials <dir> <port>: everything except refresh_token, as the guide says
credentials() {
  cat > "$1/imap_oauth2.yml" <<EOF
# Redmine support mailbox, Microsoft 365 (verification harness)
authorize_url: https://login.example.net:$2/oauth2/v2.0/authorize
token_url: https://login.example.net:$2/oauth2/v2.0/token
client_id: a-client-id
client_secret: a-client-secret   # expires 2027-01

scope: https://outlook.office.com/IMAP.AccessAsUser.All offline_access
redirect_uri: http://localhost
EOF
  cp "$1/imap_oauth2.yml" "$TMP/original-$2.yml"
}

state() {
  local f="$1/imap_oauth2.yml"
  echo "    file: $(stat -c '%U:%G %a' "$f")  sha256 $(sha256sum "$f" | cut -c1-16)"
  echo "    refresh_token line: $(grep '^refresh_token' "$f" || echo '(none)')"
}

as_redmine() {
  runuser -u redmine -- env HOME=/tmp/redmine-home SSL_CERT_FILE="$TMP/cert-$1.pem" RAILS_ENV=development "${@:2}"
}

# authorize <dir> <port> [break]: run the task, consent, paste the address
# back. With `break`, the directory is made read-only after the consent URL is
# printed, so the write after the exchange fails.
authorize() {
  local dir=$1 port=$2 out=$TMP/authorize-$2.out fifo=$TMP/fifo-$2 url redirect
  mkfifo "$fifo"
  (cd "$WT" && as_redmine "$port" bundle exec ruby bin/rails redmine:email:oauth2_authorize \
    oauth2_credentials="$dir/imap_oauth2.yml" < "$fifo" > "$out" 2>&1; echo "exit $?" >> "$out") &
  local pid=$!
  exec 7> "$fifo"
  until grep -qE '^https://|^exit [0-9]' "$out" 2>/dev/null; do sleep 0.3; done
  url=$(grep -E '^https://' "$out" | head -1)
  if [ -n "$url" ]; then
    [ "${3:-}" = break ] && chmod 500 "$dir"
    redirect=$(curl -s -o /dev/null -w '%{redirect_url}' --noproxy '*' --cacert "$TMP/cert-$port.pem" "$url")
    echo "$redirect" >&7
  fi
  exec 7>&-
  wait $pid
  grep -vE '^\s+/|^Tasks:|^\(See full trace|bundled_gems|^$' "$out" \
    | sed -E 's#^(https://[^?]*)\?.*#\1?...(consent URL)#; s/^/    | /'
  echo "  token endpoint saw:"
  grep -E 'authorization_code|refresh_token"' "$TMP/token-$port.log" | sed -E 's/"code"=>"[^"]*"/"code"=>.../; s/^/    /' || true
  grep -q 'grant_type"=>"authorization_code' "$TMP/token-$port.log" || echo "    (no grant at all)"
}

fetch() {
  local out status
  out=$(cd "$WT" && as_redmine "$2" bundle exec ruby bin/rails redmine:email:receive_imap \
    host=127.0.0.1 port=$IMAP_PORT username=redmine@example.net \
    oauth2_credentials="$1/imap_oauth2.yml" project=geoxyz-verify 2>&1)
  status=$?
  echo "    exit $status"
  echo "$out" | grep -vE '^\s+/|^Tasks:|^\(See full trace|bundled_gems|^$' | sed 's/^/    stderr: /'
  (cd "$WT" && RAILS_ENV=development bundle exec ruby bin/rails runner \
    'i = Issue.order(:id).last; puts "    newest issue: ##{i.id} \"#{i.subject}\""' 2>/dev/null)
}

echo "===== $LABEL ====="

echo
echo "--- 1. first authorization, file without a refresh_token line ---"
echo "    directory redmine 700, file redmine:redmine 640"
D1=$TMP/one; install -d -o redmine -g redmine -m 700 "$D1"
credentials "$D1" 11451; chown redmine:redmine "$D1/imap_oauth2.yml"; chmod 640 "$D1/imap_oauth2.yml"
state "$D1"
authorize "$D1" 11451
state "$D1"
echo "  diff between the file as written and the file now:"
diff "$TMP/original-11451.yml" "$D1/imap_oauth2.yml" | sed 's/^/    /'
echo "  receive_imap with that file:"
fetch "$D1" 11451

echo
echo "--- 2. directory not writable by redmine ---"
echo "    directory root 755, file redmine:redmine 600"
D2=$TMP/two; install -d -o root -g root -m 755 "$D2"
credentials "$D2" 11452; chown redmine:redmine "$D2/imap_oauth2.yml"; chmod 600 "$D2/imap_oauth2.yml"
authorize "$D2" 11452
state "$D2"

echo
echo "--- 3. the directory becomes read-only between the consent URL and the paste ---"
echo "    directory redmine 700, then 500 after the URL is printed"
D3=$TMP/three; install -d -o redmine -g redmine -m 700 "$D3"
credentials "$D3" 11453; chown redmine:redmine "$D3/imap_oauth2.yml"; chmod 600 "$D3/imap_oauth2.yml"
authorize "$D3" 11453 break
state "$D3"
echo
