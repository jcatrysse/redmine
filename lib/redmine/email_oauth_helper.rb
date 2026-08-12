# frozen_string_literal: true

require 'uri'
require 'cgi'

module Redmine
  module EmailOauthHelper
    # Read a full redirect URL from STDIN and extract ?code=...
    # Re-prompts until valid.
    def self.read_oauth_code
      loop do
        auth_resp = STDIN.gets&.strip
        if auth_resp.nil? || auth_resp.empty?
          puts 'Please enter the full redirect URL:'
          next
        end

        begin
          uri  = URI.parse(auth_resp)
          code = CGI.parse(uri.query.to_s)['code']&.first
          if code.nil? || code.empty?
            raise URI::InvalidURIError
          end
          return code
        rescue StandardError
          puts 'Invalid URL. Please enter the full redirect URL:'
        end
      end
    end
  end
end
