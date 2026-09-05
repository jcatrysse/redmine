// G9 verification for search-token-limit.
//
//   SHOT_DIR=docs/features/search-token-limit/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/search-token-limit.mjs
//
// MODE=before      runs against the unpatched instance: shots are named
//                  before-*, and every case asserts the *wrong* count the old
//                  code produces.
// MODE=after       runs against the patched instance and asserts the right one.
// MODE=regression  runs against a worktree carrying the first version of this
//                  patch, which lifted the cap in the filters but left the
//                  search page and its "Apply issues filter" button
//                  disagreeing. Only the click-through case runs.
//
// The seeded issue "Pump alignment survey report northern wind farm"
// (tools/dev-seed.rb) is the only one with more than five distinct words, so a
// six-token filter value is enough to show the truncation.
import { session, report } from '../tools/verify-lib.mjs';

const PROJECT = '/projects/geoxyz-verify';
const mode = process.env.MODE || 'after';
const prefix = {before: 'before-', regression: 'regression-'}[mode] || '';
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
    name: 'filter-any-searchable',
    field: 'any_searchable',
    op: '*~',
    value: 'zzz1 zzz2 zzz3 zzz4 zzz5 northern',
    before: 0,
    after: 1,
    caption: 'Any searchable text contains any of six words, only the sixth matches',
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

function filterUrl({ field = 'subject', op, value }) {
  const q = new URLSearchParams();
  q.append('set_filter', '1');
  q.append('f[]', field);
  q.append(`op[${field}]`, op);
  q.append(`v[${field}][]`, value);
  q.append('c[]', 'subject');
  return `${PROJECT}/issues?${q.toString()}`;
}

async function rowCount() {
  return await s.page.locator('table.issues tbody tr.issue').count();
}

const failures = [];

for (const c of (mode === 'regression' ? [] : cases)) {
  const field = c.field || 'subject';
  await s.go(filterUrl(c));
  const expected = mode === 'before' ? c.before : c.after;
  const got = await rowCount();
  // The filter must actually be applied with the full value — an ignored filter
  // would also show 0, and a value the form itself truncated would not prove
  // anything about the SQL.
  if ((await s.page.locator(`#filters-table div.filter#tr_${field}`).count()) === 0) {
    failures.push(`${c.name}: the ${field} filter is not on the page`);
  } else {
    const op = await s.page.locator(`#operators_${field}`).inputValue();
    const val = await s.page.locator(`#values_${field}`).inputValue();
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

// The button under the results must open the list the search counted. With
// "Search titles only" it goes to the subject filter — the filter this patch
// uncaps — so that is where the page and the button can disagree.
const tq = new URLSearchParams();
tq.append('q', 'pump alignment survey report northern zzz');
tq.append('issues', '1');
tq.append('all_words', '1');
tq.append('titles_only', '1');
await s.go(`${PROJECT}/search?${tq.toString()}`);
const titlesFound = await s.page.locator('#search-results dt').count();
if (titlesFound !== 1) failures.push(`search (titles only): expected 1 result, got ${titlesFound}`);
await s.page.locator('p.buttons a').first().click();
await s.page.waitForLoadState('networkidle');
const linked = await rowCount();
const expectedLinked = mode === 'regression' ? 0 : 1;
if (linked !== expectedLinked) {
  failures.push(`apply-issues-filter: expected ${expectedLinked} issue(s), got ${linked}`);
}
await s.shot(
  `${prefix}apply-issues-filter`,
  `"Apply issues filter" after a titles-only search of six words — ` +
    `${titlesFound} result(s) counted, ${linked} issue(s) behind the button`
);

report(s.shots);
await s.browser.close();

if (failures.length) {
  console.error(`\nFAIL (mode=${mode}):`);
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`\nPASS (mode=${mode})`);
