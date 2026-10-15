# frozen_string_literal: true

# perf44 TEMPORARY (measurement session, not for commit): leave the plugins named in
# PERF44_EXCLUDE (comma separated directory names) out of loading, for leave-one-out timing.
if ENV['PERF44_EXCLUDE'].present?
  require 'redmine/plugin_loader'
  module Perf44Exclude
    def setup
      super
      excl = ENV['PERF44_EXCLUDE'].split(',')
      @plugin_directories.reject! { |d| excl.include?(File.basename(d.to_s)) }
    end
  end
  Redmine::PluginLoader.singleton_class.prepend(Perf44Exclude)
end
