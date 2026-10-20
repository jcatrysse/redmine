// G9 verification for pdf-export-marshal-attachments.
//
//   SHOT_DIR=docs/features/pdf-export-marshal-attachments/shots SHOT_PREFIX=before- \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/pdf-export-marshal-attachments.mjs
//
// The instance runs a throwaway local plugin, never committed, that calls core's
// Issue#notified_users in IssuesController#show, the way GEOxyz's plugins did
// when production hit the error. ?no_prime=1 skips that call. Its source is in
// docs/features/pdf-export-marshal-attachments/dossier.md.
//
// Creates one new issue per run: a CommonMark table and an inline image of an
// attachment, assigned to a non-admin member. An admin's allowed_to? never asks
// for roles, so only a non-admin assignee or author gets the cached roles. Then exports it to PDF with and without the cached roles.
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { session, report } from '../tools/verify-lib.mjs';

const prefix = process.env.SHOT_PREFIX || '';
const shotDir = process.env.SHOT_DIR;
const fixture = process.env.PNG_FIXTURE ||
  '/home/user/wt/patch-pdf-export-marshal-attachments/test/fixtures/files/2010/11/101123161450_testfile_1.png';
const s = await session(shotDir);
const scratch = mkdtempSync(join(tmpdir(), 'pdf-verify-'));
const png = join(scratch, 'site-map.png');
copyFileSync(fixture, png);

await s.go('/settings?tab=general');
await s.page.selectOption('#settings_text_formatting', 'common_mark');
await s.page.locator('#tab-content-general input[type=submit]').click();
await s.page.waitForLoadState('networkidle');

await s.go('/projects/geoxyz-verify/issues/new');
await s.page.fill('#issue_subject', `PDF export with a table (${prefix ? prefix.replace(/-$/, '') : 'after'})`);
await s.page.fill('#issue_description', [
  'Measurements per site:',
  '',
  '| Site | Depth |',
  '|------|-------|',
  '| A    | 12 m  |',
  '| B    | 30 m  |',
  '',
  '![](site-map.png)',
].join('\n'));
await s.page.selectOption('#issue_assigned_to_id', { label: 'Dev Verify0' });
await s.page.locator('input.file_selector').setInputFiles(png);
await s.page.locator('.attachments_fields input[name$="[token]"]').waitFor({ state: 'attached' });
await s.page.waitForFunction(() =>
  [...document.querySelectorAll('.attachments_fields input[name$="[token]"]')].every((i) => i.value));
await s.page.locator('#issue-form input[name=commit]').click();
await s.page.waitForLoadState('networkidle');
const id = s.page.url().match(/\/issues\/(\d+)/)[1];
await s.shot(`${prefix}issue`, `Issue #${id}: CommonMark table and inline image of an attachment`, { full: true });

async function exportPdf(query, name, caption) {
  const path = `/issues/${id}.pdf${query}`;
  const response = await s.page.request.get(`${s.BASE}${path}`);
  const status = response.status();
  console.log(`${path} -> HTTP ${status}`);
  if (status === 200) {
    const file = join(scratch, `${name}.pdf`);
    writeFileSync(file, await response.body());
    const images = execFileSync('pdfimages', ['-list', file], { encoding: 'utf8' });
    console.log(images);
    execFileSync('pdftoppm', ['-png', '-r', '80', '-f', '1', '-l', '1', '-singlefile', file,
      join(shotDir, name)]);
    s.shots.push({ name, caption: `${caption} (HTTP 200, page 1 of the PDF)`, url: `${s.BASE}${path}` });
  } else {
    await s.page.goto(`${s.BASE}${path}`);
    await s.shot(name, `${caption} (HTTP ${status})`);
  }
  return status;
}

await exportPdf('', `${prefix}issue-pdf`, 'PDF export after the assignee\'s roles were cached');
await exportPdf('?no_prime=1', `${prefix}issue-pdf-no-prime`, 'PDF export without cached roles');

report(s.shots);
await s.browser.close();
