class TokenUsage < ApplicationRecord
  belongs_to :message

  # Pricing per million tokens (USD) by model
  # Claude: cache_write = 1.25x input (5m), cache_read = 0.1x input
  # GPT: no cache_write concept, cache_read is flat rate
  RATE_CARD = {
    "claude-opus-4-6" => { input: 5.0, output: 25.0, cache_write: 6.25, cache_read: 0.50 },
    "claude-opus-4-5" => { input: 5.0, output: 25.0, cache_write: 6.25, cache_read: 0.50 },
    "claude-opus-4-1" => { input: 15.0, output: 75.0, cache_write: 18.75, cache_read: 1.50 },
    "claude-opus-4-0" => { input: 15.0, output: 75.0, cache_write: 18.75, cache_read: 1.50 },
    "claude-sonnet-4" => { input: 3.0, output: 15.0, cache_write: 3.75, cache_read: 0.30 },
    "claude-haiku-4-5" => { input: 1.0, output: 5.0, cache_write: 1.25, cache_read: 0.10 },
    "claude-haiku-3-5" => { input: 0.80, output: 4.0, cache_write: 1.0, cache_read: 0.08 },
    "gpt-5.4" => { input: 2.50, output: 15.0, cache_write: 0.0, cache_read: 0.25 },
    "gpt-5" => { input: 2.50, output: 15.0, cache_write: 0.0, cache_read: 0.25 }
  }.freeze

  def estimated_cost
    rates = self.class.rates_for(model)
    return nil unless rates

    per_m = 1_000_000.0
    (input_tokens * rates[:input] / per_m) +
      (output_tokens * rates[:output] / per_m) +
      (cache_creation_input_tokens * rates[:cache_write] / per_m) +
      (cache_read_input_tokens * rates[:cache_read] / per_m)
  end

  def self.rates_for(model_name)
    return nil if model_name.blank?

    RATE_CARD.each do |prefix, rates|
      return rates if model_name.start_with?(prefix)
    end
    nil
  end
end
