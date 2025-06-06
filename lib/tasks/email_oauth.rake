# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# OAuth2 IMAP fetch tasks (O365 & Google)

require 'net/imap'
require 'oauth2'
require 'uri'
require 'cgi'
require 'yaml'
require_relative '../redmine/email_oauth_helper'

# XOAUTH2 helper (no-op if already loaded)
begin
  require 'gmail_xoauth'
rescue LoadError
  # ignore
end

PERMITTED = {
  permitted_classes:  [Symbol],
  permitted_symbols:  %i[
    access_token refresh_token token_type expires_at expires_in scope
    ext_expires_in mode header header_format param_name Bearer
  ],
  aliases: true
}.freeze

# ------------------------------------------------------------------
# helpers
# ------------------------------------------------------------------
def secure_file(path)
  return unless File.exist?(path)
  return if File::ALT_SEPARATOR # Windows
  File.chmod(0o600, path)
rescue StandardError
  # ignore
end

def env_bool(name, default=false)
  v = ENV[name]
  return default if v.nil?
  %w[1 true yes y t].include?(v.to_s.strip.downcase)
end

def normalize_token_file(path)
  path ||= Rails.root.join('config', 'email_oauth2_token').to_s
  base = File.basename(path)
  return path if base.start_with?('email_oauth2')
  File.join(File.dirname(path), "email_oauth2_#{base}")
end

def mask_token(tok, keep: 6)
  return "(nil)" if tok.to_s.empty?
  return tok if tok.length <= keep*2
  head = tok[0, keep]
  tail = tok[-keep, keep]
  "#{head}...#{tail} (len=#{tok.length})"
end

