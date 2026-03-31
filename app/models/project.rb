class Project < ApplicationRecord
  has_many :sessions, dependent: :destroy

  validates :name, presence: true
  validates :path, presence: true
  validates :source_type, presence: true, inclusion: { in: %w[claude_code codex] }
  validates :path, uniqueness: { scope: :source_type }

  scope :by_source, ->(source_type) { where(source_type: source_type) }
  scope :recent, -> { order(updated_at: :desc) }

  def display_name
    name.presence || File.basename(path)
  end
end
