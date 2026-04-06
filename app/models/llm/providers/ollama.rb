require "httparty"

class LLM::Providers::Ollama < LLM::Provider
  DEFAULT_URL = "http://localhost:11434"

  attr_reader :model

  def initialize(model:, base_url: DEFAULT_URL)
    @model = model
    @base_url = base_url
  end

  def name
    "ollama"
  end

  def complete(prompt, system: nil, temperature: 0.3, num_predict: 500, **)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    body = {
      model: @model,
      stream: false,
      options: { temperature: temperature, num_predict: num_predict }
    }

    if system
      body[:prompt] = "#{system}\n\n#{prompt}"
    else
      body[:prompt] = prompt
    end

    response = HTTParty.post(
      "#{@base_url}/api/generate",
      body: body.to_json,
      headers: { "Content-Type" => "application/json" },
      timeout: 120
    )

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

    unless response.success?
      raise "Ollama API error: #{response.code} #{response.body}"
    end

    parsed = response.parsed_response
    Result.new(
      output: parsed["response"]&.strip,
      tokens_in: parsed.dig("prompt_eval_count") || 0,
      tokens_out: parsed.dig("eval_count") || 0,
      model: @model,
      duration_ms: duration_ms
    )
  end
end
