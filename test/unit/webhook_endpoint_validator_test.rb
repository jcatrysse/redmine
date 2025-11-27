# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class WebhookEndpointValidatorTest < ActiveSupport::TestCase
  def teardown
    WebhookEndpointValidator.unstub(:blocked_targets)
    WebhookEndpointValidator.unstub(:allowed_targets)
    WebhookEndpointValidator.unstub(:resolve_addresses)
  rescue Mocha::NotInitializedError
    # ignore when nothing was stubbed
  end

  def test_rejects_private_ip_addresses
    WebhookEndpointValidator.stubs(:blocked_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:allowed_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['192.168.0.10'])

    assert_not WebhookEndpointValidator.safe_webhook_uri?('http://example.test')
  end

  def test_allows_private_ip_addresses_on_allowlist
    allowlist = {:ips => [IPAddr.new('10.254.80.0/24')], :host_pattern => nil}
    WebhookEndpointValidator.stubs(:blocked_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:allowed_targets).returns(allowlist)
    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['10.254.80.25'])

    assert WebhookEndpointValidator.safe_webhook_uri?('https://fileservermonitoring.geoxyz.be')
  end

  def test_allows_hosts_on_allowlist_pattern
    WebhookEndpointValidator.stubs(:blocked_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:allowed_targets).returns(
      :ips => [],
      :host_pattern => Regexp.new('\\Aallowed\\.example\\.org\\z')
    )
    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['203.0.113.5'])

    assert WebhookEndpointValidator.safe_webhook_uri?('https://allowed.example.org')
    assert_not WebhookEndpointValidator.safe_webhook_uri?('https://other.example.org')
  end

  def test_allowlisted_hostname_does_not_require_ip_entry
    allowlist = {:ips => [], :host_pattern => Regexp.new('\\Afileservermonitoring\\.geoxyz\\.be\\z')}
    WebhookEndpointValidator.stubs(:blocked_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:allowed_targets).returns(allowlist)
    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['203.0.113.7'])

    assert WebhookEndpointValidator.safe_webhook_uri?('https://fileservermonitoring.geoxyz.be/redmine/webhook')
  end

  def test_allows_hosts_with_ip_allowlist_entry
    allowlist = {:ips => [IPAddr.new('203.0.113.0/24')], :host_pattern => nil}
    WebhookEndpointValidator.stubs(:blocked_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:allowed_targets).returns(allowlist)
    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['203.0.113.99'])

    assert WebhookEndpointValidator.safe_webhook_uri?('https://example.net')

    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['198.51.100.10'])
    assert_not WebhookEndpointValidator.safe_webhook_uri?('https://example.net')
  end

  def test_hostname_allowlist_accepts_resolved_ip
    allowlist = {:ips => [], :host_pattern => Regexp.new('\\Aallowed\\.example\\.org\\z')}
    WebhookEndpointValidator.stubs(:blocked_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:allowed_targets).returns(allowlist)
    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['203.0.113.10'])

    assert WebhookEndpointValidator.safe_webhook_uri?('https://allowed.example.org/webhook')
  end

  def test_hostname_not_on_allowlist_is_rejected
    allowlist = {:ips => [], :host_pattern => Regexp.new('\\Aallowed\\.example\\.org\\z')}
    WebhookEndpointValidator.stubs(:blocked_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:allowed_targets).returns(allowlist)
    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['203.0.113.20'])

    assert_not WebhookEndpointValidator.safe_webhook_uri?('https://other.example.org/webhook')
  end

  def test_hostname_allowlist_allows_private_ip_when_host_is_allowlisted
    allowlist = {:ips => [], :host_pattern => Regexp.new('\\Ainternal\\.example\\.org\\z')}
    WebhookEndpointValidator.stubs(:blocked_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:allowed_targets).returns(allowlist)
    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['192.168.50.10'])

    assert WebhookEndpointValidator.safe_webhook_uri?('https://internal.example.org/webhook')
  end

  def test_allows_hostnames_with_whitespace_in_allowlist_entries
    WebhookEndpointValidator.unstub(:allowed_targets)
    WebhookEndpointValidator.instance_variable_set(:@allowed_targets, nil)

    Redmine::Configuration.stubs(:[]).with('webhook_allowlist').returns([' fileservermonitoring.geoxyz.be '])
    WebhookEndpointValidator.stubs(:blocked_targets).returns(:ips => [], :host_pattern => nil)
    WebhookEndpointValidator.stubs(:resolve_addresses).returns(['203.0.113.5'])

    assert WebhookEndpointValidator.safe_webhook_uri?('https://fileservermonitoring.geoxyz.be/redmine/webhook')
  ensure
    WebhookEndpointValidator.instance_variable_set(:@allowed_targets, nil)
    Redmine::Configuration.unstub(:[])
  end
end
