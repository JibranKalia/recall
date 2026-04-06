class Experiment::Run < ApplicationRecord
  self.table_name = "experiment_runs"

  belongs_to :experiment

  validates :provider_key, :model, presence: true
  validates :status, inclusion: { in: %w[pending running completed failed] }

  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :pending, -> { where(status: "pending") }

  def execute!
    update!(status: "running")

    provider = LLM.provider(provider_key)
    result = provider.complete(experiment.prompt_text, system: experiment.system_prompt)

    update!(
      status: "completed",
      response_text: result.output,
      tokens_in: result.tokens_in,
      tokens_out: result.tokens_out,
      estimated_cost: result.cost,
      duration_ms: result.duration_ms,
      model: result.model
    )

    experiment.check_completion!
    self
  rescue => e
    update!(status: "failed", error_message: "#{e.class}: #{e.message}")
    experiment.check_completion!
    raise
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def cost_formatted
    return nil unless estimated_cost && estimated_cost > 0
    "$#{'%.4f' % estimated_cost}"
  end

  def duration_formatted
    return nil unless duration_ms
    if duration_ms > 60_000
      "#{'%.1f' % (duration_ms / 60_000.0)}m"
    elsif duration_ms > 1_000
      "#{'%.1f' % (duration_ms / 1_000.0)}s"
    else
      "#{duration_ms}ms"
    end
  end

  def provider_display_name
    "#{provider_key} (#{model})"
  end
end
