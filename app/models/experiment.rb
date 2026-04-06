class Experiment < ApplicationRecord
  belongs_to :session
  has_many :runs, class_name: "Experiment::Run", dependent: :destroy
  validates :name, :prompt_text, presence: true
  validates :status, inclusion: { in: %w[pending running completed failed] }

  scope :recent, -> { order(created_at: :desc) }

  # Synchronous single-prompt call. Creates Experiment + Run, executes inline, returns the Run.
  def self.complete!(name, prompt:, provider_key: "ollama:qwen3:8b", system: nil, session: nil)
    experiment = create!(
      name: name,
      prompt_text: prompt,
      system_prompt: system,
      session: session,
      status: "running"
    )

    provider = LLM.provider(provider_key)
    run = experiment.runs.create!(provider_key: provider_key, model: provider.model, status: "pending")
    run.execute!
  end

  def completed?
    status == "completed"
  end

  def total_cost
    runs.sum(:estimated_cost)
  end

  def fastest_run
    runs.completed.order(:duration_ms).first
  end

  def cheapest_run
    runs.completed.order(:estimated_cost).first
  end

  def check_completion!
    return unless runs.where(status: %w[pending running]).none?

    update!(status: runs.failed.any? && runs.completed.none? ? "failed" : "completed")
  end
end
