class TokenUsage < ApplicationRecord
  belongs_to :message

  # Pricing per million tokens (USD) by model family
  RATE_CARD = {
    "claude-sonnet" => { input: 3.0, output: 15.0, cache_write: 3.75, cache_read: 0.30 },
    "claude-opus" => { input: 15.0, output: 75.0, cache_write: 18.75, cache_read: 1.50 },
    "claude-haiku" => { input: 0.80, output: 4.0, cache_write: 1.0, cache_read: 0.08 },
    "gpt-5" => { input: 2.0, output: 8.0, cache_write: 2.0, cache_read: 0.50 }
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
