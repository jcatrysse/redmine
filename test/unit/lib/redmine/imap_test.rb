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

class Redmine::ImapTest < ActiveSupport::TestCase
  def test_check_should_login_with_the_password
    imap = connected_imap
    imap.expects(:authenticate).never
    imap.expects(:login).with('redmine@example.net', 'secret')

    Redmine::IMAP.check(:host => 'imap.example.net', :username => 'redmine@example.net', :password => 'secret')
  end

  def test_check_should_authenticate_with_xoauth2_when_an_access_token_is_given
    imap = connected_imap
    imap.expects(:login).never
    imap.expects(:authenticate).with('XOAUTH2', 'redmine@example.net', 'an-access-token')

    Redmine::IMAP.check(
      :host => 'imap.example.net', :username => 'redmine@example.net',
      :password => 'secret', :oauth2_token => 'an-access-token'
    )
  end

  def test_check_should_authenticate_with_the_token_requested_from_the_credentials_file
    imap = connected_imap
    imap.expects(:login).never
    imap.expects(:authenticate).with('XOAUTH2', 'redmine@example.net', 'a-fresh-access-token')
    Redmine::Oauth2Client.expects(:access_token).with('/etc/redmine/imap_oauth2.yml').returns('a-fresh-access-token')

    Redmine::IMAP.check(
      :host => 'imap.example.net', :username => 'redmine@example.net',
      :oauth2_credentials => '/etc/redmine/imap_oauth2.yml'
    )
  end

  def test_check_should_not_open_a_connection_when_the_token_cannot_be_obtained
    Net::IMAP.expects(:new).never
    Redmine::Oauth2Client.expects(:access_token).raises('OAuth 2.0 token request failed with 400 Bad Request (invalid_grant)')

    assert_raise(RuntimeError) do
      Redmine::IMAP.check(
        :host => 'imap.example.net', :username => 'redmine@example.net',
        :oauth2_credentials => '/etc/redmine/imap_oauth2.yml'
      )
    end
  end

  def test_check_should_login_with_the_password_when_the_oauth2_options_are_blank
    imap = connected_imap
    imap.expects(:authenticate).never
    imap.expects(:login).with('redmine@example.net', 'secret')
    Redmine::Oauth2Client.expects(:access_token).never

    Redmine::IMAP.check(
      :host => 'imap.example.net', :username => 'redmine@example.net',
      :password => 'secret', :oauth2_token => '', :oauth2_credentials => ''
    )
  end

  private

  def connected_imap
    imap = mock('imap')
    imap.stubs(:select)
    imap.stubs(:uid_search).returns([])
    imap.stubs(:expunge)
    imap.stubs(:logout)
    imap.stubs(:disconnect)
    Net::IMAP.expects(:new).with('imap.example.net', :port => '143', :ssl => false).returns(imap)
    imap
  end
end
