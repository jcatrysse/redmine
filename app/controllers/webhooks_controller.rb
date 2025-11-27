# frozen_string_literal: true

class WebhooksController < ApplicationController
  self.main_menu = false

  before_action :require_login
  before_action :check_enabled
  before_action :authorize
  before_action :find_webhook, :only => [:edit, :update, :destroy]

  require_sudo_mode :create, :update, :destroy

  helper :projects

  def index
    @webhooks = webhooks_scope.order(:url)
  end

  def new
    @webhook = User.current.webhooks.build
  end

  def edit
  end

  def create
    @webhook = User.current.webhooks.build(webhook_params)
    if @webhook.save
      redirect_to webhooks_path
    else
      render :new
    end
  end

  def update
    if @webhook.update(webhook_params)
      redirect_to webhooks_path
    else
      render :edit
    end
  end

  def destroy
    @webhook.destroy
    redirect_to webhooks_path
  end

  private

  def webhooks_scope
    if User.current.admin?
      Webhook.includes(:user).references(:users)
    else
      User.current.webhooks
    end
  end

  def webhook_params
    attrs = params.require(:webhook).permit(:url, :secret, :active, :events => [], :project_ids => [], :tracker_ids => [])
    attrs[:events] = Array(attrs[:events]).reject(&:blank?)
    attrs[:project_ids] = Array(attrs[:project_ids]).reject(&:blank?)
    attrs[:tracker_ids] = Array(attrs[:tracker_ids]).reject(&:blank?)
    attrs
  end

  def find_webhook
    @webhook = webhooks_scope.find_by(:id => params[:id])
    render_404 unless @webhook
  end

  def authorize
    deny_access unless User.current.allowed_to?(:use_webhooks, nil, :global => true)
  end

  def check_enabled
    render_403 unless Webhook.enabled?
  end
end
