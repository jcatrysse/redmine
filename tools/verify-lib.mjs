// Browser-verification harness for a real Redmine instance.
//
// Playwright is installed globally as a CommonJS module, so it is imported by
// absolute path with a default import — a bare `import { chromium } from
// 'playwright'` does not resolve outside the global node_modules.
import pw from '/opt/node22/lib/node_modules/playwright/index.js';
const { chromium } = pw;

const BASE = process.env.REDMINE_URL || 'http://127.0.0.1:3000';
const USER = process.env.REDMINE_USER || 'admin';
const PASS = process.env.REDMINE_PASSWORD || 'GEOxyzDev123!';

// Do NOT pass executablePath: the browser directory is versioned
// (chromium-1194), so let Playwright resolve it via PLAYWRIGHT_BROWSERS_PATH.
export async function session(shotDir) {
  const browser = await chromium.launch();
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await context.newPage();
  const shots = [];

  await page.goto(`${BASE}/login`);
  await page.fill('#username', USER);
  await page.fill('#password', PASS);
  await page.click('input[type=submit]');
  await page.waitForLoadState('networkidle');
  if (await page.locator('#username').count()) {
    throw new Error(`login failed as ${USER} — set REDMINE_PASSWORD, or run tools/dev-seed.rb`);
  }

  // Every screenshot is evidence for one named function, so it carries its own
  // caption. The caption ends up in the dossier next to the image.
  async function shot(name, caption, { full = false } = {}) {
    const file = `${shotDir}/${name}.png`;
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: file, fullPage: full });
    shots.push({ name, caption, file, url: page.url() });
    return file;
  }

  async function go(path) {
    await page.goto(`${BASE}${path}`);
    await page.waitForLoadState('networkidle');
    const code = await page.evaluate(() => document.title);
    if (/^(500|422|404|Error)/.test(code)) throw new Error(`${path} returned ${code}`);
    return page;
  }

  return { browser, page, shot, go, shots, BASE };
}

export function report(shots) {
  console.log(`\n${shots.length} screenshot(s):`);
  for (const s of shots) console.log(`  ${s.name}.png  ${s.caption}\n      ${s.url}`);
  console.log('\n| Function | Screenshot | What it shows |');
  console.log('|---|---|---|');
  for (const s of shots) console.log(`| ${s.caption} | \`${s.name}.png\` | |`);
}
