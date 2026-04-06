module LLM
  # Cost per token (USD). Local models are free.
  RATES = {
    "qwen2.5:14b" => { input: 0, output: 0 },
    "qwen3:8b" => { input: 0, output: 0 },
    "qwen3:14b" => { input: 0, output: 0 },
    "gemma3:12b" => { input: 0, output: 0 },
    "llama3.1:8b" => { input: 0, output: 0 },
    "claude-sonnet-4-20250514" => { input: 3.0 / 1_000_000, output: 15.0 / 1_000_000 },
    "claude-opus-4-20250514" => { input: 15.0 / 1_000_000, output: 75.0 / 1_000_000 },
    "claude-haiku-4-5-20251001" => { input: 0.80 / 1_000_000, output: 4.0 / 1_000_000 },
    "kimi-k2" => { input: 0, output: 0 },
    "codex" => { input: 0, output: 0 }
  }.freeze

  PROVIDERS = {
    "ollama" => -> { Providers::Ollama.new },
    "ollama:qwen2.5:14b" => -> { Providers::Ollama.new(model: "qwen2.5:14b") },
    "ollama:qwen3:8b" => -> { Providers::Ollama.new(model: "qwen3:8b") },
    "ollama:qwen3:14b" => -> { Providers::Ollama.new(model: "qwen3:14b") },
    "ollama:gemma3:12b" => -> { Providers::Ollama.new(model: "gemma3:12b") },
    "ollama:llama3.1:8b" => -> { Providers::Ollama.new(model: "llama3.1:8b") },
    "claude_code" => -> { Providers::ClaudeCode.new },
    "claude_code:opus" => -> { Providers::ClaudeCode.new(model: "claude-opus-4-20250514") },
    "claude_code:sonnet" => -> { Providers::ClaudeCode.new(model: "claude-sonnet-4-20250514") },
    "opencode" => -> { Providers::OpenCode.new },
    "codex" => -> { Providers::Codex.new }
  }.freeze

  def self.provider(key)
    factory = PROVIDERS[key]
    raise ArgumentError, "Unknown provider: #{key}. Available: #{PROVIDERS.keys.join(', ')}" unless factory
    factory.call
  end
end
