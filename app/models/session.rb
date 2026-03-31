class Session < ApplicationRecord
  belongs_to :project, counter_cache: true
  has_many :messages, dependent: :destroy

  validates :external_id, presence: true, uniqueness: { scope: :source_type }
  validates :source_name, presence: true
  validates :source_type, presence: true
  validates :source_path, presence: true
  validates :source_checksum, presence: true
  validates :source_size, presence: true

  scope :recent, -> { order(started_at: :desc) }
  scope :by_source, ->(name) { where(source_name: name) }

  def display_title
    title.presence&.truncate(120) || "Untitled session"
  end

  def duration
    return nil unless started_at && ended_at
    ended_at - started_at
  end

  def total_tokens
    (total_input_tokens || 0) + (total_output_tokens || 0)
  end
end
