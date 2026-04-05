class CreateSessionSources < ActiveRecord::Migration[8.1]
  def up
    create_table :session_sources do |t|
      t.references :session, null: false, foreign_key: true, index: { unique: true }
      t.string :source_name, null: false
      t.string :source_type, null: false
      t.string :source_path, null: false
      t.string :source_checksum, null: false
      t.integer :source_size, null: false

      t.timestamps
    end

    # Migrate existing data
    execute <<~SQL
      INSERT INTO session_sources (session_id, source_name, source_type, source_path, source_checksum, source_size, created_at, updated_at)
      SELECT id, source_name, source_type, source_path, source_checksum, source_size, created_at, updated_at
      FROM sessions
    SQL

    remove_index :sessions, name: "index_sessions_on_external_id_and_source_type"
    remove_column :sessions, :source_name
    remove_column :sessions, :source_type
    remove_column :sessions, :source_path
    remove_column :sessions, :source_checksum
    remove_column :sessions, :source_size

    # external_id is still unique — source_type now lives in session_sources
    add_index :sessions, :external_id, unique: true
  end

  def down
    add_column :sessions, :source_name, :string
    add_column :sessions, :source_type, :string
    add_column :sessions, :source_path, :string
    add_column :sessions, :source_checksum, :string
    add_column :sessions, :source_size, :integer

    execute <<~SQL
      UPDATE sessions SET
        source_name = (SELECT source_name FROM session_sources WHERE session_sources.session_id = sessions.id),
        source_type = (SELECT source_type FROM session_sources WHERE session_sources.session_id = sessions.id),
        source_path = (SELECT source_path FROM session_sources WHERE session_sources.session_id = sessions.id),
        source_checksum = (SELECT source_checksum FROM session_sources WHERE session_sources.session_id = sessions.id),
        source_size = (SELECT source_size FROM session_sources WHERE session_sources.session_id = sessions.id)
    SQL

    remove_index :sessions, :external_id
    add_index :sessions, [:external_id, :source_type], unique: true

    change_column_null :sessions, :source_name, false
    change_column_null :sessions, :source_type, false
    change_column_null :sessions, :source_path, false
    change_column_null :sessions, :source_checksum, false
    change_column_null :sessions, :source_size, false

    drop_table :session_sources
  end
end
