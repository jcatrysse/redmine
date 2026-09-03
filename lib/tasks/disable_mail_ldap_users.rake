# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

namespace :user do
  desc "Mute the mail notifications of the users whose only group is ldap_sync_users"
  task :disable_mail_ldap_users => :environment do
    group = Group.find_by(:lastname => 'ldap_sync_users')
    abort "Group 'ldap_sync_users' not found." if group.nil?

    group.users.preload(:groups).find_each do |user|
      other_groups = user.groups.reject {|g| g.id == group.id}
      if other_groups.any?
        puts "SKIP:   #{user.login} is also in #{other_groups.map(&:lastname).join(', ')}"
      else
        user.mail_notification = 'only_assigned'
        user.pref[:no_self_notified] = true
        user.pref.auto_watch_on = []
        user.pref.save
        user.save(:validate => false)
        puts "UPDATE: #{user.login}"
      end
    end
  end
end
