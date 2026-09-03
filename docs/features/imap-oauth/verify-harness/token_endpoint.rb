# A local HTTPS OAuth 2.0 token endpoint, so G9 exercises the real code path
# (Net::HTTP over TLS with certificate verification on) without touching
# Google or Microsoft. Writes its self-signed CA to CERT_PATH so the client
# can be pointed at it with SSL_CERT_FILE.
#
#   ruby token_endpoint.rb <port> <cert_path> <expected_refresh_token> <access_token>

require 'webrick'
require 'webrick/https'
require 'openssl'
require 'json'
require 'cgi'

port, cert_path, expected_refresh_token, access_token = ARGV
port = port.to_i

key = OpenSSL::PKey::RSA.new(2048)
name = OpenSSL::X509::Name.parse('/CN=login.example.net')
cert = OpenSSL::X509::Certificate.new
cert.version = 2
cert.serial = 1
cert.subject = name
cert.issuer = name
cert.public_key = key.public_key
cert.not_before = Time.now - 3600
cert.not_after = Time.now + 86400
ef = OpenSSL::X509::ExtensionFactory.new
ef.subject_certificate = cert
ef.issuer_certificate = cert
cert.add_extension(ef.create_extension('subjectAltName', 'DNS:login.example.net'))
cert.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
cert.sign(key, OpenSSL::Digest.new('SHA256'))
File.write(cert_path, cert.to_pem)

server = WEBrick::HTTPServer.new(
  :BindAddress => '127.0.0.1',
  :Port => port,
  :SSLEnable => true,
  :SSLCertificate => cert,
  :SSLPrivateKey => key,
  :Logger => WEBrick::Log.new(File::NULL),
  :AccessLog => []
)

server.mount_proc '/oauth2/v2.0/token' do |request, response|
  params = CGI.parse(request.body.to_s)
  received = params.transform_values(&:first)
  warn "token endpoint: #{received.merge('client_secret' => '[redacted]', 'refresh_token' => '[redacted]')}"
  response['Content-Type'] = 'application/json'
  if received['grant_type'] == 'refresh_token' && received['refresh_token'] == expected_refresh_token
    response.status = 200
    response.body = {'access_token' => access_token, 'token_type' => 'Bearer', 'expires_in' => 3599}.to_json
  else
    response.status = 400
    response.body = {'error' => 'invalid_grant', 'error_description' => 'The refresh token is invalid.'}.to_json
  end
end

trap('INT') {server.shutdown}
trap('TERM') {server.shutdown}
server.start
