module Message::AlgoliaIndex
  extend ActiveSupport::Concern

  included do
    # Only wire the gem up when the initializer has configured credentials —
    # otherwise the gem's `.configuration` getter raises on first access.
    if defined?(AlgoliaSearch) && AlgoliaSearch::Configuration.class_variable_defined?(:@@configuration)
      include AlgoliaSearch

      algoliasearch index_name: "recall_messages_#{Rails.env}",
                    auto_index: false,
                    auto_remove: false,
                    if: :algolia_indexable? do
        attribute :session_id
        attribute :role
        attribute :position
        attribute :content_text do
          # Algolia Build plan caps each record at 10KB of *JSON*, not raw UTF-8.
          # JSON escaping of quotes, newlines, backslashes inflates content ~30%
          # on average and worse for code-heavy prose. 6000 bytes of content
          # leaves comfortable headroom for the JSON overhead + sibling attrs.
          content&.content_text.to_s.truncate_bytes(6_000)
        end
        attribute :project_id do
          session&.project_id
        end
        attribute :display_title do
          session&.display_title
        end
        attribute :source_name do
          session&.source&.source_name
        end
        attribute :started_at_ts do
          session&.started_at&.to_i
        end
        searchableAttributes ["content_text", "display_title"]
        attributesForFaceting ["filterOnly(project_id)", "filterOnly(session_id)"]
        customRanking ["desc(started_at_ts)"]
        attributesToSnippet ["content_text:40"]
        snippetEllipsisText "..."
        highlightPreTag "<mark>"
        highlightPostTag "</mark>"
      end
    end
  end

  # Indexes only meaningful conversation turns: real user/assistant prose.
  # tool_result and system roles are excluded (same rationale as FTS5 — file
  # listings / command output match on incidental terms), as are assistant
  # tool-invocation placeholders like "[Tool: Bash]".
  def algolia_indexable?
    return false unless %w[user assistant].include?(role)
    return false if tool_only?
    content&.content_text.present?
  end
end
