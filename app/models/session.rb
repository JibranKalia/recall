class Session < ApplicationRecord
  belongs_to :project, counter_cache: true
  has_many :messages, dependent: :destroy

  validates :external_id, presence: true, uniqueness: { scope: :source_type }
  validates :source_name, presence: true
  validates :source_type, presence: true
  validates :source_path, presence: true
  validates :source_checksum, presence: true
  validates :source_size, presence: true

  after_save :sync_fts, if: -> { saved_change_to_title? || saved_change_to_custom_title? || saved_change_to_summary? }
  after_destroy :remove_from_fts

  scope :recent, -> { order(ended_at: :desc) }
  scope :by_source, ->(name) { where(source_name: name) }
  scope :page, ->(num, per: 30) { limit(per).offset([(num.to_i - 1), 0].max * per) }

  def display_title
    custom_title.presence || title.presence&.truncate(120) || "Untitled session"
  end

  def duration
    return nil unless started_at && ended_at
    ended_at - started_at
  end

  def total_tokens
    (total_input_tokens || 0) + (total_output_tokens || 0)
  end

  private

  def sync_fts
    conn = self.class.connection
    conn.execute(sanitize_sql(["INSERT INTO sessions_fts(sessions_fts, rowid, title, custom_title, summary) VALUES ('delete', ?, ?, ?, ?)",
      id, title_before_last_save, custom_title_before_last_save, summary_before_last_save]))
    conn.execute(sanitize_sql(["INSERT INTO sessions_fts(rowid, title, custom_title, summary) VALUES (?, ?, ?, ?)",
      id, title, custom_title, summary]))
  end

  def remove_from_fts
    self.class.connection.execute(sanitize_sql(
      ["INSERT INTO sessions_fts(sessions_fts, rowid, title, custom_title, summary) VALUES ('delete', ?, ?, ?, ?)",
        id, title, custom_title, summary]))
  end

  def sanitize_sql(args)
    self.class.sanitize_sql_array(args)
  end
end
