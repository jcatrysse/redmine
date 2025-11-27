# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class WebhookTest < ActiveSupport::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles, :trackers, :issues, :issue_statuses

  def setup
    %w[Manager Developer].each do |role_name|
      Role.find_by_name(role_name).add_permission! :use_webhooks
    end
  end

  def test_issue_events_require_trackers
    webhook = Webhook.new(
      :user => User.find(2),
      :url => 'https://example.com',
      :projects => [Project.find(1)],
      :events => ['issue.created']
    )

    assert webhook.invalid?
    assert_includes webhook.errors.attribute_names, :trackers
  end

  def test_hooks_for_filters_by_tracker
    webhook = Webhook.create!(
      :user => User.find(1),
      :url => 'https://example.com',
      :projects => [Project.find(1)],
      :trackers => [Tracker.find(1)],
      :events => ['issue.created']
    )

    allowed_issue = Issue.find(1) # tracker_id 1
    filtered_issue = Issue.find(2) # tracker_id 2

    assert_equal [webhook], Webhook.hooks_for('issue.created', allowed_issue)
    assert_equal [], Webhook.hooks_for('issue.created', filtered_issue)
  end

  def test_trigger_enqueues_jobs_when_enabled
    webhook = Webhook.create!(
      :user => User.find(1),
      :url => 'https://example.com',
      :projects => [Project.find(1)],
      :trackers => [Tracker.find(1)],
      :events => ['issue.created']
    )

    issue = Issue.find(1)

    with_settings :webhooks_enabled => '1' do
      WebhookJob.expects(:perform_later).with(webhook.id, includes('issue.created')).once

      Webhook.trigger('issue.created', issue)
    end
  end

  def test_issue_closed_event_is_triggered_on_status_transition
    issue = Issue.find(1)

    Webhook.expects(:trigger).with('issue.updated', issue).once
    Webhook.expects(:trigger).with('issue.closed', issue).once

    issue.update_attribute(:status_id, IssueStatus.find_by(:is_closed => true).id)
  end

  def test_issue_closed_event_not_triggered_without_status_change
    issue = Issue.find(1)

    Webhook.expects(:trigger).with('issue.updated', issue).once
    Webhook.expects(:trigger).with('issue.closed', anything).never

    issue.update_attribute(:subject, 'Changed without status update')
  end
end
