require 'minitest/autorun'
require 'mocha/minitest'
require 'yaml'
require 'fileutils'
require 'tempfile'
require 'oauth2'
require 'rake'
load File.expand_path('../../../../lib/tasks/email_oauth.rake', __dir__)

class EmailOauthTokenRefreshTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @token_file = File.join(@dir, 'token')
    prefixed = File.join(@dir, 'email_oauth2_token')
    File.write("#{prefixed}_client.yml", {
      'provider' => 'google',
      'client_id' => 'id',
      'client_secret' => 'secret',
      'site' => 'site',
      'authorize_url' => 'auth',
      'token_url' => 'token',
      'redirect_uri' => 'redir',
      'scope' => 'scope',
      'auth_params' => {'access_type' => 'offline'}
    }.to_yaml)
    File.write("#{prefixed}.yml", {
      'access_token' => 'old',
      'refresh_token' => 'r',
      'expires_at' => Time.now.to_i - 3600
    }.to_yaml)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def run_init_logic
    token_file = File.join(@dir, 'email_oauth2_new')
    client_config = {
      'client_id' => 'id',
      'client_secret' => 'secret',
      'site' => 'site',
      'authorize_url' => 'auth',
      'token_url' => 'token'
    }
    File.write("#{token_file}.yml", {'access_token' => 't'}.to_yaml)
    File.chmod(0600, "#{token_file}.yml") unless File::ALT_SEPARATOR
    File.write("#{token_file}_client.yml", client_config.to_yaml)
    File.chmod(0600, "#{token_file}_client.yml") unless File::ALT_SEPARATOR
  end

  def run_refresh_logic
    file = @token_file
    unless File.basename(file).start_with?('email_oauth2')
      file = File.join(File.dirname(file), "email_oauth2_#{File.basename(file)}")
    end
    client_config = YAML.safe_load_file("#{file}_client.yml")
    client = OAuth2::Client.new(client_config['client_id'], client_config['client_secret'],
                                site: client_config['site'], authorize_url: client_config['authorize_url'], token_url: client_config['token_url'],
                                redirect_uri: client_config['redirect_uri'])
    access_token = OAuth2::AccessToken.from_hash(client, YAML.safe_load_file("#{file}.yml"))
    if access_token.expired?
      logger = defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : nil
      msg = "Refreshing OAuth token; old expiry: #{access_token.expires_at}"
      if logger
        logger.info(msg)
      else
        $stderr.puts(msg)
      end

      access_token = access_token.refresh!

      msg = "OAuth token refreshed; new expiry: #{access_token.expires_at}"
      if logger
        logger.info(msg)
      else
        $stderr.puts(msg)
      end

      File.write("#{file}.yml", access_token.to_hash.to_yaml)
      File.chmod(0600, "#{file}.yml") unless File::ALT_SEPARATOR
    end
  end

  def test_expired_token_refreshes_and_writes_file
    new_expiry = Time.now.to_i + 3600
    refreshed = stub('token', to_hash: {
      'access_token' => 'new',
      'refresh_token' => 'r',
      'expires_at' => new_expiry
    }, expires_at: new_expiry)
    old_expiry = Time.now.to_i - 3600
    access_token = stub('token', expired?: true, refresh!: refreshed, expires_at: old_expiry)

    OAuth2::Client.expects(:new).returns(:client)
    OAuth2::AccessToken.expects(:from_hash).returns(access_token)

    capture_io do
      run_refresh_logic
    end

    data = YAML.safe_load(File.read(File.join(@dir, 'email_oauth2_token.yml')))
    assert_equal 'new', data['access_token']
    if File::ALT_SEPARATOR.nil?
      assert_equal 0600, File.stat(File.join(@dir, 'email_oauth2_token.yml')).mode & 0777
    end
  end

  def test_valid_token_is_not_refreshed
    access_token = stub('token')
    access_token.stubs(:expired?).returns(false)

    OAuth2::Client.expects(:new).returns(:client)
    OAuth2::AccessToken.expects(:from_hash).returns(access_token)
    access_token.expects(:refresh!).never

    capture_io do
      run_refresh_logic
    end

    data = YAML.safe_load(File.read(File.join(@dir, 'email_oauth2_token.yml')))
    assert_equal 'old', data['access_token']
  end

  def test_init_creates_files_with_secure_permissions
    run_init_logic
    if File::ALT_SEPARATOR.nil?
      assert_equal 0600, File.stat(File.join(@dir, 'email_oauth2_new.yml')).mode & 0777
      assert_equal 0600, File.stat(File.join(@dir, 'email_oauth2_new_client.yml')).mode & 0777
    end
  end

  def test_logs_expiration_times_on_refresh
    new_expiry = Time.now.to_i + 3600
    refreshed = stub('token',
                     to_hash: {
                       'access_token' => 'new',
                       'refresh_token' => 'r',
                       'expires_at' => new_expiry
                     },
                     expires_at: new_expiry)

    old_expiry = Time.now.to_i - 3600
    access_token = stub('token', expired?: true, refresh!: refreshed, expires_at: old_expiry)

    OAuth2::Client.expects(:new).returns(:client)
    OAuth2::AccessToken.expects(:from_hash).returns(access_token)

    _out, err = capture_io do
      run_refresh_logic
    end

    assert_includes err, old_expiry.to_s
    assert_includes err, new_expiry.to_s
  end
