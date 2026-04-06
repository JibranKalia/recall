module Searchable
  extend ActiveSupport::Concern

  class_methods do
    def search(query, limit: 50, project_id: nil)
      return [] if query.blank?

      match = build_match(query)

      # Session title/summary matches are highest quality — surface them first
      session_results = search_sessions(match, limit: limit, project_id: project_id, exclude_session_ids: [])

      # Message content matches, skipping sessions already found above
      matched_session_ids = session_results.map(&:session_id).uniq
      message_results = search_messages(match, limit: limit, project_id: project_id, exclude_session_ids: matched_session_ids)

      (session_results + message_results).first(limit)
    end

    private

    # AND of individual stemmed tokens for multi-word queries.
    # Matches documents containing all terms anywhere (vs exact phrase), improving
    # recall for queries like "enrichment data modeling" matching "data model enrichment".
    def build_match(query)
      tokens = query.split.map { |t| t.gsub('"', '""') }.reject(&:blank?)
      return '""' if tokens.empty?
      tokens.map { |t| "\"#{t}\"" }.join(" ")
    end

    # Excludes tool_result and system messages — they're file listings / command
    # output that match on incidental term occurrences, not meaningful content.
    def search_messages(match, limit:, project_id: nil, exclude_session_ids: [])
      exclude_clause = if exclude_session_ids.any?
        "AND messages.session_id NOT IN (#{exclude_session_ids.map(&:to_i).join(',')})"
      else
        ""
      end

      if project_id
        sql = <<~SQL
          SELECT messages.*, mc.content_text, mc.content_json,
                 snippet(messages_fts, 0, '<mark>', '</mark>', '...', 48) as snippet,
                 'message' as source
          FROM messages
          JOIN message_contents mc ON mc.message_id = messages.id
          JOIN messages_fts ON messages.id = messages_fts.rowid
          JOIN sessions ON sessions.id = messages.session_id
          WHERE messages_fts MATCH ?
            AND sessions.project_id = ?
            AND messages.role NOT IN ('tool_result', 'system')
            #{exclude_clause}
          ORDER BY messages_fts.rank
          LIMIT ?
        SQL
        find_by_sql([sql, match, project_id, limit])
      else
        sql = <<~SQL
          SELECT messages.*, mc.content_text, mc.content_json,
                 snippet(messages_fts, 0, '<mark>', '</mark>', '...', 48) as snippet,
                 'message' as source
          FROM messages
          JOIN message_contents mc ON mc.message_id = messages.id
          JOIN messages_fts ON messages.id = messages_fts.rowid
          WHERE messages_fts MATCH ?
            AND messages.role NOT IN ('tool_result', 'system')
            #{exclude_clause}
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
          SELECT messages.*, mc.content_text, mc.content_json,
                 NULL as snippet, 'session' as source
          FROM sessions_fts
          JOIN sessions ON sessions.id = sessions_fts.rowid
          JOIN messages ON messages.session_id = sessions.id AND messages.position = 1
          JOIN message_contents mc ON mc.message_id = messages.id
          WHERE sessions_fts MATCH ?
            AND sessions.project_id = ?
            #{exclude_clause}
          ORDER BY sessions_fts.rank
          LIMIT ?
        SQL
        find_by_sql([sql, match, project_id, limit])
      else
        sql = <<~SQL
          SELECT messages.*, mc.content_text, mc.content_json,
                 NULL as snippet, 'session' as source
          FROM sessions_fts
          JOIN sessions ON sessions.id = sessions_fts.rowid
          JOIN messages ON messages.session_id = sessions.id AND messages.position = 1
          JOIN message_contents mc ON mc.message_id = messages.id
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
