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

module Issue::Webhookable
  extend ActiveSupport::Concern

  included do
    after_update_commit :trigger_issue_closed_webhook
  end

  def webhook_payload(user, action)
    h = super
    if %w(updated closed).include?(action) && current_journal.present?
      journal = journals.visible(user).find_by_id(current_journal.id)
      if journal.present?
        h[:data][:journal] = journal_payload(journal, user)
        h[:timestamp] = journal.created_on.iso8601
      end
    end
    if action == 'closed'
      h[:timestamp] = (closed_on || Time.current).iso8601
    end
    h
  end

  private

  def trigger_issue_closed_webhook
    return unless saved_change_to_status_id?

    previous_status = IssueStatus.find_by(id: saved_change_to_status_id.first)
    return unless status&.is_closed?
    return if previous_status&.is_closed?

    Webhook.trigger(event_name('closed'), self)
  end

  def journal_payload(journal, user)
    {
      id: journal.id,
      created_on: journal.created_on.iso8601,
      notes: journal.notes,
      user: {
        id: journal.user.id,
        name: journal.user.name,
      },
      details: journal.visible_details(user).map do |d|
        {
          property: d.property,
          prop_key: d.prop_key,
          old_value: d.old_value,
          value: d.value,
        }
      end
    }
  end
end
