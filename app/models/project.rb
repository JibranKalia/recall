class Project < ApplicationRecord
  has_many :sessions, dependent: :destroy

  validates :name, presence: true
  validates :path, presence: true, uniqueness: true
  scope :recent, -> { order(updated_at: :desc) }

  def source_types
    Session::Source.where(session_id: session_ids).distinct.pluck(:source_type)
  end

  def display_name
    name.presence || File.basename(path)
  end
end
