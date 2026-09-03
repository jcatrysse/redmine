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
require 'tempfile'

class Redmine::Oauth2ClientTest < ActiveSupport::TestCase
  CREDENTIALS = {
    'token_url' => 'https://login.example.net/oauth2/v2.0/token',
    'client_id' => 'a-client-id',
    'client_secret' => 'a-client-secret',
    'refresh_token' => 'a-refresh-token'
  }

  def test_access_token_should_return_the_token_of_a_refresh_token_grant
    request = nil
    expect_token_request(response(Net::HTTPOK, '200', 'OK', {'access_token' => 'an-access-token'}.to_json)) {|req| request = req}

    with_credentials(CREDENTIALS) do |file|
      assert_equal 'an-access-token', Redmine::Oauth2Client.access_token(file)
    end

    assert_equal '/oauth2/v2.0/token', request.path
    assert_equal(
      {
        'grant_type' => 'refresh_token',
        'client_id' => 'a-client-id',
        'client_secret' => 'a-client-secret',
        'refresh_token' => 'a-refresh-token'
      },
      URI.decode_www_form(request.body).to_h
    )
  end

  def test_access_token_should_send_the_scope_when_given
    request = nil
    expect_token_request(response(Net::HTTPOK, '200', 'OK', {'access_token' => 'an-access-token'}.to_json)) {|req| request = req}

    with_credentials(CREDENTIALS.merge('scope' => 'https://outlook.office.com/IMAP.AccessAsUser.All')) do |file|
      assert_equal 'an-access-token', Redmine::Oauth2Client.access_token(file)
    end

    assert_equal(
      'https://outlook.office.com/IMAP.AccessAsUser.All',
      URI.decode_www_form(request.body).to_h['scope']
    )
  end

  def test_access_token_should_raise_when_a_credential_is_missing
    Net::HTTP.expects(:start).never

    with_credentials(CREDENTIALS.except('client_secret', 'refresh_token')) do |file|
      error = assert_raise(RuntimeError) {Redmine::Oauth2Client.access_token(file)}
      assert_include 'client_secret, refresh_token', error.message
    end
  end

  def test_access_token_should_raise_when_the_file_does_not_contain_a_hash
    Net::HTTP.expects(:start).never

    with_credentials('an-access-token') do |file|
      assert_raise(RuntimeError) {Redmine::Oauth2Client.access_token(file)}
    end
  end

  def test_access_token_should_raise_when_the_token_url_is_not_https
    Net::HTTP.expects(:start).never

    with_credentials(CREDENTIALS.merge('token_url' => 'http://login.example.net/token')) do |file|
      error = assert_raise(RuntimeError) {Redmine::Oauth2Client.access_token(file)}
      assert_include 'https', error.message
    end
  end

  def test_access_token_should_raise_with_the_error_code_of_a_failed_request
    expect_token_request(response(Net::HTTPBadRequest, '400', 'Bad Request', {'error' => 'invalid_grant'}.to_json))

    with_credentials(CREDENTIALS) do |file|
      error = assert_raise(RuntimeError) {Redmine::Oauth2Client.access_token(file)}
      assert_equal 'OAuth 2.0 token request failed with 400 Bad Request (invalid_grant)', error.message
    end
  end

  def test_access_token_should_raise_when_a_failed_request_has_no_json_body
    expect_token_request(response(Net::HTTPBadGateway, '502', 'Bad Gateway', '<html>oops</html>'))

    with_credentials(CREDENTIALS) do |file|
      error = assert_raise(RuntimeError) {Redmine::Oauth2Client.access_token(file)}
      assert_equal 'OAuth 2.0 token request failed with 502 Bad Gateway', error.message
    end
  end

  def test_access_token_should_raise_when_the_response_holds_no_token
    expect_token_request(response(Net::HTTPOK, '200', 'OK', {'expires_in' => 3599}.to_json))

    with_credentials(CREDENTIALS) do |file|
      error = assert_raise(RuntimeError) {Redmine::Oauth2Client.access_token(file)}
      assert_include 'no access token', error.message
    end
  end

  private

  def with_credentials(credentials)
    file = Tempfile.new(['imap_oauth2', '.yml'])
    file.write(credentials.to_yaml)
    file.close
    yield file.path
  ensure
    file.unlink
  end

  def response(klass, code, message, body)
    response = klass.new('1.1', code, message)
    response.stubs(:body).returns(body)
    response
  end

  def expect_token_request(response, &capture)
    http = mock('http')
    http.expects(:request).with {|request| capture&.call(request); true}.returns(response)
    Net::HTTP
      .expects(:start)
      .with('login.example.net', 443, :use_ssl => true, :open_timeout => 60, :read_timeout => 60)
      .yields(http)
      .returns(response)
  end
end
