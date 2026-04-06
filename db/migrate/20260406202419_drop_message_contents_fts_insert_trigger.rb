class DropMessageContentsFtsInsertTrigger < ActiveRecord::Migration[8.1]
  def up
    execute "DROP TRIGGER IF EXISTS message_contents_ai"
    execute "DROP TRIGGER IF EXISTS message_contents_au"
    execute "DROP TRIGGER IF EXISTS message_contents_ad"
  end

  def down
    execute <<~SQL
      CREATE TRIGGER message_contents_ai AFTER INSERT ON message_contents BEGIN
        INSERT INTO messages_fts(rowid, content_text)
        VALUES (new.message_id, new.content_text);
      END;
    SQL

    execute <<~SQL
      CREATE TRIGGER message_contents_ad AFTER DELETE ON message_contents BEGIN
        INSERT INTO messages_fts(messages_fts, rowid, content_text)
        VALUES ('delete', old.message_id, old.content_text);
      END;
    SQL

    execute <<~SQL
      CREATE TRIGGER message_contents_au AFTER UPDATE ON message_contents BEGIN
        INSERT INTO messages_fts(messages_fts, rowid, content_text)
        VALUES ('delete', old.message_id, old.content_text);
        INSERT INTO messages_fts(rowid, content_text)
        VALUES (new.message_id, new.content_text);
      END;
    SQL
  end
end
