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
