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

module Redmine
  module Oauth2Client
    DEFAULT_REDIRECT_URI = 'http://localhost'

    class << self
      # Requests an access token with the refresh token grant, using the
      # credentials read from the given YAML file. The token is not cached: it
      # is short lived and requesting one costs a single request. A new refresh
      # token in the response replaces the one in the file.
      def access_token(credentials_file)
        credentials = read_credentials(credentials_file, %w(token_url client_id client_secret refresh_token))
        response = post_to_token_endpoint(
          credentials,
          'grant_type' => 'refresh_token',
          'refresh_token' => credentials['refresh_token']
        )
        token = token_from(response, 'access_token')
        refresh_token = json_body(response)['refresh_token']
        if refresh_token.present? && refresh_token != credentials['refresh_token']
          store_refresh_token(credentials_file, credentials, refresh_token)
        end
        token
      end

      # The URL the mailbox owner opens to consent, first leg of the
      # authorization code grant. Returns the URL and the state it carries;
      # refresh_token needs that state to tell this authorization apart from
      # any other one, so the two are returned together rather than left to
      # the caller to keep in step. Raises when the refresh token could not be
      # saved to the file afterwards: the authorization code can be exchanged
      # only once, so that is found out before the owner consents.
      def authorize_url(credentials_file)
        credentials = read_credentials(credentials_file, %w(authorize_url client_id))
        check_refresh_token_writable(credentials_file, credentials)
        uri = https_uri(credentials['authorize_url'], 'authorize_url')
        params = URI.decode_www_form(uri.query.to_s).to_h
        if credentials['authorize_params'].is_a?(Hash)
          params.merge!(credentials['authorize_params'].transform_keys(&:to_s))
        end
        state = SecureRandom.urlsafe_base64(32)
        params['response_type'] = 'code'
        params['client_id'] = credentials['client_id']
        params['redirect_uri'] = redirect_uri(credentials)
        params['scope'] = credentials['scope'] if credentials['scope'].present?
        params['state'] = state
        uri.query = URI.encode_www_form(params)
        [uri.to_s, state]
      end

      # Exchanges the authorization code carried by the address the browser was
      # redirected to for a refresh token, second leg of the authorization code
      # grant. The state is the one authorize_url returned in the same run.
      def refresh_token(credentials_file, redirect_url, state)
        credentials = read_credentials(credentials_file, %w(token_url client_id client_secret))
        # Read the code before checking the state so that a provider that
        # refused still reports the refusal, and check the state before the
        # code is used for anything.
        code = authorization_code(redirect_url)
        verify_state(redirect_url, state)
        response = post_to_token_endpoint(
          credentials,
          'grant_type' => 'authorization_code',
          'code' => code,
          'redirect_uri' => redirect_uri(credentials)
        )
        token_from(response, 'refresh_token')
      end

      # Writes the refresh token into the credentials file: the refresh_token
      # line is replaced, or added when the file has none yet, and the rest of
      # the file is kept as the administrator wrote it. The file is replaced
      # atomically with its mode kept. Raises when it cannot be written.
      def save_refresh_token(credentials_file, refresh_token)
        credentials = read_credentials(credentials_file, [])
        updated = with_refresh_token(credentials_file, File.read(credentials_file), credentials, refresh_token)
        File.atomic_write(credentials_file) {|file| file.write(updated)}
      end

      private

      def read_credentials(credentials_file, required)
        credentials = YAML.safe_load_file(credentials_file)
        unless credentials.is_a?(Hash)
          raise "#{credentials_file} does not contain OAuth 2.0 credentials"
        end

        missing = required.reject {|key| credentials[key].present?}
        if missing.any?
          raise "#{credentials_file} is missing #{missing.join(', ')}"
        end

        credentials
      end

      # A provider may issue a new refresh token with each access token, and
      # RFC 6749 section 6 then requires the old one to be discarded. The
      # access token of this run is already obtained, so a failure is reported
      # rather than raised.
      def store_refresh_token(credentials_file, credentials, refresh_token)
        updated = with_refresh_token(credentials_file, File.read(credentials_file), credentials, refresh_token)
        File.atomic_write(credentials_file) {|file| file.write(updated)}
      rescue SystemCallError, IOError => e
        warn "The new refresh token issued by the provider could not be written to #{credentials_file}: #{e.message}"
      rescue RuntimeError => e
        warn "#{e.message}, the new refresh token issued by the provider was not stored"
      end

      def check_refresh_token_writable(credentials_file, credentials)
        with_refresh_token(credentials_file, File.read(credentials_file), credentials, 'a-refresh-token')
        unless File.writable?(credentials_file) && File.writable?(File.dirname(credentials_file))
          raise "#{credentials_file} and its directory must be writable to save the refresh token"
        end
      end

      # The file content with only its refresh_token line replaced, or with one
      # added at the end when there is none, and parsed back to make sure that
      # nothing else changed.
      def with_refresh_token(credentials_file, content, credentials, refresh_token)
        line = /^refresh_token:[^\r\n]*/
        replacement = {'refresh_token' => refresh_token}.to_yaml(line_width: -1).delete_prefix("---\n").chomp
        updated =
          case content.scan(line).size
          when 0
            "#{content.end_with?("\n") ? content : "#{content}\n"}#{replacement}\n" unless credentials.key?('refresh_token')
          when 1
            content.sub(line) {replacement}
          end
        unless updated && yaml_equal?(updated, credentials.merge('refresh_token' => refresh_token))
          raise "#{credentials_file} has no single refresh_token line to replace"
        end

        updated
      end

      def yaml_equal?(content, credentials)
        YAML.safe_load(content) == credentials
      rescue Psych::Exception
        false
      end

      def redirect_uri(credentials)
        credentials['redirect_uri'].presence || DEFAULT_REDIRECT_URI
      end

      # Without this the code from any authorization request would be accepted,
      # so a redirect address obtained from a different one — for another
      # mailbox — could be pasted here and its token written down as this
      # mailbox's.
      def verify_state(redirect_url, state)
        if state.blank?
          raise 'No state to check the authorization against, start over with oauth2_authorize'
        end

        returned = redirect_query(redirect_url)['state'].first
        if returned.blank?
          raise 'No state parameter in the address, paste the whole address the browser was redirected to'
        end

        unless ActiveSupport::SecurityUtils.secure_compare(returned, state)
          raise 'The address does not belong to this authorization request, start over with oauth2_authorize'
        end
      end

      def authorization_code(redirect_url)
        query = redirect_query(redirect_url)
        if (error = query['error'].first).present?
          raise "The authorization was refused (#{error})"
        end

        code = query['code'].first
        if code.blank?
          raise "No code parameter in the address, paste the whole address the browser was redirected to"
        end

        code
      end

      def redirect_query(redirect_url)
        CGI.parse(URI.parse(redirect_url.to_s.strip).query.to_s)
      rescue URI::InvalidURIError
        CGI.parse('')
      end

      def post_to_token_endpoint(credentials, params)
        uri = https_uri(credentials['token_url'], 'token_url')
        form = {
          'client_id' => credentials['client_id'],
          'client_secret' => credentials['client_secret']
        }.merge(params)
        form['scope'] = credentials['scope'] if credentials['scope'].present?
        request = ::Net::HTTP::Post.new(uri)
        request.set_form_data(form)
        ::Net::HTTP.start(
          uri.host, uri.port, use_ssl: true,
          open_timeout: 60, read_timeout: 60, write_timeout: 60
        ) do |http|
          http.request(request)
        end
      end

      def token_from(response, name)
        unless response.is_a?(::Net::HTTPSuccess)
          message = "OAuth 2.0 token request failed with #{response.code} #{response.message}"
          error = error_code(response)
          message += " (#{error})" if error
          raise message
        end

        token = json_body(response)[name]
        if token.blank?
          raise "OAuth 2.0 token request returned no #{name.tr('_', ' ')}"
        end

        token
      end

      def https_uri(url, name)
        uri = URI.parse(url)
        unless uri.is_a?(URI::HTTPS)
          raise "#{name} must be an https URL"
        end

        uri
      end

      # The error field of a failed token response, which names the cause
      # (invalid_grant for a revoked refresh token, invalid_client for a wrong
      # secret). It never carries a credential.
      def error_code(response)
        json_body(response)['error'].presence
      end

      # The parsed response body, empty unless it is a JSON object. An
      # intercepting proxy answers with an HTML page, and that has to read as a
      # token request that returned no token rather than as a JSON error.
      def json_body(response)
        body = JSON.parse(response.body.to_s)
        body.is_a?(Hash) ? body : {}
      rescue JSON::ParserError
        {}
      end
    end
  end
end
