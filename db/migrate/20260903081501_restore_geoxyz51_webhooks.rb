# Copies the webhooks set aside by 20251007073255 into the tables created by
# 20251007073256 and 20260903081500, keeping their ids, then drops the 5.1
# tables. The rows are copied without validation: 7.0 resolves the host of a
# webhook URL when it is saved, so a hook whose host does not resolve is kept
# here but cannot be saved again until its URL is corrected.
class RestoreGeoxyz51Webhooks < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:geoxyz51_webhooks)

    execute <<~SQL
      INSERT INTO webhooks (id, url, secret, events, user_id, active, created_at, updated_at)
      SELECT id, url, secret, events, user_id, active, created_at, updated_at FROM geoxyz51_webhooks
    SQL
    if table_exists?(:geoxyz51_projects_webhooks)
      execute <<~SQL
        INSERT INTO projects_webhooks (project_id, webhook_id)
        SELECT project_id, webhook_id FROM geoxyz51_projects_webhooks
      SQL
    end
    if table_exists?(:geoxyz51_trackers_webhooks)
      execute <<~SQL
        INSERT INTO trackers_webhooks (tracker_id, webhook_id)
        SELECT tracker_id, webhook_id FROM geoxyz51_trackers_webhooks
      SQL
    end
    connection.reset_pk_sequence!('webhooks') if connection.respond_to?(:reset_pk_sequence!)

    %w(geoxyz51_trackers_webhooks geoxyz51_projects_webhooks geoxyz51_webhooks).each do |table|
      drop_table table if table_exists?(table)
    end
  end

  def down
    # no-op
  end
end
