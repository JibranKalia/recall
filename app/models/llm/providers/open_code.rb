require "open3"

class LLM::Providers::OpenCode < LLM::Provider
  DEFAULT_MODEL = "kimi-k2.5"

  attr_reader :model

  def initialize(model: DEFAULT_MODEL)
    @model = model
    @opencode_model = "opencode/#{model}"
  end

  def name
    "opencode"
  end

  def complete(prompt, system: nil, **)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    full_prompt = system ? "#{system}\n\n#{prompt}" : prompt

    cmd = [ "opencode", "run", "--format", "json", "--model", @opencode_model, full_prompt ]
    stdout, stderr, status = Open3.capture3(*cmd)

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

    unless status.success?
      raise "opencode failed (exit #{status.exitstatus}): #{stderr}"
    end

    # Output is newline-delimited JSON events
    text_parts = []
    tokens_in = 0
    tokens_out = 0

    stdout.each_line do |line|
      event = JSON.parse(line.strip) rescue next
      case event["type"]
      when "text"
        text_parts << event.dig("part", "text").to_s
      when "step_finish"
        tokens = event.dig("part", "tokens") || {}
        tokens_in += tokens["input"].to_i
        tokens_out += tokens["output"].to_i
      end
    end

    Result.new(
      output: text_parts.join.strip,
      tokens_in: tokens_in,
      tokens_out: tokens_out,
      model: @model,
      duration_ms: duration_ms
    )
  end
end
