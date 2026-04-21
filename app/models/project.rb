class Project < ApplicationRecord
  has_many :sessions, dependent: :destroy

  validates :name, presence: true
  validates :path, presence: true, uniqueness: true
  validates :domain, presence: true, inclusion: { in: ->(_) { Project.domains } }

  scope :recent, -> { order(updated_at: :desc) }
  scope :by_domain, ->(domain) { where(domain: domain) }

  before_validation :infer_domain, if: -> { domain.blank? || domain == Recall::Config.default_domain }

  def self.domains
    Recall::Config.domains
  end

  def self.default_domain
    Recall::Config.default_domain
  end

  def self.domain_for_path(path)
    Recall::Config.domain_for_path(path)
  end

  def source_types
    Session::Source.where(session_id: session_ids).distinct.pluck(:source_type)
  end

  def display_name
    name.presence || File.basename(path)
  end

  private

  def infer_domain
    self.domain = self.class.domain_for_path(path) if path.present?
  end
end
