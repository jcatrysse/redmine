// G9 verification for webhook-tracker-filter.
//
//   SHOT_DIR=docs/features/webhook-tracker-filter/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/webhook-tracker-filter.mjs
//
// EXPECT_UNFIXED=1 runs the last two steps against a tree with this round's
//              two model changes removed — the `tracker_ids=` writer and the
//              `deactivate_webhooks` callback — which is what the first version
//              of this patch was. A forged tracker id then reaches Rails' own
//              writer and ends in ActiveRecord::RecordNotFound, and a hook whose
//              only tracker is deleted stays active and starts firing for every
//              tracker. Those two are shot as before-*. Every other shot of the
//              run is unaffected, so the run is repeated without the flag.
//
// MODE=before  runs against the unpatched instance: there is no tracker
//              fieldset on the form at all, and every issue of every tracker is
//              delivered. Shots are named before-*.
// MODE=after   runs against the patched instance: a hook limited to one tracker
//              delivers only that tracker's issues, and a hook with no tracker
//              selected still delivers everything.
//
// The delivery itself is the feature, and a screenshot cannot show an outgoing
// POST. So the receiver below both records deliveries and serves them as an
// HTML page, which is what gets photographed — real deliveries from the real
// app, not a claim about them.
//
// It binds to the container's own address, not to loopback:
// WebhookEndpointValidator rejects loopback and link-local unconditionally, so
// http://127.0.0.1/... can never be saved as a webhook URL.
import http from 'node:http';
import { session, report } from '../tools/verify-lib.mjs';

const HOST = process.env.RECEIVER_HOST || '192.0.2.2';
const PORT = Number(process.env.RECEIVER_PORT || 9099);
const HOOK_URL = `http://${HOST}:${PORT}/hook`;
const PROJECT = 'geoxyz-verify';
const PROJECT_LABEL = 'GEOxyz verification';
const PASSWORD = process.env.REDMINE_PASSWORD || 'GEOxyzDev123!';

const mode = process.env.MODE || 'before';
const prefix = mode === 'before' ? 'before-' : '';
const after = mode !== 'before';
const failures = [];

let deliveries = [];

