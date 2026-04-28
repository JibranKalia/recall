class CreateMessageContents < ActiveRecord::Migration[8.1]
  def up
    create_table :message_contents do |t|
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      t.text :content_text
      t.text :content_json

      t.timestamps
    end

    # Migrate existing data
    execute <<~SQL
      INSERT INTO message_contents (message_id, content_text, content_json, created_at, updated_at)
      SELECT id, content_text, content_json, created_at, updated_at
      FROM messages
    SQL

    if connection.adapter_name == "SQLite"
      # Drop old FTS triggers (they reference messages.content_text)
      execute "DROP TRIGGER IF EXISTS messages_au"
      execute "DROP TRIGGER IF EXISTS messages_ad"
      execute "DROP TRIGGER IF EXISTS messages_ai"
    end

    # Remove columns from messages
    remove_column :messages, :content_text
    remove_column :messages, :content_json

    if connection.adapter_name == "SQLite"
      # Recreate FTS table pointing to message_contents as content source
      execute "DROP TABLE IF EXISTS messages_fts"
      execute <<~SQL
        CREATE VIRTUAL TABLE messages_fts USING fts5(
          content_text,
          content='message_contents',
          content_rowid='message_id',
          tokenize='porter unicode61'
        );
      SQL

      # Populate FTS index from message_contents
      execute <<~SQL
        INSERT INTO messages_fts(rowid, content_text)
        SELECT message_id, content_text FROM message_contents;
      SQL

      # Create triggers on message_contents
      execute <<~SQL
        CREATE TRIGGER message_contents_ai AFTER INSERT ON message_contents BEGIN
          INSERT INTO messages_fts(rowid, content_text)
          VALUES (new.message_id, new.content_text);
        END;

        CREATE TRIGGER message_contents_ad AFTER DELETE ON message_contents BEGIN
          INSERT INTO messages_fts(messages_fts, rowid, content_text)
          VALUES ('delete', old.message_id, old.content_text);
        END;

        CREATE TRIGGER message_contents_au AFTER UPDATE ON message_contents BEGIN
          INSERT INTO messages_fts(messages_fts, rowid, content_text)
          VALUES ('delete', old.message_id, old.content_text);
          INSERT INTO messages_fts(rowid, content_text)
          VALUES (new.message_id, new.content_text);
        END;
      SQL
    end
  end

  def down
    if connection.adapter_name == "SQLite"
      execute "DROP TRIGGER IF EXISTS message_contents_au"
      execute "DROP TRIGGER IF EXISTS message_contents_ad"
      execute "DROP TRIGGER IF EXISTS message_contents_ai"
    end

    add_column :messages, :content_text, :text
    add_column :messages, :content_json, :text

    execute <<~SQL
      UPDATE messages SET
        content_text = (SELECT content_text FROM message_contents WHERE message_contents.message_id = messages.id),
        content_json = (SELECT content_json FROM message_contents WHERE message_contents.message_id = messages.id)
    SQL

    if connection.adapter_name == "SQLite"
      # Restore original FTS table and triggers
      execute "DROP TABLE IF EXISTS messages_fts"
      execute <<~SQL
        CREATE VIRTUAL TABLE messages_fts USING fts5(
          content_text,
          content='messages',
          content_rowid='id',
          tokenize='porter unicode61'
        );

        INSERT INTO messages_fts(rowid, content_text)
        SELECT id, content_text FROM messages;
      SQL

      execute <<~SQL
        CREATE TRIGGER messages_ai AFTER INSERT ON messages BEGIN
          INSERT INTO messages_fts(rowid, content_text)
          VALUES (new.id, new.content_text);
        END;

        CREATE TRIGGER messages_ad AFTER DELETE ON messages BEGIN
          INSERT INTO messages_fts(messages_fts, rowid, content_text)
          VALUES ('delete', old.id, old.content_text);
        END;

        CREATE TRIGGER messages_au AFTER UPDATE ON messages BEGIN
          INSERT INTO messages_fts(messages_fts, rowid, content_text)
          VALUES ('delete', old.id, old.content_text);
          INSERT INTO messages_fts(rowid, content_text)
          VALUES (new.id, new.content_text);
        END;
      SQL
    end

    drop_table :message_contents
  end
end
