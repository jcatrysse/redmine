#!/usr/bin/env puma

# start puma with:
# bundle exec puma -C ./config/puma.rb RAILS_ENV=development
application_path = '/usr/local/www/redmine'
directory application_path

workers 3
threads 0,5
prune_bundler
environment 'development'
pidfile "#{application_path}/tmp/pids/puma_development.pid"
state_path "#{application_path}/tmp/pids/puma_development.state"
stdout_redirect "#{application_path}/log/puma_development.stdout.log", "#{application_path}/log/puma_development.stderr.log"
bind "unix://#{application_path}/tmp/sockets/redmine_development.sock"
