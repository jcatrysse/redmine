# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

namespace :redmine do
  namespace :email do

    desc <<-END_DESC
Read an email from standard input.

See redmine:email:receive_imap for more options and examples.
END_DESC

    task :read => :environment do
      Mailer.with_synched_deliveries do
        MailHandler.safe_receive(STDIN.read, MailHandler.extract_options_from_env(ENV))
      end
    end

    desc <<-END_DESC
Read emails from an IMAP server.

Available IMAP options:
  host=HOST                IMAP server host (default: 127.0.0.1)
  port=PORT                IMAP server port (default: 143)
  ssl=SSL                  Use SSL/TLS? (default: false)
                           Setting `ssl=force` disables server certificate
                           verification
  starttls=STARTTLS        Use STARTTLS? (default: false)
  username=USERNAME        IMAP account
  password=PASSWORD        IMAP password
  oauth2_token=TOKEN       OAuth 2.0 access token to authenticate with instead
                           of password, using the XOAUTH2 mechanism
  oauth2_credentials=FILE  path to a YAML file holding the OAuth 2.0 client
                           credentials and the refresh token used to request
                           an access token on each run:
                             token_url: https://...
                             client_id: ...
                             client_secret: ...
                             refresh_token: ...
                             scope: ...
                           Run redmine:email:oauth2_authorize once to obtain
                           the refresh token. See the guides at:
                           http://www.redmine.org/projects/redmine/wiki/EmailConfiguration
  folder=FOLDER            IMAP folder to read (default: INBOX)

Processed emails control options:
  move_on_success=MAILBOX  move emails that were successfully received
                           to MAILBOX instead of deleting them
  move_on_failure=MAILBOX  move emails that were ignored to MAILBOX

User and permissions options:
  unknown_user=ACTION      how to handle emails from an unknown user
                           ACTION can be one of the following values:
                           ignore: email is ignored (default)
                           accept: accept as anonymous user
                           create: create a user account
  no_permission_check=1    disable permission checking when receiving
                           the email
  no_account_notice=1      disable new user account notification
  no_notification=1        disable email notification to new user
  default_group=foo,bar    adds created user to foo and bar groups

Issue attributes control options:
  project=PROJECT          identifier of the target project
  project_from_subaddress=ADDR
                           select project from subaddress of ADDR found
                           in To, Cc, Bcc headers
  status=STATUS            name of the target status
  tracker=TRACKER          name of the target tracker
  category=CATEGORY        name of the target category
  priority=PRIORITY        name of the target priority
  assigned_to=ASSIGNEE     assignee (username or group name)
  fixed_version=VERSION    name of the target version
  private                  create new issues as private
  allow_override=ATTRS     allow email content to set attributes values
                           ATTRS is a comma separated list of attributes
                           or 'all' to allow all attributes to be overridable
                           (see below for details)

Overrides:
  ATTRS is a comma separated list of attributes among:
  * project, tracker, status, priority, category, assigned_to, fixed_version,
    start_date, due_date, estimated_hours, done_ratio
  * custom fields names with underscores instead of spaces (case insensitive)

  Example: allow_override=project,priority,my_custom_field

  If the project option is not set, project is overridable by default for
  emails that create new issues.

  You can use allow_override=all to allow all attributes to be overridable.

Examples:
  # No project specified. Emails MUST contain the 'Project' keyword:

  rake redmine:email:receive_imap RAILS_ENV="production" \\
    host=imap.foo.bar username=redmine@example.net password=xxx


  # Fixed project and default tracker specified, but emails can override
  # both tracker and priority attributes:

  rake redmine:email:receive_imap RAILS_ENV="production" \\
    host=imap.foo.bar username=redmine@example.net password=xxx ssl=1 \\
    project=foo \\
    tracker=bug \\
    allow_override=tracker,priority


  # Mailbox that does not accept a password, authenticated with an OAuth 2.0
  # access token requested from the credentials file on each run:

  rake redmine:email:receive_imap RAILS_ENV="production" \\
    host=outlook.office365.com port=993 ssl=1 \\
    username=redmine@example.net \\
    oauth2_credentials=/etc/redmine/imap_oauth2.yml \\
    project=foo
