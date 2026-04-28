module Searchable
  extend ActiveSupport::Concern

  class_methods do
    # Returns Message records ordered as session-title hits first, then
    # content hits. Session hits are surfaced as the first message of the
    # matched session (mirrors the legacy FTS5 layout consumed by views and
    # the CLI). Content hits expose the ts_headline excerpt via
    # `Message#snippet`.
    def search(query, limit: 50, project_id: nil)
      return [] if query.blank?

      session_results = search_by_session_metadata(query, limit: limit, project_id: project_id)
      matched_session_ids = session_results.map(&:session_id).uniq

      content_results = search_by_message_content(query, limit: limit,
        project_id: project_id, exclude_session_ids: matched_session_ids)

      (session_results + content_results).first(limit)
    end

    private

    # Match on session title/custom_title/external_id (indexed via the
    # generated tsvector column) plus associated session_summaries. Returns
    # the first message of each matched session as the carrier record.
    def search_by_session_metadata(query, limit:, project_id: nil)
      sessions = Session.search_metadata(query)
      sessions = sessions.where(project_id: project_id) if project_id

      session_ids = sessions.limit(limit).pluck(:id)
      return [] if session_ids.empty?

      Message
        .includes(:content)
        .where(session_id: session_ids, position: 1)
        .each { |m| m.search_source = "session" }
    end

    # Search the message_contents tsvector column (where pg_search_scope
    # lives), filter by Message-side criteria via a subquery, then map back
    # to Message records — preserving pg_search's rank ordering and copying
    # the ts_headline snippet onto each Message.
    def search_by_message_content(query, limit:, project_id: nil, exclude_session_ids: [])
      message_scope = Message.where.not(role: %w[tool_result system])
      message_scope = message_scope.where.not(session_id: exclude_session_ids) if exclude_session_ids.any?
      message_scope = message_scope.joins(:session).where(sessions: { project_id: project_id }) if project_id

      contents = Message::Content
        .search_full_text(query)
        .with_pg_search_highlight
        .where(message_id: message_scope.select(:id))
        .limit(limit)
        .to_a

      return [] if contents.empty?

      messages = Message
        .where(id: contents.map(&:message_id))
        .includes(:content, :session)
        .index_by(&:id)

      contents.filter_map do |c|
        msg = messages[c.message_id]
        next unless msg
        msg.instance_variable_set(:@snippet, c.pg_search_highlight)
        msg.search_source = "message"
        msg
      end
    end
  end
end
