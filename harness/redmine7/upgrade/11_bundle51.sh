#!/bin/bash
# Configure and bundle the 5.1 tree. Ruby 3.2.6 from /opt/rbenv: the 5.1 Gemfile says ruby < 3.3.0
# (tools/testenv/setup.sh uses 3.2.6 for 5.1 too).
set -uo pipefail
. "$(dirname "$0")/env.sh"
export PATH=/opt/rbenv/versions/3.2.6/bin:$PATH
cd "$U51"
cat > config/database.yml <<YML
production:
  adapter: postgresql
  database: r70h_upg
  host: 127.0.0.1
  username: redmine
  password: redmine
  encoding: utf8
YML
# as tools/testenv/setup.sh: 5.1-stable-GEOxyz uses active_record_store without declaring the gem
printf "gem 'activerecord-session_store', '~> 2.1'\ngem 'puma'\n" > Gemfile.local
# GEOxyz relation types (production config of redmine_issue_view_columns)
git -C /home/user/jira2redmine_migration show origin/redmine70-migration:tools/testenv/redmine_issue_view_columns.local.rb > plugins/redmine_issue_view_columns/config/redmine_issue_view_columns.local.rb
bundle config set --local path vendor/bundle
bundle config set --local without 'development test rmagick'
bundle install -j4 || exit 1
# as setup.sh: redmineup >= 1.1.5 defines the route auto_complete_taggable_tags that redmine_contacts (master) defines too
sed -i -E 's/^    redmineup \([0-9.]+\)/    redmineup (1.1.4)/; /^  redmineup \([0-9.]+\) sha256/d' Gemfile.lock && bundle install
bundle list 2>/dev/null | grep -E 'redmineup|rails |puma|pg '