const receiver = http.createServer((req, res) => {
  if (req.method === 'POST') {
    let body = '';
    req.on('data', c => { body += c; });
    req.on('end', () => {
      let p = null;
      try { p = JSON.parse(body); } catch { /* record it raw */ }
      const issue = p && p.data && p.data.issue;
      deliveries.push({
        at: new Date().toISOString().replace('T', ' ').slice(0, 19),
        type: (p && p.type) || '(unparsable)',
        tracker: (issue && issue.tracker && issue.tracker.name) || '—',
        subject: (issue && issue.subject) || '—',
      });
      res.writeHead(200, { 'content-type': 'text/plain' });
      res.end('OK');
    });
    return;
  }
  const rows = deliveries.map((d, i) => `<tr><td>${i + 1}</td><td>${d.at}</td>` +
    `<td><code>${d.type}</code></td><td><b>${d.tracker}</b></td><td>${d.subject}</td></tr>`).join('');
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  res.end(`<!doctype html><meta charset="utf-8"><title>Webhook deliveries</title>
<style>body{font:14px/1.5 system-ui,sans-serif;margin:2em;color:#222}
h1{font-size:1.3em}table{border-collapse:collapse;margin-top:1em}
th,td{border:1px solid #bbb;padding:.4em .8em;text-align:left}
th{background:#eee}.none{color:#a00;font-weight:bold;margin-top:1em}
code{background:#f4f4f4;padding:.1em .3em}</style>
<h1>Webhook deliveries received at ${HOOK_URL}</h1>
<p>${deliveries.length} POST request(s) received from Redmine.</p>
${deliveries.length ? `<table><thead><tr><th>#</th><th>Received at</th><th>Event</th><th>Tracker</th><th>Issue subject</th></tr></thead><tbody>${rows}</tbody></table>` : '<p class="none">No delivery received.</p>'}`);
});

await new Promise((resolve, reject) => {
  receiver.on('error', reject);
  receiver.listen(PORT, HOST, resolve);
});
console.log(`receiver listening on ${HOOK_URL}`);

const unfixed = process.env.EXPECT_UNFIXED === '1';
const s = await session(process.env.SHOT_DIR);

// The hook is saved and the issues are created through the UI, and both are
// admin actions, so sudo mode may interpose a password confirmation. Redmine's
// own tests stub it off; a browser has to answer it.
// The settings page renders every tab at once, so it holds eleven submit
// buttons of which ten are hidden. Every submit here is therefore scoped to the
// form that owns the field being saved, never to 'input[type=submit]'.
async function submitForm(fieldSelector) {
  await s.page.locator(`form:has(${fieldSelector}) input[type=submit]`).first().click();
  await s.page.waitForLoadState('networkidle');
  if (await s.page.locator('#sudo_password').count()) {
    await s.page.fill('#sudo_password', PASSWORD);
    await s.page.locator('form:has(#sudo_password) input[type=submit]').first().click();
    await s.page.waitForLoadState('networkidle');
  }
}

// The project and tracker check boxes are rendered without ids (:id => nil), so
// they are addressed through the label text that sits in the same <label>.
async function valueForLabel(selector, text) {
  return s.page.locator(selector).evaluateAll((els, t) => {
    for (const el of els) {
      const label = el.closest('label');
      if (label && label.textContent.trim() === t) return el.value;
    }
    return null;
  }, text);
}

// Deletes a tracker by name from the administration list, if it is there.
// Returns whether it found one to delete.
async function deleteTracker(name) {
  await s.go('/trackers');
  const link = s.page.locator(`tr:has(td.name a:text-is("${name}")) td.buttons a.icon-del`);
  if (!(await link.count())) return false;
  s.page.once('dialog', d => d.accept());
  await link.first().click();
  await s.page.waitForLoadState('networkidle');
  if (await s.page.locator('#sudo_password').count()) {
    await s.page.fill('#sudo_password', PASSWORD);
    await s.page.locator('form:has(#sudo_password) input[type=submit]').first().click();
    await s.page.waitForLoadState('networkidle');
  }
  return true;
}

async function waitForDeliveries(count, seconds = 25) {
  for (let i = 0; i < seconds * 4; i++) {
    if (deliveries.length >= count) return true;
    await new Promise(r => setTimeout(r, 250));
  }
  return deliveries.length >= count;
}

// 0. Webhooks are off by default (they are a security-relevant feature), so the
//    setting has to be on before any of this exists.
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

// 2. The form itself. This is the whole user-visible surface of the change: a
//    check box per tracker, and a hint saying what leaving them all unchecked
//    means.
await s.go('/webhooks/new');
const trackerBoxes = await s.page.locator('input[name="webhook[tracker_ids][]"][type=checkbox]').count();
const trackerNames = await s.page.locator('#webhook_tracker_ids label').evaluateAll(
  els => els.map(e => e.textContent.trim())
);
if (after && trackerBoxes < 3) {
  failures.push(`webhook-form: expected a check box per tracker, found ${trackerBoxes}`);
}
if (!after && trackerBoxes !== 0) {
  failures.push(`before-webhook-form: expected no tracker check box on unpatched code, found ${trackerBoxes}`);
}
if (after && !(await s.page.locator('#webhook_tracker_ids em.info').count())) {
  failures.push('webhook-form: the "leave unchecked" hint is missing');
}
await s.shot(
  `${prefix}webhook-form`,
  after
    ? `New webhook form — a check box per tracker (${trackerNames.join(', ')}) and the hint that leaving them unchecked sends every tracker`
    : 'New webhook form on unpatched code — the form offers projects only, there is no way to limit a hook to a tracker'
);

// 3. Create the hook. In "after" mode it is limited to Bug; in "before" mode
//    that is not expressible, which is the point.
await s.page.fill('#webhook_url', HOOK_URL);
if (!(await s.page.locator('#webhook_active').isChecked())) {
  await s.page.check('#webhook_active');
}
await s.page.check('input[name="webhook[events][]"][value="issue.created"]');
const projectValue = await valueForLabel('input[name="webhook[project_ids][]"]', PROJECT_LABEL);
if (!projectValue) failures.push(`setup: project check box "${PROJECT_LABEL}" not found`);
await s.page.check(`input[name="webhook[project_ids][]"][value="${projectValue}"]`);
if (after) {
  const bugValue = await valueForLabel('input[name="webhook[tracker_ids][]"]', 'Bug');
  if (!bugValue) failures.push('setup: tracker check box "Bug" not found');
  await s.page.check(`input[name="webhook[tracker_ids][]"][value="${bugValue}"]`);
}
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
if (after) {
  const checked = await s.page.locator('input[name="webhook[tracker_ids][]"]:checked').evaluateAll(
    els => els.map(e => (e.closest('label') || {}).textContent.trim())
  );
  if (checked.length !== 1 || checked[0] !== 'Bug') {
    failures.push(`edit form: expected only Bug checked, got ${JSON.stringify(checked)}`);
  }
  await s.shot('webhook-form-edit-selected',
    'The saved hook re-opened — Bug is checked and the other trackers are not, so the selection round-trips');
}

// 5. Create one issue per tracker and watch what arrives.
async function createIssue(trackerName, subject) {
  await s.go(`/projects/${PROJECT}/issues/new`);
  const options = await s.page.locator('#issue_tracker_id option').evaluateAll(
    els => Object.fromEntries(els.map(e => [e.textContent.trim(), e.value]))
  );
  if (!options[trackerName]) {
    failures.push(`setup: tracker "${trackerName}" not available in ${PROJECT}`);
    return;
  }
  await s.page.selectOption('#issue_tracker_id', options[trackerName]);
  await s.page.waitForLoadState('networkidle');
  await s.page.fill('#issue_subject', subject);
  await submitForm('#issue_subject');
}

const stamp = Date.now();
deliveries = [];
await createIssue('Bug', `Webhook verify BUG ${stamp}`);
await waitForDeliveries(1);
await createIssue('Feature', `Webhook verify FEATURE ${stamp}`);
// Give the second issue as long as the first one had to arrive, so "nothing
// arrived" is a conclusion and not a race.
await waitForDeliveries(2);

const trackersSeen = deliveries.map(d => d.tracker).sort();
if (after) {
  if (deliveries.length !== 1 || trackersSeen[0] !== 'Bug') {
    failures.push(`filtered delivery: expected exactly one Bug delivery, got ${JSON.stringify(deliveries)}`);
  }
} else if (deliveries.length !== 2 || trackersSeen.join(',') !== 'Bug,Feature') {
  failures.push(`unfiltered delivery: expected a Bug and a Feature delivery, got ${JSON.stringify(deliveries)}`);
}
await s.page.goto(`http://${HOST}:${PORT}/deliveries`);
await s.shot(
  `${prefix}deliveries-tracker-selected`,
  after
    ? 'Hook limited to Bug — one issue of each tracker was created and only the Bug issue was delivered'
    : 'Unpatched code — one issue of each tracker was created and both were delivered, because a hook cannot be limited to a tracker'
);

// 6. Failure path, and the backwards-compatibility case in one: clear the
//    tracker selection and everything is delivered again, exactly as before the
//    change. An installation that upgrades has no trackers selected anywhere,
//    so this is the behaviour every existing hook keeps.
if (after) {
  await s.go(editHref);
  for (const v of await s.page.locator('input[name="webhook[tracker_ids][]"]:checked').evaluateAll(els => els.map(e => e.value))) {
    await s.page.uncheck(`input[name="webhook[tracker_ids][]"][value="${v}"]`);
  }
  await submitForm('#webhook_url');

  await s.go(editHref);
  const stillChecked = await s.page.locator('input[name="webhook[tracker_ids][]"]:checked').count();
  if (stillChecked !== 0) failures.push(`clearing trackers: ${stillChecked} still checked after save`);
  await s.shot('webhook-form-edit-none',
    'The same hook with every tracker check box cleared — the state every hook has after an upgrade');

  const stamp2 = Date.now();
  deliveries = [];
  await createIssue('Bug', `Webhook verify ALL BUG ${stamp2}`);
  await waitForDeliveries(1);
  await createIssue('Feature', `Webhook verify ALL FEATURE ${stamp2}`);
  await waitForDeliveries(2);
  const seen = deliveries.map(d => d.tracker).sort().join(',');
  if (seen !== 'Bug,Feature') {
    failures.push(`no-tracker delivery: expected both trackers delivered, got ${JSON.stringify(deliveries)}`);
  }
  await s.page.goto(`http://${HOST}:${PORT}/deliveries`);
  await s.shot('deliveries-no-tracker-selected',
    'The same hook with no tracker selected — both issues delivered, so an existing hook keeps firing for every tracker');
}

// 7. The hint in each of the five locales the patch ships. A translation
//    nobody looked at in a browser is a string, not a translation — and these
//    four are hand-written, so each one is asserted against the exact text in
//    its own locale file and then photographed.
if (after) {
  const LOCALES = [
    ['nl', 'Issue-gebeurtenissen worden alleen verstuurd voor de geselecteerde trackers.',
     'Dutch — "gebeurtenissen" from label_user_mail_option_all, "verstuurd" from text_select_mail_notifications, "Trackers" from label_tracker_plural'],
    ['fr', 'Les événements de demande ne sont envoyés que pour les trackers sélectionnés.',
     'French — "demande" from label_issue, "sélectionnés" from text_user_mail_option, "tous les trackers" from label_tracker_all, "événements" from label_webhook_events and from the webhook_url_info line right above it'],
    ['de', 'Ticket-Ereignisse werden nur für die ausgewählten Tracker gesendet.',
     'German — "Ticket" from label_issue, "Ereignisse" from label_webhook_events, "ausgewählten" from the webhook_url_info entry right above it'],
    ['es', 'Los eventos de peticiones solo se envían para los tipos seleccionados.',
     'Spanish — "peticiones" from label_issue_plural, and a tracker is a "tipo": "todos los tipos" from label_tracker_all'],
  ];
  for (const [loc, expected, caption] of LOCALES) {
    await s.go('/my/account');
    await s.page.selectOption('#user_language', loc);
    await submitForm('#user_language');
    await s.go('/webhooks/new');
    const hint = (await s.page.locator('#webhook_tracker_ids em.info').textContent()).trim();
    if (!hint.startsWith(expected)) {
      failures.push(`webhook-form-${loc}: hint reads "${hint}"`);
    }
    // The sentence is the whole evidence and it is small on a page-wide image,
    // so the fieldset itself is cropped as well.
    await s.shot(`webhook-form-${loc}`, `The form with the interface in ${caption}`);
    await s.page.locator('#webhook_tracker_ids').screenshot({
      path: `${process.env.SHOT_DIR}/hint-${loc}.png`,
    });
    s.shots.push({
      name: `hint-${loc}`,
      caption: `Just the Trackers fieldset in ${loc} — the legend is Redmine's own label_tracker_plural, the sentence is the new key`,
      file: `${process.env.SHOT_DIR}/hint-${loc}.png`,
      url: s.page.url(),
    });
  }
  await s.go('/my/account');
  await s.page.selectOption('#user_language', 'en');
  await submitForm('#user_language');
}

// 8. A forged tracker id. The check boxes only ever offer real ids, so an id
//    that does not exist means someone wrote the POST by hand. Rails' own
//    tracker_ids= writer answers that with ActiveRecord::RecordNotFound, which
//    is an internal error page rather than a rejected form; the writer on
//    Webhook drops the unknown id instead. Last, because in the error case the
//    request does not complete and the hook keeps whatever it had.
if (after) {
  await s.go(editHref);
  await s.page.evaluate(() => {
    const box = document.querySelector('input[name="webhook[tracker_ids][]"][type=checkbox]');
    box.value = '999999';
    box.checked = true;
  });
  await submitForm('#webhook_url');
  const body = await s.page.textContent('body');
  const errored = /RecordNotFound/.test(body);
  if (unfixed && !errored) {
    failures.push('forged tracker id: expected the unpatched writer to raise RecordNotFound');
  }
  if (!unfixed && errored) {
    failures.push('forged tracker id: the request ended in RecordNotFound');
  }
  if (!unfixed) {
    if (!/\/webhooks$/.test(s.page.url())) {
      failures.push(`forged tracker id: stayed on ${s.page.url()}`);
    }
    await s.go(editHref);
    const checked = await s.page.locator('input[name="webhook[tracker_ids][]"]:checked').count();
    if (checked !== 0) failures.push(`forged tracker id: ${checked} tracker(s) checked after the forged post`);
    await s.go('/webhooks');
  }
  await s.shot(
    unfixed ? 'before-forged-tracker-id' : 'forged-tracker-id',
    unfixed
      ? 'A hand-written POST with tracker_ids[]=999999 before the fix — Rails\' own writer raises ActiveRecord::RecordNotFound and the user gets an internal error instead of a rejected value'
      : 'The same POST with the fix — the unknown id is dropped, the hook is saved with no tracker selected, and the webhook list comes back normally'
  );
}

// 9. The tracker a hook is limited to is deleted. An empty tracker selection
//    means every tracker, so a hook left with nothing selected would start
//    firing for the whole project — the opposite of what its owner asked for.
//    Tracker#deactivate_webhooks switches those hooks off instead, so the hook
//    stops firing, the way it already does when its last project is deleted.
if (after) {
  const TEMP_TRACKER = 'Webhook verify temp';

  // A run that died between creating the tracker and deleting it would make
  // the next one fail on the name being taken, so start from a clean slate.
  await deleteTracker(TEMP_TRACKER);

  await s.go('/trackers/new');
  await s.page.fill('#tracker_name', TEMP_TRACKER);
  const status = s.page.locator('#tracker_default_status_id');
  if (!(await status.inputValue())) {
    const first = await status.locator('option[value!=""]').first().getAttribute('value');
    await status.selectOption(first);
  }
  await submitForm('#tracker_name');

  await s.go(editHref);
  for (const v of await s.page.locator('input[name="webhook[tracker_ids][]"]:checked').evaluateAll(els => els.map(e => e.value))) {
    await s.page.uncheck(`input[name="webhook[tracker_ids][]"][value="${v}"]`);
  }
  const tempValue = await valueForLabel('input[name="webhook[tracker_ids][]"]', TEMP_TRACKER);
  if (!tempValue) failures.push(`tracker deletion: check box "${TEMP_TRACKER}" not found on the hook`);
  await s.page.check(`input[name="webhook[tracker_ids][]"][value="${tempValue}"]`);
  await submitForm('#webhook_url');

  if (!(await deleteTracker(TEMP_TRACKER))) {
    failures.push(`tracker deletion: no delete link for "${TEMP_TRACKER}"`);
  }
  await s.go('/trackers');
  if (await s.page.locator(`td.name a:text-is("${TEMP_TRACKER}")`).count()) {
    failures.push(`tracker deletion: "${TEMP_TRACKER}" is still there`);
  }

  await s.go('/webhooks');
  const activeCell = (await s.page.locator('table.list tbody tr td').first().textContent()).trim();
  if (unfixed && activeCell !== 'Yes') {
    failures.push(`tracker deletion: expected the unfixed hook to stay active, Active reads "${activeCell}"`);
  }
  if (!unfixed && activeCell !== 'No') {
    failures.push(`tracker deletion: expected the hook to be deactivated, Active reads "${activeCell}"`);
  }
  await s.shot(
    unfixed ? 'before-tracker-destroyed' : 'tracker-destroyed',
    unfixed
      ? `The webhook after its only tracker ("${TEMP_TRACKER}") was deleted, before the fix — still Active, and with an empty selection it now fires for every tracker in its projects`
      : `The same deletion with the fix — the hook is switched off instead of widened, so it stops firing exactly as it would if its last project had been deleted`
  );
}

report(s.shots);
await s.browser.close();
receiver.close();

if (failures.length) {
  console.error(`\nFAIL (mode=${mode}):`);
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`\nPASS (mode=${mode})`);
