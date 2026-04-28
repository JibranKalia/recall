class AddPostgresFullTextSearch < ActiveRecord::Migration[8.1]
  def up
    return unless connection.adapter_name == "PostgreSQL"

    execute <<~SQL
      ALTER TABLE message_contents
        ADD COLUMN tsv tsvector
        GENERATED ALWAYS AS (to_tsvector('english', coalesce(content_text, ''))) STORED;
    SQL
    execute "CREATE INDEX index_message_contents_on_tsv ON message_contents USING GIN (tsv);"

    execute <<~SQL
      ALTER TABLE sessions
        ADD COLUMN tsv tsvector
        GENERATED ALWAYS AS (
          to_tsvector('english',
            coalesce(title, '') || ' ' ||
            coalesce(custom_title, '') || ' ' ||
            coalesce(external_id, '')
          )
        ) STORED;
    SQL
    execute "CREATE INDEX index_sessions_on_tsv ON sessions USING GIN (tsv);"
  end

  def down
    return unless connection.adapter_name == "PostgreSQL"

    execute "DROP INDEX IF EXISTS index_sessions_on_tsv;"
    execute "ALTER TABLE sessions DROP COLUMN IF EXISTS tsv;"
    execute "DROP INDEX IF EXISTS index_message_contents_on_tsv;"
    execute "ALTER TABLE message_contents DROP COLUMN IF EXISTS tsv;"
  end
end
