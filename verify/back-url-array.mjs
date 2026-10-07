// G9 verification for back-url-array.
//
//   SHOT_DIR=docs/features/back-url-array/shots MODE=before \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/back-url-array.mjs
//
// MODE=before runs against unpatched trunk and asserts the HTTP 500s; shots are
//             named before-*.
// MODE=after  runs against the patched instance and asserts that the same
//             requests succeed.
//
// The issue list posts its hidden `back_url` field with every context-menu
// request (context_menu.js serializes the list form). A plugin that adds a
// second field of the same name, or renames it `back_url[]`, turns that value
// into an array. The cases below reproduce that in the browser by renaming the
// field, then right-clicking a row, which is what a user does.
import { session, report } from '../tools/verify-lib.mjs';

const PROJECT = '/projects/geoxyz-verify';
const mode = process.env.MODE || 'before';
const before = mode === 'before';
const prefix = before ? 'before-' : '';
const s = await session(process.env.SHOT_DIR);
const { page } = s;

function check(cond, msg) {
  if (!cond) throw new Error(`${mode}: ${msg}`);
  console.log(`ok    ${msg}`);
}

async function rightClickFirstIssue() {
  const status = page.waitForResponse(r => r.url().includes('/issues/context_menu'));
  await page.locator('table.issues tr.issue td.status').first().click({ button: 'right' });
  const res = await status;
  await page.waitForTimeout(500);
  return res.status();
}

// 1. The ordinary path: back_url is a string. Must work before and after.
await s.go(`${PROJECT}/issues`);
let code = await rightClickFirstIssue();
check(code === 200, `context menu with a string back_url answers ${code}`);
check(await page.locator('#context-menu').isVisible(), 'context menu is shown');
await s.shot(`${prefix}context-menu-string`, 'Issue list, right-click, back_url sent as a string (the normal case)');

// 2. The defect: the same right-click with back_url sent as back_url[].
await s.go(`${PROJECT}/issues`);
await page.evaluate(() => {
  document.querySelector('table.issues').closest('form').querySelector('input[name=back_url]').setAttribute('name', 'back_url[]');
});
code = await rightClickFirstIssue();
const shown = await page.locator('#context-menu').isVisible();
if (before) {
  check(code === 500, `context menu with back_url[] answers ${code}`);
  check(!shown, 'no context menu is shown');
} else {
  check(code === 200, `context menu with back_url[] answers ${code}`);
  check(shown, 'context menu is shown');
  check(await page.locator('#context-menu a.icon-del').count() === 1,
        'the Delete item is present: the referer (the issue list) was used');
}
await s.shot(`${prefix}context-menu-array`,
             before ? 'Issue list, right-click, back_url sent as back_url[]: the request fails with 500 and no menu opens'
                    : 'Issue list, right-click, back_url sent as back_url[]: the menu opens, Delete included');

// 3. The same root cause through back_url_hidden_field_tag / cancel_button_tag:
//    any form page that renders them.
for (const [name, path, caption] of [
  ['time-entry-new', `${PROJECT}/time_entries/new?back_url[]=%2Fprojects%2Fgeoxyz-verify%2Fissues`, 'New time entry with back_url[] in the query string'],
  ['version-new', `${PROJECT}/versions/new?back_url[]=%2Fprojects%2Fgeoxyz-verify%2Fissues`, 'New version with back_url[] in the query string'],
]) {
  if (before) {
    const res = await page.goto(`${s.BASE}${path}`);
    check(res.status() === 500, `${name} answers ${res.status()}`);
    await s.shot(`${prefix}${name}`, `${caption}: HTTP 500`);
  } else {
    await s.go(path);
    check(await page.locator('input[name=back_url]').count() === 0, `${name} renders, with no back_url field`);
    await s.shot(name, `${caption}: the form renders`);
  }
}

report(s.shots);
await s.browser.close();
