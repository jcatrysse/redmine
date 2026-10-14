// G9 verification for group-membership-preload.
//
//   MODE=before WORKTREE=/home/user/wt/verify-before \
//   SHOT_DIR=docs/features/group-membership-preload/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/group-membership-preload.mjs
//
// MODE=before  runs against an unpatched trunk instance, shots are named before-*.
// MODE=after   runs against the patched instance, shots are named after-*.
//
// The instance is prepared through `rails runner`: a group of 1000 users, a
// project without subprojects, a project with 5 subprojects that inherit
// members, one group user who is already a direct member of the parent, and an
// empty group. Every run starts by deleting the memberships in those projects,
// so before and after add the group to exactly the same state.
//
// The member list is filtered on "group" for the shots after an add, so the
// group row itself is in view; its 1000 users sort after it otherwise.
// Each add is done through Project > Settings > Members > New member, the path
// that was reported slow. The time and query count come from the server log
// line of that request. At the end a checksum over every member_role in the
// test projects (inherited_from resolved to project, login and role name) is
// printed: it must be the same in both modes.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { session, report } from '../tools/verify-lib.mjs';

const MODE = process.env.MODE || 'after';
const WORKTREE = process.env.WORKTREE || '/home/user/wt/patch-group-membership-preload';
const LOG = process.env.SERVER_LOG || '/tmp/redmine-dev-3000.log';
const SHOT_DIR = process.env.SHOT_DIR || 'docs/features/group-membership-preload/shots';

const SEED = `
now = Time.now
if User.where("login LIKE 'perf%'").count < 1000
  rows = (1..1000).map do |i|
    {login: format('perf%04d', i), firstname: 'Perf', lastname: format('User%04d', i), status: 1,
     type: 'User', language: 'en', mail_notification: 'only_my_events', created_on: now, updated_on: now}
  end
  User.insert_all(rows)
  ids = User.where("login LIKE 'perf%'").pluck(:id, :login)
  EmailAddress.insert_all(ids.map {|id, login| {user_id: id, address: "#{login}@example.net", is_default: true, notify: true, created_on: now, updated_on: now}})
end
group = Group.find_by_lastname('perf-group') || Group.create!(lastname: 'perf-group')
if group.users.count < 1000
  user_ids = User.where("login LIKE 'perf%'").pluck(:id)
  ActiveRecord::Base.connection.execute("DELETE FROM groups_users WHERE group_id = #{group.id}")
  values = user_ids.map {|id| "(#{group.id}, #{id})"}.join(',')
  ActiveRecord::Base.connection.execute("INSERT INTO groups_users (group_id, user_id) VALUES #{values}")
end
Group.find_by_lastname('perf-empty-group') || Group.create!(lastname: 'perf-empty-group')
flat = Project.find_by_identifier('perf-flat') || Project.create!(name: 'Perf flat', identifier: 'perf-flat')
parent = Project.find_by_identifier('perf-parent') || Project.create!(name: 'Perf parent', identifier: 'perf-parent')
(1..5).each do |i|
  next if Project.find_by_identifier("perf-parent-#{i}")
  child = Project.create!(name: "Perf parent #{i}", identifier: "perf-parent-#{i}", inherit_members: true)
  child.set_parent!(parent.reload)
end
ids = Project.where("identifier LIKE 'perf-%'").pluck(:id)
member_ids = Member.where(project_id: ids).pluck(:id)
MemberRole.where(member_id: member_ids).delete_all
Member.where(id: member_ids).delete_all
Member.create!(principal: User.find_by_login('perf0001'), project: parent.reload, roles: [Role.find_by_name('Reporter')])
puts "GROUP_ID=#{group.id}"
puts "DIRECT_USER_ID=#{User.find_by_login('perf0001').id}"
puts "PROJECT_MEMBERS=#{Member.where(project_id: ids).count}"
`;

const CHECKSUM = `
ids = Project.where("identifier LIKE 'perf-%'").order(:identifier).pluck(:id, :identifier).to_h
rows = MemberRole.joins(:member).where(members: {project_id: ids.keys}).
  pluck('member_roles.id', 'members.project_id', 'members.user_id', 'member_roles.role_id', 'member_roles.inherited_from')
by_id = rows.to_h {|r| [r[0], r]}
login = Principal.where(id: rows.map {|r| r[2]}).pluck(:id, :login, :lastname).to_h {|id, l, n| [id, l.presence || n]}
role = Role.pluck(:id, :name).to_h
key = lambda {|r| [ids[r[1]], login[r[2]], role[r[3]]]}
norm = rows.map {|r| key.call(r) + [r[4] && key.call(by_id[r[4]] || [0, 0, 0, 0])]}.sort
puts "MEMBERS=#{Member.where(project_id: ids.keys).count} MEMBER_ROLES=#{rows.size} CHECKSUM=#{Digest::SHA1.hexdigest(norm.inspect)[0, 16]}"
`;

