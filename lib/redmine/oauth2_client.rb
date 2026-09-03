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
    REQUIRED_CREDENTIALS = %w(token_url client_id client_secret refresh_token)

    class << self
      # Requests an access token with the refresh token grant, using the
      # credentials read from the given YAML file. The token is not cached: it
      # is short lived and requesting one costs a single request.
      def access_token(credentials_file)
        credentials = read_credentials(credentials_file)
        response = request_token(credentials)
        unless response.is_a?(Net::HTTPSuccess)
          message = "OAuth 2.0 token request failed with #{response.code} #{response.message}"
          error = error_code(response)
          message += " (#{error})" if error
          raise message
        end

        token = JSON.parse(response.body)['access_token']
        if token.blank?
          raise "OAuth 2.0 token request returned no access token"
        end

        token
      end

      private

      def read_credentials(credentials_file)
        credentials = YAML.safe_load_file(credentials_file)
        unless credentials.is_a?(Hash)
          raise "#{credentials_file} does not contain OAuth 2.0 credentials"
        end

        missing = REQUIRED_CREDENTIALS.reject {|key| credentials[key].present?}
        if missing.any?
          raise "#{credentials_file} is missing #{missing.join(', ')}"
        end

        credentials
      end

      def request_token(credentials)
        uri = URI.parse(credentials['token_url'])
        unless uri.is_a?(URI::HTTPS)
          raise "token_url must be an https URL"
        end

        params = {
          'grant_type' => 'refresh_token',
          'client_id' => credentials['client_id'],
          'client_secret' => credentials['client_secret'],
          'refresh_token' => credentials['refresh_token']
        }
        params['scope'] = credentials['scope'] if credentials['scope'].present?
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(params)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 60, read_timeout: 60) do |http|
          http.request(request)
        end
      end

      # The error field of a failed token response, which names the cause
      # (invalid_grant for a revoked refresh token, invalid_client for a wrong
      # secret). It never carries a credential.
      def error_code(response)
        JSON.parse(response.body.to_s)['error'].presence
      rescue JSON::ParserError
        nil
      end
    end
  end
end
