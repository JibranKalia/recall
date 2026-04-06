require "open3"

class LLM::Providers::ClaudeCode < LLM::Provider
  DEFAULT_MODEL = "claude-sonnet-4-20250514"

  attr_reader :model

  def initialize(model: DEFAULT_MODEL)
    @model = model
  end

  def name
    "claude_code"
  end

  def complete(prompt, system: nil, **)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    full_prompt = system ? "#{system}\n\n#{prompt}" : prompt

    cmd = [ "claude", "-p", "--model", @model, "--output-format", "json" ]
    stdout, stderr, status = Open3.capture3(*cmd, stdin_data: full_prompt)

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

    unless status.success?
      raise "claude -p failed (exit #{status.exitstatus}): #{stderr}"
    end

    parsed = JSON.parse(stdout)

    Result.new(
      output: parsed["result"].to_s.strip,
      tokens_in: parsed.dig("usage", "input_tokens") || 0,
      tokens_out: parsed.dig("usage", "output_tokens") || 0,
      model: @model,
      duration_ms: duration_ms
    )
  end
end
