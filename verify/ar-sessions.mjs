// G9 for ar-sessions. Three steps, driven from the shell because two of them
// need the database changed while the browser watches:
//
//   STEP=missing-table node verify/ar-sessions.mjs   (run with the table dropped)
//   STEP=working       node verify/ar-sessions.mjs   (run with the table restored)
//   STEP=revoked       node verify/ar-sessions.mjs   (deletes the row itself)
//   STEP=serializer    node verify/ar-sessions.mjs   (round 3: the serializer)
//
// The serializer step is a pair too, and it has to be run twice: once with the
// branch as it was (Marshal) and once with Redmine::SessionDataSerializer
// wired up, restarting the server in between. It writes a marshalled object of
// a class the server does not define, which only Marshal.load would try to
// build — so the Internal error on the first run is proof that the column was
// deserialised, and the login page on the second is proof that it no longer
// is. SHOT_PREFIX names which of the two this is.
//
// The point of the first two is that they are a pair: the same URL, once with
// the sessions table missing and once with it there. A screenshot of the store
// merely working proves nothing — it would look the same on the cookie store.
import { execSync } from 'node:child_process';
import pw from '/opt/node22/lib/node_modules/playwright/index.js';
import { session, report } from '../tools/verify-lib.mjs';

const step = process.env.STEP || 'working';
const shotDir = process.env.SHOT_DIR || '/tmp';
const BASE = process.env.REDMINE_URL || 'http://127.0.0.1:3000';

function psql(sql) {
  return execSync(
    `PGPASSWORD=redmine psql -h localhost -U redmine -d ${process.env.REDMINE_DEV_DB || 'redmine_dev'} -tAc ${JSON.stringify(sql)}`,
    { shell: '/bin/bash' }
  ).toString().trim();
}

if (step === 'missing-table') {
  // No login is possible here, so verify-lib's session() cannot be used.
  const browser = await pw.chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const response = await page.goto(`${BASE}/login`);
  console.log('missing-table  GET /login -> HTTP %d', response.status());
  await page.screenshot({ path: `${shotDir}/before-login-500-without-the-sessions-table.png` });
  await browser.close();
} else {
  const s = await session(shotDir);
  const cookie = (await s.page.context().cookies()).find(k => k.name === '_redmine_session');
  const stored = psql("select session_id from sessions order by id desc limit 1");
  console.log('cookie   bytes=%d  sameSite=%s  path=%s  httpOnly=%s  value=%s',
              cookie.value.length, cookie.sameSite, cookie.path, cookie.httpOnly, cookie.value);
  console.log('database session_id=%s', stored);
  console.log('cookie value stored verbatim? %s', stored === cookie.value ? 'YES' : 'no');

  if (step === 'serializer') {
    const prefix = process.env.SHOT_PREFIX || 'after';
    await s.go('/my/account');
    await s.shot('json-signed-in', 'Signed in, with the session stored as JSON in the sessions table');

    await s.go('/projects/geoxyz-verify/issues?set_filter=1&f[]=status_id&op[status_id]=o' +
               '&f[]=assigned_to_id&op[assigned_to_id]=*&c[]=tracker&c[]=subject&c[]=assigned_to' +
               '&group_by=tracker&sort=priority:desc');
    await s.shot('json-filter-applied',
                 'An issue filter applied, so the query is written to the session row');
    await s.go('/projects/geoxyz-verify/issues');
    await s.shot('json-filter-from-session',
                 'The same page with no parameters: the query came back out of the JSON session row');

    // A class the server does not define, so Marshal.load fails loudly and
    // names itself in the log. Nothing is executed: the point is only whether
    // the bytes are interpreted at all.
    execSync(
      "bundle exec ruby bin/rails runner \"module Redmine; class OnlyMarshalWouldBuildThis; end; end; " +
      "ActiveRecord::SessionStore::Session.update_all(:data => ::Base64.encode64(" +
      "Marshal.dump(Redmine::OnlyMarshalWouldBuildThis.new)))\"",
      {cwd: process.env.WORKTREE || '.', env: {...process.env, RAILS_ENV: 'development'}}
    );

    const after = await s.page.goto(`${BASE}/my/account`);
    console.log('%s  GET /my/account -> HTTP %d  %s', prefix, after.status(), s.page.url());
    await s.shot(
      prefix === 'before' ? 'before-marshal-load-runs-on-the-column' : 'after-marshal-load-is-gone',
      prefix === 'before'
        ? 'Before the fix: the request deserialises sessions.data, so bytes in that column are built into an object graph'
        : 'After the fix: the same bytes in sessions.data are a logout, because nothing deserialises them'
    );
  } else if (step === 'working') {
    await s.go('/my/account');
    await s.shot('after-login-with-the-sessions-table',
                 'The same /login now works and the account page renders, with the session in the table');
  } else {
    await s.go('/my/account');
    await s.shot('revoked-before-deleting-the-row',
                 'Signed in on /my/account, one row in the sessions table');
    console.log('deleting %s row(s)', psql('select count(*) from sessions'));
    psql('delete from sessions');
    await s.go('/my/account');
    await s.shot('revoked-after-deleting-the-row',
                 'The same page after the row is deleted: the session is gone and Redmine asks for a login');
  }
  report(s.shots);
  await s.browser.close();
}
