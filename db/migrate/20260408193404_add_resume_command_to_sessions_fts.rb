class AddResumeCommandToSessionsFts < ActiveRecord::Migration[8.1]
  def up
    return unless connection.adapter_name == "SQLite"

    execute "DROP TABLE IF EXISTS sessions_fts"
    execute <<~SQL
      CREATE VIRTUAL TABLE sessions_fts USING fts5(
        title,
        custom_title,
        summary,
        external_id,
        content='sessions',
        content_rowid='id',
        tokenize='porter unicode61'
      );
    SQL
    execute "INSERT INTO sessions_fts(sessions_fts) VALUES('rebuild')"
  end

  def down
    return unless connection.adapter_name == "SQLite"

    execute "DROP TABLE IF EXISTS sessions_fts"
    execute <<~SQL
      CREATE VIRTUAL TABLE sessions_fts USING fts5(
        title,
        custom_title,
        summary,
        content='sessions',
        content_rowid='id',
        tokenize='porter unicode61'
      );
    SQL
    execute "INSERT INTO sessions_fts(sessions_fts) VALUES('rebuild')"
  end
end
