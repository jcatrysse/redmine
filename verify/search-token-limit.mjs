// G9 verification for search-token-limit.
//
//   SHOT_DIR=docs/features/search-token-limit/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/search-token-limit.mjs
//
// MODE=before  runs against the unpatched instance: shots are named before-*,
//              and every case asserts the *wrong* count the old code produces.
// MODE=after   runs against the patched instance and asserts the right one.
//
// The seeded issue "Pump alignment survey report northern wind farm"
// (tools/dev-seed.rb) is the only one with more than five distinct words, so a
// six-token filter value is enough to show the truncation.
import { session, report } from '../tools/verify-lib.mjs';

const PROJECT = '/projects/geoxyz-verify';
const mode = process.env.MODE || 'after';
const prefix = mode === 'before' ? 'before-' : '';
const s = await session(process.env.SHOT_DIR);

// Six tokens each, and in every case the token that decides the result is the
// sixth — the first one the old code throws away.
const cases = [
  {
    name: 'filter-contains',
    op: '~',
    value: 'pump alignment survey report northern zzz',
    before: 1,
    after: 0,
    caption: 'Subject contains six words, the sixth matches nothing',
  },
  {
    name: 'filter-contains-any-of',
    op: '*~',
    value: 'zzz1 zzz2 zzz3 zzz4 zzz5 northern',
    before: 0,
    after: 1,
    caption: 'Subject contains any of six words, only the sixth matches',
  },
  {
    name: 'filter-starts-with',
    op: '^',
    value: 'zzz1 zzz2 zzz3 zzz4 zzz5 pump',
    before: 0,
    after: 1,
    caption: 'Subject starts with any of six words, only the sixth matches',
  },
  {
    name: 'filter-ends-with',
    op: '$',
    value: 'zzz1 zzz2 zzz3 zzz4 zzz5 farm',
    before: 0,
    after: 1,
    caption: 'Subject ends with any of six words, only the sixth matches',
  },
];

function filterUrl({ op, value }) {
  const q = new URLSearchParams();
  q.append('set_filter', '1');
  q.append('f[]', 'subject');
  q.append('op[subject]', op);
  q.append('v[subject][]', value);
  q.append('c[]', 'subject');
  return `${PROJECT}/issues?${q.toString()}`;
}

async function rowCount() {
  return await s.page.locator('table.issues tbody tr.issue').count();
}

const failures = [];

for (const c of cases) {
  await s.go(filterUrl(c));
  const expected = mode === 'before' ? c.before : c.after;
  const got = await rowCount();
  // The filter must actually be applied with the full value — an ignored filter
  // would also show 0, and a value the form itself truncated would not prove
  // anything about the SQL.
  if ((await s.page.locator('#filters-table div.filter#tr_subject').count()) === 0) {
    failures.push(`${c.name}: the subject filter is not on the page`);
  } else {
    const op = await s.page.locator('#operators_subject').inputValue();
    const val = await s.page.locator('#values_subject').inputValue();
    if (op !== c.op) failures.push(`${c.name}: operator on the page is ${op}, not ${c.op}`);
    if (val !== c.value) failures.push(`${c.name}: value on the page is "${val}"`);
  }
  if (got !== expected) failures.push(`${c.name}: expected ${expected} issue(s), got ${got}`);
  await s.shot(`${prefix}${c.name}`, `${c.caption} — ${got} issue(s)`);
}

// The search engine keeps its five-token cap: the sixth token is nonsense, so
// dropping it is what makes this search find the issue at all. One result here,
// before and after, is the evidence that the cap was not removed as well.
const sq = new URLSearchParams();
sq.append('q', 'pump alignment survey report northern zzz');
sq.append('issues', '1');
sq.append('all_words', '1');
await s.go(`${PROJECT}/search?${sq.toString()}`);
const found = await s.page.locator('#search-results dt').count();
if (found !== 1) failures.push(`search: expected 1 result, got ${found}`);
await s.shot(
  `${prefix}search-still-capped`,
  `Global search with six words still uses the first five — ${found} result(s)`
);

report(s.shots);
await s.browser.close();

if (failures.length) {
  console.error(`\nFAIL (mode=${mode}):`);
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`\nPASS (mode=${mode})`);
