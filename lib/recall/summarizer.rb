module Recall
  class Summarizer
    MESSAGES_PER_CHUNK = 50
    MAX_CHUNK_CHARS = 24_000

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
          Summarize this portion as bullet points focusing on OUTCOMES, not process:
          - Decisions made and why
          - Artifacts created or modified (files, diagrams, specs, queries)
          - Technical designs, architecture choices, and trade-offs
          - Problems solved and how
        TEXT

        p.rules <<~TEXT.strip
          - Never use "User asked" / "Assistant provided" / "User requested" phrasing
          - Write in past tense, action-oriented voice (e.g. "Designed enrichment pipeline with 4 layers" not "User asked for a pipeline design")
          - Group related items together rather than listing chronologically
          - Do not repeat information already covered in the prior summary
          - Output only bullet points, no preamble
        TEXT
      end
    end

    def format_messages(messages)
      meaningful = messages.reject { |m| tool_only?(m) }
      per_message = MAX_CHUNK_CHARS / [meaningful.size, 1].max

      LLM::PromptBuilder.build do |p|
        p.conversation do |c|
          meaningful.each do |m|
            text = m.content_text.to_s.truncate(per_message)
            c.send(m.role.to_sym, text)
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
