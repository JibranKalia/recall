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
      params = {
        hitsPerPage: limit * 4,
        facets: ["session_id"],
        # Algolia caps facet count arrays at 100 values by default; bump so
        # we have per-session counts for everything in the result window.
        maxValuesPerFacet: 1_000
      }
      params[:filters] = "project_id:#{project_id.to_i}" if project_id

      response = Message.algolia_search(query, params)
      hits = response.to_a
      return [] if hits.empty?

      # Counts of matching messages per session — our group-level signal.
      # Algolia returns facet keys as strings; normalize to integer.
      facets = response.algolia_facets || {}
      session_match_counts = (facets["session_id"] || facets[:session_id] || {})
        .each_with_object({}) { |(sid, count), acc| acc[sid.to_i] = count.to_i }

      # Dedupe to one hit per session — Algolia returns hits in its own
      # relevance order, so the first we see is the best match for that session.
      best_hit_per_session = {}
      hits.each do |hit|
        best_hit_per_session[hit.session_id] ||= hit
      end

      # Re-rank sessions by match count (desc), preserving Algolia's per-record
      # order within the same count.
      sorted_session_ids = best_hit_per_session.keys.sort_by.with_index do |sid, idx|
        [-session_match_counts.fetch(sid, 0), idx]
      end.first(limit)

      message_ids = sorted_session_ids.map { |sid| best_hit_per_session[sid].id }
      messages_by_id = Message.where(id: message_ids).includes(:content).index_by(&:id)

      sorted_session_ids.filter_map do |sid|
        hit = best_hit_per_session[sid]
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
