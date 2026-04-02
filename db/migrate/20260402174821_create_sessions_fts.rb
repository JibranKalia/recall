class CreateSessionsFts < ActiveRecord::Migration[8.1]
  def up
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
  end

  def down
    execute "DROP TABLE IF EXISTS sessions_fts"
  end
end
