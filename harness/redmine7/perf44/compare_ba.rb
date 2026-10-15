# ruby compare_ba.rb before.json after.json -> per page/user: core and all, before -> after, and the plugin overhead (all - core)
require 'json'
load = ->(f) { JSON.parse(File.read(f))['summary'].to_h { |r| [[r['page'], r['user'], r['target']], r] } }
b = load.(ARGV[0])
a = load.(ARGV[1])
fmt = ->(r) { r ? (r['status'] == '200' ? format('%.0f/%d', r['wall'], r['q']) : "HTTP #{r['status']}") : '-' }
puts '| page | user | core before -> after (ms/q) | all before -> after (ms/q) | all change | plugin overhead before -> after (ms, q) |'
puts '|---|---|---|---|---|---|'
a.keys.map { |p, u, _| [p, u] }.uniq.each do |p, u|
  cb, ca, ab, aa = b[[p, u, 'core']], a[[p, u, 'core']], b[[p, u, 'all']], a[[p, u, 'all']]
  ok = [cb, ca, ab, aa].all? { |r| r && r['status'] == '200' }
  change = ab && aa && ab['status'] == '200' && aa['status'] == '200' ? format('%+.0f%% / %+d q', 100.0 * (aa['wall'] - ab['wall']) / ab['wall'], aa['q'] - ab['q']) : ''
  over = ok ? format('%+.0f -> %+.0f ms, %+d -> %+d q', ab['wall'] - cb['wall'], aa['wall'] - ca['wall'], ab['q'] - cb['q'], aa['q'] - ca['q']) : ''
  puts "| #{p} | #{u} | #{fmt.(cb)} -> #{fmt.(ca)} | #{fmt.(ab)} -> #{fmt.(aa)} | #{change} | #{over} |"
end
