#!/usr/bin/env bash
# G9 for the round-3 fixes: drive the real code against a real HTTPS token
# endpoint and a real IMAP socket, once with the code as round 3 reviewed it
# and once with the fixes, and print both.
#
#   g9-round3.sh <worktree> <label>
#
# login.example.net must resolve to 127.0.0.1 (/etc/hosts), because the client
# does a real DNS lookup and a real TLS handshake against the endpoint's cert.
set -uo pipefail

WT="$1"; LABEL="$2"
H=/home/user/redmine/docs/features/imap-oauth/verify-harness
TMP=$(mktemp -d)
CERT=$TMP/endpoint.pem
CERT2=$TMP/endpoint2.pem
CREDS=$TMP/imap_oauth2.yml
CREDS2=$TMP/badjson.yml
TOKEN_PORT=11443
BAD_PORT=11444
IMAP_PORT=11143

cat > $TMP/message.eml <<'EOF'
From: dev.verify0@example.net
To: redmine@example.net
Subject: Printer on deck 3 is offline

The printer on deck 3 stopped responding after the last reboot.
EOF

ruby $H/token_endpoint.rb $TOKEN_PORT $CERT a-refresh-token an-access-token > $TMP/token.log 2>&1 &
T1=$!
BADJSON=1 ruby $H/token_endpoint.rb $BAD_PORT $CERT2 a-refresh-token an-access-token > $TMP/bad.log 2>&1 &
T2=$!
ruby $H/imap_server.rb $IMAP_PORT redmine@example.net an-access-token $TMP/message.eml > $TMP/imap.log 2>&1 &
T3=$!
trap 'kill $T1 $T2 $T3 2>/dev/null' EXIT
until grep -q "listening" $TMP/imap.log 2>/dev/null; do sleep 0.3; done
sleep 2

# The authorize endpoint carries a parameter of its own, the way Azure AD B2C's
# does. That is round-3 finding F01.
cat > $CREDS <<EOF
authorize_url: https://login.example.net:$TOKEN_PORT/oauth2/v2.0/authorize?p=B2C_1_signin
token_url: https://login.example.net:$TOKEN_PORT/oauth2/v2.0/token
client_id: a-client-id
client_secret: a-client-secret
refresh_token: a-refresh-token
scope: https://outlook.office.com/IMAP.AccessAsUser.All offline_access
redirect_uri: http://localhost
EOF
sed "s|:$TOKEN_PORT/|:$BAD_PORT/|g" $CREDS > $CREDS2

cd "$WT" || exit 2
export RAILS_ENV=test

run() { bundle exec ruby bin/rails runner "$1" 2>&1 | grep -vE "^Hold on|^DEPRECATION|^\s*from |bundled_gems|^$"; }

echo "===== $LABEL ====="
echo
echo "--- F01: the consent URL is built by the real code, then really followed ---"
URL=$(SSL_CERT_FILE=$CERT run "puts Redmine::Oauth2Client.authorize_url('$CREDS')" | tail -1)
echo "  consent URL: $URL"
curl -sS -o /dev/null --noproxy "*" --cacert $CERT "$URL" 2>&1 | sed 's/^/  curl: /'
sleep 0.5
echo "  token endpoint logged:"
grep "full query" $TMP/token.log | tail -1 | sed 's/^/    /'
echo -n "  -> policy parameter p=B2C_1_signin reached the provider: "
grep -q "p=B2C_1_signin" $TMP/token.log && echo "YES" || echo "NO, it was dropped"

echo
echo "--- F04: the token endpoint answers 200 with a JSON array, not an object ---"
SSL_CERT_FILE=$CERT2 run "begin; Redmine::Oauth2Client.access_token('$CREDS2'); rescue => e; puts \"  #{e.class}: #{e.message}\"; end" | tail -1

echo
echo "--- control: the happy path, real XOAUTH2 over a real socket ---"
SSL_CERT_FILE=$CERT run "Redmine::IMAP.check({:host => '127.0.0.1', :port => '$IMAP_PORT', :username => 'redmine@example.net', :oauth2_credentials => '$CREDS'}, {}); puts '  check returned without raising'" | tail -1
sleep 0.5
echo "  IMAP server saw:"
grep -E "authenticated=|AUTHENTICATE" $TMP/imap.log | tail -2 | sed 's/^/    /'
echo -n "  -> the mailbox accepted the XOAUTH2 credential: "
grep -q "authenticated=true" $TMP/imap.log && echo "YES" || echo "NO"
echo
