// G9 verification for members-pagination.
//
//   MODE=before SHOT_DIR=docs/features/members-pagination/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/members-pagination.mjs
//
// MODE=before  runs against the unpatched instance: shots are named before-*.
//              Neither list paginates there, so both shots show every member
//              and every group user at once, which is the whole complaint.
// MODE=after   runs against the patched instance and drives each function the
//              feature claims, plus the failure path.
// CLAMP=0      the patched instance carries #43355's two patches only. The
//              failure path is then expected to dead-end, and its shot is
//              named defect-* — that shot is the evidence for the note.
// CLAMP=1      the instance also carries the clamp, and the same path is
//              expected to fall back to the new last page.
//
// The instance is prepared through `rails runner` rather than by hand: the
// verification needs more members than tools/dev-seed.rb creates, and a small
// per-page setting so a handful of rows is already two pages.
import { execFileSync } from 'node:child_process';
import { session, report } from '../tools/verify-lib.mjs';
import pw from '/opt/node22/lib/node_modules/playwright/index.js';
const { chromium } = pw;

const MEMBERS = '/projects/geoxyz-verify/settings/members';

const WORKTREE = process.env.WORKTREE || '/home/user/wt/patch-members-pagination';

const SEED = `
Setting.per_page_options = '2,25,50'
project = Project.find_by_identifier!('geoxyz-verify')
role = Role.givable.first
(1..5).each do |i|
  login = "pager#{i}"
  u = User.find_by_login(login) || User.new(login: login, firstname: 'Pager', lastname: "User#{i}", mail: "#{login}@example.net")
  u.password = u.password_confirmation = 'GEOxyzDev123!'
  u.must_change_passwd = false
  u.status = User::STATUS_ACTIVE
  u.save!(validate: false)
  Member.create!(project: project, principal: u, roles: [role]) unless u.member_of?(project)
end
group = Group.find_by_lastname('verify-group')
(1..3).each do |i|
  u = User.find_by_login("pager#{i}")
  group.users << u unless group.users.include?(u)
end
puts "GROUP_ID=#{group.id}"
puts "MEMBER_COUNT=#{project.memberships.count}"
puts "GROUP_USER_COUNT=#{group.users.count}"
`;

function seed() {
  const out = execFileSync(
    'bundle', ['exec', 'ruby', 'bin/rails', 'runner', SEED],
    { cwd: WORKTREE, env: { ...process.env, RAILS_ENV: 'development' }, encoding: 'utf8' }
  );
  const grab = k => (out.match(new RegExp(`${k}=(\\d+)`)) || [])[1];
  return { groupId: grab('GROUP_ID'), members: grab('MEMBER_COUNT'), users: grab('GROUP_USER_COUNT') };
}

const mode = process.env.MODE || 'before';
const p = mode === 'before' ? 'before-' : '';
const after = mode !== 'before';
const clamp = process.env.CLAMP === '1';

const { groupId, members, users } = seed();
console.log(`seeded: group ${groupId}, ${members} members, ${users} group users, per page 2`);

// The two images the note on #43355 attaches have to show which page is being
// displayed, and that lives in the address bar. Playwright captures the
// viewport only, so this mode drives a headed browser on an Xvfb display and
// grabs the X root window with xwd instead. Which shot it takes depends on the
// code the server is running: CLAMP=0 gives the defect, CLAMP=1 the recovery.
if (mode === 'note-shots') {
  await noteShots(Number(members));
  process.exit(0);
}

async function chromeShot(name, caption) {
  const file = `${process.env.SHOT_DIR}/${name}.png`;
  execFileSync('/bin/sh', ['-c', `xwd -root -display ${process.env.DISPLAY} -silent | convert xwd:- ${file}`]);
  console.log(`  ${name}.png  ${caption}`);
  return file;
}

async function noteShots(memberCount) {
  if (!process.env.DISPLAY) throw new Error('note-shots needs DISPLAY — start Xvfb first');
  const browser = await chromium.launch({
    headless: false,
    args: ['--window-position=0,0', '--window-size=1280,900'],
  });
  const page = await (await browser.newContext({ viewport: null })).newPage();
  await page.goto('http://127.0.0.1:3000/login');
  await page.fill('#username', 'admin');
  await page.fill('#password', process.env.REDMINE_PASSWORD || 'GEOxyzDev123!');
  await page.click('input[type=submit]');
  await page.waitForLoadState('networkidle');

  const lastPage = Math.ceil(memberCount / 2);
  await page.goto(`http://127.0.0.1:3000${MEMBERS}?members_page=${lastPage}`);
  await page.waitForLoadState('networkidle');
  const before = await page.locator('#tab-content-members tr.member').count();
  if (before !== 1) throw new Error(`page ${lastPage} holds ${before} rows, expected 1`);

  if (!clamp) {
    await chromeShot('members-last-page',
      `Page ${lastPage} of ${lastPage}, the last one, holding the seventh of seven members`);
  }

  page.once('dialog', d => d.accept());
  await page.locator('#tab-content-members a.icon-link-break').first().click({ noWaitAfter: true });
  await page.waitForTimeout(2500);

  const empty = await page.locator('#tab-content-members p.nodata').count();
  const rowsNow = await page.locator('#tab-content-members tr.member').count();
  const url = page.url();
  if (!url.includes(`members_page=${lastPage}`)) {
    throw new Error(`the address bar lost members_page=${lastPage}: ${url}`);
  }

  if (clamp) {
    if (empty !== 0) throw new Error('the clamp did not prevent the empty page');
    await chromeShot('members-page-clamped-after-delete',
      'With the clamp, the same removal falls back to the new last page');
    console.log(`PASS  clamped: ${rowsNow} rows at ${url}`);
  } else {
    if (empty !== 1) throw new Error('the unclamped code did not produce the empty page');
    await chromeShot('defect-empty-page-after-delete',
      'Without the clamp, the tab stays on members_page=4 and shows "No data to display"');
    console.log(`PASS  defect: ${rowsNow} rows at ${url}`);
  }
  await browser.close();
}

