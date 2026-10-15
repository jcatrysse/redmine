# Run with `bin/rails runner` after `db:migrate`: prints what survived.
c = ActiveRecord::Base.connection
h = Webhook.find(3)
puts "webhooks=#{Webhook.count} projects_webhooks=#{c.select_value('SELECT COUNT(*) FROM projects_webhooks')} " \
     "trackers_webhooks=#{c.select_value('SELECT COUNT(*) FROM trackers_webhooks')}"
puts "hook 3: url=#{h.url} secret=#{h.secret} active=#{h.active} events=#{h.events.inspect} " \
     "projects=#{c.select_values('SELECT project_id FROM projects_webhooks WHERE webhook_id = 3').map(&:to_i).sort} " \
     "trackers=#{c.select_values('SELECT tracker_id FROM trackers_webhooks WHERE webhook_id = 3').map(&:to_i).sort}"
puts "leftover 5.1 tables: #{c.tables.grep(/geoxyz51/).inspect}"
puts "leftover 5.1 versions: #{(c.pool.schema_migration.versions & %w(20231120120000 20231120120100 20231120120200)).inspect}"
n = Webhook.new(:url => 'https://example.net/x', :user_id => 1, :events => ['issue.created'])
n.save(:validate => false)
puts "next webhook id: #{n.id}"
n.destroy
%w(display_revision_branches display_associated_revision_branches revision_branches_excluded revision_branches_enable_regex).each do |s|
  puts "#{s}=#{Setting.send(s).inspect}"
end
puts "leftover 5.1 settings: #{Setting.where(:name => %w(display_under_single_revision display_under_associated_revisions display_revision_branches_regex_enable display_revision_branches_enable_regex_delimiters search_token_limit)).pluck(:name).inspect}"
Setting.all.each(&:value)
puts "Setting.all.each(&:value): no error"
