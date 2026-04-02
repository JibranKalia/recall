require "httparty"

module Recall
  class TitleGenerator
    OLLAMA_URL = "http://localhost:11434/api/generate"
    MODEL = "qwen2.5:14b"
    MAX_CONTEXT_CHARS = 2000

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a title generator. Given the start of a conversation between a user and an AI coding assistant, generate a short, descriptive title (5-10 words max). The title should capture the main intent or topic. Output ONLY the title, nothing else. No quotes, no punctuation at the end.
    PROMPT

    def self.generate(session)
      new.generate(session)
    end

    def self.generate_missing(batch_size: 50)
      new.generate_missing(batch_size: batch_size)
    end

    def generate(session)
      context = build_context(session)
      return nil if context.blank?

      call_ollama(context)
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

      sessions.find_each do |session|
        title = generate(session)
        if title.present?
          session.update_column(:custom_title, title)
          generated += 1
          puts "  [#{generated}/#{total}] #{title}"
        end
      end

      puts "Generated #{generated}/#{total} titles."
    end

    private

    def build_context(session)
      messages = session.messages.order(:position).limit(6)
      return nil if messages.empty?

      parts = messages.map do |m|
        role = m.role == "tool_result" ? "tool_result" : m.role
        text = m.content_text.to_s.truncate(500)
        "#{role}: #{text}"
      end

      parts.join("\n\n").truncate(MAX_CONTEXT_CHARS)
    end

    def call_ollama(context)
      response = HTTParty.post(OLLAMA_URL,
        body: {
          model: MODEL,
          prompt: "#{SYSTEM_PROMPT}\n\nConversation:\n#{context}\n\nTitle:",
          stream: false,
          options: { temperature: 0.3, num_predict: 30 }
        }.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: 30
      )

      return nil unless response.success?

      clean_title(response.parsed_response["response"])
    end

    def clean_title(raw)
      return nil if raw.blank?

      title = raw.strip.lines.first.to_s.strip
      title = title.delete_prefix('"').delete_suffix('"')
      title = title.delete_prefix("Title:").strip
      title.truncate(150).presence
    end
  end
end
