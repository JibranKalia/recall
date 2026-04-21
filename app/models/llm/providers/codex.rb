require "open3"

class LLM::Providers::Codex < LLM::Provider
  attr_reader :model

  def initialize(model: Recall::Config.codex_default_model)
    @model = model
  end

  def name
    "codex"
  end

  def complete(prompt, system: nil, **)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    full_prompt = system ? "#{system}\n\n#{prompt}" : prompt

    stdout, stderr, status = Open3.capture3("codex", "-q", full_prompt)

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

    unless status.success?
      raise "codex failed (exit #{status.exitstatus}): #{stderr}"
    end

    Result.new(
      output: stdout.strip,
      tokens_in: 0,
      tokens_out: 0,
      model: @model,
      duration_ms: duration_ms
    )
  end
end
