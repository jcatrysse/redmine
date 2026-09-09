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

class Redmine::SessionStoreCheckTest < ActiveSupport::TestCase
  Session = ActiveRecord::SessionStore::Session

  def setup
    @check = Redmine::SessionStoreCheck.new
    Session.delete_all
  end

  def test_a_correctly_shaped_table_should_have_no_problems
    assert_equal [], @check.problems
  end

  def test_a_missing_table_should_be_the_only_problem_reported
    @check.connection.stubs(:table_exists?).returns(false)
    assert_equal 1, @check.problems.size
    assert_include 'does not exist', @check.problems.first
  end

  def test_a_store_that_is_not_the_database_store_should_be_the_only_problem_reported
    Rails.application.config.stubs(:session_store).returns(ActionDispatch::Session::CookieStore)
    assert_equal 1, @check.problems.size
    assert_include 'not ActionDispatch::Session::ActiveRecordStore', @check.problems.first
  end

  def test_a_missing_column_should_be_a_problem
    columns = @check.connection.columns('sessions').reject {|c| c.name == 'data'}
    @check.connection.stubs(:columns).returns(columns)
    assert_include "'sessions' has no column data", @check.problems
  end

  def test_a_session_id_index_that_is_not_unique_should_be_a_problem
    weaken_index('session_id')
    assert_include "'sessions' has no unique index on session_id", @check.problems
  end

  def test_a_missing_updated_at_index_should_be_a_problem
    indexes = @check.connection.indexes('sessions').reject {|i| i.columns == ['updated_at']}
    @check.connection.stubs(:indexes).returns(indexes)
    assert_include "'sessions' has no index on updated_at, so db:sessions:trim would scan the whole table",
                   @check.problems
  end

  def test_facts_should_count_the_rows_the_first_trim_would_delete
    create_session('2::aaa', :updated_at => 31.days.ago)
    create_session('2::bbb')
    assert_equal 2, @check.facts['rows']
    assert_equal 1, @check.facts['rows the first trim would delete']
    assert_equal '30 days (recommended: 7)', @check.facts['trim period']
  end

  # The count has to describe what db:sessions:trim will delete, and the gem's
  # task takes its cutoff from this variable alone.
  def test_facts_should_count_over_the_period_the_trim_task_would_use
    create_session('2::aaa', :updated_at => 8.days.ago)
    create_session('2::bbb')
    with_session_days_trim_threshold('7') do
      assert_equal 1, @check.facts['rows the first trim would delete']
      assert_equal '7 days', @check.facts['trim period']
    end
    with_session_days_trim_threshold(nil) do
      assert_equal 0, @check.facts['rows the first trim would delete']
      assert_equal '30 days (recommended: 7)', @check.facts['trim period']
    end
  end

  def test_run_should_say_so_when_the_period_is_not_the_recommended_one
    output = StringIO.new
    with_session_days_trim_threshold('30') {@check.run(output)}
    assert_include 'SESSION_DAYS_TRIM_THRESHOLD=7 on the cron line', output.string
    assert_include '30 days (recommended: 7)', output.string
  end

  def test_run_should_not_mention_the_period_when_it_is_the_recommended_one
    output = StringIO.new
    with_session_days_trim_threshold('7') {@check.run(output)}
    assert_not_include 'SESSION_DAYS_TRIM_THRESHOLD', output.string
  end

  def test_facts_should_count_the_rows_an_older_store_wrote
    create_session('2::aaa')
    create_session('plaintextcookie1234567890abcdef1')
    assert_equal 1, @check.facts['rows written by an older store']
  end

  def test_facts_should_report_the_adapter_and_the_session_size_limit
    assert_equal @check.connection.adapter_name, @check.facts['database adapter']
    assert_include @check.connection.columns('sessions').detect {|c| c.name == 'data'}.sql_type,
                   @check.facts['session size limit']
  end

  def test_run_should_raise_and_name_the_problem
    @check.connection.stubs(:table_exists?).returns(false)
    e = assert_raise(Redmine::SessionStoreCheck::Failed) {@check.run(StringIO.new)}
    assert_include 'does not exist', e.message
  end

  def test_run_should_print_the_facts_when_there_is_nothing_wrong
    output = StringIO.new
    @check.run(output)
    assert_include 'database adapter', output.string
    assert_include 'shaped the way the store expects', output.string
  end

  private

  def with_session_days_trim_threshold(value)
    was = ENV['SESSION_DAYS_TRIM_THRESHOLD']
    value.nil? ? ENV.delete('SESSION_DAYS_TRIM_THRESHOLD') : ENV['SESSION_DAYS_TRIM_THRESHOLD'] = value
    yield
  ensure
    was.nil? ? ENV.delete('SESSION_DAYS_TRIM_THRESHOLD') : ENV['SESSION_DAYS_TRIM_THRESHOLD'] = was
  end

  def create_session(session_id, attributes={})
    Session.create!({:session_id => session_id, :data => {}}.merge(attributes))
  end

  def weaken_index(column)
    indexes =
      @check.connection.indexes('sessions').collect do |index|
        index.columns == [column] ? index.class.new(index.table, index.name, false, index.columns) : index
      end
    @check.connection.stubs(:indexes).returns(indexes)
  end
end