# Print usage information for the given task symbol.
def show_oauth_help(task)
  case task
  when :o365_oauth2_init
    puts <<~EOS
      Usage: rake redmine:email:o365_oauth2_init client=CLIENT secret=SECRET tenant=TENANT [options]

      Options:
        token_file=FILE       Base name for token files (default: config/email_oauth2_token)
        redirect_uri=URI      Custom redirect URI
        force_consent=1       Force consent screen
        allow_no_refresh=1    Do not abort when refresh token is missing
    EOS
  when :google_oauth2_init
    puts <<~EOS
      Usage: rake redmine:email:google_oauth2_init client=CLIENT secret=SECRET [options]

      Options:
        token_file=FILE       Base name for token files (default: config/email_oauth2_token)
        redirect_uri=URI      Redirect URI (default: http://localhost)
        force_consent=1       Force consent screen
        allow_no_refresh=1    Do not abort when refresh token is missing
    EOS
  when :receive_imap_oauth2
    puts <<~EOS
      Usage: rake redmine:email:receive_imap_oauth2 host=HOST username=USER token_file=FILE [options]

      Options:
        port=PORT             IMAP server port (default: 993)
        ssl=BOOL              Use SSL/TLS (default: 1)
        starttls=BOOL         Use STARTTLS when ssl=0 (default: 0)
        folder=NAME           IMAP folder to read (default: INBOX)
        move_on_success=BOX   Move processed emails to BOX
        move_on_failure=BOX   Move ignored emails to BOX
        imap_debug=1          Verbose output
    EOS
  when :oauth2_status
    puts <<~EOS
      Usage: rake redmine:email:oauth2_status token_file=FILE
    EOS
  end
end

def abort_usage(task, message)
  show_oauth_help(task)
  abort(message)
end

# Build an OAuth2 client from a config hash.
def build_oauth_client(config, redirect_set)
  OAuth2::Client.new(
    config['client_id'],
    config['client_secret'],
    site:          config['site'],
    authorize_url: config['authorize_url'],
    token_url:     config['token_url'],
    redirect_uri:  redirect_set ? config['redirect_uri'] : nil
  )
end

# Exchange the authorization code for an access token.
def oauth_get_token(client, code, client_id, client_secret, redirect_uri)
  params = {client_id: client_id, client_secret: client_secret}
  params[:redirect_uri] = redirect_uri if redirect_uri
  client.auth_code.get_token(code, **params)
end

# Persist token and client configuration to disk with secure permissions.
def save_oauth_files(token_file, access_token, client_config)
  File.write("#{token_file}.yml", access_token.to_hash.to_yaml)
  secure_file("#{token_file}.yml")
  File.write("#{token_file}_client.yml", client_config.to_yaml)
  secure_file("#{token_file}_client.yml")
end

# Abort if no refresh token was returned unless explicitly allowed.
def check_refresh_token!(token)
  return unless token.refresh_token.to_s.empty?

  if ENV['allow_no_refresh'] == '1'
    warn 'No refresh token returned; proceeding (token will expire).'
  else
    abort('No refresh token received; check application permissions (try prompt=consent).')
  end
end

namespace :redmine do
  namespace :email do

    desc "Display usage for email OAuth tasks"
    task :help, [:task] => :environment do |_, args|
      tasks = {
        o365_oauth2_init: :o365_oauth2_init,
        google_oauth2_init: :google_oauth2_init,
        receive_imap_oauth2: :receive_imap_oauth2,
        oauth2_status: :oauth2_status
      }
      if args[:task]
        show_oauth_help(args[:task].to_sym)
      else
        tasks.each_value { |t| show_oauth_help(t) }
      end
    end

    # ------------------------------------------------------------------
    # Office 365 Authorization Init
    # ------------------------------------------------------------------
    desc "Init Office 365 authorization"
    task :o365_oauth2_init => :environment do
      token_file    = normalize_token_file(ENV['token_file'])
      client_id     = ENV['client']
      client_secret = ENV['secret']
      tenant_id     = ENV['tenant']
      redirect_uri  = ENV['redirect_uri'].to_s.strip
      redirect_set  = !redirect_uri.empty?

      missing = []
      missing << 'client' if client_id.to_s.empty?
      missing << 'secret' if client_secret.to_s.empty?
      missing << 'tenant' if tenant_id.to_s.empty?
      abort_usage(:o365_oauth2_init, "Missing ENV #{missing.join(', ')}") unless missing.empty?

      puts 'See doc/O365_IMAP_OAUTH.md for setup instructions.'
      puts "WARN: no redirect_uri supplied; using app-registered default." unless redirect_set


      # Note: current scopes are broad and may be pruned later
      scope = [
        "offline_access",
        "https://outlook.office.com/User.Read",
        "https://outlook.office.com/IMAP.AccessAsUser.All",
        "https://outlook.office.com/POP.AccessAsUser.All",
        "https://outlook.office.com/SMTP.Send",
      ]

      client_config = {
        "tenant_id"     => tenant_id,
        "client_id"     => client_id,
        "client_secret" => client_secret,
        "site"          => 'https://login.microsoftonline.com',
        "authorize_url" => "/#{tenant_id}/oauth2/v2.0/authorize",
        "token_url"     => "/#{tenant_id}/oauth2/v2.0/token",
        "scope"         => scope.join(' ')
      }
      client_config["redirect_uri"] = redirect_uri if redirect_set

      client = build_oauth_client(client_config, redirect_set)

      # Force prompt only when explicitly requested
      force_consent = ENV['force_consent'] == '1'

      url_params = { scope: client_config['scope'] }
      url_params[:prompt] = 'consent' if force_consent
      url_params[:redirect_uri] = client_config['redirect_uri'] if redirect_set

      puts "Go to URL: #{client.auth_code.authorize_url(**url_params)}"
      print "Enter full redirect URL after authorize: "
      code = Redmine::EmailOauthHelper.read_oauth_code

      access_token = oauth_get_token(client, code, client_id, client_secret, redirect_set ? client_config['redirect_uri'] : nil)
      check_refresh_token!(access_token)
      save_oauth_files(token_file, access_token, client_config)

      puts "AUTH OK!"
    end

    # ------------------------------------------------------------------
    # Google Authorization Init
    # ------------------------------------------------------------------
    desc "Init Google authorization"
    task :google_oauth2_init => :environment do
      token_file    = normalize_token_file(ENV['token_file'])
      client_id     = ENV['client']
      client_secret = ENV['secret']
      redirect_uri  = ENV['redirect_uri'].to_s.strip

      missing = []
      missing << 'client' if client_id.to_s.empty?
      missing << 'secret' if client_secret.to_s.empty?
      abort_usage(:google_oauth2_init, "Missing ENV #{missing.join(', ')}") unless missing.empty?

      puts 'See doc/GMAIL_IMAP_OAUTH.md for setup instructions.'
      if redirect_uri.empty?
        redirect_uri = 'http://localhost'
        puts "WARN: no redirect_uri supplied; defaulting to #{redirect_uri}"
      end
      redirect_set = true

      scope = ['https://mail.google.com/']

      client_config = {
        'client_id'     => client_id,
        'client_secret' => client_secret,
        'site'          => 'https://accounts.google.com',
        'authorize_url' => '/o/oauth2/v2/auth',
        'token_url'     => 'https://oauth2.googleapis.com/token',
        'scope'         => scope.join(' '),
        'auth_params'   => { 'access_type' => 'offline' }
      }
      client_config['redirect_uri'] = redirect_uri if redirect_set

      client = build_oauth_client(client_config, redirect_set)

      force_consent = ENV['force_consent'] == '1'

      url_params = (client_config['auth_params'] || {}).dup
      url_params = url_params.transform_keys(&:to_sym)
      url_params[:scope]  = client_config['scope']
      url_params[:prompt] = 'consent' if force_consent
      url_params[:redirect_uri] = client_config['redirect_uri'] if redirect_set

      puts "Go to URL: #{client.auth_code.authorize_url(**url_params)}"
      print "Enter full redirect URL after authorize: "
      code = Redmine::EmailOauthHelper.read_oauth_code

      access_token = oauth_get_token(client, code, client_id, client_secret, redirect_set ? client_config['redirect_uri'] : nil)
      check_refresh_token!(access_token)
      save_oauth_files(token_file, access_token, client_config)

      puts "AUTH OK!"
    end

    # ------------------------------------------------------------------
    # Receive IMAP (OAuth2)
    # ------------------------------------------------------------------
    desc "Read emails from an IMAP server authorized via OAuth2"
    task :receive_imap_oauth2 => :environment do
      debug = env_bool('imap_debug', false)

      token_file_env = ENV['token_file']
      token_file = normalize_token_file(token_file_env)
      host       = ENV['host'].to_s
      username   = ENV['username'].to_s

      missing = []
      missing << 'token_file' if token_file_env.to_s.empty? || !(File.exist?("#{token_file}.yml") && File.exist?("#{token_file}_client.yml"))
      missing << 'host' if host.empty?
      missing << 'username' if username.empty?
      abort_usage(:receive_imap_oauth2, "Missing or invalid ENV #{missing.join(', ')}") unless missing.empty?

      client_config = YAML.safe_load_file("#{token_file}_client.yml", **PERMITTED)
      client = build_oauth_client(client_config, !client_config['redirect_uri'].to_s.empty?)

      token_hash  = YAML.safe_load_file("#{token_file}.yml", **PERMITTED)
      access_token = OAuth2::AccessToken.from_hash(client, token_hash)

      if debug
        exp = access_token.expires_at ? Time.at(access_token.expires_at).utc : '(none)'
        rem = access_token.expires_at ? (access_token.expires_at - Time.now.to_i) : '(unknown)'
        puts "IMAP DEBUG: loaded token expires_at=#{exp} remaining=#{rem}"
        puts "IMAP DEBUG: refresh? #{access_token.refresh_token ? 'yes' : 'no'}"
        puts "IMAP DEBUG: token=#{mask_token(access_token.token)}"
      end

      if access_token.expired?
        logger = defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : nil
        msg = "Refreshing OAuth token; old expiry: #{access_token.expires_at}"
        logger ? logger.info(msg) : $stderr.puts(msg)

        begin
          access_token = access_token.refresh!
        rescue OAuth2::Error => e
          abort("Token refresh failed (#{e.message}). Re-run init task.")
        end

        msg = "OAuth token refreshed; new expiry: #{access_token.expires_at}"
        logger ? logger.info(msg) : $stderr.puts(msg)

        File.write("#{token_file}.yml", access_token.to_hash.to_yaml)
        secure_file("#{token_file}.yml")
      end

      port     = (ENV['port'] || 993).to_i
      ssl      = env_bool('ssl', true)
      starttls = env_bool('starttls', false)
      folder   = ENV['folder'].to_s
      folder   = 'INBOX' if folder.empty?

      # Safety: when ssl is true remove the starttls key so Redmine will not enable it
      starttls = false if ssl
      imap_options = {
        :host            => host,
        :port            => port,
        :username        => username,
        :password        => access_token.token,
        :auth_type       => 'XOAUTH2',
        :folder          => folder,
        :move_on_success => ENV['move_on_success'],
        :move_on_failure => ENV['move_on_failure']
      }
      # Only include if actually true (otherwise omit so Redmine sees nil and disables SSL/STARTTLS)
      imap_options[:ssl] = true if ssl
      imap_options[:starttls] = true if starttls

      puts "IMAP DEBUG: effective imap_options=#{imap_options.inspect}" if debug

      Mailer.with_synched_deliveries do
        begin
          # Sanitized ENV for MailHandler (without IMAP keys the core misinterprets)
          mail_env = ENV.to_h.dup
          %w[host port ssl starttls username token_file folder move_on_success move_on_failure].each { |k| mail_env.delete(k) }
          mail_opts = MailHandler.extract_options_from_env(mail_env)
          puts "IMAP DEBUG: MailHandler opts=#{mail_opts.inspect}" if debug

          Redmine::IMAP.check(imap_options, mail_opts)
        rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError => e
          puts "IMAP ERROR: #{e.class}: #{e.message}"
          if e.message.to_s.include?('AUTHENTICATIONFAILED')
            puts "Please re-run the OAuth init task. Token file: #{token_file}.yml"
          end
          raise
        rescue StandardError => e
          warn "IMAP error: #{e.class}: #{e.message}"
          warn e.backtrace.join("\n") if debug
          raise
        end
      end
    end

    # ------------------------------------------------------------------
    # Inspect token
    # ------------------------------------------------------------------
    desc "Display OAuth2 token information"
    task :oauth2_status => :environment do
      token_file_env = ENV['token_file']
      token_file = normalize_token_file(token_file_env)

      unless token_file_env && File.exist?("#{token_file}.yml") && File.exist?("#{token_file}_client.yml")
        abort_usage(:oauth2_status, "Missing or invalid ENV token_file")
      end

      raw_token_data = YAML.safe_load_file("#{token_file}.yml", **PERMITTED)
      token_data = if raw_token_data.is_a?(Hash)
                     raw_token_data.each_with_object({}) { |(k,v),h| h[k.to_s.sub(/\A:/,'')] = v }
                   else
                     {}
                   end

      client_config = YAML.safe_load_file("#{token_file}_client.yml", **PERMITTED)

      provider =
        case client_config['site']
        when /microsoftonline/ then 'office365'
        when /google/          then 'google'
        else client_config['site']
        end

      exp_val = token_data['expires_at']
      if exp_val
        expires_at = Time.at(exp_val.to_i)
        remaining  = exp_val.to_i - Time.now.to_i
      else
        expires_at = '(none)'
        remaining  = '(unknown)'
      end

      refresh_present = token_data['refresh_token'].to_s != ''

      puts "provider: #{provider}"
      puts "expiry time: #{expires_at.is_a?(Time) ? expires_at.utc : expires_at} (#{expires_at})"
      puts "seconds remaining: #{remaining}"
      puts "refresh token present: #{refresh_present}"
      puts "redirect_uri stored: #{client_config['redirect_uri'].inspect}"
    end

  end
end
