// G9 verification for wiki-export-attachments.
//
//   SHOT_DIR=docs/features/wiki-export-attachments/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/wiki-export-attachments.mjs
//
// SHOT_PREFIX=before-   names the shots taken against the unpatched instance.
// MODE=modal            opens the ZIP dialog and downloads both ways, by clicking.
// MODE=denied           expects the size-limit error instead of a download.
// MODE=forbidden        expects 403 on the direct URL.
import { execFileSync } from 'node:child_process';
import { session, report } from '../tools/verify-lib.mjs';

const WIKI = '/projects/geoxyz-verify/wiki';
const prefix = process.env.SHOT_PREFIX || '';
const mode = process.env.MODE || 'pages';
const OUT = `${process.env.SHOT_DIR}/..`;
const s = await session(process.env.SHOT_DIR);

async function openDialog() {
  await s.go(`${WIKI}/index`);
  const link = s.page.locator('p.other-formats a.zip');
  if ((await link.count()) === 0) throw new Error('no ZIP link on the wiki index');
  await link.click();
  const dialog = s.page.locator('#zip-export-options');
  // A link that renders but does nothing is exactly what this gate exists for.
  await dialog.waitFor({ state: 'visible', timeout: 5000 });
  return dialog;
}

async function saveZip(download, name) {
  const path = `${OUT}/${name}`;
  await download.saveAs(path);
  console.log(`\n${name}  (${download.suggestedFilename()})`);
  console.log(execFileSync('unzip', ['-l', path], { encoding: 'utf8' }));
}

await s.go(`${WIKI}/index`);
await s.shot(`${prefix}wiki-index`, 'Wiki index, "Also available in" line');

await s.go(`${WIKI}/date_index`);
await s.shot(`${prefix}wiki-date-index`, 'Wiki index by date, same line');

if (mode === 'modal') {
  await openDialog();
  await s.shot(`${prefix}zip-export-dialog`, 'The ZIP export dialog, attachments unchecked');

  // 1. Export without ticking the box.
  let [download] = await Promise.all([
    s.page.waitForEvent('download'),
    s.page.click('#zip-export-form input[type=submit]'),
  ]);
  await saveZip(download, `${prefix}zip-without-attachments.zip`);

  // 2. Export with the box ticked.
  await openDialog();
  await s.page.check('#zip-export-form input[name=with_attachments]');
  await s.shot(`${prefix}zip-export-dialog-checked`, 'The same dialog with attachments ticked');
  [download] = await Promise.all([
    s.page.waitForEvent('download'),
    s.page.click('#zip-export-form input[type=submit]'),
  ]);
  await saveZip(download, `${prefix}zip-with-attachments.zip`);
}

if (mode === 'denied') {
  await openDialog();
  await s.page.check('#zip-export-form input[name=with_attachments]');
  await s.page.click('#zip-export-form input[type=submit]');
  await s.page.waitForLoadState('networkidle');
  await s.shot(`${prefix}size-limit-error`,
               'bulk_download_max_size exceeded: the export is refused, not truncated');
}

if (mode === 'forbidden') {
  // Chromium turns the .zip URL into a download even for the error page, so
  // read the status through the logged-in request context instead of goto().
  const resp = await s.page.request.get(`${s.BASE}${WIKI}/export.zip?with_attachments=1`);
  console.log(`\ndirect URL without :export_wiki_pages -> HTTP ${resp.status()}`);
  if (resp.status() !== 403) throw new Error(`expected 403, got ${resp.status()}`);
}

report(s.shots);
await s.browser.close();
