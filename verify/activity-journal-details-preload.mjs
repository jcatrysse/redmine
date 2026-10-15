// G9 verification for activity-journal-details-preload.
//
//   MODE=before WORKTREE=/tmp/claude-0/base \
//   SHOT_DIR=docs/features/activity-journal-details-preload/shots \
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node verify/activity-journal-details-preload.mjs
//
// MODE=before  runs against an unpatched trunk instance, shots are named before-*.
// MODE=after   runs against the patched instance, shots are named after-*.
// REDMINE_USER=dev runs the same pages as a non-admin project member; the shot
// names then carry "-member".
//
// The instance is prepared through `rails runner`: 1000 journals on the seeded
// issues of geoxyz-verify, spread over the last 20 days, half of them a status
// change and half a note with an assignee change. They are inserted once and
// recognised by their note prefix, so before and after read exactly the same
// data. Their timestamps are reset on every run to 750 s apart, counting back
// from midnight today, so all of them fall inside the default 10-day window and
// both modes render the same text on the same day.
//
// Every page is requested once to warm up and then RUNS times; time and query
// count come from the "Completed" line of each request in the server log, and
// the median is printed. A SHA-1 over the text of #activity is printed per page:
// it must be the same in both modes, which shows the preload changes no event.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { session, report } from '../tools/verify-lib.mjs';

const MODE = process.env.MODE || 'after';
const WORKTREE = process.env.WORKTREE || '/home/user/wt/patch-activity-journal-details-preload';
const LOG = process.env.SERVER_LOG || '/tmp/redmine-dev-3000.log';
const SHOT_DIR = process.env.SHOT_DIR || 'docs/features/activity-journal-details-preload/shots';
const RUNS = +(process.env.RUNS || 5);
const WHO = (process.env.REDMINE_USER || 'admin') === 'admin' ? '' : '-member';

const SEED = `
project = Project.find_by_identifier('geoxyz-verify')
issues = project.issues.to_a
users = User.where(login: %w[admin dev tester]).to_a
statuses = IssueStatus.sorted.pluck(:id)
if Journal.where("notes LIKE 'perf-activity%'").count < 1000
  now = Time.now
  rows = (1..1000).map do |i|
    {journalized_type: 'Issue', journalized_id: issues[i % issues.size].id, user_id: users[i % users.size].id,
     notes: (i.even? ? "perf-activity note #{i}" : 'perf-activity'), private_notes: false,
     created_on: now - (i * 1700), updated_on: now - (i * 1700)}
  end
  ids = Journal.insert_all(rows, returning: [:id]).rows.flatten
  details = ids.each_with_index.map do |id, i|
    if i.odd?
      {journal_id: id, property: 'attr', prop_key: 'status_id', old_value: statuses[0].to_s, value: statuses[1 + (i % (statuses.size - 1))].to_s}
    else
      {journal_id: id, property: 'attr', prop_key: 'assigned_to_id', old_value: nil, value: users[i % users.size].id.to_s}
    end
  end
  JournalDetail.insert_all(details)
end
anchor = Date.today.to_time.utc.strftime('%Y-%m-%d %H:%M:%S')
ActiveRecord::Base.connection.execute(<<~SQL)
  UPDATE journals SET created_on = t.ts, updated_on = t.ts
  FROM (SELECT id, TIMESTAMP '#{anchor}' - (row_number() OVER (ORDER BY id)) * INTERVAL '750 seconds' AS ts
        FROM journals WHERE notes LIKE 'perf-activity%') t
  WHERE journals.id = t.id
SQL
puts "JOURNALS=#{Journal.count} PERF_JOURNALS=#{Journal.where("notes LIKE 'perf-activity%'").count} DETAILS=#{JournalDetail.count}"
`;

function runner(code) {
  return execFileSync(
    'bundle', ['exec', 'ruby', 'bin/rails', 'runner', code],
    { cwd: WORKTREE, env: { ...process.env, RAILS_ENV: 'development' }, encoding: 'utf8' }
  );
}

