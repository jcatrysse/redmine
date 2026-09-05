# frozen_string_literal: true

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

module Redmine
  # Deploy-time check that the database session store can actually serve a
  # request, plus the handful of facts the deploy needs about the table.
  #
  # The migration cannot be this check. On the database that matters, its
  # version came over from 5.1 and is already in schema_migrations, so the
  # migration never runs and the guard inside it is never reached — and Rails
  # prints nothing at all for a migration it skips. A missing or wrongly shaped
  # table is then invisible until the first request, which is a 500 on every
  # page, /login included.
  class SessionStoreCheck
    REQUIRED_COLUMNS = %w[session_id data created_at updated_at].freeze

    # The number of days after which db:sessions:trim deletes a session. A row
    # is written for every page view, signed in or not, so the gem's own 30-day
    # default lets the table grow far beyond what it is worth keeping.
    TRIM_DAYS = 7

    class Failed < StandardError; end

    def table
      ActiveRecord::SessionStore::Session.table_name
    end

    def connection
      ActiveRecord::Base.connection
    end

    # The reasons the deploy must not go ahead, most fundamental first. The
    # first two are fatal on their own, so nothing below them is worth saying.
    def problems
      store = Rails.application.config.session_store
      if store != ActionDispatch::Session::ActiveRecordStore
        return ["the session store is #{store}, not ActionDispatch::Session::ActiveRecordStore"]
      end
      unless connection.table_exists?(table)
        return ["the table '#{table}' does not exist, so every request would be a 500 — /login included"]
      end

      list = []
      missing = REQUIRED_COLUMNS - connection.columns(table).collect(&:name)
      list << "'#{table}' has no column #{missing.join(', ')}" if missing.any?
      unless index_on?('session_id', :unique => true)
        list << "'#{table}' has no unique index on session_id"
      end
      unless index_on?('updated_at')
        list << "'#{table}' has no index on updated_at, so db:sessions:trim would scan the whole table"
      end
      list
    end

    # What the deploy has to know and cannot work out from the repository: how
    # big a session may get, how much there is to trim, and how many rows an
    # older store left behind.
    def facts
      data = connection.columns(table).detect {|c| c.name == 'data'}
      {
        'database adapter' => connection.adapter_name,
        'session size limit' =>
          data.limit ? "#{data.limit} bytes (#{data.sql_type}); a bigger session raises" : "none (#{data.sql_type})",
        'rows' => count,
        'rows the first trim would delete' => count("updated_at < ?", TRIM_DAYS.days.ago),
        'rows written by an older store' => count("session_id NOT LIKE ?", '%::%')
      }
    end

    def index_on?(column, unique: false)
      connection.indexes(table).any? do |index|
        Array(index.columns) == [column] && (!unique || index.unique)
      end
    end

    def count(*condition)
      scope = ActiveRecord::SessionStore::Session.all
      scope = scope.where(*condition) if condition.any?
      scope.count
    end

    # Prints the findings and raises when the deploy must stop.
    def run(io=$stdout)
      found = problems
      raise Failed, found.collect {|problem| "FAIL  #{problem}"}.join("\n") if found.any?

      collected = facts
      collected.each {|name, value| io.puts format('  %-34s %s', name, value)}
      if collected['rows written by an older store'].positive?
        io.puts '  note  those rows are refused as a login by secure_session_only, but they are dead ' \
                'weight — db:sessions:clear empties the table, db:sessions:upgrade rewrites them.'
      end
      io.puts "  ok    '#{table}' is there and shaped the way the store expects"
    end
  end
end