const s = await session(process.env.SHOT_DIR);
const failures = [];
const check = (ok, what) => { if (!ok) failures.push(what); };

const rows = () => s.page.locator('#tab-content-members tr.member').count();
const pager = () => s.page.locator('#tab-content-members span.pagination').count();
const userRows = () => s.page.locator('#tab-content-users table.users tbody tr').count();
const userPager = () => s.page.locator('#tab-content-users span.pagination').count();

// ---------------------------------------------------------------- members
await s.go(MEMBERS);
await s.shot(`${p}members-page-1`, 'Project settings, Members tab, first page');
const n1 = await rows();
if (after) {
  check(n1 === 2, `members page 1 shows ${n1} rows, expected 2`);
  check((await pager()) === 1, 'members page 1 has no pagination');
} else {
  check(n1 === Number(members), `unpatched members tab shows ${n1} rows, expected all ${members}`);
  check((await pager()) === 0, 'unpatched members tab already paginates');
}

if (after) {
  await s.page.locator('#tab-content-members span.pagination a', { hasText: '2' }).first().click();
  await s.page.waitForLoadState('networkidle');
  await s.shot('members-page-2', 'Second page of members, reached from the pagination links');
  check((await rows()) === 2, 'members page 2 does not show its own two rows');
  check(s.page.url().includes('members_page=2'), 'members page 2 is not addressed by members_page');

  // Per page: raising it puts every member back on one page.
  await s.page.locator('#tab-content-members span.per-page a', { hasText: '25' }).first().click();
  await s.page.waitForLoadState('networkidle');
  await s.shot('members-per-page', 'Per page raised to 25: every member on one page again');
  check((await rows()) === Number(members), 'per page 25 does not show every member');
  await s.go(`${MEMBERS}?per_page=2`);

  // Editing a member on page 2 must leave the list on page 2.
  await s.go(`${MEMBERS}?members_page=2`);
  await s.page.locator('#tab-content-members a.icon-edit').first().click();
  await s.page.waitForSelector('#tab-content-members form.edit_membership');
  await s.page.locator('#tab-content-members form.edit_membership input[type=checkbox]').nth(1).check();
  await s.page.locator('#tab-content-members form.edit_membership input[type=submit]').first().click();
  await s.page.waitForSelector('#tab-content-members form.edit_membership', { state: 'detached' });
  await s.page.waitForLoadState('networkidle');
  await s.shot('members-stay-on-page-after-edit',
               'A saved role change on page 2 re-renders page 2, not page 1');
  check((await rows()) === 2, 'the list did not stay on members page 2 after an edit');
  check(s.page.url().includes('members_page=2'), 'the URL lost members_page after an edit');

  // The failure path: removing the only member of the last page. With seven
  // members at two per page the fourth page holds exactly one.
  const lastPage = Math.ceil(Number(members) / 2);
  await s.go(`${MEMBERS}?members_page=${lastPage}`);
  await s.shot('members-last-page', `Page ${lastPage}, the last one, holding a single member`);
  check((await rows()) === 1, `the last members page holds ${await rows()} rows, expected 1`);
  s.page.once('dialog', d => d.accept());
  await s.page.locator('#tab-content-members a.icon-link-break').first().click({ noWaitAfter: true });
  await s.page.waitForTimeout(2000);
  const emptied = await s.page.locator('#tab-content-members p.nodata').count();
  if (clamp) {
    await s.shot('members-page-clamped-after-delete',
                 'After removing the only member of the last page the tab falls back to the new last page');
    check(emptied === 0, 'the clamp did not prevent the empty page');
    check((await rows()) > 0, 'the tab is empty after removing the only member of the last page');
  } else {
    await s.shot('defect-empty-page-after-delete',
                 'Without the clamp, removing the only member of the last page leaves the tab on a page that no longer exists');
    check(emptied === 1, 'the unclamped code did not produce the empty page this shot is for');
  }
}

// ------------------------------------------------------------ group users
const GROUP = `/groups/${groupId}/edit?tab=users`;
await s.go(GROUP);
await s.shot(`${p}group-users-page-1`, 'Group, Users tab, first page');
const g1 = await userRows();
if (after) {
  check(g1 === 2, `group users page 1 shows ${g1} rows, expected 2`);
  check((await userPager()) === 1, 'group users page 1 has no pagination');

  await s.page.locator('#tab-content-users span.pagination a', { hasText: '2' }).first().click();
  await s.page.waitForLoadState('networkidle');
  await s.shot('group-users-page-2', 'Second page of the group users list');
  check(s.page.url().includes('users_page=2'), 'group users page 2 is not addressed by users_page');
  check((await userRows()) >= 1, 'group users page 2 is empty');
} else {
  check(g1 === Number(users), `unpatched group users tab shows ${g1} rows, expected all ${users}`);
  check((await userPager()) === 0, 'unpatched group users tab already paginates');
}

report(s.shots);
if (failures.length) {
  console.log(`\nFAIL  ${failures.length}`);
  for (const f of failures) console.log(`  - ${f}`);
} else {
  console.log('\nPASS  every check held');
}
await s.browser.close();
process.exit(failures.length ? 1 : 0);
