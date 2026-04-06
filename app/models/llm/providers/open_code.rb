require "open3"

class LLM::Providers::OpenCode < LLM::Provider
  DEFAULT_MODEL = "kimi-k2"

  attr_reader :model

  def initialize(model: DEFAULT_MODEL)
    @model = model
  end

  def name
    "opencode"
  end

  def complete(prompt, system: nil, **)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    full_prompt = system ? "#{system}\n\n#{prompt}" : prompt

    stdout, stderr, status = Open3.capture3("opencode", "-p", full_prompt)

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

    unless status.success?
      raise "opencode failed (exit #{status.exitstatus}): #{stderr}"
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
