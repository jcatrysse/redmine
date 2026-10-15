User.current = User.find_by_login(ENV['U'] || 'member1')
def bench(n = 10)
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { yield }
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000 / n
end
ActiveRecord::Base.cache do
  q = IssueQuery.new(name: '_')
  q.available_filters
  puts format('assigned_to_values (zenedit viewed_by_id, eager): %.1f ms, %d values', bench { IssueQuery.new(name: '_').send(:assigned_to_values) }, q.send(:assigned_to_values).size)
  begin; puts format("itil impact_options+urgency_options (global): %.1f ms", bench { RedmineItilPriority.impact_options(nil, nil); RedmineItilPriority.urgency_options(nil, nil) }); rescue => e; puts "itil options: #{e.class}"; end
  puts format('Issue.visible_condition(member): %.1f ms', bench { Issue.visible_condition(User.current) })
  puts format('IssueQuery.new.available_columns: %.1f ms', bench { IssueQuery.new(name: '_').available_columns })
end
