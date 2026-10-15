# frozen_string_literal: true

# perf44 TEMPORARY instrumentation (measurement session, not for commit).
# Per request: SQL count (SCHEMA/CACHE skipped), SQL ms, view/db runtime, returned as x-perf-* headers.
# PERF44_TRACE=1 additionally attributes each query to the innermost plugin frame and the innermost core
# app frame, and times every hook listener; one JSON line per request in PERF44_TRACE_FILE.
require 'json'

module Perf44
  ROOT = Rails.root.to_s
  PLUGIN_DIRS = [File.join(ROOT, 'plugins') + '/', (ENV['PERF44_PLUGINS_DIRECTORY'].to_s.chomp('/') + '/' if ENV['PERF44_PLUGINS_DIRECTORY'].present?)].compact
  TRACE = ENV['PERF44_TRACE'] == '1'
  TRACE_FILE = ENV['PERF44_TRACE_FILE'] || File.join(ROOT, 'log', 'perf44_trace.jsonl')
  PLUGIN_GEMS = %r{/gems/(redmineup|deface|liquid|render_parent|acts_as_list|vcard|ruby-openai|jwt)-[^/]+/}

  def self.now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def self.fingerprint(sql)
    sql.gsub(/'(?:[^']|'')*'/, '?').gsub(/\b\d+(\.\d+)?\b/, '?').gsub(/\$\d+/, '?')
       .gsub(/\((?:\s*\?\s*,)+\s*\?\s*\)/, '(?..)').gsub(/\s+/, ' ')[0, 220]
  end

  def self.frames(locs)
    plugin = core = nil
    stack = []
    chain = []
    locs.each do |l|
      path = l.absolute_path || l.path
      next unless path
      if (pd = PLUGIN_DIRS.find { |d| path.start_with?(d) })
        rel = path.delete_prefix(pd)
        fr = "#{rel}:#{l.lineno}"
        if plugin.nil?
          plugin = fr
        elsif chain.size < 3 && !chain.any? { |c| c.start_with?(rel.split(':')[0]) } && !plugin.start_with?(rel)
          chain << fr
        end
        stack << rel.split('/', 2)[0]
      elsif (m = PLUGIN_GEMS.match(path))
        plugin ||= "gem:#{m[1]}/#{File.basename(path)}:#{l.lineno}"
        stack << "gem:#{m[1]}"
      elsif core.nil? && path.start_with?(ROOT) && !path.include?('/vendor/') && !path.include?('zz_perf44')
        core = "#{path.delete_prefix(ROOT + '/')}:#{l.lineno}"
      end
    end
    plugin = ([plugin] + chain).join(' < ') if plugin && chain.any?
    [plugin, core, stack.uniq]
  end

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      st = Thread.current[:perf44] = { q: 0, cached: 0, sql_ms: 0.0 }
      if TRACE
        st[:sql] = Hash.new { |h, k| h[k] = [0, 0.0] }
        st[:hooks] = Hash.new { |h, k| h[k] = [0, 0.0, 0] }
        st[:plugins] = Hash.new(0)
      end
      t0 = Perf44.now
      status, headers, body = @app.call(env)
      ms = (Perf44.now - t0) * 1000
      headers['x-perf-queries'] = st[:q].to_s
      headers['x-perf-cached'] = st[:cached].to_s
      headers['x-perf-sql-ms'] = format('%.1f', st[:sql_ms])
      headers['x-perf-view-ms'] = format('%.1f', st[:view] || -1)
      headers['x-perf-db-ms'] = format('%.1f', st[:db] || -1)
      headers['x-perf-action-ms'] = format('%.1f', st[:act] || -1)
      headers['x-perf-total-ms'] = format('%.1f', ms)
      headers['x-perf-action'] = st[:action].to_s
      if TRACE && env['HTTP_X_PERF_TRACE']
        rec = { label: env['HTTP_X_PERF_TRACE'], path: env['REQUEST_URI'] || env['PATH_INFO'], status: status, total_ms: ms.round(1),
                q: st[:q], sql_ms: st[:sql_ms].round(1), view: st[:view], db: st[:db], act: st[:act],
                plugins_in_stack: st[:plugins],
                sql: st[:sql].map { |(pl, co, fp), (n, t)| { plugin: pl, core: co, fp: fp, n: n, ms: t.round(2) } }.sort_by { |h| -h[:n] },
                hooks: st[:hooks].map { |k, (n, t, q)| { hook: k, n: n, ms: t.round(2), q: q } }.sort_by { |h| -h[:ms] } }
        File.open(TRACE_FILE, 'a') { |f| f.puts(rec.to_json) }
      end
      [status, headers, body]
    ensure
      Thread.current[:perf44] = nil
    end
  end

  module HookTiming
    def call_hook(hook, context = {})
      st = Thread.current[:perf44]
      return super unless st && st[:hooks]

      [].tap do |response|
        hook_listeners(hook).each do |listener|
          t = Perf44.now
          q0 = st[:q]
          response << listener.send(hook, context)
          h = st[:hooks]["#{listener.class.name}##{hook}"]
          h[0] += 1
          h[1] += (Perf44.now - t) * 1000
          h[2] += st[:q] - q0
        end
      end
    end
  end
end

Rails.application.config.middleware.insert_before 0, Perf44::Middleware
ActionMailer::Base.perform_deliveries = false

ActiveSupport::Notifications.subscribe('sql.active_record') do |event|
  st = Thread.current[:perf44]
  next unless st

  p = event.payload
  next if p[:name] == 'SCHEMA' || p[:name] == 'EXPLAIN'
  if p[:cached]
    st[:cached] += 1
    next
  end
  st[:q] += 1
  st[:sql_ms] += event.duration
  if st[:sql]
    plugin, core, stack = Perf44.frames(caller_locations)
    e = st[:sql][[plugin, core, Perf44.fingerprint(p[:sql])]]
    e[0] += 1
    e[1] += event.duration
    stack.each { |s| st[:plugins][s] += 1 }
  end
end

ActiveSupport::Notifications.subscribe('process_action.action_controller') do |event|
  st = Thread.current[:perf44]
  next unless st

  st[:view] = event.payload[:view_runtime]
  st[:db] = event.payload[:db_runtime]
  st[:act] = event.duration
  st[:action] = "#{event.payload[:controller]}##{event.payload[:action]}"
end

Rails.application.config.after_initialize do
  Redmine::Hook.singleton_class.prepend(Perf44::HookTiming) if Perf44::TRACE
end
