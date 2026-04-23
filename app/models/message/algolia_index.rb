# Algolia indexing configuration for Message.
#
# One record per indexable message. Sessions are reconstructed at search
# time by Recall::AlgoliaSearcher, which dedupes hits down to one per
# session and re-ranks by per-session facet counts. See comments below and
# `lib/recall/algolia_searcher.rb` for how ranking ties together.
module Message::AlgoliaIndex
  extend ActiveSupport::Concern

  included do
    # The gem's `.configuration` getter raises NameError before the
    # initializer has set credentials. Guard by checking the class variable
    # directly so models load cleanly in envs with no Algolia env vars
    # (CI, fresh clones).
    if defined?(AlgoliaSearch) && AlgoliaSearch::Configuration.class_variable_defined?(:@@configuration)
      include AlgoliaSearch

      # auto_index/auto_remove OFF: writes don't hit Algolia on save/destroy.
      # Reindexing is a batched offline job (`bin/rails recall:algolia_reindex`).
      # `if: :algolia_indexable?` filters non-indexable rows server-side
      # during iteration — the gem calls the predicate on each record and
      # skips ones that return false, so we don't have to scope the query.
      algoliasearch index_name: "recall_messages_#{Rails.env}",
                    auto_index: false,
                    auto_remove: false,
                    if: :algolia_indexable? do
        # --- Record identity / grouping -------------------------------------
        # session_id: used at search time to dedupe hits to one-per-session
        # and (via faceting below) to count matching messages per session.
        attribute :session_id
        # role + position preserved so we can display the right badge and
        # link deep into the session at the matched turn.
        attribute :role
        attribute :position

        # --- Matchable text --------------------------------------------------
        # content_text is the only large field and the main matchable surface.
        attribute :content_text do
          # Algolia Build plan caps each record at 10KB of *JSON*, not raw
          # UTF-8. JSON escaping of quotes, newlines, backslashes inflates
          # content ~30% on average and worse for code-heavy prose. 6000
          # bytes of content leaves comfortable headroom for the JSON
          # overhead + sibling attrs. ~2.7% of indexable messages exceed
          # this and get truncated.
          content&.content_text.to_s.truncate_bytes(6_000)
        end
        # display_title is per-message for denormalization: it lets title
        # matches surface the right session even for messages whose own
        # content_text doesn't contain the query (see searchableAttributes).
        attribute :display_title do
          session&.display_title
        end

        # --- Filter / facet fields ------------------------------------------
        # project_id powers the per-project scoped search on /projects/:id
        # (passed as `filters: "project_id:N"`).
        attribute :project_id do
          session&.project_id
        end
        # source_name: filterable if we later want per-source (claude_code,
        # codex, etc.) searches. Not used yet — cheap to carry.
        attribute :source_name do
          session&.source&.source_name
        end

        # --- Custom-ranking signals -----------------------------------------
        # started_at_ts is the recency tiebreaker. Epoch seconds so Algolia
        # can sort numerically.
        attribute :started_at_ts do
          session&.started_at&.to_i
        end
        # session_message_count is a query-independent proxy for session
        # "importance" — a 200-message investigation deserves to outrank a
        # 4-message daily-log entry that happens to mention the query term
        # once. messages_count is a counter_cache column on sessions so this
        # is O(1); no N+1.
        attribute :session_message_count do
          session&.messages_count.to_i
        end

        # --- Index settings --------------------------------------------------
        # searchableAttributes order = priority. Title first so a session
        # titled "Investigating BPO Delegation" outranks a daily log that
        # mentions those words in passing in its content. content_text is
        # still searchable, just ranked below title matches on the
        # "attribute" criterion.
        searchableAttributes ["display_title", "content_text"]
        # filterOnly(project_id): we filter by project but never request
        # facet counts on it, so cheaper mode.
        # session_id: full faceting — Recall::AlgoliaSearcher requests
        # `facets: ["session_id"]` and uses the returned per-session match
        # counts to re-rank deduped results (more matches = more relevant
        # session).
        attributesForFaceting ["filterOnly(project_id)", "session_id"]
        # Applied AFTER Algolia's 7 default tie-breaking criteria (typo,
        # words, proximity, attribute, exact, …). session_message_count is
        # first so that when two messages tie on textual relevance the one
        # from the bigger session wins; started_at_ts breaks remaining ties
        # toward newer activity.
        customRanking ["desc(session_message_count)", "desc(started_at_ts)"]

        # --- Highlight / snippet --------------------------------------------
        # Snippet window: 40 words around matches in content_text.
        attributesToSnippet ["content_text:40"]
        snippetEllipsisText "..."
        # <mark> tags are whitelisted by the view's `sanitize` call, so they
        # render without escaping; other HTML in content_text is stripped.
        highlightPreTag "<mark>"
        highlightPostTag "</mark>"
      end
    end
  end

  # Gate for which messages go into the index. Mirrors the FTS5 Searchable
  # concern's role filter — tool_result and system messages are command
  # output / file listings that match on incidental terms and flood results.
  # Assistant tool-invocation placeholders like "[Tool: Bash]" are similar
  # noise. Also skip records with empty content since there's nothing to
  # match.
  def algolia_indexable?
    return false unless %w[user assistant].include?(role)
    return false if tool_only?
    content&.content_text.present?
  end
end
