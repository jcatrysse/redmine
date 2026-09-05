# frozen_string_literal: true

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

require_relative '../../../test_helper'

class Redmine::LdapNotificationDefaultsTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses, :user_preferences, :auth_sources

  def setup
    @dir = Dir.mktmpdir
    @journal = File.join(@dir, 'journal.json')
    # jsmith and dlopper come from LDAP, everybody else is a local account.
    User.where(:id => [2, 3]).update_all(:auth_source_id => 1)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_scope_should_only_return_accounts_with_an_auth_source
    assert_equal [2, 3], Redmine::LdapNotificationDefaults.scope.ids.sort
  end

  def test_scope_should_not_return_groups
    Group.generate!.update_column(:auth_source_id, 1)
    assert_equal [2, 3], Redmine::LdapNotificationDefaults.scope.ids.sort
  end

  def test_parse_should_keep_only_the_fields_that_were_given
    values = Redmine::LdapNotificationDefaults.parse('mail_notification' => 'none', 'apply' => '1')
    assert_equal({'mail_notification' => 'none'}, values)
  end

  def test_parse_should_read_the_three_fields
    values =
      Redmine::LdapNotificationDefaults.parse(
        'mail_notification' => 'only_assigned',
        'no_self_notified' => '1',
        'auto_watch_on' => 'issue_assigned_to_me, issue_created'
      )
    assert_equal 'only_assigned', values['mail_notification']
    assert_equal true, values['no_self_notified']
    assert_equal %w[issue_created issue_assigned_to_me], values['auto_watch_on']
  end

  def test_parse_should_read_an_empty_auto_watch_on_as_none
    values = Redmine::LdapNotificationDefaults.parse('auto_watch_on' => '')
    assert_equal({'auto_watch_on' => []}, values)
  end

  def test_parse_should_reject_an_unknown_mail_notification
    e = assert_raise(Redmine::LdapNotificationDefaults::Error) do
      Redmine::LdapNotificationDefaults.parse('mail_notification' => 'silent')
    end
    assert_include 'mail_notification', e.message
  end

  def test_parse_should_reject_an_unknown_auto_watch_on
    e = assert_raise(Redmine::LdapNotificationDefaults::Error) do
      Redmine::LdapNotificationDefaults.parse('auto_watch_on' => 'issue_created,everything')
    end
    assert_include 'everything', e.message
  end

  def test_parse_should_reject_a_non_boolean_no_self_notified
    assert_raise(Redmine::LdapNotificationDefaults::Error) do
      Redmine::LdapNotificationDefaults.parse('no_self_notified' => 'maybe')
    end
  end

  def test_new_should_reject_a_run_that_sets_nothing
    assert_raise(Redmine::LdapNotificationDefaults::Error) do
      Redmine::LdapNotificationDefaults.new('apply' => '1')
    end
  end

  def test_run_should_raise_when_no_account_has_an_auth_source
    User.update_all(:auth_source_id => nil)
    e = assert_raise(Redmine::LdapNotificationDefaults::Error) do
      set_defaults('mail_notification' => 'none', 'apply' => '1')
    end
    assert_include 'authentication source', e.message
  end

  def test_run_without_apply_should_change_nothing
    changed = set_defaults('mail_notification' => 'none', 'no_self_notified' => '1', 'auto_watch_on' => '')
    assert_equal 2, changed
    assert_equal 'all', User.find(2).mail_notification
    assert_equal false, User.find(2).pref.no_self_notified
  end

  def test_run_without_apply_should_still_write_the_journal
    set_defaults('mail_notification' => 'none')
    assert_equal false, JSON.parse(File.read(@journal))['applied']
    assert_equal [2, 3], JSON.parse(File.read(@journal))['users'].pluck('id').sort
  end

  def test_run_with_apply_should_set_the_three_fields
    changed =
      set_defaults('mail_notification' => 'none', 'no_self_notified' => '1',
                   'auto_watch_on' => 'issue_created', 'apply' => '1')
    assert_equal 2, changed
    user = User.find(2)
    assert_equal 'none', user.mail_notification
    assert_equal true, user.pref.no_self_notified
    assert_equal ['issue_created'], user.pref.auto_watch_on
  end

  def test_run_with_apply_should_leave_local_accounts_alone
    set_defaults('mail_notification' => 'none', 'apply' => '1')
    assert_equal 'all', User.find(1).mail_notification
    assert_equal 'all', User.find(4).mail_notification
  end

  def test_run_should_leave_a_field_that_was_not_given_alone
    User.find(2).pref.update!(:auto_watch_on => ['issue_created'])
    set_defaults('mail_notification' => 'none', 'apply' => '1')
    assert_equal ['issue_created'], User.find(2).pref.auto_watch_on
  end

  def test_run_should_leave_unrelated_preferences_alone
    User.find(2).pref.update!(:comments_sorting => 'desc')
    set_defaults('mail_notification' => 'none', 'apply' => '1')
    assert_equal 'desc', User.find(2).pref.comments_sorting
  end

  def test_run_should_skip_an_account_that_already_holds_the_values
    User.find(2).update_column(:mail_notification, 'none')
    was = User.find(2).updated_on
    output = StringIO.new
    changed = set_defaults({'mail_notification' => 'none', 'apply' => '1'}, output)
    assert_equal 1, changed
    assert_include 'SKIP:   jsmith already set', output.string
    assert_equal was, User.find(2).updated_on
  end

  def test_run_should_journal_the_previous_values
    set_defaults('mail_notification' => 'none', 'no_self_notified' => '1', 'apply' => '1')
    entry = JSON.parse(File.read(@journal))['users'].detect {|u| u['id'] == 2}
    assert_equal 'all', entry['previous']['mail_notification']
    assert_equal false, entry['previous']['no_self_notified']
    assert_nil entry['previous']['auto_watch_on']
  end

  def test_run_should_roll_back_every_account_when_a_later_one_fails
    break_preferences_of_dlopper
    assert_raise(StandardError) do
      set_defaults('mail_notification' => 'none', 'no_self_notified' => '1', 'apply' => '1')
    end
    assert_equal 'all', User.find(2).mail_notification
    assert_equal 'all', User.find(3).mail_notification
  end

  def test_run_should_name_the_account_it_failed_on
    break_preferences_of_dlopper
    e = assert_raise(StandardError) do
      set_defaults('mail_notification' => 'none', 'no_self_notified' => '1', 'apply' => '1')
    end
    assert_include 'dlopper', e.message
  end

  def test_undo_should_restore_the_previous_values
    set_defaults('mail_notification' => 'none', 'no_self_notified' => '1', 'apply' => '1')
    assert_equal 2, Redmine::LdapNotificationDefaults.undo(
      {'journal' => @journal, 'apply' => '1'}, StringIO.new
    )
    assert_equal 'all', User.find(2).mail_notification
    assert_equal false, User.find(2).pref.no_self_notified
  end

  def test_undo_without_apply_should_change_nothing
    set_defaults('mail_notification' => 'none', 'apply' => '1')
    Redmine::LdapNotificationDefaults.undo({'journal' => @journal}, StringIO.new)
    assert_equal 'none', User.find(2).mail_notification
  end

  def test_undo_should_skip_an_account_that_no_longer_exists
    set_defaults('mail_notification' => 'none', 'apply' => '1')
    User.find(3).destroy
    output = StringIO.new
    assert_equal 1, Redmine::LdapNotificationDefaults.undo(
      {'journal' => @journal, 'apply' => '1'}, output
    )
    assert_include 'no longer exists', output.string
  end

  def test_undo_should_raise_without_a_journal
    assert_raise(Redmine::LdapNotificationDefaults::Error) do
      Redmine::LdapNotificationDefaults.undo({}, StringIO.new)
    end
  end

  def test_undo_should_raise_on_a_missing_journal_file
    assert_raise(Redmine::LdapNotificationDefaults::Error) do
      Redmine::LdapNotificationDefaults.undo({'journal' => File.join(@dir, 'gone.json')}, StringIO.new)
    end
  end

  private

  # dlopper is the second account the pass reaches, and after this its stored
  # preferences can no longer be read, so it fails once jsmith is written.
  def break_preferences_of_dlopper
    UserPreference.where(:user_id => 3).update_all(:others => "--- !ruby/object:Redmine::LdapNotificationDefaults {}\n")
  end

  def set_defaults(options, io=StringIO.new)
    Redmine::LdapNotificationDefaults.new(options.merge('journal' => @journal)).run(io)
  end
end
