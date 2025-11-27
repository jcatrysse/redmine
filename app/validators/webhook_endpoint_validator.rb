# frozen_string_literal: true

require 'set'
require 'uri'
require 'resolv'
require 'ipaddr'

class WebhookEndpointValidator < ActiveModel::EachValidator
  BAD_PORTS = Set[25, 111, 135, 139, 445, 1433, 1521, 2049, 3306, 3389, 5985, 5986].freeze

  def validate_each(record, attribute, value)
    return if value.blank?

    valid, reason = self.class.validate_uri(value)
    record.errors.add(attribute, :invalid, message: reason && " (#{reason})") unless valid
  end

  class << self
    def safe_webhook_uri?(value)
      valid, = validate_uri(value)
      valid
    end

    def validate_uri(value)
      uri = value.is_a?(URI) ? value : URI.parse(value.to_s)

      return [false, 'must use http or https'] unless valid_scheme?(uri.scheme)

      host_reason = host_validation_error(uri.host)
      return [false, host_reason] if host_reason

      return [false, 'uses a disallowed port'] unless valid_port?(uri.port)

      [true, nil]
    rescue URI::Error, ArgumentError => e
      Rails.logger.warn {"Webhook endpoint rejected: #{value.inspect} (#{e.message})"}
      [false, e.message]
    end

    def valid_scheme?(scheme)
      %w[http https].include?(scheme)
    end

    def host_validation_error(host)
      return 'host is missing' if host.blank?

      blocked = blocked_targets
      allowed = allowed_targets

      host_allowlisted = allowed[:host_pattern]&.match?(host)

      return 'host is blocklisted' if host_blocked?(host, blocked)
      if !allowlist_empty?(allowed) && !host_allowlisted && !allowlist_ip_allowed_for_host?(host, allowed)
        return "host is not on the allowlist"
      end

      addresses = ip_literal?(host) ? [host] : resolve_addresses(host)
      return nil if addresses.blank? && allowlist_empty?(allowed)

      addresses.each do |ip|
        ipaddr = IPAddr.new(ip)
        allowlisted_ip = host_allowlisted || allowlist_ip_allowed?(ipaddr, allowed)

        return "address #{ipaddr} is blocklisted" if blocked[:ips].any? {|entry| entry.include?(ipaddr)}
        return "address #{ipaddr} is not on the allowlist" if !allowlist_empty?(allowed) && !allowlisted_ip
        return "address #{ipaddr} is not reachable from the public network" if !allowlisted_ip && (ipaddr.loopback? || ipaddr.link_local? || ipaddr.private?)
      rescue IPAddr::Error
        return "address #{ip.inspect} is invalid"
      end

      nil
    end

    def valid_port?(port)
      port.present? && !BAD_PORTS.include?(port)
    end

    def resolve_addresses(host)
      addresses = []
      Resolv.each_address(host) {|ip| addresses << ip}
      addresses
    rescue Resolv::ResolvError
      []
    end

    def ip_literal?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::Error
      false
    end

    def blocked_targets
      @blocked_targets ||= begin
        ips = []
        host_patterns = []
        Array(Redmine::Configuration['webhook_blocklist']).each do |entry|
          entry = entry.to_s.strip
          next if entry.empty?

          begin
            ips << IPAddr.new(entry)
          rescue IPAddr::Error
            host_patterns << entry
          end
        end
        {
          :ips => ips.freeze,
          :host_pattern => build_host_pattern(host_patterns)
        }
      end
    end

    def allowed_targets
      @allowed_targets ||= begin
        ips = []
        host_patterns = []
        Array(Redmine::Configuration['webhook_allowlist']).each do |entry|
          entry = entry.to_s.strip
          next if entry.empty?

          begin
            ips << IPAddr.new(entry)
          rescue IPAddr::Error
            host_patterns << entry
          end
        end
        {
          :ips => ips.freeze,
          :host_pattern => build_host_pattern(host_patterns)
        }
      end
    end

    def build_host_pattern(patterns)
      return if patterns.empty?

      sources = patterns.map do |value|
        if value.start_with?('*.')
          "(?:.*\\.)?#{Regexp.escape(value.delete_prefix('*.'))}"
        else
          Regexp.escape(value)
        end
      end

      Regexp.new("\\A(?:#{sources.join('|')})\\z", Regexp::IGNORECASE)
    end

    def host_blocked?(host, blocked)
      blocked[:host_pattern]&.match?(host)
    end

    def host_allowed_by_allowlist?(host, allowed)
      return true if allowlist_empty?(allowed)

      allowed[:host_pattern]&.match?(host) || allowlist_ip_allowed_for_host?(host, allowed)
    end

    def allowlist_empty?(allowed)
      allowed[:ips].empty? && allowed[:host_pattern].nil?
    end

    def allowlist_ip_allowed_for_host?(host, allowed)
      addresses = ip_literal?(host) ? [host] : resolve_addresses(host)
      return false if addresses.empty?

      addresses.any? do |ip|
        allowlist_ip_allowed?(IPAddr.new(ip), allowed)
      rescue IPAddr::Error
        false
      end
    end

    def allowlist_ip_allowed?(ipaddr, allowed)
      allowed[:ips].any? {|entry| entry.include?(ipaddr)}
    end
  end
end
