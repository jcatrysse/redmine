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
  namespace :sessions do
    desc <<-DESC
Verifies that the database session store can serve a request: that the sessions
table exists, has the columns the store needs and both of its indexes, and that
the store is configured not to accept a plain-text session id. Exits 1 with the
reason when any of that is not true.

Run it as its own deploy step, after db:migrate and before traffic reaches the
new code. db:migrate cannot stand in for it: on a database upgraded from 5.1 the
migration's version is already in schema_migrations, so it is skipped in silence
and the guard inside it never runs.

On success it also prints what the deploy needs to know about the table: the
database adapter, the size limit on a single session, how many rows there are,
how many the first db:sessions:trim would delete, and how many were written by an
older version of the store.

Example:
  bundle exec rake redmine:sessions:check RAILS_ENV="production"
DESC
    task :check => :environment do
      Redmine::SessionStoreCheck.new.run
    rescue Redmine::SessionStoreCheck::Failed => e
      abort e.message
    end
  end
end
