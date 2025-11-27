# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class WebhooksControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :roles, :members, :member_roles, :trackers

  def setup
    %w[Manager Developer].each do |role_name|
      Role.find_by_name(role_name).add_permission! :use_webhooks
    end
  end

  def test_admin_can_view_all_webhooks
    with_webhooks_enabled do
      hook_one = create_webhook_for(User.find(2))
      hook_two = create_webhook_for(User.find(3), 'https://example.net')

      @request.session[:user_id] = 1
      get :index

      assert_response :success
      assert_select 'table.list tbody tr', 2
      assert_select 'td.username', :text => hook_one.user.name
      assert_select 'td.username', :text => hook_two.user.name
    end
  end

  def test_admin_can_edit_other_user_webhook
    with_webhooks_enabled do
      webhook = create_webhook_for(User.find(2))

      @request.session[:user_id] = 1
      get :edit, :params => {:id => webhook.id}

      assert_response :success
      assert_select 'form[action=?]', webhook_path(webhook)
    end
  end

  private

  def with_webhooks_enabled
    with_settings :webhooks_enabled => '1' do
      yield
    end
  end

  def create_webhook_for(user, url = 'https://example.com')
    project = Project.find(1)
    role = Role.find_by_name('Manager')
    tracker = Tracker.find(1)

    unless user.member_of?(project)
      Member.create!(:project => project, :principal => user, :roles => [role])
    end

    project.trackers << tracker unless project.trackers.include?(tracker)

    Webhook.create!(
      :user => user,
      :url => url,
      :projects => [project],
      :trackers => [tracker],
      :events => ['issue.created']
    )
  end
end
