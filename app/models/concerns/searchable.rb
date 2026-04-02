module Searchable
  extend ActiveSupport::Concern

  class_methods do
    def search(query, limit: 50, project_id: nil)
      sanitized = query.gsub('"', '""')
      match = %("#{sanitized}")

      # Search message content
      message_results = search_messages(match, limit: limit, project_id: project_id)

      # Search session titles/summaries for sessions not already matched
      matched_session_ids = message_results.map(&:session_id).uniq
      session_results = search_sessions(match, limit: limit, project_id: project_id, exclude_session_ids: matched_session_ids)

      (message_results + session_results).first(limit)
    end

    private

    def search_messages(match, limit:, project_id: nil)
      if project_id
        sql = <<~SQL
          SELECT messages.*, snippet(messages_fts, 0, '<mark>', '</mark>', '...', 48) as snippet,
                 'message' as source
          FROM messages
          JOIN messages_fts ON messages.id = messages_fts.rowid
          JOIN sessions ON sessions.id = messages.session_id
          WHERE messages_fts MATCH ?
            AND sessions.project_id = ?
          ORDER BY messages_fts.rank
          LIMIT ?
        SQL
        find_by_sql([sql, match, project_id, limit])
      else
        sql = <<~SQL
          SELECT messages.*, snippet(messages_fts, 0, '<mark>', '</mark>', '...', 48) as snippet,
                 'message' as source
          FROM messages
          JOIN messages_fts ON messages.id = messages_fts.rowid
          WHERE messages_fts MATCH ?
          ORDER BY messages_fts.rank
          LIMIT ?
        SQL
        find_by_sql([sql, match, limit])
      end
    end

    def search_sessions(match, limit:, project_id: nil, exclude_session_ids: [])
      exclude_clause = if exclude_session_ids.any?
        "AND sessions.id NOT IN (#{exclude_session_ids.map(&:to_i).join(',')})"
      else
        ""
      end

      if project_id
        sql = <<~SQL
          SELECT messages.*, NULL as snippet, 'session' as source
          FROM sessions_fts
          JOIN sessions ON sessions.id = sessions_fts.rowid
          JOIN messages ON messages.session_id = sessions.id AND messages.position = 1
          WHERE sessions_fts MATCH ?
            AND sessions.project_id = ?
            #{exclude_clause}
          ORDER BY sessions_fts.rank
          LIMIT ?
        SQL
        find_by_sql([sql, match, project_id, limit])
      else
        sql = <<~SQL
          SELECT messages.*, NULL as snippet, 'session' as source
          FROM sessions_fts
          JOIN sessions ON sessions.id = sessions_fts.rowid
          JOIN messages ON messages.session_id = sessions.id AND messages.position = 1
          WHERE sessions_fts MATCH ?
            #{exclude_clause}
          ORDER BY sessions_fts.rank
          LIMIT ?
        SQL
        find_by_sql([sql, match, limit])
      end
    end
  end
end
