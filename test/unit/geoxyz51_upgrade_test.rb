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

require_relative '../test_helper'

%w(
  20251007073255_set_aside_geoxyz51_webhooks
  20251007073256_create_webhooks
  20260903081500_create_trackers_webhooks
  20260903081501_restore_geoxyz51_webhooks
  20261014120000_copy_geoxyz51_settings
).each {|migration| require Rails.root.join('db', 'migrate', migration).to_s}

class Geoxyz51UpgradeTest < ActiveSupport::TestCase
  # The migrations under test create and drop tables, which MySQL commits
  # implicitly, so the state is restored by hand in teardown.
  self.use_transactional_tests = false

  fixtures :users, :projects, :trackers

  VERSIONS_51 = %w(20231120120000 20231120120100 20231120120200)
  SETTINGS = %w(
    display_under_single_revision display_under_associated_revisions
    display_revision_branches_regex_enable display_revision_branches_enable_regex_delimiters
    search_token_limit
    display_revision_branches display_associated_revision_branches
    revision_branches_excluded revision_branches_enable_regex
  )

  teardown do
    %w(
      geoxyz51_trackers_webhooks geoxyz51_projects_webhooks geoxyz51_webhooks
      trackers_webhooks projects_webhooks webhooks
    ).each do |table|
      connection.drop_table(table) if connection.table_exists?(table)
    end
    migrate CreateWebhooks, CreateTrackersWebhooks
    VERSIONS_51.each {|version| schema_migration.delete_version(version)}
    Setting.where(:name => SETTINGS).delete_all
    Setting.clear_cache
    Webhook.reset_column_information
  end

  test "7.0 cannot create its webhooks table over the one of 5.1" do
    create_51_webhooks
    assert_raises(ActiveRecord::StatementInvalid) {migrate CreateWebhooks}
  end

  test "upgrade from 5.1 keeps webhooks with their projects and trackers" do
    create_51_webhooks
    upgrade

    hook = Webhook.find(7)
    assert_equal 'https://hooks.nonexistent.invalid/redmine', hook.url
    assert_equal 's3cret', hook.secret
    assert_equal ['issue.created', 'issue.closed'], hook.events
    assert_equal 2, hook.user_id
    assert_equal false, hook.active
    assert_equal [1, 2], hook.project_ids.sort
    assert_equal [1, 2, 3], hook.tracker_ids.sort
    assert Webhook.find(8).active

    assert_not connection.table_exists?(:geoxyz51_webhooks)
    assert_not connection.table_exists?(:geoxyz51_projects_webhooks)
    assert_not connection.table_exists?(:geoxyz51_trackers_webhooks)
    assert_empty schema_migration.versions & VERSIONS_51
  end

  test "upgrade from 5.1 continues the webhook ids after the copied ones" do
    create_51_webhooks
    upgrade

    hook = Webhook.new(:url => 'https://example.net/hook', :user_id => 1, :events => ['issue.created'])
    hook.save(:validate => false)
    assert_equal 9, hook.id
  end

  test "upgrade from 5.1 without trackers_webhooks keeps the projects of the webhooks" do
    create_51_webhooks(:trackers => false)
    upgrade

    assert_equal [1, 2], Webhook.find(7).project_ids.sort
    assert_equal [], Webhook.find(7).tracker_ids
  end

  test "set aside and restore leave a database without the 5.1 webhooks alone" do
    hook = Webhook.new(:url => 'https://example.net/hook', :user_id => 1, :events => ['issue.created'])
    hook.save(:validate => false)
    migrate SetAsideGeoxyz51Webhooks, RestoreGeoxyz51Webhooks

    assert_equal [hook.id], Webhook.ids
    assert_not connection.table_exists?(:geoxyz51_webhooks)
  end

  test "copy settings carries the revision branches display settings over" do
    store_51_settings('display_under_single_revision' => '1', 'display_under_associated_revisions' => '1')
    migrate CopyGeoxyz51Settings

    assert Setting.display_revision_branches?
    assert Setting.display_associated_revision_branches?
  end

  test "copy settings turns the 5.1 branch regexps into unanchored case-sensitive ones" do
    store_51_settings('display_revision_branches_regex_enable' => '1',
                      'display_revision_branches_enable_regex_delimiters' => "^dependabot/\nwip\r\n\nRelease")
    migrate CopyGeoxyz51Settings

    assert_equal '.*(?-i:^dependabot/).*,.*(?-i:wip).*,.*(?-i:Release).*', Setting.revision_branches_excluded
    assert Setting.revision_branches_enable_regex?

    changeset = Changeset.new(:scmid => 'abc')
    names = %w(master dependabot/bundler/rails my-wip-branch release-1 Release-2 feature/dependabot/x)
    changeset.stubs(:repository).returns(stub(:scm => stub(:branches_containing => names)))
    assert_equal %w(master release-1 feature/dependabot/x), changeset.branches
  end

  test "copy settings does not copy the branch regexps when 5.1 did not apply them" do
    store_51_settings('display_revision_branches_regex_enable' => '0',
                      'display_revision_branches_enable_regex_delimiters' => 'wip')
    migrate CopyGeoxyz51Settings

    assert_equal '', Setting.revision_branches_excluded
    assert_not Setting.revision_branches_enable_regex?
  end

  test "copy settings skips a branch regexp with a comma or that is invalid" do
    store_51_settings('display_revision_branches_regex_enable' => '1',
                      'display_revision_branches_enable_regex_delimiters' => "a{1,2}\n[unclosed\nwip")
    migrate CopyGeoxyz51Settings

    assert_equal '.*(?-i:wip).*', Setting.revision_branches_excluded
  end

  test "copy settings keeps a setting already stored under its 7.0 name" do
    store_51_settings('display_under_single_revision' => '1', 'display_revision_branches' => '0')
    migrate CopyGeoxyz51Settings

    assert_not Setting.display_revision_branches?
  end

  test "copy settings reports a search_token_limit that 7.0 no longer applies" do
    store_51_settings('search_token_limit' => '0')
    out, = capture_io {CopyGeoxyz51Settings.new.migrate(:up)}

    assert_match /search_token_limit was 0/, out
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def schema_migration
    connection.pool.schema_migration
  end

  def migrate(*migrations)
    ActiveRecord::Migration.suppress_messages do
      migrations.each {|migration| migration.new.migrate(:up)}
    end
  end

  def upgrade
    migrate SetAsideGeoxyz51Webhooks, CreateWebhooks, CreateTrackersWebhooks, RestoreGeoxyz51Webhooks
    Webhook.reset_column_information
  end

  # The tables as 5.1-stable-GEOxyz migrations 20231120120000 to
  # 20231120120200 create them, with two webhooks in them.
  def create_51_webhooks(trackers: true)
    %w(trackers_webhooks projects_webhooks webhooks).each {|table| connection.drop_table(table)}
    connection.create_table :webhooks do |t|
      t.references :user, :null => false
      t.string :url, :limit => 2000, :null => false
      t.string :secret, :limit => 255
      t.boolean :active, :default => true, :null => false
      t.text :events
      t.timestamps
    end
    connection.create_table :projects_webhooks, :id => false do |t|
      t.references :project, :null => false
      t.references :webhook, :null => false
    end
    connection.add_index :projects_webhooks, [:project_id, :webhook_id], :unique => true,
                         :name => 'index_projects_webhooks_on_project_and_webhook'
    if trackers
      connection.create_table :trackers_webhooks, :id => false do |t|
        t.references :tracker, :null => false
        t.references :webhook, :null => false
      end
      connection.add_index :trackers_webhooks, [:tracker_id, :webhook_id], :unique => true,
                           :name => 'index_trackers_webhooks_on_tracker_and_webhook'
    end
    (trackers ? VERSIONS_51 : VERSIONS_51.first(2)).each {|version| schema_migration.create_version(version)}

    now = connection.quote(Time.now.utc)
    events = connection.quote(['issue.created', 'issue.closed'].to_yaml)
    connection.execute "INSERT INTO webhooks (id, user_id, url, secret, active, events, created_at, updated_at) " \
                       "VALUES (7, 2, 'https://hooks.nonexistent.invalid/redmine', 's3cret', #{connection.quoted_false}, " \
                       "#{events}, #{now}, #{now})"
    connection.execute "INSERT INTO webhooks (id, user_id, url, active, events, created_at, updated_at) " \
                       "VALUES (8, 1, 'https://example.net/other', #{connection.quoted_true}, #{events}, #{now}, #{now})"
    connection.execute "INSERT INTO projects_webhooks (project_id, webhook_id) VALUES (1, 7), (2, 7)"
    if trackers
      connection.execute "INSERT INTO trackers_webhooks (tracker_id, webhook_id) VALUES (1, 7), (2, 7), (3, 7)"
    end
    connection.reset_pk_sequence!('webhooks') if connection.respond_to?(:reset_pk_sequence!)
  end

  def store_51_settings(values)
    values.each do |name, value|
      connection.execute "INSERT INTO settings (name, value) VALUES (#{connection.quote(name)}, #{connection.quote(value)})"
    end
    Setting.clear_cache
  end
end
