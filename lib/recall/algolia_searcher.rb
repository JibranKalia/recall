module Recall
  # Experimental Algolia-backed search. Queries the per-message index, groups
  # hits by session (up to MAX_MESSAGES_PER_SESSION per session), and returns
  # results shaped like the FTS5 Searchable concern so the existing search
  # view can render them unchanged: an array of Message-like structs with
  # `session_id`, `content_text`, `content_json`, `role`, `snippet`, and
  # `source`. The view groups by session_id at render time and shows the
  # first 3 matches with an "expand" for the rest.
  class AlgoliaSearcher
    # Cap per-session results so one chatty session can't flood the list. The
    # view shows 3 by default with an "Show N more" expand, so 5 gives the
    # reader 2 extra turns to confirm relevance before expanding fully.
    MAX_MESSAGES_PER_SESSION = 5

    Result = Struct.new(:id, :session_id, :role, :content_text, :content_json, :snippet, :source, keyword_init: true) do
      def respond_to_missing?(name, include_private = false)
        %i[id session_id role content_text content_json snippet source].include?(name) || super
      end
    end

    def self.search(query, limit: 50, project_id: nil)
      return [] if query.blank?
      return [] unless Session.algolia_enabled?

      # Over-fetch so that after capping per session we still fill `limit`.
      # Worst case: every session has MAX_MESSAGES_PER_SESSION matches, so
      # we need `limit` hits; realistically we need more because sessions
      # vary in match count. 4× `limit` covers typical distributions.
      params = {
        hitsPerPage: limit * 4,
        facets: ["session_id"],
        # Algolia caps facet count arrays at 100 values by default; bump so
        # we have per-session counts for every session in the result window.
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

      # Group hits by session, preserving Algolia's relevance order within
      # each group, capped per session.
      hits_per_session = Hash.new { |h, k| h[k] = [] }
      first_index_per_session = {}
      hits.each_with_index do |hit, idx|
        sid = hit.session_id
        first_index_per_session[sid] ||= idx
        bucket = hits_per_session[sid]
        bucket << hit if bucket.size < MAX_MESSAGES_PER_SESSION
      end

      # Rank sessions by facet count desc, breaking ties by Algolia's own
      # order (which already honors custom ranking — session_message_count,
      # then started_at_ts).
      sorted_session_ids = hits_per_session.keys.sort_by do |sid|
        [-session_match_counts.fetch(sid, 0), first_index_per_session[sid]]
      end

      # Flatten session-first, then truncate to overall message limit.
      ordered_hits = sorted_session_ids.flat_map { |sid| hits_per_session[sid] }.first(limit)

      message_ids = ordered_hits.map(&:id)
      messages_by_id = Message.where(id: message_ids).includes(:content).index_by(&:id)

      ordered_hits.filter_map do |hit|
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
