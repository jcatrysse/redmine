# Cost of building IssueQuery#available_filters (what /issues, my page blocks, calendar, gantt do per request).
User.current = User.find_by_login(ENV['U'] || 'member1')
proj = Project.find_by(identifier: 'geo-main')
def bench(n)
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { yield }
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000 / n
end
ActiveRecord::Base.cache do
  3.times { IssueQuery.new(name: '_').available_filters }
  g = bench(10) { IssueQuery.new(name: '_').available_filters }
  pr = bench(10) { IssueQuery.new(name: '_', project: proj).available_filters }
  n = IssueQuery.new(name: '_').available_filters.size
  puts format('available_filters: global %.1f ms, project %.1f ms, %d filters (user %s, plugins %d)', g, pr, n, User.current.login, Redmine::Plugin.all.size)
  if ENV['PROF'] == '1'
    require 'ruby-prof'
    res = RubyProf::Profile.profile { 5.times { IssueQuery.new(name: '_').available_filters } }
    rows = res.threads.flat_map(&:methods).sort_by { |m| -m.self_time }.first(25)
    rows.each { |m| puts format('  self %7.1fms total %7.1fms %6dx  %s  %s:%d', m.self_time * 1000 / 5, m.total_time * 1000 / 5, m.called / 5, m.full_name[0, 90], m.source_file.to_s.sub(%r{.*/(plugins|gems)/}, ''), m.line) }
    puts '  -- by total time (plugin methods):'
    res.threads.flat_map(&:methods).select { |m| m.source_file.to_s.include?('/plugins/') }.sort_by { |m| -m.total_time }.first(15).each { |m| puts format('  total %7.1fms self %6.1fms %6dx  %s  %s:%d', m.total_time * 1000 / 5, m.self_time * 1000 / 5, m.called / 5, m.full_name[0, 90], m.source_file.to_s.sub(%r{.*/plugins/}, ''), m.line) }
  end
end
