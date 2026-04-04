require "httparty"

module Recall
  class TitleGenerator
    OLLAMA_URL = "http://localhost:11434/api/generate"
    MODEL = "qwen2.5:14b"

    TITLE_PROMPT = <<~PROMPT.freeze
      You are a conversation summarizer. Given a summary of an entire conversation between a user and an AI coding assistant, generate a descriptive title (up to 15 words) that captures the main intent, topic, and outcome.

      Output only the title, no quotes, no preamble.
    PROMPT

    def self.generate(session)
      new.generate(session)
    end

    def self.generate_missing(batch_size: 50)
      new.generate_missing(batch_size: batch_size)
    end

    def generate(session)
      summary = Summarizer.new(session).call
      return nil if summary.blank?

      title = generate_title_from_summary(summary)
      return nil if title.blank?

      session.update!(custom_title: title, summary: summary)
      title
    rescue => e
      warn "  Title generation failed for session #{session.id}: #{e.message}"
      nil
    end

    def generate_missing(batch_size: 50)
      sessions = Session.where(custom_title: nil).order(started_at: :desc).limit(batch_size)
      total = sessions.count
      return if total == 0

      puts "Generating titles for #{total} sessions..."
      generated = 0

      sessions.each do |session|
        title = generate(session)
        if title.present?
          generated += 1
          puts "  [#{generated}/#{total}] #{title}"
        end
      end

      puts "Generated #{generated}/#{total} titles."
    end

    private

    def generate_title_from_summary(summary)
      response = HTTParty.post(OLLAMA_URL,
        body: {
          model: MODEL,
          prompt: "#{TITLE_PROMPT}\n\nSummary:\n#{summary}",
          stream: false,
          options: { temperature: 0.3, num_predict: 50 }
        }.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: 60
      )

      return nil unless response.success?

      raw = response.parsed_response["response"]&.strip
      return nil if raw.blank?

      raw.delete_prefix('"').delete_suffix('"').truncate(200)
    end
  end
end
