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
      # is short lived and requesting one costs a single request.
      def access_token(credentials_file)
        credentials = read_credentials(credentials_file, %w(token_url client_id client_secret refresh_token))
        response = post_to_token_endpoint(
          credentials,
          'grant_type' => 'refresh_token',
          'refresh_token' => credentials['refresh_token']
        )
        token_from(response, 'access_token')
      end

      # The URL the mailbox owner opens to consent, first leg of the
      # authorization code grant.
      def authorize_url(credentials_file)
        credentials = read_credentials(credentials_file, %w(authorize_url client_id))
        uri = https_uri(credentials['authorize_url'], 'authorize_url')
        params = {}
        if credentials['authorize_params'].is_a?(Hash)
          params.merge!(credentials['authorize_params'].transform_keys(&:to_s))
        end
        params['response_type'] = 'code'
        params['client_id'] = credentials['client_id']
        params['redirect_uri'] = redirect_uri(credentials)
        params['scope'] = credentials['scope'] if credentials['scope'].present?
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      # Exchanges the authorization code carried by the address the browser was
      # redirected to for a refresh token, second leg of the authorization code
      # grant.
      def refresh_token(credentials_file, redirect_url)
        credentials = read_credentials(credentials_file, %w(token_url client_id client_secret))
        response = post_to_token_endpoint(
          credentials,
          'grant_type' => 'authorization_code',
          'code' => authorization_code(redirect_url),
          'redirect_uri' => redirect_uri(credentials)
        )
        token_from(response, 'refresh_token')
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

      def redirect_uri(credentials)
        credentials['redirect_uri'].presence || DEFAULT_REDIRECT_URI
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
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(form)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 60, read_timeout: 60) do |http|
          http.request(request)
        end
      end

      def token_from(response, name)
        unless response.is_a?(Net::HTTPSuccess)
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

      # The parsed response body, empty when the body is not JSON at all. An
      # intercepting proxy answers with an HTML page, and that has to read as a
      # token request that returned no token rather than as a JSON error.
      def json_body(response)
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        {}
      end
    end
  end
end
