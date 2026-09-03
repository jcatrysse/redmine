# A local IMAP server that accepts exactly one XOAUTH2 credential, so G9
# proves the SASL exchange over a real socket rather than a mock. It holds one
# message; fetching it drives MailHandler and creates a real issue.
#
#   ruby imap_server.rb <port> <username> <expected_access_token> <message_file>
#
# LOGIN is refused unless ALLOW_LOGIN=1, which is how Exchange Online behaves
# with basic authentication disabled.

require 'socket'
require 'base64'

port, username, expected_access_token, message_file = ARGV
message = File.binread(message_file)
expected = format("user=%s\x01auth=Bearer %s\x01\x01", username, expected_access_token)

server = TCPServer.new('127.0.0.1', port.to_i)
warn "imap server: listening on 127.0.0.1:#{port}"

loop do
  socket = server.accept
  deleted = false
  authenticated = false
  socket.print "* OK [CAPABILITY IMAP4REV1 AUTH=XOAUTH2 LOGIN] ready\r\n"
  while (line = socket.gets)
    line = line.chomp
    warn "imap server: C: #{line.sub(/(AUTHENTICATE XOAUTH2 ).*/, '\1<base64>')}"
    tag, command, rest = line.split(' ', 3)
    case command&.upcase
    when 'CAPABILITY'
      socket.print "* CAPABILITY IMAP4REV1 AUTH=XOAUTH2 LOGIN\r\n#{tag} OK CAPABILITY completed\r\n"
    when 'AUTHENTICATE'
      mechanism, initial = rest.to_s.split(' ', 2)
      if initial.nil? && mechanism.to_s.upcase == 'XOAUTH2'
        socket.print "+ \r\n"
        initial = socket.gets.to_s.chomp
      end
      if mechanism.to_s.upcase != 'XOAUTH2'
        socket.print "#{tag} NO [CANNOT] unsupported mechanism\r\n"
      elsif Base64.decode64(initial.to_s) == expected
        authenticated = true
        socket.print "#{tag} OK AUTHENTICATE completed\r\n"
      else
        socket.print "#{tag} NO [AUTHENTICATIONFAILED] Invalid credentials\r\n"
      end
    when 'LOGIN'
      if ENV['ALLOW_LOGIN'] == '1'
        authenticated = true
        socket.print "#{tag} OK LOGIN completed\r\n"
      else
        socket.print "#{tag} NO [AUTHENTICATIONFAILED] basic authentication is disabled\r\n"
      end
    when 'SELECT'
      socket.print "* 1 EXISTS\r\n* OK [UIDVALIDITY 1] UIDs valid\r\n#{tag} OK [READ-WRITE] SELECT completed\r\n"
    when 'UID'
      subcommand, args = rest.to_s.split(' ', 2)
      case subcommand.upcase
      when 'SEARCH'
        socket.print "* SEARCH#{deleted ? '' : ' 1'}\r\n#{tag} OK UID SEARCH completed\r\n"
      when 'FETCH'
        socket.print "* 1 FETCH (UID 1 RFC822 {#{message.bytesize}}\r\n"
        socket.print message
        socket.print ")\r\n#{tag} OK UID FETCH completed\r\n"
      when 'STORE'
        deleted = true if args.to_s.include?('Deleted')
        socket.print "* 1 FETCH (UID 1 FLAGS (\\Seen))\r\n#{tag} OK UID STORE completed\r\n"
      when 'COPY'
        socket.print "#{tag} OK UID COPY completed\r\n"
      else
        socket.print "#{tag} BAD unsupported\r\n"
      end
    when 'EXPUNGE'
      socket.print "#{tag} OK EXPUNGE completed\r\n"
    when 'LOGOUT'
      socket.print "* BYE\r\n#{tag} OK LOGOUT completed\r\n"
      break
    else
      socket.print "#{tag} BAD unsupported\r\n"
    end
  end
  warn "imap server: connection closed (authenticated=#{authenticated})"
  socket.close
end
