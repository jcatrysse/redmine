import { session, report } from '../tools/verify-lib.mjs';

const s = await session(process.env.SHOT_DIR);

await s.go('/projects/geoxyz-verify/issues?set_filter=1&sort=id:desc');
await s.shot('issues-list', 'Issues of the verification project, newest first');

const link = s.page.locator('table.issues td.subject a', { hasText: 'Printer on deck 3 is offline' });
if (await link.count()) {
  await link.first().click();
  await s.page.waitForLoadState('networkidle');
  await s.shot('issue-from-xoauth2-mail', 'The issue created from the mail fetched with an OAuth 2.0 access token');
} else {
  await s.shot('issue-from-xoauth2-mail', 'No issue was created from mail: receive_imap could not authenticate');
}

report(s.shots);
await s.browser.close();
