// G9 verification for webhook-issue-closed.
//
//   SHOT_DIR=docs/features/webhook-issue-closed/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/webhook-issue-closed.mjs
//
// MODE=before  runs against the unpatched instance: the events fieldset has no
//              "Issue closed" check box, so the only way to hear about a
//              closing is to subscribe to issue.updated and receive every
//              other change too. Shots are named before-*.
// MODE=after   runs against the patched instance: a hook subscribed only to
//              issue.closed receives exactly one delivery per closing.
//
// Both modes drive the same seven-step life cycle of one issue through the UI:
// create, note, status change to another open status, close, move to a second
// closed status, reopen, close again. What differs is what arrives.
//
// The delivery is the feature and a screenshot cannot show an outgoing POST,
// so the receiver below records deliveries and serves them as an HTML page,
// which is what gets photographed — real deliveries from the real app.
//
// It binds to the container's own address, not to loopback:
// WebhookEndpointValidator rejects loopback and link-local unconditionally, so
// http://127.0.0.1/... can never be saved as a webhook URL.
import http from 'node:http';
import { session, report } from '../tools/verify-lib.mjs';

const HOST = process.env.RECEIVER_HOST || '192.0.2.2';
const PORT = Number(process.env.RECEIVER_PORT || 9098);
const HOOK_URL = `http://${HOST}:${PORT}/hook`;
const PROJECT = 'geoxyz-verify';
const PROJECT_LABEL = 'GEOxyz verification';
const PASSWORD = process.env.REDMINE_PASSWORD || 'GEOxyzDev123!';

const mode = process.env.MODE || 'before';
const prefix = mode === 'before' ? 'before-' : '';
const after = mode !== 'before';
const failures = [];

// In "after" mode the hook subscribes to the new event only. In "before" mode
// that event does not exist, so the nearest thing a receiver can do is
// subscribe to issue.updated — and that is exactly the problem being shown.
const SUBSCRIBED = after ? 'issue.closed' : 'issue.updated';

let deliveries = [];