END_DESC

    task :receive_imap => :environment do
      imap_options = {:host => ENV['host'],
                      :port => ENV['port'],
                      :ssl => ENV['ssl'],
                      :starttls => ENV['starttls'],
                      :username => ENV['username'],
                      :password => ENV['password'],
                      :oauth2_token => ENV['oauth2_token'],
                      :oauth2_credentials => ENV['oauth2_credentials'],
                      :folder => ENV['folder'],
                      :move_on_success => ENV['move_on_success'],
                      :move_on_failure => ENV['move_on_failure']}

      Mailer.with_synched_deliveries do
        Redmine::IMAP.check(imap_options, MailHandler.extract_options_from_env(ENV))
      end
    end

    desc <<-END_DESC
Obtain the refresh token that receive_imap needs, once, for one mailbox.

This is interactive on purpose: only the mailbox owner can consent, in a
browser. The task prints a URL to open, and the browser is then redirected to
redirect_uri. That address usually fails to load, which is expected - copy it
out of the address bar and paste it back here.

Available options:
  oauth2_credentials=FILE  the YAML file described in receive_imap, with
                           everything except refresh_token filled in, plus:
                             authorize_url: https://...
                             redirect_uri: http://localhost (the default; it
                               must be registered with the provider)
                             authorize_params:  extra query parameters the
                               provider needs, as name: value pairs

Provider specific values belong in that file rather than in Redmine. The
guides for Gmail and Microsoft 365 are at:
http://www.redmine.org/projects/redmine/wiki/EmailConfiguration

Example:
  rake redmine:email:oauth2_authorize RAILS_ENV="production" \\
    oauth2_credentials=/etc/redmine/imap_oauth2.yml
END_DESC

    task :oauth2_authorize => :environment do
      credentials_file = ENV['oauth2_credentials']
      abort 'Missing oauth2_credentials=FILE' if credentials_file.blank?

      puts "Open this URL in a browser and sign in as the mailbox owner:"
      puts
      puts Redmine::Oauth2Client.authorize_url(credentials_file)
      puts
      print "Then paste the whole address you were redirected to: "
      STDOUT.flush
      redirect_url = STDIN.gets
      refresh_token = Redmine::Oauth2Client.refresh_token(credentials_file, redirect_url)

      puts
      puts "Add this line to #{credentials_file}:"
      puts
      puts "refresh_token: #{refresh_token}"
    end

    desc <<-END_DESC
Read emails from an POP3 server.

Available POP3 options:
  host=HOST                POP3 server host (default: 127.0.0.1)
  port=PORT                POP3 server port (default: 110)
  username=USERNAME        POP3 account
  password=PASSWORD        POP3 password
  apop=1                   use APOP authentication (default: false)
  ssl=SSL                  Use SSL? (default: false)
                           Setting `ssl=force` disables server certificate
                           verification
  delete_unprocessed=1     delete messages that could not be processed
                           successfully from the server (default
                           behaviour is to leave them on the server)

See redmine:email:receive_imap for more options and examples.
END_DESC

    task :receive_pop3 => :environment do
      pop_options  = {:host => ENV['host'],
                      :port => ENV['port'],
                      :apop => ENV['apop'],
                      :ssl => ENV['ssl'],
                      :username => ENV['username'],
                      :password => ENV['password'],
                      :delete_unprocessed => ENV['delete_unprocessed']}

      Mailer.with_synched_deliveries do
        Redmine::POP3.check(pop_options, MailHandler.extract_options_from_env(ENV))
      end
    end

    desc "Send a test email to the user with the provided login name"
    task :test, [:login] => :environment do |task, args|
      include Redmine::I18n
      abort l(:notice_email_error, "Please include the user login to test with. Example: rake redmine:email:test[login]") if args[:login].blank?

      user = User.find_by_login(args[:login])
      abort l(:notice_email_error, "User #{args[:login]} not found") unless user && user.logged?

      begin
        Mailer.deliver_test_email(user)
        puts l(:notice_email_sent, user.mail)
      rescue => e
        abort l(:notice_email_error, e.message)
      end
    end
  end
end
