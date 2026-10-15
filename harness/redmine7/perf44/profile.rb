# CPU attribution with ruby-prof (in the full bundle). Run inside the app:
#   PROFILE_USER=member1 PROFILE_PASS=... bundle exec rails runner profile.rb '/my/page' ['/issues?...']
# Prints, per plugin, the inclusive wall time of its outermost frames (time spent in or below code of
# that plugin, nested frames of the same plugin not counted twice), and the top plugin methods.
require 'ruby-prof'

ROOT = Rails.root.to_s
PDIRS = [File.join(ROOT, 'plugins') + '/', (ENV['PERF44_PLUGINS_DIRECTORY'].to_s.chomp('/') + '/' if ENV['PERF44_PLUGINS_DIRECTORY'].present?)].compact

def plugin_of(file)
  return nil unless file
  d = PDIRS.find { |p| file.start_with?(p) }
  d ? file.delete_prefix(d).split('/', 2)[0] : nil
end

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host! '127.0.0.1'
s.get '/login'
token = s.response.body[/name="authenticity_token" value="([^"]+)"/, 1]
s.post '/login', params: { username: ENV['PROFILE_USER'] || 'member1', password: ENV['PROFILE_PASS'] || 'Perf44pass!', authenticity_token: token }
raise "login failed #{s.response.status}" unless s.response.status == 302

ARGV.each do |path|
  3.times { s.get path }
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  s.get path
  plain = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000
  prof = RubyProf::Profile.new(measure_mode: RubyProf::WALL_TIME)
  prof.start
  s.get path
  result = prof.stop
  per_plugin = Hash.new(0.0)
  per_method = Hash.new { |h, k| h[k] = [0.0, 0] }
  total = 0.0
  walk = lambda do |node, active|
    mi = node.target
    pl = plugin_of(mi.source_file)
    if pl && !active.include?(pl)
      per_plugin[pl] += node.total_time
      per_method["#{mi.full_name} (#{mi.source_file.to_s.sub(%r{.*/plugins/}, '')}:#{mi.line})"][0] += node.total_time
      per_method["#{mi.full_name} (#{mi.source_file.to_s.sub(%r{.*/plugins/}, '')}:#{mi.line})"][1] += 1
      active = active + [pl]
    end
    node.children.each { |c| walk.call(c, active) }
  end
  result.threads.each do |th|
    total += th.call_tree.total_time
    walk.call(th.call_tree, [])
  end
  puts '=' * 100
  puts format('%s  status=%d  unprofiled=%.0fms  profiled total=%.0fms', path, s.response.status, plain, total * 1000)
  puts '  inclusive time below each plugin\'s outermost frames (share of profiled total):'
  per_plugin.sort_by { |_, v| -v }.first(15).each { |k, v| puts format('    %6.0fms %5.1f%%  %s', v * 1000, 100 * v / total, k) }
  puts '  top outermost plugin methods:'
  per_method.sort_by { |_, (v, _)| -v }.first(18).each { |k, (v, n)| puts format('    %6.0fms %6dx  %s', v * 1000, n, k[0, 200]) }
end
