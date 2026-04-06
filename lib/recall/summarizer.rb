module Recall
  class Summarizer
    # ~400K chars ≈ 100K tokens, fits 128K context non-local models.
    # Local (Ollama) models will NOT work with this chunk size.
    MAX_CHUNK_CHARS = 400_000

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

    def initialize(session, provider_key: "ollama:qwen3:8b")
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

      chunks = chunk_by_chars(messages)
      total_chunks = chunks.size
      @logger.info "[Summarizer] Session #{@session.id}: #{messages.size} messages -> #{total_chunks} chunks"
      summary_so_far = nil

      chunks.each_with_index do |chunk, i|
        run = Experiment.complete!(
          "Session #{@session.id} — summary chunk #{i + 1}/#{total_chunks}",
          prompt: format_messages(chunk),
          system: chunk_system_prompt(summary_so_far),
          provider_key: @provider_key,
          session: @session
        )

        unless run.response_text.present?
          @logger.warn "[Summarizer] Session #{@session.id}: chunk #{i + 1}/#{total_chunks} returned blank, stopping"
          break
        end

        @logger.info "[Summarizer] Session #{@session.id}: chunk #{i + 1}/#{total_chunks} done (#{run.duration_formatted}, #{chunk.size} msgs)"

        summary_so_far = [ summary_so_far, strip_thinking_tags(run.response_text) ].compact.join("\n")
      end

      summary_so_far
    end

    def generate_title(body)
      system = LLM::PromptBuilder.build do |p|
        p.text "You are a conversation summarizer."
        p.instructions "Given a summary of a conversation between a user and an AI coding assistant, generate a descriptive title (up to 15 words) that captures the main intent, topic, and outcome."
        p.rules "- Output only the title, no quotes, no preamble"
      end

      prompt = LLM::PromptBuilder.build do |p|
        p.summary body
      end

      run = Experiment.complete!(
        "Session #{@session.id} — title generation",
        prompt: prompt,
        system: system,
        provider_key: @provider_key,
        session: @session
      )

      return nil if run.response_text.blank?

      strip_thinking_tags(run.response_text).delete_prefix('"').delete_suffix('"').truncate(200)
    end

    def chunk_system_prompt(summary_so_far)
      LLM::PromptBuilder.build do |p|
        p.text "You are a conversation summarizer. You will receive a portion of a conversation between a user and an AI coding assistant."

        p.context do |c|
          if summary_so_far
            c.text "This is a continuation. Here is the summary so far:"
            c.prior_summary summary_so_far
            c.text "Summarize the next portion. Only add new information not already covered above."
          else
            c.text "This is the beginning of the conversation."
          end
        end

        p.instructions <<~TEXT.strip
          Summarize this portion as bullet points. Focus on what was LEARNED, DECIDED, or PRODUCED — not the back-and-forth process.

          Capture whichever apply:
          - Decisions made and their rationale
          - Code or artifacts created, modified, or deleted
          - Technical designs, architecture choices, and trade-offs
          - Bugs, root causes, or incorrect assumptions uncovered
          - Code review findings and recommendations given
          - Key facts or constraints discovered during investigation
          - Corrections to earlier understanding (what changed and why)
        TEXT

        p.rules <<~TEXT.strip
          - Never use "User asked" / "Assistant provided" / "User requested" phrasing
          - Write in past tense, action-oriented voice (e.g. "Identified latent bug in legacy cancellation path" not "User asked about cancellation behavior")
          - Group related items together rather than listing chronologically
          - Do not repeat information already covered in the prior summary
          - Never use emojis
          - Output only bullet points, no preamble
        TEXT
      end
    end

    def chunk_by_chars(messages)
      chunks = []
      current_chunk = []
      current_size = 0

      messages.each do |m|
        next if tool_only?(m)
        size = m.content_text.to_s.size
        if current_chunk.any? && current_size + size > MAX_CHUNK_CHARS
          chunks << current_chunk
          current_chunk = []
          current_size = 0
        end
        current_chunk << m
        current_size += size
      end
      chunks << current_chunk if current_chunk.any?
      chunks
    end

    def format_messages(messages)
      LLM::PromptBuilder.build do |p|
        p.conversation do |c|
          messages.each do |m|
            c.send(m.role.to_sym, m.content_text.to_s)
          end
        end
      end
    end

    # Qwen3 models emit <think>...</think> blocks by default.
    # Strip them from summaries/titles but preserve in experiment runs.
    def strip_thinking_tags(text)
      text.gsub(%r{<think>.*?</think>}m, "").strip
    end

    def tool_only?(message)
      return false unless message.role == "assistant"
      text = message.content_text.to_s.strip
      text.match?(/\A\[Tool: .+\]\z/)
    end
  end
end