function runner(code) {
  return execFileSync(
    'bundle', ['exec', 'ruby', 'bin/rails', 'runner', code],
    { cwd: WORKTREE, env: { ...process.env, RAILS_ENV: 'development' }, encoding: 'utf8' }
  );
}

const seed = runner(SEED);
const grab = k => (seed.match(new RegExp(`${k}=(\\d+)`)) || [])[1];
const directUserId = grab('DIRECT_USER_ID');
console.log(seed.trim());

const s = await session(SHOT_DIR);
const { page } = s;
const name = n => `${MODE}-${n}`;
const timings = [];

function lastCompleted(after) {
  const lines = readFileSync(LOG, 'utf8').slice(after).split('\n');
  const start = lines.findIndex(l => /^Started POST "\/projects\/[^"]+\/memberships/.test(l));
  const done = start < 0 ? undefined : lines.slice(start).find(l => l.startsWith('Completed'));
  return done || '(no Completed line for the POST in the server log)';
}

async function addMember(project, principal, roleName) {
  await s.go(`/projects/${project}/settings/members`);
  await page.click('a.icon-add[href$="/memberships/new"]');
  await page.waitForSelector('#principal_search');
  await page.fill('#principal_search', principal);
  const box = page.locator('#principals_for_new_member label', { hasText: principal }).first().locator('input');
  await box.waitFor();
  await box.check();
  await page.locator('.roles-selection label', { hasText: roleName }).locator('input').check();
  const logStart = readFileSync(LOG, 'utf8').length;
  const started = Date.now();
  const [response] = await Promise.all([
    page.waitForResponse(r => r.url().includes(`/projects/${project}/memberships`) && r.request().method() === 'POST', { timeout: 600000 }),
    page.click('#member-add-submit'),
  ]);
  const wall = Date.now() - started;
  await page.waitForLoadState('networkidle');
  const completed = lastCompleted(logStart);
  timings.push({ project, principal, status: response.status(), wall, completed });
  console.log(`${project} + ${principal}: HTTP ${response.status()}, ${wall} ms wall\n  ${completed}`);
  return { wall, completed };
}

function short(completed) {
  const m = completed.match(/in (\d+)ms.*ActiveRecord: ([\d.]+)ms(?: \((\d+) queries)?/);
  return m ? `${m[1]} ms, ActiveRecord ${Math.round(+m[2])} ms${m[3] ? `, ${m[3]} queries` : ''}` : completed;
}

let t = await addMember('perf-flat', 'perf-group', 'Developer');
await s.go('/projects/perf-flat/settings/members?member_name=group');
await s.shot(name('flat-added'), `${MODE}: group of 1000 users added to a project without subprojects (${short(t.completed)})`);

t = await addMember('perf-parent', 'perf-group', 'Developer');
await s.go('/projects/perf-parent/settings/members?member_name=group');
await s.shot(name('parent-added'), `${MODE}: same group added to a project with 5 inheriting subprojects (${short(t.completed)})`);

await s.go('/projects/perf-parent-3/settings/members');
await s.shot(name('subproject-inherited'), `${MODE}: a subproject lists the group and its users with the inherited role`);

await s.go(`/users/${directUserId}/edit?tab=memberships`);
await s.shot(name('direct-member-kept'), `${MODE}: perf0001 keeps their own Reporter role next to the Developer role inherited from the group`);

t = await addMember('perf-flat', 'perf-empty-group', 'Manager');
await s.go('/projects/perf-flat/settings/members?member_name=group');
await s.shot(name('empty-group'), `${MODE}: a group without users is added on its own, nothing else changes (${short(t.completed)})`);

report(s.shots);
await s.browser.close();

console.log('\nTimings:');
for (const x of timings) console.log(`  ${x.project} + ${x.principal}: ${x.wall} ms wall | ${x.completed}`);
console.log('\n' + runner(CHECKSUM).trim());
