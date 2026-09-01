// G9 verification for wiki-export-attachments.
//
//   SHOT_DIR=docs/features/wiki-export-attachments/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/wiki-export-attachments.mjs
//
// SHOT_PREFIX=before-   names the shots taken against the unpatched instance.
// MODE=download         also clicks the link and lists what the ZIP contains.
// MODE=denied           expects the size-limit error instead of a download.
import { execFileSync } from 'node:child_process';
import { session, report } from '../tools/verify-lib.mjs';

const WIKI = '/projects/geoxyz-verify/wiki';
const prefix = process.env.SHOT_PREFIX || '';
const mode = process.env.MODE || 'pages';
const s = await session(process.env.SHOT_DIR);

await s.go(`${WIKI}/index`);
await s.shot(`${prefix}wiki-index`, 'Wiki index, "Also available in" line');

await s.go(`${WIKI}/date_index`);
await s.shot(`${prefix}wiki-date-index`, 'Wiki index by date, same line');

if (mode === 'forbidden') {
  // Chromium turns the .zip URL into a download even for the error page, so
  // read the status through the logged-in request context instead of goto().
  const resp = await s.page.request.get(`${s.BASE}${WIKI}/export.zip?with_attachments=1`);
  console.log(`\ndirect URL without :export_wiki_pages -> HTTP ${resp.status()}`);
  if (resp.status() !== 403) throw new Error(`expected 403, got ${resp.status()}`);
}

if (mode === 'download-plain') {
  await s.go(`${WIKI}/index`);
  const plain = s.page.locator('p.other-formats a.zip').first();
  const [download] = await Promise.all([s.page.waitForEvent('download'), plain.click()]);
  const path = `${process.env.SHOT_DIR}/../${prefix}wiki-export-plain.zip`;
  await download.saveAs(path);
  console.log(execFileSync('unzip', ['-l', path], { encoding: 'utf8' }));
}

if (mode === 'download' || mode === 'denied') {
  await s.go(`${WIKI}/index`);
  const link = s.page.locator('p.other-formats a[href*="with_attachments"]');
  if ((await link.count()) === 0) throw new Error('no ZIP-with-attachments link on the wiki index');

  if (mode === 'download') {
    const [download] = await Promise.all([
      s.page.waitForEvent('download'),
      link.click(),
    ]);
    const path = `${process.env.SHOT_DIR}/../wiki-export.zip`;
    await download.saveAs(path);
    console.log(`\ndownloaded ${download.suggestedFilename()}`);
    console.log(execFileSync('unzip', ['-l', path], { encoding: 'utf8' }));
  } else {
    await link.click();
    await s.page.waitForLoadState('networkidle');
    await s.shot(`${prefix}size-limit-error`,
                 'bulk_download_max_size exceeded: the export is refused, not truncated');
  }
}

report(s.shots);
await s.browser.close();
