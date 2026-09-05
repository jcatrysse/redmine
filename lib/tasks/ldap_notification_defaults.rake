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

namespace :redmine do
  namespace :users do
    desc <<-DESC
Sets the notification preferences of every account that an authentication source
owns, for the one-off pass after an LDAP import. Local accounts, the built-in
administrator included, have no authentication source and are never touched.

Only the preferences you name are written; the ones you leave out keep their
current value. Nothing is written unless apply=1 is given: without it the task
reports what it would change. Either way it writes a journal file holding the
previous values of every account it would touch, so that a run can be undone
with redmine:users:undo_ldap_notification_defaults.

Available options:
  * mail_notification => all, selected, only_my_events, only_assigned,
                         only_owner, only_my_watches or none
  * no_self_notified  => 1 or 0
  * auto_watch_on     => comma separated list of issue_created,
                         issue_contributed_to and issue_assigned_to_me, or
                         empty for none
  * apply             => 1 to write the changes; omit it to report only
  * journal           => path of the journal file, defaults to
                         log/ldap-notification-defaults-<timestamp>.json

Example:
  bundle exec rake redmine:users:set_ldap_notification_defaults mail_notification=none no_self_notified=1 auto_watch_on= apply=1 RAILS_ENV="production"
DESC
    task :set_ldap_notification_defaults => :environment do
      Redmine::LdapNotificationDefaults.new(ENV.to_h).run
    rescue Redmine::LdapNotificationDefaults::Error => e
      abort e.message
    end

    desc <<-DESC
Restores the notification preferences recorded in the journal file of an earlier
redmine:users:set_ldap_notification_defaults run.

Available options:
  * journal => path of the journal file to undo
  * apply   => 1 to write the changes; omit it to report only

Example:
  bundle exec rake redmine:users:undo_ldap_notification_defaults journal=log/ldap-notification-defaults-20260905-101500.json apply=1 RAILS_ENV="production"
DESC
    task :undo_ldap_notification_defaults => :environment do
      Redmine::LdapNotificationDefaults.undo(ENV.to_h)
    rescue Redmine::LdapNotificationDefaults::Error => e
      abort e.message
    end
  end
end
