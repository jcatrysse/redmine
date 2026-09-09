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

# The functional tests build their own TestSession and never run the session
# middleware, so only an integration test can say which store is configured.
class SessionStoreTest < Redmine::IntegrationTest
  Session = ActiveRecord::SessionStore::Session

  def setup
    Session.delete_all
  end

  def test_session_should_be_stored_in_the_database
    assert_difference 'Session.count' do
      log_user('jsmith', 'jsmith')
    end
    assert_equal 2, Session.last.data['user_id']
  end

  def test_stored_session_id_should_not_be_the_cookie_value
    log_user('jsmith', 'jsmith')

    stored = Session.last.session_id
    assert_match(/\A\d+::/, stored)
    assert_not_equal cookies['_redmine_session'], stored
  end

  def test_deleting_the_row_should_log_the_user_out
    log_user('jsmith', 'jsmith')
    get '/my/account'
    assert_response :success

    Session.delete_all
    get '/my/account'
    assert_redirected_to '/login?back_url=http%3A%2F%2Fwww.example.com%2Fmy%2Faccount'
  end

  def test_session_data_should_not_be_marshalled
    log_user('jsmith', 'jsmith')

    raw = Session.connection.select_value("SELECT data FROM #{Session.table_name} LIMIT 1")
    # 'BAh' is the Base64 of Marshal's own version header, which is what the
    # store writes when its serializer is left at the default.
    assert_not raw.start_with?('BAh'), 'session data is marshalled'
    assert_equal 2, JSON.parse(raw)['value']['user_id']
  end

  def test_a_marshalled_session_row_should_log_the_user_out_rather_than_raise
    log_user('jsmith', 'jsmith')

    # What a row written before the serializer changed looks like. Marshal.load
    # would accept it — and accept anything else in that column too.
    Session.update_all(:data => ::Base64.encode64(Marshal.dump({'user_id' => 2})))
    get '/my/account'
    assert_redirected_to '/login?back_url=http%3A%2F%2Fmy%2Faccount'.sub('%2F%2F', '%2F%2Fwww.example.com%2F')
  end

  def test_the_serializer_should_read_an_unparsable_row_as_an_empty_session
    assert_equal({}, Redmine::SessionDataSerializer.load(::Base64.encode64(Marshal.dump({'user_id' => 2}))))
    assert_equal({}, Redmine::SessionDataSerializer.load('not json at all'))
  end

  def test_a_query_should_survive_a_round_trip_through_the_stored_session
    log_user('jsmith', 'jsmith')

    get(
      '/projects/ecookbook/issues',
      :params => {
        :set_filter => 1,
        :f => ['status_id', 'assigned_to_id'],
        :op => {'status_id' => 'o', 'assigned_to_id' => '='},
        :v => {'assigned_to_id' => ['3']},
        :c => ['tracker', 'subject', 'assigned_to', 'priority'],
        :group_by => 'tracker',
        :sort => 'priority:desc'
      }
    )
    assert_response :success

    assert_equal [2, 3], issue_ids_on_page.sort

    # No parameters this time, so the query can only come from the session row.
    # assigns() is not available here — it needs rails-controller-testing, and
    # INV-6 is not worth a gem for one test — so the assertions read what the
    # rebuilt query actually rendered.
    get '/projects/ecookbook/issues'
    assert_response :success
    assert_equal [2, 3], issue_ids_on_page.sort

    # Each of the four values in the session hash is a different round-trip
    # hazard, and each has its own marker on the page.
    #
    #   filters       a hash of symbol-keyed hashes -> the addFilter() calls
    #   group_by      a plain string                -> the selected option
    #   column_names  symbols, strings after JSON   -> the table headers
    #   sort          an array of arrays            -> the sort link
    assert_include 'addFilter("status_id", "o", [""]);', response.body
    assert_include 'addFilter("assigned_to_id", "=", ["3"]);', response.body
    assert_select 'select#group_by option[selected=selected][value=?]', 'tracker'
    assert_equal ['#', 'Tracker', 'Subject', 'Assignee', 'Priority'],
                 css_select('table.issues thead th:not(.checkbox):not(.buttons)')
                   .collect {|th| th.text.strip}.reject(&:blank?)
    assert_include 'priority%3Adesc', css_select('table.issues thead th.tracker a').first['href']
  end

  def issue_ids_on_page
    css_select('table.issues tr.issue td.id a').collect {|a| a.text.to_i}.sort
  end

  def test_a_plain_text_session_id_should_not_be_accepted_as_a_login
    log_user('jsmith', 'jsmith')
    signed_in = Session.last
    plain_text = 'plaintextcookie1234567890abcdef1'
    Session.create!(:session_id => plain_text, :data => signed_in.data)

    reset!
    cookies['_redmine_session'] = plain_text
    get '/my/account'
    assert_redirected_to '/login?back_url=http%3A%2F%2Fwww.example.com%2Fmy%2Faccount'
  end
end
