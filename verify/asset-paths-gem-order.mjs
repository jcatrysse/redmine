// G9 for asset-paths-gem-order.
//
// The instance runs with its bundle in vendor/bundle (inside Rails.root) and
// with an engine gem in that bundle that ships its own chart.min.js, the way
// redmineup 1.1.13 does. The gem is a stand-in (asset_shadow_probe), not
// redmineup itself: see the dossier, "Live verification", for why.
//
//   PREFIX=before-        -> trunk, unpatched: the gem's file wins, no chart
//   PREFIX=               -> trunk with the patch: core's Chart.js 4 wins
//   PREFIX=nogem-         -> trunk with the patch, the stand-in gem removed
//                            from the bundle: nothing to reorder, chart drawn
//   PREFIX=geoxyz-before- -> 7.0-stable-GEOxyz at 1bf0ef69b (fix reverted)
//   PREFIX=geoxyz-        -> 7.0-stable-GEOxyz with the same commit as trunk
import { session, report } from '../tools/verify-lib.mjs';

const prefix = process.env.PREFIX ?? '';
const s = await session(process.env.SHOT_DIR);
const errors = [];
s.page.on('pageerror', e => errors.push(e.message));
s.page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

// The issue report details page draws a Chart.js bar chart through the
// importmap pin "chart.js" -> chart.min.js.
await s.go('/projects/geoxyz-verify/issues/report/tracker');
await s.page.waitForTimeout(1500);

const served = await s.page.evaluate(async () => {
  const map = JSON.parse(document.querySelector('script[type=importmap]').textContent);
  const url = map.imports['chart.js'];
  const head = (await (await fetch(url)).text()).slice(0, 160);
  return { url, head };
});
const drawn = await s.page.evaluate(() => {
  const c = document.querySelector('.issue-report-graph canvas');
  if (!c) return 'no canvas';
  const ctx = c.getContext('2d');
  const data = ctx.getImageData(0, 0, c.width, c.height).data;
  let painted = 0;
  for (let i = 3; i < data.length; i += 4) if (data[i] > 0) painted++;
  return `${c.width}x${c.height}, ${painted} painted pixels`;
});

console.log(`chart.js pin -> ${served.url}`);
console.log(`  first bytes: ${served.head.replace(/\s+/g, ' ')}`);
console.log(`canvas: ${drawn}`);
console.log(`page errors: ${errors.length ? errors.join(' | ') : 'none'}`);

await s.page.locator('.issue-report-graph').first().scrollIntoViewIfNeeded();
const captions = {
  'before-': 'Issue report by tracker, trunk unpatched, gem in vendor/bundle ships chart.min.js: no chart',
  '': 'Issue report by tracker, trunk with the patch, same bundle: core Chart.js 4 draws the chart',
  'nogem-': 'Issue report by tracker, trunk with the patch, no colliding gem: unchanged, chart drawn',
  'geoxyz-before-': 'Issue report by tracker, 7.0-stable-GEOxyz with the fix reverted, same gem: no chart',
  'geoxyz-': 'Issue report by tracker, 7.0-stable-GEOxyz with the same commit as the patch: chart drawn'
};
await s.shot(`${prefix}issue-report-chart`, captions[prefix], { full: true });

report(s.shots);
await s.browser.close();
