module LLM
  # Cost per token (USD). Local models are free.
  RATES = {
    "qwen3:8b" => { input: 0, output: 0 },
    "qwen2.5:14b" => { input: 0, output: 0 },
    "gemma3:12b" => { input: 0, output: 0 },
    "gemma4:e4b" => { input: 0, output: 0 },
    "claude-sonnet-4-20250514" => { input: 3.0 / 1_000_000, output: 15.0 / 1_000_000 },
    "claude-opus-4-20250514" => { input: 15.0 / 1_000_000, output: 75.0 / 1_000_000 },
    "claude-haiku-4-5-20251001" => { input: 0.80 / 1_000_000, output: 4.0 / 1_000_000 },
    "kimi-k2.5" => { input: 0.60 / 1_000_000, output: 3.0 / 1_000_000 },
    "big-pickle" => { input: 0, output: 0 },
    "gpt-5-nano" => { input: 0, output: 0 },
    "gpt-5.4-mini" => { input: 0.75 / 1_000_000, output: 4.5 / 1_000_000 },
    "gemini-3-flash" => { input: 0.50 / 1_000_000, output: 3.0 / 1_000_000 },
    "gpt-5.4" => { input: 2.50 / 1_000_000, output: 15.0 / 1_000_000 },
    "codex" => { input: 0, output: 0 }
  }.freeze

  PROVIDERS = {
    "ollama:qwen3:8b" => -> { Providers::Ollama.new(model: "qwen3:8b") },
    "ollama:qwen2.5:14b" => -> { Providers::Ollama.new(model: "qwen2.5:14b") },
    "ollama:gemma3:12b" => -> { Providers::Ollama.new(model: "gemma3:12b") },
    "ollama:gemma4:e4b" => -> { Providers::Ollama.new(model: "gemma4:e4b") },
    "claude_code:sonnet" => -> { Providers::ClaudeCode.new(model: "claude-sonnet-4-20250514") },
    "claude_code:opus" => -> { Providers::ClaudeCode.new(model: "claude-opus-4-20250514") },
    "opencode:kimi-k2.5" => -> { Providers::OpenCode.new },
    "opencode:big-pickle" => -> { Providers::OpenCode.new(model: "big-pickle") },
    "opencode:gpt-5-nano" => -> { Providers::OpenCode.new(model: "gpt-5-nano") },
    "opencode:gpt-5.4-mini" => -> { Providers::OpenCode.new(model: "gpt-5.4-mini") },
    "opencode:gemini-3-flash" => -> { Providers::OpenCode.new(model: "gemini-3-flash") },
    "opencode:gpt-5.4" => -> { Providers::OpenCode.new(model: "gpt-5.4") },
    "codex" => -> { Providers::Codex.new }
  }.freeze

  TIER_HINTS = {
    "Local" => "runs on your machine",
    "Free" => "$0",
    "Budget" => "< $5/1M out",
    "Standard" => "$5\u2013$10/1M out",
    "Premium" => "$10\u2013$20/1M out",
    "Flagship" => "> $20/1M out"
  }.freeze
  def self.provider_groups
    groups = { "Local" => [], "Free" => [], "Budget" => [], "Standard" => [], "Premium" => [], "Flagship" => [] }

    PROVIDERS.each_key do |key|
      if key.start_with?("ollama:")
        groups["Local"] << key
      else
        provider = PROVIDERS[key].call
        rates = RATES[provider.model]
        output_per_m = rates ? rates[:output] * 1_000_000 : 0

        tier = if output_per_m == 0
                 "Free"
               elsif output_per_m < 5
                 "Budget"
               elsif output_per_m <= 10
                 "Standard"
               elsif output_per_m <= 20
                 "Premium"
               else
                 "Flagship"
               end
        groups[tier] << key
      end
    end

    groups.reject { |_, v| v.empty? }
  end

  def self.provider(key)
    factory = PROVIDERS[key]
    raise ArgumentError, "Unknown provider: #{key}. Available: #{PROVIDERS.keys.join(', ')}" unless factory
    factory.call
  end
end
