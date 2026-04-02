require "httparty"

module Recall
  class TitleGenerator
    OLLAMA_URL = "http://localhost:11434/api/generate"
    MODEL = "qwen2.5:14b"
    MAX_CONTEXT_CHARS = 32_000

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a conversation summarizer. Given the beginning and end of a conversation between a user and an AI coding assistant, generate:

      1. A descriptive title (up to 15 words) that captures the main intent, topic, and outcome.
      2. A bullet-point summary (3-7 bullets) of what was discussed and accomplished.

      Use this exact format:

      Title: <title here>

      Summary:
      - <bullet 1>
      - <bullet 2>
      - <bullet 3>
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

      result = call_ollama(context)
      return nil unless result

      session.update!(custom_title: result[:title], summary: result[:summary])
      result[:title]
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

    def build_context(session)
      all_messages = session.messages.where.not(role: "tool_result").order(:position)
      return nil if all_messages.empty?

      beginning = all_messages.first(15)
      ending = all_messages.last(15)

      # Deduplicate if session is short and beginning/ending overlap
      combined = (beginning + ending).uniq(&:id)

      half_budget = MAX_CONTEXT_CHARS / 2

      beginning_parts = format_messages(beginning, half_budget)
      ending_parts = format_messages(ending, half_budget)

      if combined.length == (beginning + ending).uniq(&:id).length && combined == beginning
        beginning_parts.join("\n\n").truncate(MAX_CONTEXT_CHARS)
      else
        "[Beginning of conversation]\n#{beginning_parts.join("\n\n")}\n\n[End of conversation]\n#{ending_parts.join("\n\n")}".truncate(MAX_CONTEXT_CHARS)
      end
    end

    def format_messages(messages, budget)
      per_message = budget / [messages.size, 1].max
      messages.map do |m|
        text = m.content_text.to_s.truncate(per_message)
        "#{m.role}: #{text}"
      end
    end

    def call_ollama(context)
      response = HTTParty.post(OLLAMA_URL,
        body: {
          model: MODEL,
          prompt: "#{SYSTEM_PROMPT}\n\nConversation:\n#{context}",
          stream: false,
          options: { temperature: 0.3, num_predict: 300 }
        }.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: 120
      )

      return nil unless response.success?

      parse_response(response.parsed_response["response"])
    end

    def parse_response(raw)
      return nil if raw.blank?

      # Extract title
      title_match = raw.match(/Title:\s*(.+?)(?:\n|$)/)
      return nil unless title_match

      title = title_match[1].strip.delete_prefix('"').delete_suffix('"').truncate(200)

      # Extract summary (everything after "Summary:")
      summary_match = raw.match(/Summary:\s*\n(.*)/m)
      summary = summary_match ? summary_match[1].strip : nil

      { title: title.presence, summary: summary.presence }
    end
  end
end
