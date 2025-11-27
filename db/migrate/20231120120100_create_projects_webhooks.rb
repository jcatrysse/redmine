# frozen_string_literal: true

class CreateProjectsWebhooks < ActiveRecord::Migration[6.1]
  def change
    create_table :projects_webhooks, :id => false do |t|
      t.references :project, :null => false
      t.references :webhook, :null => false
    end

    add_index :projects_webhooks, [:project_id, :webhook_id], :unique => true, :name => 'index_projects_webhooks_on_project_and_webhook'
  end
end
