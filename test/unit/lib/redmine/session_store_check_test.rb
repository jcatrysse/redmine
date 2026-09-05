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
    create_session('2::aaa', :updated_at => (Redmine::SessionStoreCheck::TRIM_DAYS + 1).days.ago)
    create_session('2::bbb')
    assert_equal 2, @check.facts['rows']
    assert_equal 1, @check.facts['rows the first trim would delete']
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
