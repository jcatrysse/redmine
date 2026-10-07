// G9 for rake-webhook-flush. A real `rake redmine:email:read` per mail, the way
// an MTA pipe or a cron runs it, against a real webhook receiver, with the
// development environment's default :async job adapter.
//
//   WORKTREE=/home/user/wt/patch-rake-webhook-flush SHOT_PREFIX=before \
//     SHOT_DIR=docs/features/rake-webhook-flush/shots node verify/rake-webhook-flush.mjs
//
// MODE=deliver (default) points the hook at the receiver and counts what
// arrives; MODE=unreachable points it at a closed port and checks that the
// rake task still creates the issue and exits 0; MODE=disabled turns the
// webhooks setting off and checks that nothing is sent and nothing breaks.
//
// The receiver binds to RECEIVER_HOST, not 127.0.0.1: Redmine refuses loopback
// webhook targets (WebhookEndpointValidator), so it has to be a routable
// address of this machine.
import http from 'node:http';
import { spawn } from 'node:child_process';
import { session, report } from '../tools/verify-lib.mjs';

const WORKTREE = process.env.WORKTREE || '/home/user/wt/patch-rake-webhook-flush';
const PREFIX = process.env.SHOT_PREFIX || 'after';
const MODE = process.env.MODE || 'deliver';
const RUNS = Number(process.env.RUNS || 4);
const HOST = process.env.RECEIVER_HOST || '192.0.2.2';
const PORT = Number(process.env.RECEIVER_PORT || 4567);
const TAG = `rake-webhook-flush ${PREFIX}${MODE === 'deliver' ? '' : ' ' + MODE} ${Date.now()}`;

const received = [];
const receiver = http.createServer((req, res) => {
  let body = '';
  req.on('data', c => { body += c; });
  req.on('end', () => {
    if (req.method === 'POST') {
      const p = JSON.parse(body);
      const issue = p.data?.issue || {};
      if ((issue.subject || '').startsWith(TAG)) {
        received.push({ type: p.type, id: issue.id, subject: issue.subject, at: new Date().toISOString() });
      }
      res.end('OK');
      return;
    }
    const rows = received.map(r =>
      `<tr><td>${r.at}</td><td>${r.type}</td><td>#${r.id}</td><td>${r.subject}</td></tr>`).join('');
    res.setHeader('content-type', 'text/html; charset=utf-8');
    res.end(`<!doctype html><title>Webhook receiver</title>
<style>body{font:14px sans-serif;margin:24px}td,th{border:1px solid #ccc;padding:4px 8px}
table{border-collapse:collapse}h1{font-size:20px}.n{font-size:28px;font-weight:bold}</style>
<h1>Webhook receiver at http://${HOST}:${PORT}/hook</h1>
<p>Redmine worktree: <code>${WORKTREE}</code>, job adapter: development default (:async)</p>
<p>${RUNS} separate <code>rake redmine:email:read</code> runs, one mail each, each creating one issue
tagged <code>${TAG}</code>.</p>
<p class="n">${received.length} of ${RUNS} issue.created webhooks received</p>
<table><tr><th>received at</th><th>event</th><th>issue</th><th>subject</th></tr>${rows}</table>`);
  });
});
await new Promise(r => receiver.listen(PORT, HOST, r));

// Asynchronous on purpose: spawnSync would block this process's event loop, so
// the receiver above could not answer until Redmine's 60 s read timeout, and a
// delivery would be counted that Redmine itself logged as failed.
function rails(args, input) {
  return new Promise(resolve => {
    const child = spawn('bundle', ['exec', 'ruby', 'bin/rails', ...args], {
      cwd: WORKTREE, env: { ...process.env, RAILS_ENV: 'development' }
    });
    let stdout = '', stderr = '';
    child.stdout.on('data', c => { stdout += c; });
    child.stderr.on('data', c => { stderr += c; });
    child.on('close', status => resolve({ status, stdout, stderr }));
    child.stdin.end(input || '');
  });
}

const hookUrl = MODE === 'unreachable' ? `http://${HOST}:${PORT + 1}/hook` : `http://${HOST}:${PORT}/hook`;
// Issue is referenced first because it registers its webhook events when it is
// loaded, and development does not eager-load (redmine.org #44454).
const setup = await rails(['runner', `
  Issue
  Setting.webhooks_enabled = '${MODE === 'disabled' ? 0 : 1}'
  admin = User.find_by_login!('admin')
  hook = Webhook.find_or_initialize_by(user: admin)
  hook.url = '${hookUrl}'
  hook.events = ['issue.created']
  hook.projects = [Project.find('geoxyz-verify')]
  hook.active = true
  hook.save!
  puts admin.mail
`]);
if (setup.status !== 0) throw new Error(`setup failed:\n${setup.stderr}`);
const from = setup.stdout.trim().split('\n').pop();

const runs = [];
for (let i = 1; i <= RUNS; i++) {
  const mail = [
    `From: ${from}`,
    'To: redmine@example.net',
    `Subject: ${TAG} #${i}`,
    `Message-ID: <rwf-${Date.now()}-${i}@example.net>`,
    `Date: ${new Date().toUTCString()}`,
    '',
    `Mail ${i} of ${RUNS}, received by rake redmine:email:read.`,
    ''
  ].join('\r\n');
  const t0 = Date.now();
  const r = await rails(['redmine:email:read', 'project=geoxyz-verify'], mail);
  runs.push({ i, status: r.status, ms: Date.now() - t0 });
  if (r.status !== 0) console.log(r.stderr);
}
// Anything still in flight from a process that already exited is lost; give a
// straggler every chance to arrive before counting.
await new Promise(r => setTimeout(r, 3000));

const count = await rails(['runner', `puts Issue.where("subject LIKE ?", "${TAG}%").count`]);
const issues = Number(count.stdout.trim().split('\n').pop());
console.log(`${PREFIX}/${MODE}: runs`, runs);
console.log(`${PREFIX}/${MODE}: ${issues} issues created, ${received.length} webhooks received`);

const s = await session(process.env.SHOT_DIR || '/tmp');
const name = MODE === 'deliver' ? PREFIX : `${PREFIX}-${MODE}`;
const q = encodeURIComponent(TAG);
await s.go(`/projects/geoxyz-verify/issues?set_filter=1&f[]=subject&op[subject]=~&v[subject][]=${q}` +
           '&c[]=tracker&c[]=subject&c[]=author&c[]=created_on&sort=id');
await s.shot(`${name}-issues`,
  `${issues} issues created by ${RUNS} rake redmine:email:read runs (${PREFIX}, ${MODE})`);
await s.page.goto(`http://${HOST}:${PORT}/`);
await s.shot(`${name}-receiver`,
  `${received.length} of ${RUNS} issue.created webhooks reached the receiver (${PREFIX}, ${MODE})`);
if (MODE === 'deliver') {
  await s.go('/webhooks');
  await s.shot(`${name}-webhook-config`, `The webhook used for this run (${PREFIX})`);
}
report(s.shots);
await s.browser.close();
receiver.close();

await rails(['runner', `Setting.webhooks_enabled = '0'`]);

// The script asserts what each pass must show, so a screenshot cannot quietly
// disagree with the claim next to it.
const expected = MODE === 'deliver' ? RUNS : 0;
const ok = issues === RUNS && runs.every(r => r.status === 0) &&
  (PREFIX === 'before' ? true : received.length === expected);
console.log(ok ? 'PASS' : 'FAIL', `${name}: issues ${issues}/${RUNS}, webhooks ${received.length}/${expected}`);
process.exit(ok ? 0 : 1);
