# ruby loo_ba.rb -> per plugin and page: ms / queries saved by leaving it out, before (loo2, loo2b, loo3) vs after (loo_after)
require 'json'
R = File.join(__dir__, 'results')
def saved(dir)
  out = {}
  Dir[File.join(R, dir, '*.json')].each do |f|
    v = File.basename(f, '.json')
    JSON.parse(File.read(f))['summary'].group_by { |r| "#{r['page']}@#{r['user']}" }.each do |k, rs|
      b = rs.find { |r| r['target'] == 'base' }
      l = rs.find { |r| r['target'] == 'loo' }
      next unless b && l && l['status'] == '200'
      out[[v, k]] = [b['wall'] - l['wall'], b['q'] - l['q'], b['wall']]
    end
  end
  out
end
before = saved('loo2').merge(saved('loo3')).merge(saved('loo2b'))
after = saved('loo_after')
puts '| plugin | page@user | saved before (ms / q) | saved after (ms / q) |'
puts '|---|---|---|---|'
after.keys.map(&:first).uniq.sort.each do |v|
  after.select { |(pv, _), _| pv == v }.sort_by { |(_, k), _| k }.each do |(_, k), (ms, q, _)|
    b = before[[v, k]]
    next if ms.abs < 25 && q.abs < 5 && (b.nil? || (b[0].abs < 25 && b[1].abs < 5))
    puts format('| %s | %s | %s | %.0f / %d |', v, k, b ? format('%.0f / %d', b[0], b[1]) : 'n/m', ms, q)
  end
end
