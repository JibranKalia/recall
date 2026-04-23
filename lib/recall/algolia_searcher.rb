module Recall
  # Experimental Algolia-backed search. Queries the per-message index, dedupes
  # to one top-ranked hit per session, and returns results shaped like the
  # FTS5 Searchable concern so the existing search view can render them
  # unchanged: an array of Message-like structs with `session_id`,
  # `content_text`, `content_json`, `role`, `snippet`, and `source`.
  class AlgoliaSearcher
    Result = Struct.new(:id, :session_id, :role, :content_text, :content_json, :snippet, :source, keyword_init: true) do
      def respond_to_missing?(name, include_private = false)
        %i[id session_id role content_text content_json snippet source].include?(name) || super
      end
    end

    def self.search(query, limit: 50, project_id: nil)
      return [] if query.blank?
      return [] unless Session.algolia_enabled?

      # Over-fetch so we have enough unique sessions after session-level dedup.
      params = { hitsPerPage: limit * 4 }
      params[:filters] = "project_id:#{project_id.to_i}" if project_id

      hits = Message.algolia_search(query, params).to_a
      return [] if hits.empty?

      best_hit_per_session = {}
      hits.each do |hit|
        best_hit_per_session[hit.session_id] ||= hit
        break if best_hit_per_session.size >= limit
      end

      message_ids = best_hit_per_session.values.map(&:id)
      messages_by_id = Message.where(id: message_ids).includes(:content).index_by(&:id)

      best_hit_per_session.values.filter_map do |hit|
        message = messages_by_id[hit.id]
        next unless message

        Result.new(
          id: message.id,
          session_id: message.session_id,
          role: message.role,
          content_text: message.content_text,
          content_json: message.content_json,
          snippet: extract_highlight(hit),
          source: "algolia"
        )
      end
    end

    def self.extract_highlight(hit)
      snip = hit.try(:snippet_result)
      if snip.is_a?(Hash)
        node = snip[:content_text] || snip["content_text"]
        if node.is_a?(Hash)
          value = (node[:value] || node["value"]).to_s
          return value if value.include?("<mark>")
        end
      end

      highlight = hit.try(:highlight_result)
      return nil unless highlight.is_a?(Hash)
      %i[content_text display_title].each do |attr|
        node = highlight[attr] || highlight[attr.to_s]
        next unless node.is_a?(Hash)
        value = (node[:value] || node["value"]).to_s
        return value if value.include?("<mark>")
      end
      nil
    end
  end
end
