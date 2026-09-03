// G9 verification for version-subprojects.
//
//   SHOT_DIR=docs/features/version-subprojects/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/version-subprojects.mjs
//
// MODE=before  runs against the unpatched instance: shots are named before-*
//              and every case asserts what the old code does — the two
//              subproject versions are simply not in the list.
// MODE=after   runs against the patched instance and asserts the right answer.
//
// The seeded tree (tools/dev-seed.rb):
//   geoxyz-verify            version geoxyz-verify-1.0        sharing none
//     geoxyz-verify-sub      version geoxyz-verify-sub-1.0    sharing none
//     geoxyz-verify-sub2     version geoxyz-verify-sub2-1.0   sharing none
//   geoxyz-verify-other      version shared-systemwide-1.0    sharing system
// The last one is outside the tree and has always been offered; a change that
// scopes the list to the project tree would silently drop it, so every case
// asserts it is still there.
import { session, report } from '../tools/verify-lib.mjs';

const PROJECT = '/projects/geoxyz-verify';
const SUB = 'geoxyz-verify-sub-1.0';
const SUB2 = 'geoxyz-verify-sub2-1.0';
const OWN = 'geoxyz-verify-1.0';
const SYSTEM = 'shared-systemwide-1.0';

const mode = process.env.MODE || 'before';
const prefix = mode === 'before' ? 'before-' : '';
const after = mode !== 'before';
const s = await session(process.env.SHOT_DIR);
const failures = [];

// Ids are assigned by the seed, not fixed, so read them off the pages that
// list them. The version ids come from the project's settings/versions tab,
// where each row links to /versions/<id>.
async function versionIds(identifier) {
  await s.go(`/projects/${identifier}/settings/versions`);
  const rows = await s.page.locator('table.versions tbody tr').evaluateAll(trs =>
    trs.map(tr => {
      const a = tr.querySelector('a[href^="/versions/"]');
      return a ? [a.textContent.trim(), a.getAttribute('href').split('/')[2]] : null;
    }).filter(Boolean)
  );
  return Object.fromEntries(rows);
}

const versions = {
  ...(await versionIds('geoxyz-verify')),
  ...(await versionIds('geoxyz-verify-sub')),
  ...(await versionIds('geoxyz-verify-sub2')),
  ...(await versionIds('geoxyz-verify-other')),
};
for (const name of [OWN, SUB, SUB2, SYSTEM]) {
  if (!versions[name]) failures.push(`seed: version ${name} not found — run tools/dev-seed.rb`);
}

const subprojectIds = await (async () => {
  await s.go(`${PROJECT}/issues?set_filter=1&f[]=subproject_id&op[subproject_id]==`);
  return s.page.locator('#values_subproject_id_1 option').evaluateAll(els =>
    Object.fromEntries(els.map(e => [e.textContent.trim(), e.value]))
  );
})();

function issuesUrl(params) {
  const q = new URLSearchParams();
  q.append('set_filter', '1');
  for (const [k, v] of params) q.append(k, v);
  q.append('c[]', 'subject');
  q.append('c[]', 'fixed_version');
  return `${PROJECT}/issues?${q.toString()}`;
}

// Expands the Target version multi-select and returns its option labels. A
// closed native select shows only the selected entry, so the listbox has to be
// opened before the options are in the image as well as in the DOM.
async function targetVersionOptions() {
  await s.page.click('#tr_fixed_version_id .toggle-multiselect');
  await s.page.waitForTimeout(200);
  // The listbox opens at a fixed height, so the last entries are in the DOM but
  // scrolled out of the image — and an option a screenshot does not show is not
  // evidence. Grow it to fit everything it holds.
  await s.page.locator('#values_fixed_version_id_1').evaluate(el => {
    el.size = el.options.length + 1;
  });
  return s.page.locator('#values_fixed_version_id_1 option').evaluateAll(els =>
    els.map(e => e.textContent.trim())
  );
}

