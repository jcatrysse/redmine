class CreateTrackersWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :trackers_webhooks do |t|
      t.integer :tracker_id, null: false, index: true
      t.integer :webhook_id, null: false, index: true
    end
  end
end