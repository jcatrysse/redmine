# ruby diff_trace.rb trace-all.jsonl trace-core.jsonl page user  -> query fingerprints the plugins add (all minus core),
# per request, with the plugin frames they come from in the all trace.
require 'json'
fa, fc, page, user = ARGV
def load(f, page, user)
  File.readlines(f).map { |l| JSON.parse(l) }.select { |r| _, u, pg, = r['label'].split('|'); pg == page && u == user }
end
a = load(fa, page, user)
c = load(fc, page, user)
agg = lambda do |rs|
  h = Hash.new { |hh, k| hh[k] = { n: 0.0, ms: 0.0, sites: Hash.new(0.0) } }
  rs.each do |r|
    r['sql'].each do |e|
      x = h[e['fp']]
      x[:n] += e['n'] / rs.size.to_f
      x[:ms] += e['ms'] / rs.size.to_f
      x[:sites][[e['plugin'] || '-', e['core'] || '-']] += e['n'] / rs.size.to_f
    end
  end
  h
end
ha = agg.call(a)
hc = agg.call(c)
tot_a = a.sum { |r| r['q'] } / a.size.to_f
tot_c = c.empty? ? 0 : c.sum { |r| r['q'] } / c.size.to_f
puts format('%s %s: all q=%.0f core q=%.0f delta=%.0f', page, user, tot_a, tot_c, tot_a - tot_c)
rows = ha.map { |fp, x| [fp, x, x[:n] - (hc[fp] ? hc[fp][:n] : 0)] }.select { |_, _, d| d >= 1 }.sort_by { |_, _, d| -d }
rows.first((ENV['TOP'] || 15).to_i).each do |fp, x, d|
  puts format('  +%5.0f  (all %5.0f, %6.1fms)  %s', d, x[:n], x[:ms], fp[0, 150])
  x[:sites].sort_by { |_, n| -n }.first(2).each { |(pl, co), n| puts format('           %4.0f  %s  [core %s]', n, pl[0, 230], co) }
end