const receiver = http.createServer((req, res) => {
  if (req.method === 'POST') {
    let body = '';
    req.on('data', c => { body += c; });
    req.on('end', () => {
      let p = null;
      try { p = JSON.parse(body); } catch { /* record it raw */ }
      const issue = p && p.data && p.data.issue;
      const journal = p && p.data && p.data.journal;
      deliveries.push({
        at: new Date().toISOString().replace('T', ' ').slice(0, 19),
        type: (p && p.type) || '(unparsable)',
        status: (issue && issue.status && issue.status.name) || '—',
        notes: (journal && journal.notes) || '',
        details: journal ? journal.details.map(d => d.prop_key).join(', ') : '',
      });
      res.writeHead(200, { 'content-type': 'text/plain' });
      res.end('OK');
    });
    return;
  }
  const rows = deliveries.map((d, i) => `<tr><td>${i + 1}</td><td>${d.at}</td>` +
    `<td><code>${d.type}</code></td><td><b>${d.status}</b></td><td>${d.notes}</td>` +
    `<td>${d.details}</td></tr>`).join('');
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  res.end(`<!doctype html><meta charset="utf-8"><title>Webhook deliveries</title>
<style>body{font:14px/1.5 system-ui,sans-serif;margin:2em;color:#222}
h1{font-size:1.3em}table{border-collapse:collapse;margin-top:1em}
th,td{border:1px solid #bbb;padding:.4em .8em;text-align:left}
th{background:#eee}.none{color:#a00;font-weight:bold;margin-top:1em}
code{background:#f4f4f4;padding:.1em .3em}</style>
<h1>Webhook deliveries received at ${HOOK_URL}</h1>
<p>Hook subscribed to <code>${SUBSCRIBED}</code> only.
${deliveries.length} POST request(s) received from Redmine.</p>
${deliveries.length ? `<table><thead><tr><th>#</th><th>Received at</th><th>Event</th><th>Issue status</th><th>Note</th><th>Journal details</th></tr></thead><tbody>${rows}</tbody></table>` : '<p class="none">No delivery received.</p>'}`);
});

await new Promise((resolve, reject) => {
  receiver.on('error', reject);
  receiver.listen(PORT, HOST, resolve);
});
console.log(`receiver listening on ${HOOK_URL}`);

const s = await session(process.env.SHOT_DIR);

// The settings page renders every tab at once, so it holds eleven submit
// buttons of which ten are hidden. Every submit is therefore scoped to the
// form that owns the field being saved, never to 'input[type=submit]'.
// Admin actions may also hit sudo mode, which a browser has to answer.
async function submitForm(fieldSelector) {
  await s.page.locator(`form:has(${fieldSelector}) input[type=submit]`).first().click();
  await s.page.waitForLoadState('networkidle');
  if (await s.page.locator('#sudo_password').count()) {
    await s.page.fill('#sudo_password', PASSWORD);
    await s.page.locator('form:has(#sudo_password) input[type=submit]').first().click();
    await s.page.waitForLoadState('networkidle');
  }
}

// The project check boxes are rendered without ids (:id => nil), so they are
// addressed through the label text that sits in the same <label>.
async function valueForLabel(selector, text) {
  return s.page.locator(selector).evaluateAll((els, t) => {
    for (const el of els) {
      const label = el.closest('label');
      if (label && label.textContent.trim() === t) return el.value;
    }
    return null;
  }, text);
}

async function waitForDeliveries(count, seconds = 25) {
  for (let i = 0; i < seconds * 4; i++) {
    if (deliveries.length >= count) return true;
    await new Promise(r => setTimeout(r, 250));
  }
  return deliveries.length >= count;
}

// 0. Webhooks are off by default (they are a security-relevant feature), so
//    the setting has to be on before any of this exists.
await s.go('/settings?tab=integrations');
if (!(await s.page.locator('#settings_webhooks_enabled').isChecked())) {
  await s.page.check('#settings_webhooks_enabled');
  await submitForm('#settings_webhooks_enabled');
}
await s.go('/settings?tab=integrations');
if (!(await s.page.locator('#settings_webhooks_enabled').isChecked())) {
  failures.push('setup: could not enable webhooks');
}

// 1. Start from no hooks, so the delivery counts below mean what they say.
await s.go('/webhooks');
while (await s.page.locator('td.buttons a.icon-del').count()) {
  s.page.once('dialog', d => d.accept());
  await s.page.locator('td.buttons a.icon-del').first().click();
  await s.page.waitForLoadState('networkidle');
  if (await s.page.locator('#sudo_password').count()) {
    await s.page.fill('#sudo_password', PASSWORD);
    await s.page.locator('form:has(#sudo_password) input[type=submit]').first().click();
    await s.page.waitForLoadState('networkidle');
  }
  await s.go('/webhooks');
}

// 2. The form. This is the whole user-visible surface of the change: one more
//    check box in the Issues fieldset, and nothing else anywhere.
await s.go('/webhooks/new');
const issueEvents = await s.page.locator('#issue_events label').evaluateAll(
  els => els.map(e => e.textContent.trim())
);
const closedBox = await s.page.locator('input[name="webhook[events][]"][value="issue.closed"]').count();
if (after && closedBox !== 1) {
  failures.push(`webhook-form: expected an "issue.closed" check box, found ${closedBox}`);
}
if (!after && closedBox !== 0) {
  failures.push(`before-webhook-form: expected no "issue.closed" check box on unpatched code, found ${closedBox}`);
}
if (after && !issueEvents.includes('Issue closed')) {
  failures.push(`webhook-form: label "Issue closed" missing, fieldset reads ${JSON.stringify(issueEvents)}`);
}
if (!after && issueEvents.length !== 3) {
  failures.push(`before-webhook-form: expected three issue events, got ${JSON.stringify(issueEvents)}`);
}
await s.shot(
  `${prefix}webhook-form`,
  after
    ? `New webhook form — the Issues fieldset now offers ${issueEvents.join(', ')}`
    : `New webhook form on unpatched code — the Issues fieldset offers only ${issueEvents.join(', ')}, so a closing cannot be subscribed to`
);

// The fieldset is a few lines on a page-wide image, so crop it as well: this
// pair is the only visual difference the patch makes.
await s.page.locator('#issue_events').screenshot({
  path: `${process.env.SHOT_DIR}/${prefix}issue-events.png`,
});
s.shots.push({
  name: `${prefix}issue-events`,
  caption: after
    ? 'Just the Issues fieldset — four check boxes, "Issue closed" between updated and deleted'
    : 'Just the Issues fieldset on unpatched code — three check boxes, no way to say "closed"',
  file: `${process.env.SHOT_DIR}/${prefix}issue-events.png`,
  url: s.page.url(),
});

// 3. Create the hook, subscribed to the one event this mode can express.
await s.page.fill('#webhook_url', HOOK_URL);
if (!(await s.page.locator('#webhook_active').isChecked())) {
  await s.page.check('#webhook_active');
}
await s.page.check(`input[name="webhook[events][]"][value="${SUBSCRIBED}"]`);
const projectValue = await valueForLabel('input[name="webhook[project_ids][]"]', PROJECT_LABEL);
if (!projectValue) failures.push(`setup: project check box "${PROJECT_LABEL}" not found`);
await s.page.check(`input[name="webhook[project_ids][]"][value="${projectValue}"]`);
await submitForm('#webhook_url');
if (!/\/webhooks$/.test(s.page.url())) {
  const err = await s.page.locator('#errorExplanation').textContent().catch(() => '');
  failures.push(`create hook: stayed on ${s.page.url()} ${err}`);
}

// 4. Re-open it. A selection that is not shown back is a selection the next
//    editor silently drops.
await s.go('/webhooks');
const editHref = await s.page.locator('td.buttons a.icon-edit').first().getAttribute('href');
await s.go(editHref);
const checkedEvents = await s.page.locator('input[name="webhook[events][]"]:checked').evaluateAll(
  els => els.map(e => e.value)
);
if (checkedEvents.length !== 1 || checkedEvents[0] !== SUBSCRIBED) {
  failures.push(`edit form: expected only ${SUBSCRIBED} checked, got ${JSON.stringify(checkedEvents)}`);
}
if (after) {
  await s.shot('webhook-form-edit-selected',
    'The saved hook re-opened — only "Issue closed" is checked, so the selection round-trips');
}

// 5. One issue, seven changes, of which exactly two are closings.
async function newIssue(subject) {
  await s.go(`/projects/${PROJECT}/issues/new`);
  await s.page.fill('#issue_subject', subject);
  await submitForm('#issue_subject');
  const m = s.page.url().match(/\/issues\/(\d+)/);
  if (!m) {
    failures.push(`setup: could not create issue, landed on ${s.page.url()}`);
    return null;
  }
  return m[1];
}

// Redmine's default data ships New, In Progress, Resolved, Feedback, Closed
// and Rejected; Closed and Rejected are the two closed ones.
async function changeIssue(id, { status, notes }) {
  await s.go(`/issues/${id}/edit`);
  if (status) {
    const options = await s.page.locator('#issue_status_id option').evaluateAll(
      els => Object.fromEntries(els.map(e => [e.textContent.trim(), e.value]))
    );
    if (!options[status]) {
      failures.push(`setup: status "${status}" not available on issue ${id} (has ${Object.keys(options).join(', ')})`);
      return;
    }
    await s.page.selectOption('#issue_status_id', options[status]);
  }
  if (notes) await s.page.fill('#issue_notes', notes);
  await submitForm('#issue_status_id');
}

const stamp = Date.now();
deliveries = [];
const issueId = await newIssue(`Webhook closed verify ${stamp}`);

// The seven steps, in order. Only steps 3 and 6 are closings.
await changeIssue(issueId, { notes: 'a plain note, no status change' });
await changeIssue(issueId, { status: 'In Progress', notes: 'still open' });
await changeIssue(issueId, { status: 'Closed', notes: 'closing it — delivery expected' });
await waitForDeliveries(after ? 1 : 3);
await changeIssue(issueId, { status: 'Rejected', notes: 'closed to closed, no second closing' });
await changeIssue(issueId, { status: 'In Progress', notes: 'reopened' });
await changeIssue(issueId, { status: 'Closed', notes: 'closing it again — delivery expected' });
// Give the last change as long as the first one had, so "nothing more arrived"
// is a conclusion and not a race.
await waitForDeliveries(after ? 2 : 6);
await new Promise(r => setTimeout(r, 3000));

const types = deliveries.map(d => d.type);
if (after) {
  if (deliveries.length !== 2 || types.join(',') !== 'issue.closed,issue.closed') {
    failures.push(`expected exactly two issue.closed deliveries, got ${JSON.stringify(deliveries)}`);
  }
  const statuses = deliveries.map(d => d.status).join(',');
  if (statuses !== 'Closed,Closed') {
    failures.push(`expected both deliveries to carry a closed status, got ${statuses}`);
  }
  if (!deliveries.every(d => d.notes)) {
    failures.push(`expected the closing note in every delivery, got ${JSON.stringify(deliveries.map(d => d.notes))}`);
  }
} else if (deliveries.length !== 6) {
  failures.push(`expected six issue.updated deliveries on unpatched code, got ${JSON.stringify(deliveries)}`);
}

await s.page.goto(`http://${HOST}:${PORT}/deliveries`);
await s.shot(
  `${prefix}deliveries`,
  after
    ? 'Hook subscribed to Issue closed only — the same seven changes produced exactly two deliveries, one per closing, each carrying the closing note'
    : 'Unpatched code, hook subscribed to Issue updated — the same seven changes produced six deliveries, and the receiver has to work out which two were closings'
);

// 6. The failure path that matters most: with the setting off, nothing is
//    delivered at all. Same hook, same closing.
if (after) {
  await s.go('/settings?tab=integrations');
  await s.page.uncheck('#settings_webhooks_enabled');
  await submitForm('#settings_webhooks_enabled');

  deliveries = [];
  await changeIssue(issueId, { status: 'In Progress', notes: 'reopened with webhooks off' });
  await changeIssue(issueId, { status: 'Closed', notes: 'closed with webhooks off — no delivery expected' });
  await new Promise(r => setTimeout(r, 6000));
  if (deliveries.length !== 0) {
    failures.push(`webhooks disabled: expected no delivery, got ${JSON.stringify(deliveries)}`);
  }
  await s.page.goto(`http://${HOST}:${PORT}/deliveries`);
  await s.shot('deliveries-webhooks-disabled',
    'The same hook with "Enable webhooks" turned off — the issue was reopened and closed again and nothing was delivered');

  await s.go('/settings?tab=integrations');
  await s.page.check('#settings_webhooks_enabled');
  await submitForm('#settings_webhooks_enabled');
}

// 7. The issue itself, so the journal the receiver was sent can be read next
//    to the deliveries it produced.
await s.go(`/issues/${issueId}`);
await s.shot(`${prefix}issue-history`,
  'The issue that produced the deliveries above — its full journal, with the two closings among the other changes',
  { full: true });

report(s.shots);
await s.browser.close();
receiver.close();

if (failures.length) {
  console.error(`\nFAIL (mode=${mode}):`);
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`\nPASS (mode=${mode})`);
