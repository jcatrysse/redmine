# ruby loo_report.rb  -> per page: which plugin's removal saves time/queries (leave-one-out vs the all-plugins baseline)
require 'json'
dir = File.join(__dir__, 'results', 'loo')
load = ->(f) { JSON.parse(File.read(f))['summary'].to_h { |r| ["#{r['page']}@#{r['user']}", r] } }
bases = %w[none none2].map { |b| File.join(dir, "#{b}.json") }.select { |f| File.exist?(f) }.map { |f| load.(f) }
abort 'no baseline' if bases.empty?
keys = bases.first.keys
base = keys.to_h { |k| [k, { 'wall' => bases.sum { |b| b[k]['wall'] } / bases.size, 'q' => bases.sum { |b| b[k]['q'] } / bases.size.to_f }] }
variants = Dir[File.join(dir, '*.json')].map { |f| File.basename(f, '.json') } - %w[none none2]
data = variants.to_h { |v| [v, load.(File.join(dir, "#{v}.json"))] }
min_ms = (ENV['MIN_MS'] || 15).to_f
puts "baseline (#{bases.size} run(s)): " + keys.map { |k| format('%s %.0fms/%dq', k, base[k]['wall'], base[k]['q']) }.join(', ')
if bases.size == 2
  puts 'baseline drift none->none2: ' + keys.map { |k| format('%s %+.0f%%', k, 100.0 * (bases[1][k]['wall'] - bases[0][k]['wall']) / bases[0][k]['wall']) }.join(', ')
end
keys.each do |k|
  rows = data.map { |v, d| next unless d[k]; [v, base[k]['wall'] - d[k]['wall'], base[k]['q'] - d[k]['q']] }.compact
  sig = rows.select { |_, ms, q| ms >= min_ms && ms >= 0.05 * base[k]['wall'] || q >= 5 }.sort_by { |_, ms, _| -ms }
  puts format('%-28s base %6.0f ms %4.0f q | %s', k, base[k]['wall'], base[k]['q'],
              sig.map { |v, ms, q| format('%s -%.0fms/-%dq', v.sub(/^redmine_/, ''), ms, q) }.join(', '))
end
