#!/bin/bash
# viewings.ip is varchar(24) on the upgraded database (45 on a fresh 7.0): a contact viewed from an IPv6 address.
# Rails trusts X-Forwarded-For from 127.0.0.1, so remote_ip becomes the IPv6 address. 70 or 51.
. "$(dirname "$0")/env.sh"
v=${1:-70}; port=3200; [ "$v" = 51 ] && port=3201
python3 -I - $port <<'PY'
import sys, urllib.request
sys.path.insert(0, '/tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/upgrade/py')
from rmclient import Session
port = sys.argv[1]
s = Session(f'http://127.0.0.1:{port}'); s.login('admin', 'Upgrade-Admin-2026')
for ip in ('192.0.2.10', '2001:0db8:85a3:0000:0000:8a2e:0370:7334'):
    for path in ('/contacts/2', '/deals/2', '/issues/1'):
        r = urllib.request.Request(f'http://127.0.0.1:{port}{path}', headers={'X-Forwarded-For': ip})
        try:
            with s.op.open(r, timeout=60) as resp: st = resp.status
        except urllib.error.HTTPError as e: st = e.code
        print(port, ip, path, st)
PY
