# frozen_string_literal: true

require 'rest-client'

class Webhook < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :projects
  has_and_belongs_to_many :trackers

  serialize :events, Array

  validates :url, :presence => true,
                  :length => {:maximum => 2000},
                  :webhook_endpoint => true
  validates :secret, :length => {:maximum => 255}, :allow_blank => true
  validate :validate_events
  validate :validate_projects
  validate :validate_trackers

  scope :active, -> {where(:active => true)}

  before_validation :filter_projects
  before_validation :filter_trackers
  after_initialize :ensure_events_array

  def self.enabled?
    Setting.webhooks_enabled?
  end

  def self.trigger(event, object)
    return unless enabled?

    hooks_for(event, object).each do |hook|
      payload = hook.payload(event, object)
      WebhookJob.perform_later(hook.id, payload.to_json)
    end
  end

  def self.hooks_for(event, object)
    project = object.respond_to?(:project) ? object.project : nil
    return [] unless project

    active
      .joins(:projects, :user)
      .where(:projects => {:id => project.id})
      .where(:users => {:status => User::STATUS_ACTIVE})
      .select do |hook|
        hook.events.include?(event) &&
          (!object.respond_to?(:visible?) || object.visible?(hook.user)) &&
          hook.user.allowed_to?(:use_webhooks, project) &&
          hook.tracker_allowed?(object)
      end
  end

  def setable_projects
    member = user || User.current
    return Project.none unless member

    Project.allowed_to(member, :use_webhooks).sorted
  end

  def setable_events
    WebhookPayload::EVENTS
  end

  def setable_event_names
    setable_events.flat_map {|type, actions| actions.map {|action| "#{type}.#{action}"}}
  end

  def setable_trackers
    project_trackers = setable_projects.includes(:trackers).flat_map(&:trackers)
    project_trackers.uniq.sort_by(&:position)
  end

  def payload(event, object)
    WebhookPayload.new(event, object, user).to_h
  end

  def call(payload_json)
    Executor.new(url, payload_json, secret).call
    true
  rescue => e
    Rails.logger.warn do
      "Webhook delivery failed: #{e.class}: #{e.message}\n#{Array(e.backtrace).join("\n")}"
    end
    false
  end

  class Executor
    def initialize(url, payload, secret)
      @url = url
      @payload = payload
      @secret = secret
    end

    def call
      raise URI::BadURIError unless WebhookEndpointValidator.safe_webhook_uri?(@url)

      headers = {
        :accept => '*/*',
        :content_type => :json,
        :user_agent => 'Redmine'
      }
      headers['X-Redmine-Signature-256'] = compute_signature if @secret.present?

      Rails.logger.debug {"Webhook: POST #{@url}"}
      RestClient.post(@url, @payload, headers)
    end

    private

    def compute_signature
      'sha256=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @secret, @payload)
    end
  end

  def tracker_allowed?(object)
    return true unless object.respond_to?(:tracker_id)
    tracker_ids.blank? || tracker_ids.include?(object.tracker_id)
  end

  private

  def ensure_events_array
    self.events ||= []
  end

  def filter_projects
    return if project_ids.blank?

    allowed_ids = setable_projects.map(&:id)
    self.project_ids = project_ids & allowed_ids
  end

  def filter_trackers
    return if tracker_ids.blank?

    allowed_ids = setable_trackers.map(&:id)
    self.tracker_ids = tracker_ids & allowed_ids
  end

  def validate_events
    self.events = Array(events).reject(&:blank?)
    if events.blank? || (events - setable_event_names).any?
      errors.add(:events, :invalid)
    end
  end

  def validate_projects
    if project_ids.blank?
      errors.add(:projects, :blank)
    end
  end

  def validate_trackers
    self.tracker_ids = tracker_ids & setable_trackers.map(&:id)

    if issue_events_selected? && tracker_ids.blank?
      errors.add(:trackers, :blank)
    end
  end

  def issue_events_selected?
    Array(events).any? {|event| event.to_s.start_with?('issue.')}
  end
end
