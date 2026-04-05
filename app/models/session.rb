class Session < ApplicationRecord
  belongs_to :project, counter_cache: true
  has_many :messages, dependent: :destroy
  has_many :token_usages, through: :messages
  has_many :summaries, dependent: :destroy
  has_one :source, dependent: :destroy

  validates :external_id, presence: true, uniqueness: true

  after_save :sync_fts, if: -> { saved_change_to_title? || saved_change_to_custom_title? }
  after_destroy :remove_from_fts

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
    token_usages.sum { |tu| tu.estimated_cost || 0 }
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
    conn.execute(sanitize_sql(["INSERT INTO sessions_fts(sessions_fts, rowid, title, custom_title, summary) VALUES ('delete', ?, ?, ?, ?)",
      id, title_before_last_save, custom_title_before_last_save, nil]))
    conn.execute(sanitize_sql(["INSERT INTO sessions_fts(rowid, title, custom_title, summary) VALUES (?, ?, ?, ?)",
      id, title, custom_title, latest_summary&.body]))
  end

  def remove_from_fts
    self.class.connection.execute(sanitize_sql(
      ["INSERT INTO sessions_fts(sessions_fts, rowid, title, custom_title, summary) VALUES ('delete', ?, ?, ?, ?)",
        id, title, custom_title, latest_summary&.body]))
  end

  def sanitize_sql(args)
    self.class.sanitize_sql_array(args)
  end
end
