require 'minitest/autorun'
require 'mocha/minitest'
require 'yaml'
require 'fileutils'
require 'tempfile'
require 'oauth2'
require 'cgi'
require 'uri'
require 'rake'
load File.expand_path('../../../../lib/tasks/email_oauth.rake', __dir__)

class GoogleOauth2InitTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @token_file = File.join(@dir, 'token')
    @redirect_uri = 'http://localhost'
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def run_init_logic
    token_file = @token_file
    unless File.basename(token_file).start_with?('email_oauth2')
      token_file = File.join(File.dirname(token_file), "email_oauth2_#{File.basename(token_file)}")
    end
    client_id = 'id'
    client_secret = 'secret'
    scope = ['https://mail.google.com/']
    redirect_uri = @redirect_uri
    client_config = {
      'client_id' => client_id,
      'client_secret' => client_secret,
      'site' => 'https://accounts.google.com',
      'authorize_url' => '/o/oauth2/v2/auth',
      'token_url' => 'https://oauth2.googleapis.com/token',
      'redirect_uri' => redirect_uri
    }
    client = build_oauth_client(client_config, true)
    print("Go to URL: #{client.auth_code.authorize_url(access_type: 'offline', scope: scope.join(' '), redirect_uri: redirect_uri)}\n")
    print('Enter full URL after authorize:')
    code = CGI.parse(URI.parse(STDIN.gets.strip).query)['code'].first
    access_token = oauth_get_token(client, code, client_id, client_secret, redirect_uri)
    save_oauth_files(token_file, access_token, client_config)
    token_file
  end

  def test_redirect_uri_saved_and_used
    OAuth2::Client.expects(:new).returns(client = stub('client'))
    client.stubs(:auth_code).returns(auth_code = stub('auth_code'))
    auth_code.expects(:authorize_url).with(access_type: 'offline', scope: 'https://mail.google.com/', redirect_uri: @redirect_uri).returns('http://auth.example')
    auth_code.expects(:get_token).with('abc', redirect_uri: @redirect_uri, client_id: 'id', client_secret: 'secret').returns(stub('token', to_hash: {}))
    STDIN.expects(:gets).returns("http://localhost/?code=abc\n")

    token_file = run_init_logic

    data = YAML.safe_load(File.read("#{token_file}_client.yml"))
    assert_equal @redirect_uri, data['redirect_uri']
  end
end
