module Searchable
  extend ActiveSupport::Concern

  class_methods do
    def search(query, limit: 50, project_id: nil)
      sanitized = query.gsub('"', '""')

      if project_id
        sql = <<~SQL
          SELECT messages.*, snippet(messages_fts, 0, '<mark>', '</mark>', '...', 48) as snippet
          FROM messages
          JOIN messages_fts ON messages.id = messages_fts.rowid
          JOIN sessions ON sessions.id = messages.session_id
          WHERE messages_fts MATCH ?
            AND sessions.project_id = ?
          ORDER BY messages_fts.rank
          LIMIT ?
        SQL
        find_by_sql([sql, %("#{sanitized}"), project_id, limit])
      else
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
end