function check(name, options, { expect = [], reject = [] }) {
  for (const v of expect) {
    if (!options.some(o => o.endsWith(v))) {
      failures.push(`${name}: expected ${v} in the list, got ${options.join(' | ')}`);
    }
  }
  for (const v of reject) {
    if (options.some(o => o.endsWith(v))) {
      failures.push(`${name}: did not expect ${v} in the list, got ${options.join(' | ')}`);
    }
  }
}

// 1. The plain project issue list. With subproject issues displayed, the list
//    shows issues on subproject versions, so those versions have to be
//    filterable. The system-shared version must survive either way.
await s.go(issuesUrl([
  ['f[]', 'fixed_version_id'],
  ['op[fixed_version_id]', '='],
  ['v[fixed_version_id][]', versions[OWN]],
]));
let options = await targetVersionOptions();
check('dropdown-project', options, {
  expect: after ? [OWN, SUB, SUB2, SYSTEM] : [OWN, SYSTEM],
  reject: after ? [] : [SUB, SUB2],
});
await s.shot(
  `${prefix}dropdown-project`,
  `Target version list in the parent project — ${after ? 'both subproject versions are offered' : 'no subproject version is offered'}, the system-shared version is present either way`
);

// 2. The AJAX path. The filter is added after the page has loaded, so its
//    values come from /queries/filter, which has to be told which subprojects
//    the query is currently scoped to.
await s.go(issuesUrl([
  ['f[]', 'subproject_id'],
  ['op[subproject_id]', '='],
  ['v[subproject_id][]', subprojectIds['GEOxyz sub']],
]));
await s.page.selectOption('#add_filter_select', 'fixed_version_id');
await s.page.waitForTimeout(1000);
await s.page.waitForLoadState('networkidle');
options = await targetVersionOptions();
check('dropdown-one-subproject', options, {
  expect: after ? [OWN, SUB, SYSTEM] : [OWN, SYSTEM],
  reject: after ? [SUB2] : [SUB, SUB2],
});
await s.shot(
  `${prefix}dropdown-one-subproject`,
  `Target version added after filtering on one subproject — ${after ? "only that subproject's version is added" : 'the subproject filter is ignored'}`
);

// 3. Failure path: main project only. Nothing from a subproject may appear,
//    and nothing that was always there may disappear.
await s.go(issuesUrl([
  ['f[]', 'subproject_id'],
  ['op[subproject_id]', '!*'],
  ['f[]', 'fixed_version_id'],
  ['op[fixed_version_id]', '='],
  ['v[fixed_version_id][]', versions[OWN]],
]));
options = await targetVersionOptions();
check('dropdown-main-project-only', options, {
  expect: [OWN, SYSTEM],
  reject: [SUB, SUB2],
});
await s.shot(
  `${prefix}dropdown-main-project-only`,
  'Subprojects excluded from the query — no subproject version is offered, in either version of the code'
);

// 4. The filter actually filters. The subproject issue is on the subproject's
//    own version; before the change that version cannot be picked in the
//    widget, so the select falls back to its first entry even though the URL
//    asked for it — that fallback is the defect, not a broken check.
await s.go(issuesUrl([
  ['f[]', 'fixed_version_id'],
  ['op[fixed_version_id]', '='],
  ['v[fixed_version_id][]', versions[SUB]],
]));
const rows = await s.page.locator('table.issues tbody tr.issue').count();
if (rows !== 1) failures.push(`filter-subproject-version: expected 1 issue, got ${rows}`);
if (after) {
  const selected = await s.page.locator('#values_fixed_version_id_1').evaluate(el =>
    Array.from(el.selectedOptions).map(o => o.textContent.trim())
  );
  if (!selected.some(o => o.endsWith(SUB))) {
    failures.push(`filter-subproject-version: the widget shows ${selected.join(',')}, not ${SUB}`);
  }
}
await s.shot(
  `${prefix}filter-subproject-version`,
  `Filtering on the subproject version returns its issue — ${after ? 'and the widget shows the version that was asked for' : 'but the widget cannot show a value it does not have and falls back to the first entry'}`
);

report(s.shots);
await s.browser.close();

if (failures.length) {
  console.error(`\nFAIL (mode=${mode}):`);
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`\nPASS (mode=${mode})`);
