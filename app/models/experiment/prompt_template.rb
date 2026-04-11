class Experiment::PromptTemplate
  TEMPLATES = {
    "detailed_summary" => { name: "Detailed Summary", description: "Comprehensive summary for seeding a new conversation" },
    "brief_summary" => { name: "Brief Summary", description: "Concise bullet-point summary" }
  }.freeze

  def self.all
    TEMPLATES.map { |key, t| { key: key, name: t[:name], description: t[:description] } }
  end

  def self.build(key, session)
    template = TEMPLATES.fetch(key) { raise ArgumentError, "Unknown template: #{key}" }

    {
      name: "#{template[:name]} — #{session.display_title.truncate(60)}",
      system_prompt: system_prompt_for(key),
      prompt: conversation_prompt(session)
    }
  end

  class << self
    private

    def system_prompt_for(key)
      case key
      when "detailed_summary" then detailed_summary_system_prompt
      when "brief_summary"    then brief_summary_system_prompt
      end
    end

    def conversation_prompt(session)
      messages = session.messages.for_summarization
      return "" if messages.empty?

      LLM::PromptBuilder.build do |p|
        p.conversation do |c|
          messages.each do |m|
            next if m.tool_only?
            c.send(m.role.to_sym, m.content_text.to_s)
          end
        end
      end
    end

    def detailed_summary_system_prompt
      LLM::PromptBuilder.build do |p|
        p.text "You are a conversation summarizer producing a detailed summary that will be used to seed a new AI conversation with full context."

        p.instructions <<~TEXT.strip
          Produce a thorough, structured summary that captures enough detail for someone to continue this work in a new conversation without re-reading the original.

          Capture ALL of the following that apply:
          - Decisions made, their rationale, and alternatives that were considered or rejected
          - Code created, modified, or deleted — include file paths and the nature of changes
          - Architecture and design choices, including trade-offs discussed
          - Bugs found, root causes identified, and how they were fixed
          - Key technical constraints or gotchas discovered
          - Configuration, environment, or infrastructure details that matter
          - Open questions, unresolved issues, or next steps identified
          - Corrections to earlier understanding — what changed and why
        TEXT

        p.rules <<~TEXT.strip
          - Write in past tense, action-oriented voice
          - Include file paths, function names, and specific values when referenced in the conversation
          - Group related items under descriptive headings (use ## Markdown headings)
          - Preserve technical specifics — a reader should be able to act on this summary without the original conversation
          - Do NOT include conversational back-and-forth or "User asked / Assistant said" framing
          - Never use emojis
        TEXT

        p.output_format <<~TEXT.strip
          Wrap your output in XML tags:

          <summary>
          ## Heading

          - detailed bullet points with file paths, specifics, etc.

          ## Another Heading

          - more bullets...

          ## Open Questions / Next Steps

          - anything unresolved
          </summary>
          <title>descriptive title up to 15 words</title>

          The title should capture the main topic and outcome of the conversation.
          Output no quotes or preamble — only the two XML blocks.
        TEXT
      end
    end

    def brief_summary_system_prompt
      LLM::PromptBuilder.build do |p|
        p.text "You are a conversation summarizer. You will receive a conversation between a user and an AI coding assistant."

        p.instructions <<~TEXT.strip
          Summarize as bullet points. Focus on what was LEARNED, DECIDED, or PRODUCED — not the back-and-forth process.

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
          - Write in past tense, action-oriented voice
          - Group related items together rather than listing chronologically
          - Never use emojis
        TEXT

        p.output_format <<~TEXT.strip
          Wrap your output in XML tags:

          <summary>
          - bullet points here
          </summary>
          <title>descriptive title up to 15 words</title>

          The title should capture the main intent, topic, and outcome of the conversation.
          Output no quotes or preamble — only the two XML blocks.
        TEXT
      end
    end
  end
end
