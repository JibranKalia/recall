require "open3"

class LLM::Providers::ClaudeCode < LLM::Provider
  attr_reader :model

  def initialize(model: Recall::Config.claude_code_default_model)
    @model = model
  end

  def name
    "claude_code"
  end

  def complete(prompt, system: nil, **)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    full_prompt = system ? "#{system}\n\n#{prompt}" : prompt

    cmd = [ Recall::Config.claude_code_command, "-p", "--model", @model, "--output-format", "json", "--no-session-persistence" ]
    stdout, stderr, status = Open3.capture3(*cmd, stdin_data: full_prompt)

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

    unless status.success?
      raise "claude -p failed (exit #{status.exitstatus}): #{stderr}"
    end

    parsed = JSON.parse(stdout)

    # Output is a JSON array; the result summary is the last element with type "result"
    result_entry = parsed.is_a?(Array) ? parsed.find { |e| e["type"] == "result" } : parsed

    Result.new(
      output: result_entry["result"].to_s.strip,
      tokens_in: result_entry.dig("usage", "input_tokens") || 0,
      tokens_out: result_entry.dig("usage", "output_tokens") || 0,
      model: @model,
      duration_ms: duration_ms
    )
  end
end
