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
  # Writes one chosen set of notification preferences to every account that an
  # authentication source owns, for the one-off pass after an LDAP import.
  #
  # It reports what it would do unless it is told to apply, and it journals the
  # previous values of every account it touches so that a run can be undone.
  class LdapNotificationDefaults
    # The preferences this class reads and writes, in report order.
    FIELDS = %w[mail_notification no_self_notified auto_watch_on].freeze

    BOOLEANS = {'1' => true, 'true' => true, 'yes' => true,
                '0' => false, 'false' => false, 'no' => false}.freeze

    class Error < StandardError; end

    attr_reader :values, :journal_path

    # Options are the raw strings a rake task takes from ENV: the three field
    # names, plus 'apply' and 'journal'.
    def initialize(options={})
      @values = self.class.parse(options)
      raise Error, "Give at least one of #{FIELDS.join(', ')}; nothing to set." if @values.empty?

      @apply = options['apply'].present?
      @journal_path = options['journal'].presence || self.class.default_journal_path
    end

    def apply?
      @apply
    end

    # Returns the values to write, keyed by field name. A field that was not
    # given is left out, so omitting it leaves the accounts alone instead of
    # silently resetting it.
    def self.parse(options)
      FIELDS.each_with_object({}) do |field, values|
        values[field] = send(:"parse_#{field}", options[field].to_s) if options.key?(field)
      end
    end

    def self.parse_mail_notification(value)
      allowed = User::MAIL_NOTIFICATION_OPTIONS.collect(&:first)
      unless allowed.include?(value)
        raise Error, "mail_notification must be one of #{allowed.join(', ')}, got #{value.inspect}."
      end

      value
    end

    def self.parse_no_self_notified(value)
      parsed = BOOLEANS[value.downcase]
      if parsed.nil?
        raise Error, "no_self_notified must be one of #{BOOLEANS.keys.join(', ')}, got #{value.inspect}."
      end

      parsed
    end

    def self.parse_auto_watch_on(value)
      given = value.split(',').collect(&:strip).reject(&:blank?)
      unknown = given - UserPreference::AUTO_WATCH_ON_OPTIONS
      if unknown.any?
        raise Error, "auto_watch_on takes #{UserPreference::AUTO_WATCH_ON_OPTIONS.join(', ')} " \
                     "or an empty value, got #{unknown.join(', ')}."
      end

      UserPreference::AUTO_WATCH_ON_OPTIONS & given
    end

    def self.default_journal_path
      Rails.root.join('log', "ldap-notification-defaults-#{Time.now.strftime('%Y%m%d-%H%M%S')}.json").to_s
    end

    # The accounts an authentication source owns. A local account, the
    # built-in administrator included, has no authentication source and is
    # therefore never touched.
    def self.scope
      User.where.not(:auth_source_id => nil)
    end

    def self.current_values(user, fields)
      fields.index_with do |field|
        case field
        when 'mail_notification' then user.mail_notification
        when 'no_self_notified'  then user.pref.no_self_notified
        when 'auto_watch_on'     then user.pref.auto_watch_on
        end
      end
    end

    # True when the account already holds every value, so that the run reports
    # a change only where it makes one.
    def self.already_set?(current, wanted)
      wanted.all? do |field, value|
        if field == 'auto_watch_on'
          Array(current[field]).sort == Array(value).sort
        else
          current[field] == value
        end
      end
    end

    # Writes the values to an account without saving it.
    def self.assign(user, values)
      values.each do |field, value|
        case field
        when 'mail_notification' then user.mail_notification = value
        when 'no_self_notified'  then user.pref.no_self_notified = value
        when 'auto_watch_on'     then user.pref.auto_watch_on = value
        end
      end
    end

    # LDAP-managed accounts do not always pass Redmine's own validations (a
    # missing mail address, for one) and this pass must still be able to set
    # their preferences.
    def self.persist(user)
      user.pref.save!
      user.save!(:validate => false)
    end

    # Restores the previous values recorded in a journal file. Reports what it
    # would do unless options['apply'] is given.
    def self.undo(options={}, io=$stdout)
      path = options['journal'].presence
      raise Error, 'Give journal=<path of the journal file to undo>.' if path.nil?
      raise Error, "#{path} does not exist." unless File.exist?(path)

      journal = JSON.parse(File.read(path))
      entries = journal['users'] || []
      apply = options['apply'].present?
      io.puts "Undoing #{path} of #{journal['run_at']}: #{entries.size} accounts."
      io.puts 'Reporting only. Add apply=1 to write.' unless apply

      restored = 0
      transaction(apply) do
        entries.each do |entry|
          user = User.find_by(:id => entry['id'])
          if user.nil?
            io.puts "SKIP:    #{entry['login']} no longer exists"
            next
          end

          previous = entry['previous'].slice(*FIELDS)
          io.puts "#{apply ? 'RESTORE:' : 'WOULD RESTORE:'} #{user.login} #{describe(previous)}"
          restored += 1
          next unless apply

          naming(user) do
            assign(user, previous)
            persist(user)
          end
        end
      end
      restored
    end

    # Rolls the whole pass back when one account fails, so that a failed run
    # never leaves half of them written.
    def self.transaction(apply, &)
      apply ? ActiveRecord::Base.transaction(&) : yield
    end

    # Names the account an exception came from: without this the stack trace
    # says which line failed but not on whom.
    def self.naming(user)
      yield
    rescue => e
      raise e, "#{e.message} (while updating #{user.login}, id #{user.id})", e.backtrace
    end

    def self.describe(values)
      FIELDS.filter_map do |field|
        next unless values.key?(field)

        value = values[field]
        value = value.join('+').presence || 'none' if value.is_a?(Array)
        "#{field}=#{value}"
      end.join(' ')
    end

    # Runs the pass. Returns the number of accounts it changed, or would
    # change when it is only reporting.
    def run(io=$stdout)
      total = self.class.scope.count
      raise Error, 'No account has an authentication source; nothing to do.' if total.zero?

      io.puts "#{total} accounts with an authentication source. Setting #{self.class.describe(values)}."
      io.puts 'Reporting only. Add apply=1 to write.' unless apply?

      # Written twice on purpose: an unwritable journal path has to fail before
      # the first account is changed, not after the last one.
      write_journal([])

      journal = []
      self.class.transaction(apply?) do
        self.class.scope.preload(:preference).find_each do |user|
          self.class.naming(user) do
            current = self.class.current_values(user, values.keys)
            if self.class.already_set?(current, values)
              io.puts "SKIP:   #{user.login} already set"
              next
            end

            journal << {:id => user.id, :login => user.login, :previous => current}
            io.puts "#{apply? ? 'UPDATE:' : 'WOULD UPDATE:'} #{user.login} " \
                    "#{self.class.describe(current)} -> #{self.class.describe(values)}"
            next unless apply?

            self.class.assign(user, values)
            self.class.persist(user)
          end
        end
      end

      write_journal(journal)
      io.puts "#{journal.size} of #{total} accounts #{apply? ? 'changed' : 'would change'}, " \
              "#{total - journal.size} already set. Journal: #{journal_path}"
      journal.size
    end

    private

    def write_journal(entries)
      File.write(
        journal_path,
        JSON.pretty_generate(
          'run_at' => Time.now.iso8601,
          'applied' => apply?,
          'values' => values,
          'users' => entries
        )
      )
    end
  end
end
