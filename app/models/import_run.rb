class ImportRun < ApplicationRecord
  STATUSES = %w[running completed failed].freeze

  scope :completed, -> { where(status: "completed") }

  def self.last_completed_at
    completed.order(completed_at: :desc).pick(:completed_at)
  end

  # A run is considered stale (not really running) if it started >10 minutes ago
  # without completing — handles crashed processes.
  def self.any_running?
    where(status: "running").where("started_at > ?", 10.minutes.ago).exists?
  end

  def complete!
    update!(status: "completed", completed_at: Time.current)
  end

  def fail!
    update!(status: "failed", completed_at: Time.current)
  end
end
