# Harness shim: shoulda-context 2.0 (in the shared bundle through redmine_wiki_extensions'
# PluginGemfile) calls Rails::TestUnitReporter#executable, which Rails 8.1 no longer has,
# so the first failure crashed the reporter and the run printed no summary.
require 'rails/test_unit/reporter'
class Rails::TestUnitReporter
  def executable
    'bin/rails test'
  end unless method_defined?(:executable)
end
