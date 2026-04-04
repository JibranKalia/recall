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

    def initialize(session)
      @session = session
    end

    def call
      messages = @session.messages.where.not(role: "tool_result").order(:position)
      return nil if messages.empty?

      chunks = messages.each_slice(MESSAGES_PER_CHUNK).to_a
      summary_so_far = nil

      chunks.each_with_index do |chunk, i|
        context_line = if summary_so_far
          "Here is the summary of the conversation so far:\n#{summary_so_far}\n\nNow summarize the next portion. Only add new information."
        else
          "This is the beginning of the conversation."
        end

        prompt = format(CHUNK_SYSTEM_PROMPT, context_line: context_line)
        formatted = format_messages(chunk)

        result = call_ollama(prompt, formatted)
        break unless result

        summary_so_far = if summary_so_far
          "#{summary_so_far}\n#{result}"
        else
          result
        end
      end

      summary_so_far
    end

    private

    def format_messages(messages)
      per_message = MAX_CHUNK_CHARS / [messages.size, 1].max
      messages.map do |m|
        text = m.content_text.to_s.truncate(per_message)
        "#{m.role}: #{text}"
      end.join("\n\n")
    end

    def call_ollama(system_prompt, context)
      response = HTTParty.post(OLLAMA_URL,
        body: {
          model: MODEL,
          prompt: "#{system_prompt}\n\nConversation:\n#{context}",
          stream: false,
          options: { temperature: 0.3, num_predict: 500 }
        }.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: 120
      )

      return nil unless response.success?

      response.parsed_response["response"]&.strip
    end
  end
end
