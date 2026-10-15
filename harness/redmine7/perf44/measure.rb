# perf44 page measurement driver (plain Ruby, no bundler).
#   ruby measure.rb --targets all=3100,core=3101 --users admin,member1 --reps 5 --out results/main
#   options: --pages a,b  --trace (send X-Perf-Trace on measured requests)
require 'net/http'
require 'json'
require 'uri'
require 'optparse'

P = __dir__
opts = { targets: 'all=3100,core=3101', users: 'admin,member1', reps: 5, out: File.join(P, 'results', 'run'), pages: nil, trace: false, warm: 1 }
OptionParser.new do |o|
  o.on('--targets T') { |v| opts[:targets] = v }
  o.on('--users U') { |v| opts[:users] = v }
  o.on('--reps N', Integer) { |v| opts[:reps] = v }
  o.on('--warm N', Integer) { |v| opts[:warm] = v }
  o.on('--out F') { |v| opts[:out] = v }
  o.on('--pages L') { |v| opts[:pages] = v.split(',') }
  o.on('--trace') { opts[:trace] = true }
  o.on('--pu L') { |v| opts[:pu] = v.split(',').map { |x| x.split('@') } }
end.parse!

CFG = JSON.parse(File.read(File.join(P, 'config.json')))
PASS = { 'admin' => 'Perf44admin!', 'member1' => 'Perf44pass!' }
KEYS = { 'admin' => CFG['admin_key'], 'member1' => CFG['member_key'] }
pj = CFG['project']
ctx = CFG['context_ids'].map { |i| "ids[]=#{i}" }.join('&')
plugcols = %w[project tracker status subject assigned_to fixed_version cf_2 cf_3 cf_8 tags_relations checklist_relations story_points agile_sprint
              impact_id urgency_id issue_todo_list_titles.titles last_message helpdesk_contact contact_company].map { |c| "c[]=#{c}" }.join('&')
PAGES = {
  'issues_25' => '/issues?set_filter=1&per_page=25',
  'issues_100' => '/issues?set_filter=1&per_page=100',
  'issues_plugcols_25' => "/issues?set_filter=1&per_page=25&#{plugcols}",
  'issues_plugcols_100' => "/issues?set_filter=1&per_page=100&#{plugcols}",
  'proj_issues_25' => "/projects/#{pj}/issues?set_filter=1&per_page=25",
  'proj_issues_100' => "/projects/#{pj}/issues?set_filter=1&per_page=100",
  'issue_show' => "/issues/#{CFG['showcase']}",
  'issue_new' => "/projects/#{pj}/issues/new",
  'project_overview' => "/projects/#{pj}",
  'projects' => '/projects',
  'my_page' => '/my/page',
  'project_settings' => "/projects/#{pj}/settings",
  'calendar' => '/issues/calendar',
  'gantt' => '/issues/gantt',
  'agile_board' => "/projects/#{pj}/agile/board",
  'context_menu' => "/issues/context_menu?#{ctx}",
  'users' => '/users',
  'wiki' => "/projects/#{pj}/wiki/Wiki",
  'activity' => '/activity',
  'search' => '/search?q=x',
  'search_word' => '/search?q=vessel',
  'api_issues_100' => '/issues.json?limit=100'
}.freeze
pages = opts[:pages] ? PAGES.slice(*opts[:pages]) : PAGES
targets = opts[:targets].split(',').to_h { |t| n, port = t.split('='); [n, port.to_i] }
users = opts[:users].split(',')

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

