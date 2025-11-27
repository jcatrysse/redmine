# frozen_string_literal: true

class WebhookJob < ApplicationJob
  def perform(hook_id, payload_json)
    previous_user = User.current
    hook = Webhook.find_by(:id => hook_id)
    return unless hook&.user&.active?

    User.current = hook.user
    hook.call(payload_json)
  ensure
    User.current = previous_user
  end
end
