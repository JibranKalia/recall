class Project < ApplicationRecord
  DOMAINS = %w[work velopro personal].freeze

  has_many :sessions, dependent: :destroy

  validates :name, presence: true
  validates :path, presence: true, uniqueness: true
  validates :domain, presence: true, inclusion: { in: DOMAINS }

  scope :recent, -> { order(updated_at: :desc) }
  scope :by_domain, ->(domain) { where(domain: domain) }

  before_validation :infer_domain, if: -> { domain.blank? || domain == "personal" }

  def source_types
    Session::Source.where(session_id: session_ids).distinct.pluck(:source_type)
  end

  def display_name
    name.presence || File.basename(path)
  end

  def self.domain_for_path(path)
    case path
    when %r{/work/}
      "work"
    when %r{/side/velo/}
      "velopro"
    else
      "personal"
    end
  end

  private

  def infer_domain
    self.domain = self.class.domain_for_path(path) if path.present?
  end
end
