# frozen_string_literal: true

class WebhookPayload
  EVENTS = {
    :issue => %w[created updated closed deleted],
    :wiki_page => %w[created updated deleted]
  }.freeze

  attr_reader :event, :object, :user

  def initialize(event, object, user)
    @event = event
    @object = object
    @user = user
  end

  def to_h
    type, action = event.split('.')
    type = type&.to_sym
    unless EVENTS[type]&.include?(action)
      raise ArgumentError, "Unsupported webhook event: #{event}"
    end

    payload, timestamp = send("#{type}_payload", action)
    timestamp ||= Time.current
    {
      :type => event,
      :timestamp => timestamp.utc.iso8601,
      :data => payload
    }
  end

  private

  def issue_payload(action)
    issue = object
    journal = %w[updated closed].include?(action) ? issue.current_journal : nil

    payload = {
      :issue => issue_hash(issue)
    }
    payload[:journal] = journal_hash(journal) if journal

    timestamp =
      case action
      when 'created'
        issue.created_on
      when 'closed'
        issue.closed_on || Time.current
      when 'deleted'
        Time.current
      else
        journal&.created_on || issue.updated_on
      end

    [payload, timestamp]
  end

  def wiki_page_payload(action)
    page, content = wiki_page_and_content
    payload = {
      :wiki_page => wiki_page_hash(page)
    }
    payload[:content] = wiki_content_hash(content) if content

    timestamp =
      case action
      when 'created'
        content&.created_on || Time.current
      when 'deleted'
        Time.current
      else
        content&.updated_on || Time.current
      end

    [payload, timestamp]
  end

  def issue_hash(issue)
    hash = {
      :id => issue.id,
      :subject => issue.subject,
      :description => issue.description,
      :is_private => issue.is_private?,
      :project => project_hash(issue.project),
      :tracker => reference_hash(issue.tracker),
      :status => status_hash(issue.status),
      :priority => reference_hash(issue.priority),
      :author => user_hash(issue.author),
      :assigned_to => user_hash(issue.assigned_to),
      :category => reference_hash(issue.category),
      :fixed_version => reference_hash(issue.fixed_version),
      :parent => issue.parent_id ? {:id => issue.parent_id} : nil,
      :start_date => issue.start_date&.to_s,
      :due_date => issue.due_date&.to_s,
      :done_ratio => issue.done_ratio,
      :estimated_hours => issue.estimated_hours,
      :total_estimated_hours => issue.total_estimated_hours,
      :created_on => issue.created_on&.iso8601,
      :updated_on => issue.updated_on&.iso8601,
      :closed_on => issue.closed_on&.iso8601
    }

    if user&.allowed_to?(:view_time_entries, issue.project)
      hash[:spent_hours] = issue.spent_hours
      hash[:total_spent_hours] = issue.total_spent_hours
    end

    custom_fields = issue.visible_custom_field_values(user).map do |value|
      {
        :id => value.custom_field_id,
        :name => value.custom_field.name,
        :value => value.value
      }
    end
    hash[:custom_fields] = custom_fields if custom_fields.any?

    hash.compact
  end

  def journal_hash(journal)
    return unless journal

    {
      :id => journal.id,
      :notes => journal.notes,
      :created_on => journal.created_on&.iso8601,
      :user => user_hash(journal.user),
      :details => journal.visible_details(user).map do |detail|
        {
          :property => detail.property,
          :prop_key => detail.prop_key,
          :old_value => detail.old_value,
          :value => detail.value
        }
      end
    }
  end

  def wiki_page_hash(page)
    return {} unless page

    {
      :id => page.id,
      :title => page.title,
      :project => project_hash(page.project),
      :parent_id => page.parent_id,
      :created_on => page.created_on&.iso8601,
      :updated_on => page.updated_on&.iso8601
    }.compact
  end

  def wiki_content_hash(content)
    return unless content

    {
      :version => content.version,
      :text => content.text,
      :comments => content.comments,
      :author => user_hash(content.author),
      :created_on => content.created_on&.iso8601,
      :updated_on => content.updated_on&.iso8601
    }
  end

  def wiki_page_and_content
    if object.is_a?(WikiContent)
      [object.page, object]
    else
      [object, object.respond_to?(:content) ? object.content : nil]
    end
  end

  def project_hash(project)
    return unless project

    {
      :id => project.id,
      :identifier => project.identifier,
      :name => project.name
    }
  end

  def reference_hash(record)
    return unless record

    {:id => record.id, :name => record.name}
  end

  def status_hash(status)
    return unless status

    {:id => status.id, :name => status.name, :is_closed => status.is_closed?}
  end

  def user_hash(user_record)
    return unless user_record

    {:id => user_record.id, :name => user_record.name}
  end
end
