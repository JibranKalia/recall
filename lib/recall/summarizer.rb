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

      body, title = summarize
      if body.blank?
        @logger.warn "[Summarizer] Session #{@session.id}: summarize returned blank"
        return nil
      end

      if title.blank?
        @logger.warn "[Summarizer] Session #{@session.id}: title generation returned blank"
        return nil
      end

      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(1)
      @logger.info "[Summarizer] Session #{@session.id}: done in #{elapsed}s — \"#{title}\""

      summary = @session.summaries.create!(title: title, body: body, experiment_run: @last_run, message_count: msg_count)
      PushTitleToClaudeCodeJob.perform_later(@session)
      summary
    rescue => e
      @logger.error "[Summarizer] Session #{@session.id} failed: #{e.message}"
      nil
    end

    private

    # Returns [body, title]
    def summarize
      messages = @session.messages.for_summarization
      return [ nil, nil ] if messages.empty?

      chunks = chunk_by_chars(messages)
      total_chunks = chunks.size
      @logger.info "[Summarizer] Session #{@session.id}: #{messages.size} messages -> #{total_chunks} chunks"
      summary_so_far = nil

      chunks.each_with_index do |chunk, i|
        last_chunk = (i == total_chunks - 1)

        run = Experiment.complete!(
          "Session #{@session.id} — summary#{last_chunk ? ' + title' : ''} chunk #{i + 1}/#{total_chunks}",
          prompt: format_messages(chunk),
          system: chunk_system_prompt(summary_so_far, include_title: last_chunk),
          provider_key: @provider_key,
          session: @session
        )

        unless run.response_text.present?
          @logger.warn "[Summarizer] Session #{@session.id}: chunk #{i + 1}/#{total_chunks} returned blank, stopping"
          break
        end

        @logger.info "[Summarizer] Session #{@session.id}: chunk #{i + 1}/#{total_chunks} done (#{run.duration_formatted}, #{chunk.size} msgs)"

        response = strip_thinking_tags(run.response_text)

        if last_chunk
          @last_run = run
          body, title = parse_summary_and_title(response)
          summary_so_far = [ summary_so_far, body ].compact.join("\n")
          return [ summary_so_far, title&.truncate(200) ]
        else
          summary_so_far = [ summary_so_far, response ].compact.join("\n")
        end
      end

      [ summary_so_far, nil ]
    end

    def chunk_system_prompt(summary_so_far, include_title: false)
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
        TEXT

        if include_title
          p.output_format <<~TEXT.strip
            Wrap your output in XML tags:

            <summary>
            - bullet points here
            </summary>
            <title>descriptive title up to 15 words</title>

            The title should capture the main intent, topic, and outcome of the ENTIRE conversation (including any prior summary above).
            Output no quotes or preamble — only the two XML blocks.
          TEXT
        else
          p.rules "- Output only bullet points, no preamble"
        end
      end
    end

    def parse_summary_and_title(response)
      summary = response[%r{<summary>\s*(.*?)\s*</summary>}m, 1]
      title = response[%r{<title>\s*(.*?)\s*</title>}m, 1]

      # Fall back to treating entire response as summary if no XML tags found
      summary = response unless summary.present?
      title = title&.delete_prefix('"')&.delete_suffix('"')

      [ summary, title ]
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
      message.tool_only?
    end
  end
end
