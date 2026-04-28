class Session < ApplicationRecord
  include PgSearch::Model

  belongs_to :project, counter_cache: true
  has_many :messages, dependent: :destroy
  has_many :token_usages, through: :messages
  has_many :summaries, dependent: :destroy
  has_many :experiments, dependent: :nullify
  has_one :source, dependent: :destroy

  validates :external_id, presence: true, uniqueness: true

  pg_search_scope :search_metadata,
    against: [:title, :custom_title, :external_id],
    associated_against: { summaries: [:body, :title] },
    using: {
      tsearch: {
        dictionary: "english",
        tsvector_column: "tsv"
      }
    }

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
end
