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

  def test_authorize_url_should_carry_the_authorization_code_grant_parameters
    with_credentials(CREDENTIALS.merge('authorize_url' => 'https://login.example.net/oauth2/v2.0/authorize')) do |file|
      url = URI.parse(Redmine::Oauth2Client.authorize_url(file))

      assert_equal 'login.example.net', url.host
      assert_equal '/oauth2/v2.0/authorize', url.path
      assert_equal(
        {
          'response_type' => 'code',
          'client_id' => 'a-client-id',
          'redirect_uri' => 'http://localhost'
        },
        URI.decode_www_form(url.query).to_h
      )
    end
  end

  def test_authorize_url_should_use_the_configured_redirect_uri_and_extra_parameters
    credentials = CREDENTIALS.merge(
      'authorize_url' => 'https://login.example.net/oauth2/v2.0/authorize',
      'redirect_uri' => 'http://localhost:8080/oauth2',
      'scope' => 'https://mail.google.com/',
      'authorize_params' => {'access_type' => 'offline', 'prompt' => 'consent'}
    )
    with_credentials(credentials) do |file|
      params = URI.decode_www_form(URI.parse(Redmine::Oauth2Client.authorize_url(file)).query).to_h

      assert_equal 'http://localhost:8080/oauth2', params['redirect_uri']
      assert_equal 'https://mail.google.com/', params['scope']
      assert_equal 'offline', params['access_type']
      assert_equal 'consent', params['prompt']
    end
  end

  def test_authorize_url_should_not_let_the_extra_parameters_override_the_grant
    credentials = CREDENTIALS.merge(
      'authorize_url' => 'https://login.example.net/oauth2/v2.0/authorize',
      'authorize_params' => {'response_type' => 'token', 'client_id' => 'someone-else'}
    )
    with_credentials(credentials) do |file|
      params = URI.decode_www_form(URI.parse(Redmine::Oauth2Client.authorize_url(file)).query).to_h

      assert_equal 'code', params['response_type']
      assert_equal 'a-client-id', params['client_id']
    end
  end

  def test_authorize_url_should_raise_when_the_authorize_url_is_not_https
    with_credentials(CREDENTIALS.merge('authorize_url' => 'http://login.example.net/authorize')) do |file|
      error = assert_raise(RuntimeError) {Redmine::Oauth2Client.authorize_url(file)}
      assert_equal 'authorize_url must be an https URL', error.message
    end
  end

  def test_refresh_token_should_exchange_the_code_from_the_redirect_address
    request = nil
    expect_token_request(response(Net::HTTPOK, '200', 'OK', {'refresh_token' => 'a-refresh-token'}.to_json)) {|req| request = req}

    with_credentials(CREDENTIALS) do |file|
      assert_equal(
        'a-refresh-token',
        Redmine::Oauth2Client.refresh_token(file, "http://localhost/?code=the-code&session_state=abc\n")
      )
    end

    assert_equal(
      {
        'grant_type' => 'authorization_code',
        'client_id' => 'a-client-id',
        'client_secret' => 'a-client-secret',
        'code' => 'the-code',
        'redirect_uri' => 'http://localhost'
      },
      URI.decode_www_form(request.body).to_h
    )
  end

  def test_refresh_token_should_raise_when_the_provider_refused_the_authorization
    Net::HTTP.expects(:start).never

    with_credentials(CREDENTIALS) do |file|
      error = assert_raise(RuntimeError) do
        Redmine::Oauth2Client.refresh_token(file, 'http://localhost/?error=access_denied')
      end
      assert_equal 'The authorization was refused (access_denied)', error.message
    end
  end

  def test_refresh_token_should_raise_when_the_address_carries_no_code
    Net::HTTP.expects(:start).never

    with_credentials(CREDENTIALS) do |file|
      error = assert_raise(RuntimeError) {Redmine::Oauth2Client.refresh_token(file, 'http://localhost/')}
      assert_include 'paste the whole address', error.message
    end
  end

  def test_refresh_token_should_raise_when_the_address_cannot_be_parsed
    Net::HTTP.expects(:start).never

    with_credentials(CREDENTIALS) do |file|
      error = assert_raise(RuntimeError) {Redmine::Oauth2Client.refresh_token(file, 'not an address at all')}
      assert_include 'paste the whole address', error.message
    end
  end

  def test_refresh_token_should_raise_when_the_response_holds_no_refresh_token
    expect_token_request(response(Net::HTTPOK, '200', 'OK', {'access_token' => 'an-access-token'}.to_json))

    with_credentials(CREDENTIALS) do |file|
      error = assert_raise(RuntimeError) do
        Redmine::Oauth2Client.refresh_token(file, 'http://localhost/?code=the-code')
      end
      assert_include 'no refresh token', error.message
    end
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
