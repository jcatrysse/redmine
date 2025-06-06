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

class O365Oauth2InitTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @token_file = File.join(@dir, 'token')
    @client_id = 'o365-client-id'
    @client_secret = 'o365-secret'
    @tenant_id = 'o365-tenant'
    @redirect_uri = 'https://localhost/o365_callback'
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # Lightweight port of the rake task logic (without Rails).
  # The redirect_set parameter determines whether redirect_uri is passed.
  def run_init_logic(redirect_set: true)
    token_file = @token_file
    unless File.basename(token_file).start_with?('email_oauth2')
      token_file = File.join(File.dirname(token_file), "email_oauth2_#{File.basename(token_file)}")
    end

    scope = [
      "offline_access",
      "https://outlook.office.com/User.Read",
      "https://outlook.office.com/IMAP.AccessAsUser.All",
      "https://outlook.office.com/POP.AccessAsUser.All",
      "https://outlook.office.com/SMTP.Send"
    ]
    scope_str = scope.join(' ')

    client_config = {
      'client_id'     => @client_id,
      'client_secret' => @client_secret,
      'site'          => 'https://login.microsoftonline.com',
      'authorize_url' => "/#{@tenant_id}/oauth2/v2.0/authorize",
      'token_url'     => "/#{@tenant_id}/oauth2/v2.0/token",
      'scope'         => scope_str
    }
    client_config['redirect_uri'] = @redirect_uri if redirect_set

    client = build_oauth_client(client_config, redirect_set)

    # Build url_params as in the rake task
    url_params = { scope: scope_str }
    url_params[:prompt] = 'consent'
    url_params[:redirect_uri] = client_config['redirect_uri'] if redirect_set

    puts "Go to URL: #{client.auth_code.authorize_url(**url_params)}"
    print('Enter full URL after authorize:')

    code = CGI.parse(URI.parse(STDIN.gets.strip).query)['code'].first

    access_token = oauth_get_token(client, code, @client_id, @client_secret, redirect_set ? client_config['redirect_uri'] : nil)
    save_oauth_files(token_file, access_token, client_config)
    token_file
  end

  # --------------------------------------------------------------------
  # Test: redirect_uri provided → expect parameter
  # --------------------------------------------------------------------
  def test_redirect_uri_saved_and_used
    # Stubs
    OAuth2::Client.expects(:new).with(
      @client_id, @client_secret,
      has_entries(
        site: 'https://login.microsoftonline.com',
        authorize_url: "/#{@tenant_id}/oauth2/v2.0/authorize",
        token_url: "/#{@tenant_id}/oauth2/v2.0/token",
        redirect_uri: @redirect_uri
      )
    ).returns(client = mock('client'))

    client.expects(:auth_code).twice.returns(auth_code = mock('auth_code'))
    # authorize_url must include redirect_uri
    auth_code.expects(:authorize_url).with(
      has_entries(scope: includes('offline_access'), prompt: 'consent', redirect_uri: @redirect_uri)
    ).returns('https://auth.example/authorize')

    # get_token should receive redirect_uri
    auth_code.expects(:get_token).with('abc', has_entries(redirect_uri: @redirect_uri, client_id: @client_id, client_secret: @client_secret)).returns(stub('token', to_hash: {}))

    STDIN.expects(:gets).returns("https://localhost/o365_callback?code=abc\n")

    token_file = run_init_logic(redirect_set: true)

    data = YAML.safe_load(File.read("#{token_file}_client.yml"))
    assert_equal @redirect_uri, data['redirect_uri'], "redirect_uri should be persisted in client config"
  end

  # --------------------------------------------------------------------
  # Test: NO redirect_uri → should not appear in params
  # --------------------------------------------------------------------
  def test_no_redirect_uri_not_sent
    # When redirect is not set we expect the client
    # to be built with redirect_uri=nil and that authorize_url &
    # get_token receive no redirect parameter.

    OAuth2::Client.expects(:new).with(
      @client_id, @client_secret,
      has_entries(
        site: 'https://login.microsoftonline.com',
        authorize_url: "/#{@tenant_id}/oauth2/v2.0/authorize",
        token_url: "/#{@tenant_id}/oauth2/v2.0/token",
        redirect_uri: nil
      )
    ).returns(client = mock('client'))

    client.expects(:auth_code).twice.returns(auth_code = mock('auth_code'))

    # Capture params to assert that :redirect_uri is absent
    captured_params = nil
    auth_code.expects(:authorize_url).with { |**h|
      captured_params = h
      h[:scope].include?('offline_access') && h[:prompt] == 'consent' && !h.key?(:redirect_uri)
    }.returns('https://auth.example/authorize')

    auth_code.expects(:get_token).with('abc', has_entries(client_id: @client_id, client_secret: @client_secret)).returns(stub('token', to_hash: {})).then

    STDIN.expects(:gets).returns("https://localhost/somecallback?code=abc\n")

    token_file = run_init_logic(redirect_set: false)

    # Extra assertion: captured params has no redirect_uri
    refute captured_params.key?(:redirect_uri), "redirect_uri should not be sent when not configured"

    data = YAML.safe_load(File.read("#{token_file}_client.yml"))
    refute data.key?('redirect_uri'), "redirect_uri should not be persisted when not provided"
  end
end
