# frozen_string_literal: true

# Quiet mail prefs for users who belong only to the LDAP sync holding group.
# Forward-port of 9e2c38e2d (GEOxyz #5986).

namespace :user do
  desc <<-END_DESC
Quiet email notification prefs for users who belong only to the LDAP sync group.

Users who are also in any other group are skipped.

Options:
  GROUP=name   group lastname (default: ldap_sync_users)

Example:
  rake user:disable_mail_ldap_users RAILS_ENV=production
  rake user:disable_mail_ldap_users GROUP=ldap_sync_users RAILS_ENV=production
END_DESC
  task disable_mail_ldap_users: :environment do
    group_name = ENV['GROUP'].presence || 'ldap_sync_users'
    sync_group = Group.named(group_name).first
    if sync_group.nil?
      puts "Group '#{group_name}' not found."
      next
    end

    sync_group.users.preload(:groups).find_each do |user|
      other_groups = user.groups.reject {|g| g.id == sync_group.id}

      if other_groups.any?
        puts "SKIP: #{user.login} is also in groups: #{other_groups.map(&:lastname).join(', ')}"
        next
      end

      puts "UPDATE: #{user.login} is only in #{group_name} — updating preferences..."

      user.mail_notification = 'only_assigned'
      user.pref.no_self_notified = true
      user.pref.auto_watch_on = []
      user.pref.save
      user.save(validate: false)
    end
  end
end
