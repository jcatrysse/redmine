require 'benchmark'
User.current = User.find_by(login: 'admin')
project = Project.find_by(identifier: 'bench')
COMMON = (1..60).map {|i| "common#{i}"}          # in every row
RARE   = (1..400).map {|i| "term#{i}"}.shuffle(random: Random.new(7))  # selective

def timed(runs = 5)
  ActiveRecord::Base.uncached { yield }
  t = runs.times.map { Benchmark.realtime { ActiveRecord::Base.uncached { yield } } }
  (t.sort[runs / 2] * 1000).round(1)
end

def q_for(project, field, op, terms)
  q = IssueQuery.new(name: '_', project: project)
  q.add_filter(field, op, [terms.join(' ')])
  q
end

puts "50 000 issues, description ~895 chars"
puts
[['worst case: every term matches every row', COMMON],
 ['realistic: selective terms',               RARE]].each do |label, vocab|
  puts "contains (~, AND) - #{label}"
  base = nil
  [1, 5, 10, 20, 50].each do |n|
    terms = vocab.first(n)
    ms  = timed { q_for(project, 'description', '~', terms).issue_count }
    cnt = q_for(project, 'description', '~', terms).issue_count
    base ||= ms
    puts format("  %2d terms | %8s ms | x%.1f | rows %6d", n, ms, ms / base, cnt)
  end
  puts
end

puts "contains any of (*~, OR) - selective terms"
base = nil
[1, 5, 10, 20, 50].each do |n|
  terms = RARE.first(n)
  ms  = timed { q_for(project, 'description', '*~', terms).issue_count }
  cnt = q_for(project, 'description', '*~', terms).issue_count
  base ||= ms
  puts format("  %2d terms | %8s ms | x%.1f | rows %6d", n, ms, ms / base, cnt)
end
puts
puts "global search, issues only, worst-case terms (what the limit guards)"
base = nil
[1, 5, 10, 20, 50].each do |n|
  ms = timed(3) do
    Redmine::Search::Fetcher.new(COMMON.first(n).join(' '), User.current,
      %w(issues), [project], token_limit: nil).result_count
  end
  base ||= ms
  puts format("  %2d tokens | %8s ms | x%.1f", n, ms, ms / base)
end
