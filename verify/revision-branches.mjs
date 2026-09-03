// G9 verification for revision-branches.
//
//   bundle exec ruby bin/rails runner -e development \
//     /home/user/redmine/docs/features/revision-branches/seed.rb
//   MODE=before SHOT_DIR=docs/features/revision-branches/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/revision-branches.mjs
//
// MODE=before  runs against the unpatched instance. The four settings do not
//              exist there, so every case records what the old code does: no
//              branch row on the revision page, nothing in the associated
//              revisions, and no settings on the Repositories tab.
// MODE=after   runs against the patched instance, drives the settings through
//              the admin form, and asserts each case.
//
// The exclusion cases are the ones worth looking at: the demo repository has a
// `dependabot/bundler/rails-8.1.4` branch precisely so that filtering it out
// is visible rather than theoretical.
import pw from '/opt/node22/lib/node_modules/playwright/index.js';
import { session, report } from '../tools/verify-lib.mjs';
const { chromium } = pw;

const PROJECT = 'geoxyz-verify';
const REPO = 'demo';
// 'Adds a changelog' — reachable from every branch, and linked to the issue.
const REV = process.env.REV;
const ISSUE = process.env.ISSUE;

const mode = process.env.MODE || 'before';
const prefix = mode === 'before' ? 'before-' : '';
const after = mode !== 'before';
const s = await session(process.env.SHOT_DIR);
const failures = [];

if (!REV || !ISSUE) throw new Error('set REV and ISSUE from the output of seed.rb');

const REVISION_PATH = `/projects/${PROJECT}/repository/${REPO}/revisions/${REV}`;

function check(name, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}: ${JSON.stringify(actual)}`);
  if (!ok) failures.push(`${name}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

// The branch names shown on the revision page, read from the "Branches" row of
// ul.revision-info. Returns null when the row is absent, which is what the
// unpatched instance must do.
async function revisionBranches() {
  await s.go(REVISION_PATH);
  return s.page.evaluate(() => {
    const li = [...document.querySelectorAll('ul.revision-info li')]
      .find(el => el.querySelector('strong')?.textContent.trim() === 'Branches');
    if (!li) return null;
    return [...li.querySelectorAll('a')].map(a => a.textContent.trim());
  });
}

// The branch names shown in the issue's Associated revisions tab.
async function issueBranches() {
  await s.go(`/issues/${ISSUE}`);
  await s.page.locator('#tab-changesets').click();
  await s.page.waitForLoadState('networkidle');
  return s.page.evaluate(() => {
    const em = document.querySelector('#tab-content-changesets em, div.changeset em');
    if (!em) return null;
    return [...em.querySelectorAll('a')].map(a => a.textContent.trim());
  });
}

// Drives the Repositories settings tab. Only reachable once the patch is in.
async function saveSettings({ revision, associated, excluded, regex }) {
  await s.go('/settings?tab=repositories');
  await s.page.setChecked('#settings_display_revision_branches', revision);
  await s.page.setChecked('#settings_display_associated_revision_branches', associated);
  await s.page.fill('#settings_revision_branches_excluded', excluded);
  await s.page.setChecked('#settings_revision_branches_enable_regex', regex);
  await s.page.click('#tab-content-repositories input[type=submit]');
  await s.page.waitForLoadState('networkidle');
}

// 1. The settings themselves.
await s.go('/settings?tab=repositories');
await s.shot(`${prefix}settings-repositories`,
             'Administration > Settings > Repositories, where the four settings live',
             { full: true });
const settingsPresent = await s.page.locator('#settings_display_revision_branches').count();
check('four settings on the Repositories tab', settingsPresent > 0, after);

// 2. Default state: both displays off. Identical on both instances — this is
//    the shot that proves an existing installation sees no change.
if (after) await saveSettings({ revision: false, associated: false, excluded: '', regex: false });
check('revision page at the default', await revisionBranches(), null);
await s.shot(`${prefix}revision-default`,
             'Revision page with the setting off: no branch row');
check('associated revisions at the default', await issueBranches(), null);
await s.shot(`${prefix}issue-default`,
             'Associated revisions with the setting off: no branches');

// 3. Both displays on.
if (after) await saveSettings({ revision: true, associated: true, excluded: '', regex: false });
check('revision page with the setting on', await revisionBranches(),
      after ? ['12345-add-revision-branches', 'dependabot/bundler/rails-8.1.4',
               'main', 'release/7.0', 'wip/experiment'] : null);
await s.shot(`${prefix}revision-branches`,
             'Revision page listing every branch that contains the commit');
