require 'minitest/autorun'
require 'yaml'
require 'fileutils'
require 'tempfile'

class EmailOauthStatusTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @token_file = File.join(@dir, 'token')
    prefixed = File.join(@dir, 'email_oauth2_token')
    File.write("#{prefixed}_client.yml", {
      'client_id' => 'id',
      'client_secret' => 'secret',
      'site' => 'https://accounts.google.com',
      'authorize_url' => 'auth',
      'token_url' => 'token'
    }.to_yaml)
    File.write("#{prefixed}.yml", {
      'access_token' => 'abc',
      'refresh_token' => 'r',
      'expires_at' => Time.now.to_i + 3600
    }.to_yaml)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def run_status_logic
    file = @token_file
    unless File.basename(file).start_with?('email_oauth2')
      file = File.join(File.dirname(file), "email_oauth2_#{File.basename(file)}")
    end
    token_data = YAML.safe_load_file("#{file}.yml")
    client_config = YAML.safe_load_file("#{file}_client.yml")

    provider =
      case client_config['site']
      when /microsoftonline/ then 'office365'
      when /google/ then 'google'
      else client_config['site']
      end

    expires_at = Time.at(token_data['expires_at'].to_i)
    remaining = token_data['expires_at'].to_i - Time.now.to_i
    refresh_present = token_data.key?('refresh_token') && !token_data['refresh_token'].to_s.empty?

    puts "provider: #{provider}"
    puts "expiry time: #{expires_at.utc} (#{expires_at})"
    puts "seconds remaining: #{remaining}"
    puts "refresh token present: #{refresh_present}"
  end

  def test_status_output_format
    out, = capture_io { run_status_logic }
    lines = out.split("\n")
    assert_match(/^provider: google$/, lines[0])
    assert_match(/^expiry time: .*UTC \(.+\)$/, lines[1])
    assert_match(/^seconds remaining: \d+$/, lines[2])
    assert_match(/^refresh token present: true$/, lines[3])
  end
end
