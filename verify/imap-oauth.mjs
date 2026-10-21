import { session, report } from '../tools/verify-lib.mjs';

const s = await session(process.env.SHOT_DIR);
// SHOT_PREFIX names a later verification round (rotation-before-, rotation-after-)
const prefix = process.env.SHOT_PREFIX || '';
const caption = process.env.SHOT_CAPTION || 'Issues of the verification project, newest first';

await s.go('/projects/geoxyz-verify/issues?set_filter=1&sort=id:desc');
await s.shot(`${prefix}issues-list`, caption);
if (prefix) {
  report(s.shots);
  await s.browser.close();
  process.exit(0);
}

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