console.log(runner(SEED).trim());

const s = await session(SHOT_DIR);
const { page } = s;
// ActivitiesController answers a repeated request with 304 Not Modified (ETag),
// which skips the rendering where the N+1 sits. Every sample must be a full
// render, so the conditional headers are dropped.
await page.route(/\/activity/, route => {
  const headers = { ...route.request().headers() };
  delete headers['if-none-match'];
  delete headers['if-modified-since'];
  route.continue({ headers });
});
const name = n => `${MODE}${WHO}-${n}`;
const results = [];

function completedSince(offset) {
  const lines = readFileSync(LOG, 'utf8').slice(offset).split('\n');
  const start = lines.findIndex(l => /^Started GET "\/(projects\/[^/]+\/)?activity/.test(l));
  return start < 0 ? undefined : lines.slice(start).find(l => l.startsWith('Completed'));
}

function parse(completed) {
  const m = (completed || '').match(/in (\d+)ms.*ActiveRecord: ([\d.]+)ms \((\d+) quer(?:y|ies), (\d+) cached\)/);
  return m ? { ms: +m[1], ar: +m[2], queries: +m[3], cached: +m[4] } : undefined;
}

const median = xs => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

async function measure(path) {
  await s.go(path);
  const samples = [];
  for (let i = 0; i < RUNS; i++) {
    const offset = readFileSync(LOG, 'utf8').length;
    await s.go(path);
    const p = parse(completedSince(offset));
    if (!p) throw new Error(`no parsable Completed line for ${path}`);
    samples.push(p);
  }
  const text = await page.locator('#content').innerText();
  const events = await page.locator('#activity dt').count();
  const sha = createHash('sha1').update(text).digest('hex').slice(0, 16);
  const r = {
    path, events, sha,
    ms: median(samples.map(x => x.ms)),
    ar: median(samples.map(x => x.ar)),
    queries: median(samples.map(x => x.queries)),
    cached: median(samples.map(x => x.cached)),
    samples,
  };
  results.push(r);
  console.log(`${path}: ${events} events, median ${r.ms} ms, ActiveRecord ${r.ar} ms, ${r.queries} queries (${r.cached} cached), sha ${sha}`);
  return r;
}

const label = r => `${r.events} events, median of ${RUNS}: ${r.ms} ms, ${r.queries} queries`;

let r = await measure('/activity');
await s.shot(name('activity-global'), `${MODE}: global activity (${label(r)})`);

r = await measure('/projects/geoxyz-verify/activity');
await s.shot(name('activity-project'), `${MODE}: project activity (${label(r)})`);

r = await measure('/projects/geoxyz-verify/activity?show_issues=1');
await s.shot(name('activity-issues-only'), `${MODE}: project activity, issues only (${label(r)})`);
await page.locator('#activity dt.issue-edit, #activity dt.issue-closed').first().scrollIntoViewIfNeeded();
await s.shot(name('journal-events'), `${MODE}: the journal events further down, with the new status in their title, read from the details`);

r = await measure('/projects/geoxyz-verify/activity?show_wiki_edits=1');
await s.shot(name('activity-no-issues'), `${MODE}: project activity without issues, no journal is fetched (${label(r)})`);

r = await measure('/projects/geoxyz-verify/activity?from=2001-01-31');
await s.shot(name('activity-empty'), `${MODE}: an empty period (${label(r)})`);

report(s.shots);
await s.browser.close();

console.log('\n| Page | Events | Median ms | Queries | Cached | SHA-1 of #content |');
console.log('|---|---|---|---|---|---|');
for (const x of results) console.log(`| \`${x.path}\` | ${x.events} | ${x.ms} | ${x.queries} | ${x.cached} | ${x.sha} |`);
console.log('\nSamples (ms/queries):');
for (const x of results) console.log(`  ${x.path}: ${x.samples.map(p => `${p.ms}/${p.queries}`).join(' ')}`);
