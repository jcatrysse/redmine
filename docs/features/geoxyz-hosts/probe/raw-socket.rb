# Sends a raw GET /login with a literal Host header to a running dev server, so
# nothing normalises it — curl and every browser rewrite several of these host
# strings before they leave the client.
#
#   /home/user/redmine/tools/dev-server.sh /home/user/wt/geoxyz
#   ruby docs/features/geoxyz-hosts/probe/raw-socket.rb
require "socket"

HOSTS = ["redmine.geoxyz.eu", "a.b.geoxyz.eu", "a.b.c.geoxyz.eu",
         "redmine.GEOXYZ.eu", "redmine.Geoxyz.EU", "REDMINE.geoxyz.eu",
         "geoxyz.eu", "evil-geoxyz.eu", "geoxyz.eu.attacker.com",
         "attacker.com/.geoxyz.eu", "attacker.com:8080.geoxyz.eu",
         "_.geoxyz.eu", ".geoxyz.eu",
         "evil.example.com", "127.0.0.1", "localhost"].freeze

HOSTS.each do |host|
  socket = TCPSocket.new("127.0.0.1", ENV.fetch("REDMINE_PORT", "3000").to_i)
  socket.write("GET /login HTTP/1.1\r\nHost: #{host}\r\nConnection: close\r\n\r\n")
  printf("%-30s %s\n", host, socket.gets.to_s[/\d{3}/])
  socket.close
end
