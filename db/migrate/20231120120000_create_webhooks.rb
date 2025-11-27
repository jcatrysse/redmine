# frozen_string_literal: true

class CreateWebhooks < ActiveRecord::Migration[6.1]
  def change
    create_table :webhooks do |t|
      t.references :user, :null => false
      t.string :url, :limit => 2000, :null => false
      t.string :secret, :limit => 255
      t.boolean :active, :default => true, :null => false
      t.text :events
      t.timestamps
    end
  end
end
