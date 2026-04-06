module Recall
  class Summarizer
    MESSAGES_PER_CHUNK = 50
    MAX_CHUNK_CHARS = 24_000

    CHUNK_SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a conversation summarizer. You will receive a portion of a conversation between a user and an AI coding assistant.

      <context>
      %{context_line}
      </context>

      <instructions>
      Summarize this portion as bullet points focusing on OUTCOMES, not process:
      - Decisions made and why
      - Artifacts created or modified (files, diagrams, specs, queries)
      - Technical designs, architecture choices, and trade-offs
      - Problems solved and how
      </instructions>

      <rules>
      - Never use "User asked" / "Assistant provided" / "User requested" phrasing
      - Write in past tense, action-oriented voice (e.g. "Designed enrichment pipeline with 4 layers" not "User asked for a pipeline design")
      - Group related items together rather than listing chronologically
      - Do not repeat information already covered in the prior summary
      - Output only bullet points, no preamble
      </rules>
    PROMPT

    TITLE_PROMPT = <<~PROMPT.freeze
      You are a conversation summarizer.

      <instructions>
      Given a summary of an entire conversation between a user and an AI coding assistant, generate a descriptive title (up to 15 words) that captures the main intent, topic, and outcome.
      </instructions>

      <rules>
      - Output only the title, no quotes, no preamble
      </rules>
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

    def initialize(session, provider_key: "ollama")
      @session = session
      @provider_key = provider_key
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
      @logger.info "[Summarizer] Session #{@session.id}: #{messages.size} messages -> #{total_chunks} chunks"
      summary_so_far = nil

      chunks.each_with_index do |chunk, i|
        system = format(CHUNK_SYSTEM_PROMPT, context_line: context_line_for(summary_so_far))
        formatted = format_messages(chunk)

        run = Experiment.complete!(
          "Session #{@session.id} — summary chunk #{i + 1}/#{total_chunks}",
          prompt: formatted,
          system: system,
          provider_key: @provider_key
        )

        unless run.response_text.present?
          @logger.warn "[Summarizer] Session #{@session.id}: chunk #{i + 1}/#{total_chunks} returned blank, stopping"
          break
        end

        @logger.info "[Summarizer] Session #{@session.id}: chunk #{i + 1}/#{total_chunks} done (#{run.duration_formatted}, #{chunk.size} msgs)"

        summary_so_far = [ summary_so_far, run.response_text ].compact.join("\n")
      end

      summary_so_far
    end

    def generate_title(body)
      run = Experiment.complete!(
        "Session #{@session.id} — title generation",
        prompt: "<summary>\n#{body}\n</summary>",
        system: TITLE_PROMPT,
        provider_key: @provider_key,
        session: @session
      )

      return nil if run.response_text.blank?

      run.response_text.delete_prefix('"').delete_suffix('"').truncate(200)
    end

    def context_line_for(summary_so_far)
      if summary_so_far
        "This is a continuation. Here is the summary so far:\n<prior_summary>\n#{summary_so_far}\n</prior_summary>\n\nSummarize the next portion. Only add new information not already covered above."
      else
        "This is the beginning of the conversation."
      end
    end

    def format_messages(messages)
      per_message = MAX_CHUNK_CHARS / [messages.size, 1].max
      turns = messages.map do |m|
        text = m.content_text.to_s.truncate(per_message)
        "<message role=\"#{m.role}\">\n#{text}\n</message>"
      end.join("\n\n")

      "<conversation>\n#{turns}\n</conversation>"
    end
  end
end
