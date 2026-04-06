class LLM::Provider
  Result = Data.define(:output, :tokens_in, :tokens_out, :model, :duration_ms) do
    def cost
      rates = LLM::RATES[model]
      return 0.0 unless rates

      (tokens_in * rates[:input]) + (tokens_out * rates[:output])
    end
  end

  def name
    raise NotImplementedError
  end

  def model
    raise NotImplementedError
  end

  def complete(prompt, system: nil, **options)
    raise NotImplementedError
  end
end
