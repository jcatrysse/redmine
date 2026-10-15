# ruby loo2_report.rb <outdir>  -> per page, ms and queries saved by leaving each variant out (same-run interleaved baseline)
require 'json'
dir = File.join(__dir__, 'results', ARGV[0] || 'loo2')
rows = Hash.new { |h, k| h[k] = [] }
Dir[File.join(dir, '*.json')].sort.each do |f|
  v = File.basename(f, '.json')
  s = JSON.parse(File.read(f))['summary']
  s.group_by { |r| "#{r['page']}@#{r['user']}" }.each do |k, rs|
    b = rs.find { |r| r['target'] == 'base' }
    l = rs.find { |r| r['target'] == 'loo' }
    next unless b && l
    rows[k] << [v, b['wall'] - l['wall'], b['q'] - l['q'], b['wall'], l['status']]
  end
end
min = (ENV['MIN_MS'] || 20).to_f
rows.each do |k, rs|
  base = rs.map { |r| r[3] }.sort[rs.size / 2]
  sig = rs.select { |_, ms, q, b| ms >= min && ms >= 0.04 * b || q >= 5 }.sort_by { |_, ms, _| -ms }
  puts format('%-26s base~%5.0fms | %s', k, base, sig.map { |v, ms, q, _, st| format('%s %+.0fms/%+dq%s', v.sub(/^redmine_/, ''), -ms, -q, st == '200' ? '' : " (#{st})") }.join(', '))
end
