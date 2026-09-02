// G9 verification for assignee-nobody.
//
//   SHOT_DIR=docs/features/assignee-nobody/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/assignee-nobody.mjs
//
// MODE=before  runs against the unpatched instance: shots are named before-*,
//              and every case asserts what the old code does — which for four
//              of the six operators is an error page, and for one is a silently
//              empty result.
// MODE=after   runs against the patched instance and asserts the right answer.
//
// The seeded project (tools/dev-seed.rb) has, among its open issues:
//   4 unassigned, 4 assigned to `dev` and 1 assigned to `tester`. One of
//   dev's ("Picked up from the queue") carries a journal recording the change
//   from nobody. Those counts are what the cases below expect.
import { session, report } from '../tools/verify-lib.mjs';

const PROJECT = '/projects/geoxyz-verify';
const mode = process.env.MODE || 'before';
const prefix = mode === 'before' ? 'before-' : '';
const s = await session(process.env.SHOT_DIR);

// The user ids are not fixed by the seed, so look them up through the page the
// filter itself uses.
async function userId(login) {
  await s.go(`/users?name=${login}`);
  const href = await s.page.locator('table.users tbody tr td.login a').first().getAttribute('href');
  return href.split('/')[2];
}
const dev = await userId('dev');

// error   — the old code puts 'none' into a comparison with an integer column
// silent  — no error, but the result is wrong: nothing matches the literal 'none'
const cases = [
  {
    name: 'is-nobody-or-dev',
    op: '=',
    values: ['none', dev],
    before: 'error',
    after: 8,
    caption: 'Assignee is nobody or dev — the queue plus what dev already has',
  },
  {
    name: 'is-not-nobody-or-dev',
    op: '!',
    values: ['none', dev],
    before: 'error',
    after: 1,
    caption: 'Assignee is neither nobody nor dev — only the tester issue is left',
  },
  {
    name: 'is-nobody-alone',
    op: '=',
    values: ['none'],
    before: 'error',
    after: 4,
    caption: 'Assignee is nobody, selected as a value — same as the none operator',
  },
  {
    name: 'has-been-nobody',
    op: 'ev',
    values: ['none'],
    before: 'error',
    after: 5,
    caption: 'Assignee has been nobody — the queue plus the issue picked up from it',
  },
  {
    name: 'has-never-been-nobody',
    op: '!ev',
    values: ['none'],
    before: 'error',
    after: 4,
    caption: 'Assignee has never been nobody — the issues that were assigned from the start',
  },
  {
    name: 'changed-from-nobody',
    op: 'cf',
    values: ['none'],
    before: 0,
    after: 1,
    caption: 'Assignee changed from nobody — the one issue picked up from the queue',
  },
];

function filterUrl({ op, values }) {
  const q = new URLSearchParams();
  q.append('set_filter', '1');
  q.append('f[]', 'assigned_to_id');
  q.append('op[assigned_to_id]', op);
  for (const v of values) q.append('v[assigned_to_id][]', v);
  q.append('c[]', 'subject');
  q.append('c[]', 'assigned_to');
  return `${PROJECT}/issues?${q.toString()}`;
}

const failures = [];

for (const c of cases) {
  const expected = mode === 'before' ? c.before : c.after;
  // go() refuses an error page, and on the unpatched instance four of these
  // cases are exactly that, so navigate directly and read the outcome.
  const response = await s.page.goto(`${s.BASE}${filterUrl(c)}`);
  await s.page.waitForLoadState('networkidle');
  const status = response.status();
  const rows = await s.page.locator('table.issues tbody tr.issue').count();
  const got = status >= 400 ? 'error' : rows;

  if (got !== expected) {
    failures.push(`${c.name}: expected ${expected}, got ${got} (HTTP ${status})`);
  }
  if (got !== 'error') {
    // An ignored filter would also produce a plausible number, so prove the
    // filter is on the page with the operator and values that were asked for.
    // The chosen operator and values live in the DOM properties only.
    if ((await s.page.locator('#filters-table div.filter#tr_assigned_to_id').count()) === 0) {
      failures.push(`${c.name}: the assignee filter is not on the page`);
    } else {
      const op = await s.page.locator('#operators_assigned_to_id').inputValue();
      if (op !== c.op) failures.push(`${c.name}: operator on the page is ${op}, not ${c.op}`);
      // Before the change there is no << nobody >> option, so the select cannot
      // hold the value the URL asked for and falls back to its first entry.
      // That is the defect, not a broken check — only assert the selection once
      // the option exists.
      if (mode !== 'before') {
        const vals = await s.page.locator('#values_assigned_to_id_1').evaluate(
          el => Array.from(el.selectedOptions).map(o => o.value)
        );
        if (vals.sort().join(',') !== [...c.values].sort().join(',')) {
          failures.push(`${c.name}: selected values are ${vals.join(',')}, not ${c.values.join(',')}`);
        }
      }
    }
  }
  await s.shot(
    `${prefix}${c.name}`,
    `${c.caption} — ${got === 'error' ? `HTTP ${status}` : `${rows} issue(s)`}`
  );
}

// The pseudo-value has to be in the dropdown, next to << me >>, or none of the
// above is reachable without hand-writing a URL.
await s.go(`${PROJECT}/issues?set_filter=1&f[]=assigned_to_id&op[assigned_to_id]==&v[assigned_to_id][]=${dev}`);
// A closed native select shows only the selected entry, so expand it into the
// multi-select listbox first — that is what puts every option in the image.
await s.page.click('#tr_assigned_to_id .toggle-multiselect');
await s.page.waitForTimeout(200);
const options = await s.page.locator('#values_assigned_to_id_1 option').evaluateAll(
  els => els.map(e => `${e.value}:${e.textContent.trim()}`)
);
const hasNobody = options.some(o => o.startsWith('none:'));
if (hasNobody !== (mode !== 'before')) {
  failures.push(`dropdown: << nobody >> present=${hasNobody}, options were ${options.join(' | ')}`);
}
await s.shot(
  `${prefix}filter-dropdown`,
  `The assignee dropdown${hasNobody ? ' offers << nobody >>' : ' has no way to say nobody'}`
);

report(s.shots);
await s.browser.close();

if (failures.length) {
  console.error(`\nFAIL (mode=${mode}):`);
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`\nPASS (mode=${mode})`);
