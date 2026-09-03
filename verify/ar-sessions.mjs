import { session, report } from '../tools/verify-lib.mjs';

const s = await session(process.env.SHOT_DIR || '/tmp');

const c = (await s.page.context().cookies()).find(k => k.name === '_redmine_session');
console.log('cookie  sameSite=%s  path=%s  httpOnly=%s  bytes=%d  value=%s',
            c.sameSite, c.path, c.httpOnly, c.value.length, c.value);

await s.go('/my/page');
await s.shot('logged-in-with-a-database-session',
             'Logged in as admin while the session lives in the sessions table, not in the cookie');

report(s.shots);
await s.browser.close();
