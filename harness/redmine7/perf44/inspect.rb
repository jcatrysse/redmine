puts "MODULES: " + Redmine::AccessControl.available_project_modules.map(&:to_s).join(' ')
puts "PERMS: #{Redmine::AccessControl.permissions.size}"
q = IssueQuery.new
puts "COLUMNS: " + q.available_columns.map { |c| "#{c.name}(#{c.class.name.to_s.split("::").last})" }.join(' ')
puts "FILTERS: " + q.available_filters.keys.join(' ')
puts "CF formats: " + Redmine::FieldFormat.available_formats.join(' ')
puts "TABLES: " + (ActiveRecord::Base.connection.tables.sort - %w[]).join(' ')
puts "PLUGINS: #{Redmine::Plugin.all.size}"
