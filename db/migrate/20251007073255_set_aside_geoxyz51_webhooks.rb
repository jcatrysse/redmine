# 5.1-stable-GEOxyz created webhooks, projects_webhooks and trackers_webhooks
# in its own migrations 20231120120000 to 20231120120200, in a shape that
# differs from the tables 7.0 creates under the same names in 20251007073256.
# Renames them out of the way on a database upgraded from 5.1-stable-GEOxyz;
# 20260903081501 copies their rows into the 7.0 tables and drops them.
class SetAsideGeoxyz51Webhooks < ActiveRecord::Migration[8.1]
  TABLES = %w(webhooks projects_webhooks trackers_webhooks)
  VERSIONS = %w(20231120120000 20231120120100 20231120120200)

  def up
    schema_migration = connection.pool.schema_migration
    return unless schema_migration.versions.include?(VERSIONS.first)

    TABLES.each do |table|
      rename_table table, "geoxyz51_#{table}" if table_exists?(table)
    end
    VERSIONS.each {|version| schema_migration.delete_version(version)}
  end

  def down
    # no-op
  end
end
