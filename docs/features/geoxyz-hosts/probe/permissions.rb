# Drives Rails' real host allowlist over a fixed corpus, for each candidate entry.
#
#   cd /home/user/wt/geoxyz && bundle exec ruby \
#     /home/user/redmine/docs/features/geoxyz-hosts/probe/permissions.rb
#
# Permissions#allows? is the code path that decides 403 vs 200, and
# sanitize_regexp rewrites the pattern before it is used — so a candidate is
# measured here, never eyeballed.
require "action_dispatch"

OLD = /.*\.geoxyz\.eu/
NEW = /[a-z0-9-]+(?:\.[a-z0-9-]+)*\.geoxyz\.eu/i
STR = ".geoxyz.eu"

DEV_DEFAULTS = ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT

HOSTS = [
  # intended
  "redmine.geoxyz.eu", "a.b.geoxyz.eu", "a.b.c.geoxyz.eu", "redmine-dev.geoxyz.eu",
  "redmine.geoxyz.eu:3000", "a.b.geoxyz.eu:8080", "r2d2.geoxyz.eu",
  # case variants (F01)
  "REDMINE.geoxyz.eu", "redmine.GEOXYZ.eu", "redmine.Geoxyz.EU", "redmine.geoxyz.EU",
  "REDMINE.GEOXYZ.EU", "redmine.GEOXYZ.eu:3000",
  # must stay refused
  "geoxyz.eu", "geoxyz.eu:3000", "evil-geoxyz.eu", "evilgeoxyz.eu", "notgeoxyz.eu",
  "geoxyz.eux", "geoxyz.eu.attacker.com", "geoxyz.eu.attacker.com:3000",
  "redmine.geoxyz.eu.", "redmine.geoxyz.eu:", "redmine.geoxyz.eu:abc",
  "redmine.xn--geoxyz-abc.eu", "redmine.gеoxyz.eu", "evil.example.com",
  "attacker.com\n.geoxyz.eu", "redmine.geoxyz.eu\n", "redmine.geoxyz.eu\nevil.com",
  # junk prefixes (F02)
  ".geoxyz.eu", "..geoxyz.eu", "attacker.com/.geoxyz.eu", "attacker.com@.geoxyz.eu",
  "attacker.com#.geoxyz.eu", "attacker.com:8080.geoxyz.eu", "attacker.com\r.geoxyz.eu",
  "%00.geoxyz.eu", "_.geoxyz.eu", "*.geoxyz.eu", "[.geoxyz.eu", "a b.geoxyz.eu",
  "a\tb.geoxyz.eu",
  # what Rails' own development default already allows
  "127.0.0.1", "localhost", "1.2.3.4", "[::1]",
].freeze

def allows?(entries, host)
  ActionDispatch::HostAuthorization::Permissions.new(entries).allows?(host)
end

def anchored(entry)
  ActionDispatch::HostAuthorization::Permissions
    .new([entry]).instance_variable_get(:@hosts).first.inspect
end

puts "anchored form stored by Rails:"
puts "  old: #{anchored(OLD)}"
puts "  new: #{anchored(NEW)}"
puts "  str: #{anchored(STR)}"
puts

fmt = "%-32s %-7s %-7s %-7s %-9s %s"
puts format(fmt, "HOST", "old", "new", "string", "dev-only", "dev+new")
HOSTS.each do |h|
  puts format(fmt, h.inspect,
              allows?([OLD], h), allows?([NEW], h), allows?([STR], h),
              allows?(DEV_DEFAULTS, h), allows?(DEV_DEFAULTS + [NEW], h))
end
