# ruby compare.rb results/main.json [base=core] [other=all]  -> markdown table, flags >30% time or >50 queries
require 'json'
file, base, other = ARGV[0], ARGV[1] || 'core', ARGV[2] || 'all'
s = JSON.parse(File.read(file))['summary']
idx = s.group_by { |r| [r['page'], r['user']] }
puts "| page | user | #{base} ms / q | #{other} ms / q | delta ms (%) | delta q | view ms #{base}->#{other} | db ms #{base}->#{other} | flag |"
puts '|---|---|---|---|---|---|---|---|---|'
idx.each do |(page, user), rows|
  b = rows.find { |r| r['target'] == base }
  o = rows.find { |r| r['target'] == other }
  next unless b && o

  if b['status'] != '200' || o['status'] != '200'
    puts "| #{page} | #{user} | #{b['status'] == '200' ? format('%.0f / %d', b['wall'], b['q']) : "HTTP #{b['status']}"} | #{format('%.0f / %d', o['wall'], o['q'])} (HTTP #{o['status']}) | | | | | #{b['status'] == '404' ? 'plugin page' : ''} |"
    next
  end
  dms = o['wall'] - b['wall']
  pct = 100.0 * dms / b['wall']
  dq = o['q'] - b['q']
  flag = []
  flag << 'time' if pct > 30
  flag << 'queries' if dq > 50
  puts format('| %s | %s | %.0f / %d | %.0f / %d | %+.0f (%+.0f%%) | %+d | %.0f -> %.0f | %.0f -> %.0f | %s |',
              page, user, b['wall'], b['q'], o['wall'], o['q'], dms, pct, dq, b['view'], o['view'], b['db'], o['db'], flag.join(' '))
end
