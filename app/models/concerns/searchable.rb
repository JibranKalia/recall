module Searchable
  extend ActiveSupport::Concern

  class_methods do
    def search(query, limit: 50)
      sanitized = query.gsub('"', '""')
      sql = <<~SQL
        SELECT messages.*, snippet(messages_fts, 0, '<mark>', '</mark>', '...', 48) as snippet
        FROM messages
        JOIN messages_fts ON messages.id = messages_fts.rowid
        WHERE messages_fts MATCH ?
        ORDER BY messages_fts.rank
        LIMIT ?
      SQL
      find_by_sql([sql, %("#{sanitized}"), limit])
    end
  end
end
