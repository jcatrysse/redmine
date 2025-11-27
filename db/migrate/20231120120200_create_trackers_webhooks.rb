# frozen_string_literal: true

class CreateTrackersWebhooks < ActiveRecord::Migration[6.1]
  def change
    create_table :trackers_webhooks, :id => false do |t|
      t.references :tracker, :null => false
      t.references :webhook, :null => false
    end

    add_index :trackers_webhooks, [:tracker_id, :webhook_id], :unique => true,
              :name => 'index_trackers_webhooks_on_tracker_and_webhook'
  end
end
