# ruby analyze_trace.rb <trace.jsonl> [page-regex] [user]  -> per page/user: queries per plugin, top query sites, hook listener time
require 'json'
file, page_re, user = ARGV
page_re = Regexp.new(page_re || '.')
recs = File.readlines(file).map { |l| JSON.parse(l) }.select { |r| t, u, pg, = r['label'].split('|'); pg =~ page_re && (user.nil? || u == user) && t }
recs.group_by { |r| r['label'].split('|')[0..2] }.each do |(target, u, pg), rs|
  n = rs.size.to_f
  puts "=" * 100
  puts format('%s %s %s  reps=%d  q=%.0f sql=%.0fms view=%.0f db=%.0f act=%s total=%.0f', target, u, pg, rs.size,
              rs.sum { |r| r['q'] } / n, rs.sum { |r| r['sql_ms'] } / n, rs.sum { |r| r['view'].to_f } / n, rs.sum { |r| r['db'].to_f } / n,
              rs.map { |r| r['act'] }.compact.then { |a| a.empty? ? '-' : format('%.0f', a.sum / a.size) }, rs.sum { |r| r['total_ms'] } / n)
  by_plugin = Hash.new(0.0)
  by_site = Hash.new { |h, k| h[k] = [0.0, 0.0] }
  rs.each do |r|
    r['sql'].each do |e|
      pl = e['plugin'] ? e['plugin'].split('/')[0].sub(/:\d+$/, '') : 'core'
      by_plugin[pl] += e['n'] / n
      s = by_site[[e['plugin'] || '-', e['core'] || '-', e['fp']]]
      s[0] += e['n'] / n
      s[1] += e['ms'] / n
    end
  end
  puts '  queries by innermost plugin frame: ' + by_plugin.sort_by { |_, v| -v }.map { |k, v| format('%s=%.0f', k, v) }.join('  ')
  stack = Hash.new(0.0)
  rs.each { |r| r['plugins_in_stack'].each { |k, v| stack[k] += v / n } }
  puts '  plugin anywhere in stack: ' + stack.sort_by { |_, v| -v }.first(12).map { |k, v| format('%s=%.0f', k, v) }.join('  ')
  puts '  top query sites (n/request, ms):'
  by_site.sort_by { |_, (c, _)| -c }.first((ENV['TOP'] || 12).to_i).each do |(pl, co, fp), (c, ms)|
    puts format('    %6.1f %7.1fms  plugin=%s  core=%s', c, ms, pl, co)
    puts "             #{fp[0, 180]}"
  end
  hooks = Hash.new { |h, k| h[k] = [0.0, 0.0, 0.0] }
  rs.each { |r| r['hooks'].each { |h| x = hooks[h['hook']]; x[0] += h['n'] / n; x[1] += h['ms'] / n; x[2] += h['q'] / n } }
  puts format('  hooks total %.0f ms; top listeners (calls, ms, queries):', hooks.values.sum { |v| v[1] })
  hooks.sort_by { |_, v| -v[1] }.first(10).each { |k, (c, ms, q)| puts format('    %5.0f %8.1fms %5.0fq  %s', c, ms, q, k) }
end
