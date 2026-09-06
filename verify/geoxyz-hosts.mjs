// G9 for geoxyz-hosts. Drives a real browser at the dev server over four
// hostnames and captures what Rails' host allowlist does with each.
//
// Two of the four cases this feature's findings are about cannot be produced
// from a browser at all: Chromium lowercases the authority before it builds the
// Host header (F01), and it will not emit a header with a slash, a space or a
// port inside the name (F02). Those live in the raw-socket table in status.md
// instead; what a browser can still prove is that the tightened pattern did not
// cost the subdomains the feature exists for.
// Playwright is a global CommonJS module: the named import does not resolve
// even by absolute path, so import the default and destructure.
import pw from '/opt/node22/lib/node_modules/playwright/index.js';
const { chromium } = pw;
import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';

const PORT = process.env.REDMINE_PORT || '3000';
const SHOT_DIR = process.env.SHOT_DIR || 'docs/features/geoxyz-hosts/shots';
const PREFIX = process.env.SHOT_PREFIX || '';

const CASES = [
  ['single-label-subdomain', 'redmine.geoxyz.eu', 'the everyday development hostname'],
  ['multi-label-subdomain', 'a.b.geoxyz.eu', 'two subdomain levels — what the string form would have cost'],
  ['apex-refused', 'geoxyz.eu', 'the apex domain, refused before and after'],
  ['junk-prefix-label', '_.geoxyz.eu', 'a label that is not a DNS label (F02)'],
];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1100, height: 620 } });
const rows = [];

for (const [name, host, caption] of CASES) {
  const url = `http://${host}:${PORT}/login`;
  const response = await page.goto(url, { waitUntil: 'networkidle' });
  const status = response.status();
  const file = `${SHOT_DIR}/${PREFIX}${name}.png`;
  await page.screenshot({ path: file });
  const sha = createHash('sha256').update(readFileSync(file)).digest('hex').slice(0, 16);
  rows.push({ name, host, status, caption, file, sha });
  console.log(`${String(status).padEnd(4)} ${host.padEnd(20)} ${sha}  ${file}`);
}

await browser.close();

// An accepted host renders the ordinary login page, and a screenshot of it
// cannot show which host was asked for — there is no browser chrome in the
// image. So the pair is compared instead: identical bytes mean the tightened
// pattern changed nothing for that host, different bytes mean it did.
console.log('\n| Host | HTTP | Screenshot | before == after | What it shows |');
console.log('|---|---|---|---|---|');
for (const r of rows) {
  const other = `${SHOT_DIR}/${PREFIX ? '' : 'before-'}${r.name}.png`;
  let same = 'no pair yet';
  if (existsSync(other)) {
    const otherSha = createHash('sha256').update(readFileSync(other)).digest('hex').slice(0, 16);
    same = otherSha === r.sha ? 'identical' : `differs (${otherSha} vs ${r.sha})`;
  }
  console.log(`| \`${r.host}\` | ${r.status} | \`${PREFIX}${r.name}.png\` | ${same} | ${r.caption} |`);
}
