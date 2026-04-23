class Session < ApplicationRecord
  belongs_to :project, counter_cache: true
  has_many :messages, dependent: :destroy
  has_many :token_usages, through: :messages
  has_many :summaries, dependent: :destroy
  has_many :experiments, dependent: :nullify
  has_one :source, dependent: :destroy

  validates :external_id, presence: true, uniqueness: true

  after_save :sync_fts, if: -> { saved_change_to_title? || saved_change_to_custom_title? || saved_change_to_external_id? }
  after_destroy :remove_from_fts

  # Algolia indexing — only included when the gem is configured (see
  # config/initializers/algoliasearch.rb). auto_index/auto_remove are off;
  # reindexing is batched via the recall:algolia_reindex rake task.
  if defined?(AlgoliaSearch) && AlgoliaSearch::Configuration.class_variable_defined?(:@@configuration)
    include AlgoliaSearch

    algoliasearch index_name: "recall_sessions_#{Rails.env}", auto_index: false, auto_remove: false do
      attribute :display_title
      attribute :project_id
      attribute :project_name do
        project&.display_name
      end
      attribute :source_name do
        source&.source_name
      end
      attribute :summary_body do
        latest_summary&.body.to_s.truncate(2_000)
      end
      attribute :first_user_text do
        messages.where(role: "user").order(:position).limit(1).joins(:content).pick("message_contents.content_text").to_s.truncate(5_000)
      end
      attribute :started_at_ts do
        started_at&.to_i
      end
      searchableAttributes ["display_title", "project_name", "summary_body", "first_user_text"]
      attributesForFaceting ["filterOnly(project_id)"]
      customRanking ["desc(started_at_ts)"]
      attributesToSnippet ["summary_body:40", "first_user_text:40"]
      snippetEllipsisText "..."
      highlightPreTag "<mark>"
      highlightPostTag "</mark>"
    end
  end

  def self.algolia_enabled?
    defined?(AlgoliaSearch) && AlgoliaSearch::Configuration.class_variable_defined?(:@@configuration)
  end

  scope :recent, -> { order(ended_at: :desc) }
  scope :by_source, ->(name) { joins(:source).where(session_sources: { source_name: name }) }
  scope :page, ->(num, per: 30) { limit(per).offset([(num.to_i - 1), 0].max * per) }

  delegate :source_name, :source_type, :source_path, :source_checksum, :source_size, to: :source, allow_nil: true

  def display_title
    latest_summary&.title.presence || custom_title.presence || title.presence&.truncate(120) || "Untitled session"
  end

  def duration
    return nil unless started_at && ended_at
    ended_at - started_at
  end

  def total_tokens
    (total_input_tokens || 0) + (total_output_tokens || 0)
  end

  def estimated_cost
    @estimated_cost ||= if messages.loaded?
      messages.filter_map(&:token_usage).sum { |tu| tu.estimated_cost || 0 }
    else
      token_usages.sum { |tu| tu.estimated_cost || 0 }
    end
  end

  def estimated_cost_formatted
    cost = estimated_cost
    return nil if cost.zero?
    "$#{'%.2f' % cost}"
  end

  def latest_summary
    summaries.order(created_at: :desc).first
  end

  def to_markdown(**options)
    Session::Markdown.new(self).render(**options)
  end

  private

  def sync_fts
    conn = self.class.connection
    unless previously_new_record?
      conn.execute(sanitize_sql(["INSERT INTO sessions_fts(sessions_fts, rowid, title, custom_title, summary, external_id) VALUES ('delete', ?, ?, ?, ?, ?)",
        id, title_before_last_save, custom_title_before_last_save, nil, external_id_before_last_save]))
    end
    conn.execute(sanitize_sql(["INSERT INTO sessions_fts(rowid, title, custom_title, summary, external_id) VALUES (?, ?, ?, ?, ?)",
      id, title, custom_title, latest_summary&.body, external_id]))
  end

  def remove_from_fts
    self.class.connection.execute(sanitize_sql(
      ["INSERT INTO sessions_fts(sessions_fts, rowid, title, custom_title, summary, external_id) VALUES ('delete', ?, ?, ?, ?, ?)",
        id, title, custom_title, latest_summary&.body, external_id]))
  end

  def sanitize_sql(args)
    self.class.sanitize_sql_array(args)
  end
end
