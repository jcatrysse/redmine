// G9 verification for mypage-query-blocks.
//
//   SHOT_DIR=docs/features/mypage-query-blocks/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/mypage-query-blocks.mjs
//
// MODE=before  runs against the unpatched instance: shots are named before-*.
//              The setting does not exist there, so every case asserts what the
//              old code does — three blocks, and no way to get a fourth.
// MODE=after   runs against the patched instance and asserts the new answer.
//
// The point of the before/after pair is the *second* shot: at the default of 3
// the two instances are identical, which is the answer to note-9 on #27313.
import { readFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { session, report } from '../tools/verify-lib.mjs';

const FIELD = '#settings_my_page_max_issuequery_blocks';

// The blocks are only worth looking at when they display something, so the run
// creates one public query and points every block at it.
const QUERY_NAME = 'Verification query';

// Redmine::MyPage::MAX_ISSUEQUERY_BLOCKS — kept in step by hand, and the run
// fails if the form ever stops refusing one above it.
const UPPER_BOUND = 20;

const mode = process.env.MODE || 'before';
const prefix = mode === 'before' ? 'before-' : '';
const after = mode !== 'before';
const s = await session(process.env.SHOT_DIR);
const failures = [];

// Reads the "Issues" entry of the add-block select, and grows the listbox so
// the entries are in the image and not only in the DOM.
async function issuesOption() {
  await s.go('/my/page');
  await s.page.locator('#block-select').evaluate(el => {
    el.size = el.options.length;
  });
  return s.page.locator('#block-select option').evaluateAll(els => {
    const el = els.find(e => e.textContent.trim() === 'Issues');
    return el ? {value: el.value, disabled: el.disabled} : null;
  });
}

// A disabled <option> is greyed by the browser, but at full-page scale the
// difference is a few pixels of text colour. Crop the select so the state is
// actually readable in the image. getComputedStyle reports the same colour
// either way, so the picture is the only place this shows.
async function shotSelect(name, caption) {
  const file = `${process.env.SHOT_DIR}/${name}.png`;
  // Park the pointer first: left where a click put it, the browser draws its
  // native tooltip over the listbox and the two runs no longer produce the
  // same image.
  await s.page.mouse.move(0, 0);
  await s.page.waitForTimeout(300);
  await s.page.locator('#block-select').screenshot({path: file});
  s.shots.push({name, caption, file, url: s.page.url()});
  return file;
}

function digest(file) {
  return createHash('sha256').update(readFileSync(file)).digest('hex');
}

// Creates the public query the blocks display. Idempotent: the dev database is
// shared between the two runs, so the second one finds it already there.
async function savedQueryExists() {
  // The issues sidebar is where a global public query shows up; the /queries
  // index does not list one that belongs to no project.
  await s.go('/issues');
  return (await s.page.locator(`#sidebar a:text-is("${QUERY_NAME}")`).count()) > 0;
}

async function ensureSavedQuery() {
  if (await savedQueryExists()) return;

  await s.go('/queries/new?type=IssueQuery');
  await s.page.fill('#query_name', QUERY_NAME);
  await s.page.check('#query_visibility_2');
  await s.page.check('#query_is_for_all');
  await s.page.click('input[type=submit]');
  await s.page.waitForLoadState('networkidle');
  if (!(await savedQueryExists())) {
    failures.push(`saved query: ${QUERY_NAME} was not created`);
  }
}

// A freshly added block shows a "Custom query" form, not an issue list. Point
// every unconfigured block at the saved query, one page load at a time because
// each save re-renders the page.
async function configureBlocks() {
  for (let i = 0; i < 20; i++) {
    await s.go('/my/page');
    const select = s.page.locator('.mypage-box select[name$="[query_id]"]').first();
    if (!(await select.count())) return;
    await select.selectOption({label: QUERY_NAME});
    await select.locator('xpath=ancestor::form').locator('input[type=submit]').click();
    await s.page.waitForLoadState('networkidle');
    await s.page.waitForTimeout(300);
  }
  failures.push('configureBlocks: blocks left unconfigured after 20 rounds');
}

async function blockCount() {
  return s.page.locator('.mypage-box[id^="block-issuequery"]').count();
}

// Starts from an empty My page in both modes, so the two runs are comparable.
async function clearBlocks() {
  await s.go('/my/page');
  for (let i = 0; i < 20; i++) {
    const close = s.page.locator('.mypage-box .icon-close').first();
    if (!(await close.count())) break;
    await close.click();
    await s.page.waitForTimeout(300);
  }
  await s.go('/my/page');
}

async function addBlock() {
  await s.page.selectOption('#block-select', {label: 'Issues'});
  await s.page.waitForTimeout(600);
  await s.page.waitForLoadState('networkidle');
}

// Returns false when the field is absent, which is the whole of the before case.
async function setMaximum(value) {
  await s.go('/settings?tab=general');
  if (!(await s.page.locator(FIELD).count())) return false;

  await s.page.fill(FIELD, String(value));
  await s.page.click('input[type=submit]');
  await s.page.waitForLoadState('networkidle');
  const stored = await s.page.locator(FIELD).inputValue();
  if (stored !== String(value)) failures.push(`setting: asked for ${value}, page shows ${stored}`);
  return true;
}

await ensureSavedQuery();

// 1. The setting itself. Absent before, present with its default of 3 after.
await s.go('/settings?tab=general');
const present = await s.page.locator(FIELD).count() > 0;
if (present !== after) {
  failures.push(`settings-general: field ${present ? 'present' : 'absent'} in mode ${mode}`);
}
if (after) {
  const value = await s.page.locator(FIELD).inputValue();
  if (value !== '3') failures.push(`settings-general: default is ${value}, expected 3`);
}
await s.shot(
  `${prefix}settings-general`,
  after
    ? 'Administration > Settings > General — the new field, at its default of 3'
    : 'Administration > Settings > General — there is no field for the limit'
);

// 2. The default is unchanged. Three blocks, and "Issues" is greyed out — the
//    same on both instances, which is what makes the patch safe to take.
await clearBlocks();
await addBlock();
await addBlock();
await addBlock();
await configureBlocks();
let option = await issuesOption();
if (!option) failures.push('dropdown-at-default-maximum: no Issues entry in the select');
if (option && !option.disabled) {
  failures.push(`dropdown-at-default-maximum: Issues is enabled (value ${option.value})`);
}
let count = await blockCount();
if (count !== 3) failures.push(`dropdown-at-default-maximum: ${count} blocks, expected 3`);
await s.shot(
  `${prefix}dropdown-at-default-maximum`,
  'Three issue query blocks at the default limit, and the add-block list beside them'
);
const defaultSelect = await shotSelect(
  `${prefix}select-at-default-maximum`,
  '"Issues" greyed out at the default of 3 — the same on both instances, which is what makes the patch safe to take'
);

// The note's central claim is that nothing changes at the default, so the run
// proves it rather than leaving it to a human to assert.
if (after) {
  const beforeShot = `${process.env.SHOT_DIR}/before-select-at-default-maximum.png`;
  if (!existsSync(beforeShot)) {
    failures.push('select-at-default-maximum: no before shot to compare with — run MODE=before first');
  } else if (digest(beforeShot) !== digest(defaultSelect)) {
    failures.push('select-at-default-maximum: the before/after pair is not the same image');
  }
}

// 3. Raising the limit re-enables the entry. Impossible before: the shot shows
//    the same greyed-out entry, because there is nothing to raise.
const raised = await setMaximum(5);
if (raised !== after) failures.push(`dropdown-raised-maximum: setting ${raised ? 'was' : 'was not'} settable in mode ${mode}`);
option = await issuesOption();
if (after) {
  if (option.disabled) failures.push('dropdown-raised-maximum: Issues still disabled at limit 5');
  if (option.value !== 'issuequery__3') {
    failures.push(`dropdown-raised-maximum: next block is ${option.value}, expected issuequery__3`);
  }
} else if (!option.disabled) {
  failures.push('dropdown-raised-maximum: Issues is enabled on the old code with three blocks');
}
await shotSelect(
  `${prefix}select-raised-maximum`,
  after
    ? 'Limit raised to 5 — "Issues" is black again, so a fourth block can be added'
    : 'The old code has no limit to raise, so "Issues" stays greyed out at three blocks'
);

// 4. And the fourth block actually appears.
if (after) {
  await addBlock();
  await configureBlocks();
  await s.go('/my/page');
  count = await blockCount();
  if (count !== 4) failures.push(`fourth-block: ${count} blocks, expected 4`);
} else {
  count = await blockCount();
  if (count !== 3) failures.push(`fourth-block: ${count} blocks, expected 3`);
}
await s.shot(
  `${prefix}fourth-block`,
  after ? 'A fourth issue query block on My page' : 'Three blocks is the ceiling on the old code',
  {full: true}
);

// 5. Failure path: lowering the limit below what a user already has must not
//    remove or break their blocks. It only stops them adding more.
if (after) {
  await setMaximum(1);
  option = await issuesOption();
  if (!option.disabled) failures.push('lowered-maximum: Issues is still enabled at limit 1');
  count = await blockCount();
  if (count !== 4) failures.push(`lowered-maximum: ${count} blocks left, expected the 4 to survive`);
  await s.shot(
    'lowered-maximum',
    'Limit lowered to 1 with four blocks already in place — all four still render, only adding is blocked',
    {full: true}
  );
  await shotSelect(
    'select-lowered-maximum',
    'The same lowered limit in the add-block list — "Issues" greyed out again'
  );
  await setMaximum(3);
}

// 6. Failure path: the setting has a range now, so a value outside it is
//    refused at the form instead of being stored and then quietly ignored.
if (after) {
  await s.go('/settings?tab=general');
  await s.page.fill(FIELD, String(UPPER_BOUND + 1));
  await s.page.click('input[type=submit]');
  await s.page.waitForLoadState('networkidle');
  if (!(await s.page.locator('#errorExplanation').count())) {
    failures.push(`rejected-out-of-range: ${UPPER_BOUND + 1} was accepted without an error`);
  }
  await s.page.mouse.move(0, 0);
  await s.shot(
    'rejected-out-of-range',
    'Above the upper bound the form refuses the value and says so, instead of storing it'
  );
  await s.go('/settings?tab=general');
  const kept = await s.page.locator(FIELD).inputValue();
  if (kept !== '3') failures.push(`rejected-out-of-range: stored value is ${kept}, expected 3`);

  // 7. And the low end of that range: 0 means no new query blocks at all,
  //    which is what note-5 on #27313 asked for.
  await setMaximum(0);
  option = await issuesOption();
  if (!option.disabled) failures.push('zero-maximum: Issues is still enabled at limit 0');
  count = await blockCount();
  if (count !== 4) failures.push(`zero-maximum: ${count} blocks left, expected the 4 to survive`);
  await shotSelect(
    'select-zero-maximum',
    'Limit 0 — no new custom query block can be added, and the four already on the page still render'
  );
  await setMaximum(3);
}

report(s.shots);
await s.browser.close();

if (failures.length) {
  console.error(`\nFAIL (mode=${mode}):`);
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`\nPASS (mode=${mode})`);
