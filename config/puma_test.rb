#!/usr/bin/env puma

# start puma with:
# bundle exec puma -C ./config/puma.rb RAILS_ENV=test
application_path = '/usr/local/www/redmine'
directory application_path

workers 3
threads 0,5
prune_bundler
environment 'test'
pidfile "#{application_path}/tmp/pids/puma_test.pid"
state_path "#{application_path}/tmp/pids/puma_test.state"
stdout_redirect "#{application_path}/log/puma_test.stdout.log", "#{application_path}/log/puma_test.stderr.log"
bind "unix://#{application_path}/tmp/sockets/redmine_test.sock"
activate_control_app 'tcp://127.0.0.1:9294', { auth_token: "trustteam" }