class Client
  attr_reader :cookies

  def initialize(port)
    @port = port
    @cookies = {}
    connect
  end

  def connect
    @http = Net::HTTP.new('127.0.0.1', @port)
    @http.read_timeout = 600
    @http.keep_alive_timeout = 30
    @http.start
  end

  def store(res)
    Array(res.get_fields('set-cookie')).each { |c| k, v = c.split(';', 2)[0].split('=', 2); @cookies[k] = v }
  end

  def request(req)
    req['Cookie'] = @cookies.map { |k, v| "#{k}=#{v}" }.join('; ') unless @cookies.empty?
    tries = 0
    begin
      res = @http.request(req)
    rescue EOFError, Errno::ECONNRESET, Net::ReadTimeout, IOError
      tries += 1
      raise if tries > 2

      connect
      retry
    end
    store(res)
    res
  end

  def login(user, pass)
    res = request(Net::HTTP::Get.new('/login'))
    token = res.body[/name="authenticity_token" value="([^"]+)"/, 1] || res.body[/name="csrf-token" content="([^"]+)"/, 1]
    post = Net::HTTP::Post.new('/login')
    post.set_form_data('username' => user, 'password' => pass, 'authenticity_token' => token, 'back_url' => '/')
    res = request(post)
    raise "login #{user} on #{@port} failed: #{res.code} #{res['location']}" unless res.code == '302' && res['location'] !~ %r{/login}
  end

  def get(path, user, trace_label = nil)
    req = Net::HTTP::Get.new(path)
    if path.include?('.json')
      req['X-Redmine-API-Key'] = KEYS[user]
      saved = @cookies
      @cookies = {}
    end
    req['Accept'] = path.include?('.json') ? 'application/json' : 'text/html'
    req['X-Perf-Trace'] = trace_label if trace_label
    t = now
    res = request(req)
    body = res.body.to_s
    wall = (now - t) * 1000
    @cookies = saved if saved
    { 'wall' => wall.round(1), 'status' => res.code.to_i, 'bytes' => body.bytesize,
      'q' => res['x-perf-queries'].to_i, 'cached' => res['x-perf-cached'].to_i, 'sql' => res['x-perf-sql-ms'].to_f,
      'view' => res['x-perf-view-ms'].to_f, 'db' => res['x-perf-db-ms'].to_f, 'act' => res['x-perf-action-ms'].to_f, 'srv' => res['x-perf-total-ms'].to_f,
      'action' => res['x-perf-action'], 'location' => res['location'] }
  end
end

plan = opts[:pu] ? opts[:pu].map { |pg, u| [pg, PAGES.fetch(pg), u] } : pages.flat_map { |pg, path| users.map { |u| [pg, path, u] } }
users = plan.map(&:last).uniq if opts[:pu]
pages = plan.to_h { |pg, path, _| [pg, path] } if opts[:pu]
clients = {}
targets.each { |tn, port| users.each { |u| c = Client.new(port); c.login(u, PASS[u]); clients[[tn, u]] = c } }
med = ->(a) { s = a.sort; n = s.size; n.odd? ? s[n / 2] : ((s[n / 2 - 1] + s[n / 2]) / 2.0) }
raw = []
summary = []
# global warm-up pass: compile templates and fill caches for every page
opts[:warm].times { plan.each { |_pg, path, u| targets.each_key { |tn| clients[[tn, u]].get(path, u) } } }
plan.each do |pname, path, u|
  begin
    targets.each_key { |tn| clients[[tn, u]].get(path, u) } # discarded
    runs = Hash.new { |h, k| h[k] = [] }
    opts[:reps].times do |r|
      targets.each_key do |tn|
        m = clients[[tn, u]].get(path, u, opts[:trace] ? "#{tn}|#{u}|#{pname}|#{r}" : nil)
        runs[tn] << m
        raw << m.merge('target' => tn, 'user' => u, 'page' => pname, 'rep' => r)
      end
    end
    targets.each_key do |tn|
      a = runs[tn]
      row = { 'page' => pname, 'user' => u, 'target' => tn, 'status' => a.map { |m| m['status'] }.uniq.join('/'),
              'wall' => med.(a.map { |m| m['wall'] }), 'q' => med.(a.map { |m| m['q'] }), 'sql' => med.(a.map { |m| m['sql'] }),
              'view' => med.(a.map { |m| m['view'] }), 'db' => med.(a.map { |m| m['db'] }), 'act' => med.(a.map { |m| m['act'] }), 'srv' => med.(a.map { |m| m['srv'] }),
              'bytes' => med.(a.map { |m| m['bytes'] }), 'min' => a.map { |m| m['wall'] }.min, 'max' => a.map { |m| m['wall'] }.max,
              'action' => a.first['action'] }
      summary << row
      $stdout.puts format('%-20s %-8s %-5s %-7s wall %8.1f ms (min %7.1f max %7.1f)  q %5d  sql %7.1f  view %8.1f  db %7.1f  %s',
                          pname, u, tn, row['status'], row['wall'], row['min'], row['max'], row['q'], row['sql'], row['view'], row['db'], row['action'])
      $stdout.flush
    end
  end
end
File.write("#{opts[:out]}.json", JSON.pretty_generate('summary' => summary, 'raw' => raw, 'opts' => opts))
File.open("#{opts[:out]}.tsv", 'w') do |f|
  f.puts %w[page user target status wall_ms q sql_ms view_ms db_ms srv_ms bytes min max action act_ms].join("\t")
  summary.each { |r| f.puts r.values_at(*%w[page user target status wall q sql view db srv bytes min max action act]).join("\t") }
end