check('associated revisions with the setting on', await issueBranches(),
      after ? ['12345-add-revision-branches', 'dependabot/bundler/rails-8.1.4',
               'main', 'release/7.0', 'wip/experiment'] : null);
await s.shot(`${prefix}issue-branches`,
             "Branches shown in the issue's Associated revisions tab");

// 3b. A branch name must be a working link, not just an <a> in the DOM. This
//     is the check the 5.1 grouping link would have failed: its handler lived
//     in repository_navigation.js, which neither of these two views loads.
if (after) {
  await s.go(REVISION_PATH);
  const link = s.page.locator('ul.revision-info li a', {hasText: 'release/7.0'}).first();
  await link.click();
  await s.page.waitForLoadState('networkidle');
  check('clicking a branch name opens the repository at that branch',
        {browsing: /\/repository\/demo/.test(s.page.url()),
         rev: await s.page.locator('#revision_selector #branch').inputValue().catch(() => null)},
        {browsing: true, rev: 'release/7.0'});
  await s.shot('revision-branch-link-followed',
               "Following the 'release/7.0' link lands on the repository browser at that branch");
}

// 4. Exclusion by pattern, the non-regex form: dependabot/* and wip/*.
if (after) {
  await saveSettings({ revision: true, associated: true, excluded: 'dependabot/*, wip/*', regex: false });
}
check('revision page with two patterns excluded', await revisionBranches(),
      after ? ['12345-add-revision-branches', 'main', 'release/7.0'] : null);
await s.shot(`${prefix}revision-excluded-glob`,
             'Two branch name patterns excluded, the rest still listed');

// 5. Exclusion by regular expression.
if (after) {
  await saveSettings({ revision: true, associated: true, excluded: '.*/.*', regex: true });
}
check('revision page with a regular expression excluded', await revisionBranches(),
      after ? ['12345-add-revision-branches', 'main'] : null);
await s.shot(`${prefix}revision-excluded-regex`,
             'Every branch name containing a slash excluded by a regular expression');

// 6. An invalid regular expression must not break the page.
if (after) {
  await saveSettings({ revision: true, associated: true, excluded: '[, main', regex: true });
}
check('revision page with an invalid regular expression', await revisionBranches(),
      after ? ['12345-add-revision-branches', 'dependabot/bundler/rails-8.1.4',
               'release/7.0', 'wip/experiment'] : null);
await s.shot(`${prefix}revision-invalid-regex`,
             'Invalid pattern ignored, the page still renders and the valid pattern still applies');

// 7. The display inherits Redmine's own gate: Changeset.visible needs
//    :view_changesets, so a user without it sees no Associated revisions tab
//    and therefore no branches, whatever the setting says.
if (after) {
  await saveSettings({ revision: true, associated: true, excluded: '', regex: false });
}
// verify-lib reads REDMINE_USER once at import, so the second user gets its own
// browser here rather than a second session() from the library.
const readerBrowser = await chromium.launch();
const readerPage = await (await readerBrowser.newContext({viewport: {width: 1280, height: 900}})).newPage();
await readerPage.goto(`${s.BASE}/login`);
await readerPage.fill('#username', 'norepo');
await readerPage.fill('#password', 'GEOxyzDev123!');
await readerPage.click('input[type=submit]');
await readerPage.waitForLoadState('networkidle');
if (await readerPage.locator('#username').count()) throw new Error('login as norepo failed — run seed.rb');
await readerPage.goto(`${s.BASE}/issues/${ISSUE}`);
await readerPage.waitForLoadState('networkidle');
const readerState = await readerPage.evaluate(() => ({
  changesetsTab: !!document.querySelector('#tab-changesets'),
  changeset: !!document.querySelector('div.changeset'),
  branches: !!document.querySelector('div.changeset em')
}));
check('reader without view_changesets sees no associated revisions and no branches',
      readerState, {changesetsTab: false, changeset: false, branches: false});
const readerFile = `${process.env.SHOT_DIR}/${prefix}issue-no-permission.png`;
await readerPage.screenshot({path: readerFile});
s.shots.push({name: `${prefix}issue-no-permission`,
              caption: 'A user without view_changesets gets no Associated revisions tab, so no branches',
              file: readerFile, url: readerPage.url()});
await readerBrowser.close();

report(s.shots);
if (failures.length) {
  console.log(`\n${failures.length} FAILURE(S):`);
  for (const f of failures) console.log(`  ${f}`);
}
await s.browser.close();
process.exit(failures.length ? 1 : 0);
