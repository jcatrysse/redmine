class AddSessionsTable < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:sessions)

    create_table :sessions do |t|
      t.string :session_id, null: false
      t.text :data
      t.timestamps
    end

    add_index :sessions, :session_id, unique: true
    add_index :sessions, :updated_at
  end

  # Not reversible on purpose. Dropping the table logs every user out and
  # destroys every live session, and the guard in up makes a recorded rollback
  # a silent no-op that still removes the schema_migrations row.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
