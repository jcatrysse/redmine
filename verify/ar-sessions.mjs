// G9 for ar-sessions. Three steps, driven from the shell because two of them
// need the database changed while the browser watches:
//
//   STEP=missing-table node verify/ar-sessions.mjs   (run with the table dropped)
//   STEP=working       node verify/ar-sessions.mjs   (run with the table restored)
//   STEP=revoked       node verify/ar-sessions.mjs   (deletes the row itself)
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

  if (step === 'working') {
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
