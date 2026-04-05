require "httparty"

module Recall
  class Summarizer
    OLLAMA_URL = "http://localhost:11434/api/generate"
    MODEL = "qwen2.5:14b"
    MESSAGES_PER_CHUNK = 50
    MAX_CHUNK_CHARS = 24_000

    CHUNK_SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a conversation summarizer. You will be given a portion of a conversation between a user and an AI coding assistant.

      %{context_line}

      Summarize this portion as bullet points focusing on OUTCOMES, not process:
      - Decisions made and why
      - Artifacts created or modified (files, diagrams, specs, queries)
      - Technical designs, architecture choices, and trade-offs
      - Problems solved and how

      Rules:
      - Never use "User asked" / "Assistant provided" / "User requested" phrasing
      - Write in past tense, action-oriented voice (e.g. "Designed enrichment pipeline with 4 layers" not "User asked for a pipeline design")
      - Group related items together rather than listing chronologically
      - Do not repeat information already covered in the prior summary
      - Output only bullet points, no preamble
    PROMPT

    TITLE_PROMPT = <<~PROMPT.freeze
      You are a conversation summarizer. Given a summary of an entire conversation between a user and an AI coding assistant, generate a descriptive title (up to 15 words) that captures the main intent, topic, and outcome.

      Output only the title, no quotes, no preamble.
    PROMPT

    def self.generate(session)
      new(session).generate
    end

    def self.generate_missing(batch_size: 50)
      sessions = Session.where(custom_title: nil).order(started_at: :desc).limit(batch_size)
      total = sessions.count
      return if total == 0

      puts "Generating summaries for #{total} sessions..."
      generated = 0

      sessions.each do |session|
        summary = new(session).generate
        if summary
          generated += 1
          puts "  [#{generated}/#{total}] #{summary.title}"
        end
      end

      puts "Generated #{generated}/#{total} summaries."
    end

    def initialize(session)
      @session = session
      @logger = Rails.logger
    end

    def generate
      msg_count = @session.messages.count
      @logger.info "[Summarizer] Starting session #{@session.id} (#{msg_count} messages)"
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      body = summarize
      if body.blank?
        @logger.warn "[Summarizer] Session #{@session.id}: summarize returned blank"
        return nil
      end

      @logger.info "[Summarizer] Session #{@session.id}: generating title..."
      title = generate_title(body)
      if title.blank?
        @logger.warn "[Summarizer] Session #{@session.id}: title generation returned blank"
        return nil
      end

      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(1)
      @logger.info "[Summarizer] Session #{@session.id}: done in #{elapsed}s — \"#{title}\""

      @session.summaries.create!(title: title, body: body)
    rescue => e
      @logger.error "[Summarizer] Session #{@session.id} failed: #{e.message}"
      nil
    end

    private

    def summarize
      messages = @session.messages.includes(:content).where.not(role: "tool_result").order(:position)
      return nil if messages.empty?

      chunks = messages.each_slice(MESSAGES_PER_CHUNK).to_a
      total_chunks = chunks.size
      @logger.info "[Summarizer] Session #{@session.id}: #{messages.size} messages → #{total_chunks} chunks"
      summary_so_far = nil

      chunks.each_with_index do |chunk, i|
        chunk_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        context_line = if summary_so_far
          "Here is the summary of the conversation so far:\n#{summary_so_far}\n\nNow summarize the next portion. Only add new information."
        else
          "This is the beginning of the conversation."
        end

        prompt = format(CHUNK_SYSTEM_PROMPT, context_line: context_line)
        formatted = format_messages(chunk)

        result = call_ollama(prompt, formatted, num_predict: 500)
        unless result
          @logger.warn "[Summarizer] Session #{@session.id}: chunk #{i + 1}/#{total_chunks} returned nil, stopping"
          break
        end

        chunk_elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - chunk_start).round(1)
        @logger.info "[Summarizer] Session #{@session.id}: chunk #{i + 1}/#{total_chunks} done (#{chunk_elapsed}s, #{chunk.size} msgs)"

        summary_so_far = if summary_so_far
          "#{summary_so_far}\n#{result}"
        else
          result
        end
      end

      summary_so_far
    end

    def generate_title(body)
      raw = call_ollama(TITLE_PROMPT, body, num_predict: 50)
      return nil if raw.blank?

      raw.delete_prefix('"').delete_suffix('"').truncate(200)
    end

    def format_messages(messages)
      per_message = MAX_CHUNK_CHARS / [messages.size, 1].max
      messages.map do |m|
        text = m.content_text.to_s.truncate(per_message)
        "#{m.role}: #{text}"
      end.join("\n\n")
    end

    def call_ollama(system_prompt, context, num_predict: 500)
      response = HTTParty.post(OLLAMA_URL,
        body: {
          model: MODEL,
          prompt: "#{system_prompt}\n\nConversation:\n#{context}",
          stream: false,
          options: { temperature: 0.3, num_predict: num_predict }
        }.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: 120
      )

      return nil unless response.success?

      response.parsed_response["response"]&.strip
    end
  end
end
