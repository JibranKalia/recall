module Recall
  # Experimental Algolia-backed search. Returns results shaped like the FTS5
  # Searchable concern so the existing search view can render them unchanged:
  # an array of Message-like structs with `session_id`, `content_text`,
  # `content_json`, `role`, `snippet`, and `source` attributes.
  class AlgoliaSearcher
    Result = Struct.new(:id, :session_id, :role, :content_text, :content_json, :snippet, :source, keyword_init: true) do
      def respond_to_missing?(name, include_private = false)
        %i[id session_id role content_text content_json snippet source].include?(name) || super
      end
    end

    def self.search(query, limit: 50, project_id: nil)
      return [] if query.blank?
      return [] unless Session.algolia_enabled?

      params = { hitsPerPage: limit }
      params[:filters] = "project_id:#{project_id.to_i}" if project_id

      hits = Session.algolia_search(query, params).to_a
      return [] if hits.empty?

      session_ids = hits.map(&:id)
      sessions_by_id = Session.where(id: session_ids).index_by(&:id)
      first_messages_by_session = Message
        .where(session_id: session_ids)
        .where(role: %w[user assistant])
        .includes(:content)
        .group_by(&:session_id)
        .transform_values { |ms| ms.min_by(&:position) }

      hits.filter_map do |session|
        first_message = first_messages_by_session[session.id]
        next unless first_message

        highlight = extract_highlight(session)

        Result.new(
          id: first_message.id,
          session_id: session.id,
          role: first_message.role,
          content_text: first_message.content_text,
          content_json: first_message.content_json,
          snippet: highlight,
          source: "algolia"
        )
      end
    end

    def self.extract_highlight(session)
      meta = session.try(:highlight_result)
      return nil unless meta.is_a?(Hash)

      %i[summary_body first_user_text display_title].each do |attr|
        node = meta[attr] || meta[attr.to_s]
        next unless node.is_a?(Hash)
        value = (node[:value] || node["value"]).to_s
        return value if value.include?("<mark>")
      end
      nil
    end
  end
end