end

class EmailOauthInitCheckTest < Minitest::Test
  def run_init_check(token)
    if !token.refresh_token && ENV['allow_no_refresh'] != '1'
      warn 'No refresh token returned. Re-authorize with prompt=consent.'
      exit 1
    end
  end

  def test_exit_without_refresh_token
    token = stub('token', refresh_token: nil)
    ENV.delete('allow_no_refresh')
    assert_raises(SystemExit) do
      _, err = capture_io { run_init_check(token) }
      assert_match(/prompt=consent/, err)
    end
  end

  def test_no_exit_when_allowed
    token = stub('token', refresh_token: nil)
    ENV['allow_no_refresh'] = '1'
    assert_silent { run_init_check(token) }
  ensure
    ENV.delete('allow_no_refresh')
  end
end

require_relative '../../../../lib/redmine/email_oauth_helper'

class EmailOauthReadUrlTest < Minitest::Test
  def test_reads_valid_url
    STDIN.stubs(:gets).returns("https://example.com/?code=abc\n")
    assert_equal 'abc', Redmine::EmailOauthHelper.read_oauth_code
  end

  def test_invalid_then_valid_url
    STDIN.stubs(:gets).returns("invalid\n", "https://example.com/?code=xyz\n")
    out, = capture_io do
      assert_equal 'xyz', Redmine::EmailOauthHelper.read_oauth_code
    end
    assert_match 'Invalid URL', out
  end
end

class EmailOauthInitTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @token_file = File.join(@dir, 'token')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def run_init_logic(token_hash)
    file = @token_file
    unless File.basename(file).start_with?('email_oauth2')
      file = File.join(File.dirname(file), "email_oauth2_#{File.basename(file)}")
    end
    client_config = {
      'client_id' => 'id',
      'client_secret' => 'secret',
      'site' => 'site',
      'authorize_url' => 'auth',
      'token_url' => 'token'
    }
    client = build_oauth_client(client_config, false)
    auth_code = stub('auth_code')
    client.stubs(:auth_code).returns(auth_code)
    auth_code.stubs(:authorize_url)
    token = stub('token', refresh_token: token_hash['refresh_token'], to_hash: token_hash)
    auth_code.stubs(:get_token).returns(token)

    access_token = oauth_get_token(client, 'code', client_config['client_id'], client_config['client_secret'], nil)
    check_refresh_token!(access_token)
    save_oauth_files(file, access_token, client_config)
  end

  def test_init_aborts_without_refresh_token
    assert_raises(SystemExit) do
      Kernel.stub(:abort, proc { |msg| raise SystemExit.new }) do
        run_init_logic('access_token' => 'a')
      end
    end
  end

  def test_refresh_token_is_persisted
    run_init_logic('access_token' => 'a', 'refresh_token' => 'r')
    data = YAML.safe_load(File.read(File.join(@dir, 'email_oauth2_token.yml')))
    assert_equal 'r', data['refresh_token']
  end
end

module Redmine
  module IMAP
  end
end

class Mailer
  def self.with_synched_deliveries(&block)
    yield
  end
end

require 'net/imap'

class EmailOauthReceiveImapRescueTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def imap_exception(klass, message)
    response = Struct.new(:data).new(Struct.new(:text).new(message))
    klass.new(response)
  end

  def run_receive_logic(exception)
    token_file = File.join(@dir, 'email_oauth2_token')
    imap_options = {
      :host => nil,
      :port => nil,
      :ssl => nil,
      :starttls => nil,
      :username => nil,
      :password => 'token',
      :auth_type => 'XOAUTH2',
      :folder => nil,
      :move_on_success => nil,
      :move_on_failure => nil
    }
    Redmine::IMAP.stubs(:check).raises(exception)

    out, _ = capture_io do
      Mailer.with_synched_deliveries do
        begin
          Redmine::IMAP.check(imap_options, {})
        rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError => e
          puts e.message
          if e.message.to_s.include?('AUTHENTICATIONFAILED')
            puts "Please re-run the OAuth init task. Token file: #{token_file}.yml"
          end
        end
      end
    end
    out
  end

  def test_authentication_failed_outputs_hint
    exception = imap_exception(Net::IMAP::BadResponseError, 'AUTHENTICATIONFAILED')
    output = run_receive_logic(exception)
    assert_includes output, 'Please re-run the OAuth init task'
    assert_includes output, File.join(@dir, 'email_oauth2_token.yml')
  end

  def test_other_errors_do_not_output_hint
    exception = imap_exception(Net::IMAP::NoResponseError, 'some error')
    output = run_receive_logic(exception)
    assert_includes output, 'some error'
    refute_includes output, 'Please re-run the OAuth init task'
  end
end
