class Session::Markdown
  attr_reader :session

  def initialize(session)
    @session = session
  end

  def render(thinking: false, tool_details: false)
    cache_key = "session/#{session.id}/markdown/#{session.messages_count}/t#{thinking ? 1 : 0}_d#{tool_details ? 1 : 0}"

    Rails.cache.fetch(cache_key) do
      build(thinking: thinking, tool_details: tool_details)
    end
  end

  private

  def build(thinking: false, tool_details: false)
    lines = []
    lines << "# #{session.display_title}"
    lines << ""
    lines << "**Session ID:** #{session.external_id}"
    lines << "**Project:** #{session.project.path}"
    lines << "**Created:** #{session.started_at&.strftime('%Y-%m-%d %H:%M')}" if session.started_at
    lines << "**Model:** #{session.model}" if session.model.present?
    lines << ""
    lines << "---"
    lines << ""

    msgs = session.messages.loaded? ? session.messages.sort_by(&:position) : session.messages.order(:position)
    turns = group_into_turns(msgs)

    turns.each do |turn|
      case turn[:role]
      when "user"
        text = turn[:texts].join("\n\n")
        next if text.blank?
        lines << "## User"
        lines << ""
        lines << text
        lines << ""
        lines << "---"
        lines << ""
      when "assistant"
        has_text = turn[:texts].any?
        has_thinking = thinking && turn[:thinking].any?
        has_tools = tool_details && turn[:tools].any?

        next unless has_text || has_thinking || has_tools

        lines << "## Assistant"
        lines << ""

        turn[:parts].each do |part|
          case part[:type]
          when :thinking
            next unless thinking
            lines << "_Thinking:_"
            lines << ""
            lines << part[:text]
            lines << ""
          when :text
            lines << part[:text]
            lines << ""
          when :tool_use
            next unless tool_details
            summary = tool_call_summary(part[:name], part[:input])
            line = "**Tool: #{part[:name]}**"
            line += " — `#{summary}`" if summary.present?
            lines << line
            if tool_details && part[:input]
              lines << ""
              lines << "**Input:**"
              lines << "```json"
              lines << JSON.pretty_generate(part[:input])
              lines << "```"
            end
            lines << ""
          when :tool_result
            next unless tool_details
            label = part[:error] ? "Error" : "Output"
            lines << "**#{label}:**"
            lines << "```"
            lines << part[:content].truncate(500)
            lines << "```"
            lines << ""
          end
        end

        lines << "---"
        lines << ""
      end
    end

    lines.join("\n")
  end

  def group_into_turns(ordered_messages)
    turns = []
    current_turn = nil

    ordered_messages.each do |msg|
      case msg.role
      when "user"
        text = extract_message_text(msg)
        text = nil if text&.match?(/\[Request interrupted by user/)
        next if text.blank?
        current_turn = { role: "user", texts: [text], parts: [] }
        turns << current_turn
      when "assistant"
        if current_turn.nil? || current_turn[:role] != "assistant"
          current_turn = { role: "assistant", texts: [], thinking: [], tools: [], parts: [] }
          turns << current_turn
        end

        blocks = msg.parsed_content
        if blocks.is_a?(Array)
          blocks.each do |block|
            case block["type"]
            when "text"
              text = block["text"]
              next if text.blank? || text.strip == "No response requested."
              current_turn[:texts] << text
              current_turn[:parts] << { type: :text, text: text }
            when "thinking"
              next if block["thinking"].blank?
              current_turn[:thinking] << block["thinking"]
              current_turn[:parts] << { type: :thinking, text: block["thinking"] }
            when "tool_use"
              current_turn[:tools] << block
              current_turn[:parts] << { type: :tool_use, name: block["name"], input: block["input"] }
            end
          end
        elsif msg.content_text.present? && msg.content_text.strip != "No response requested."
          current_turn[:texts] << msg.content_text
          current_turn[:parts] << { type: :text, text: msg.content_text }
        end
      when "tool_result"
        if current_turn && current_turn[:role] == "assistant"
          blocks = msg.parsed_content
          block = blocks.is_a?(Array) ? blocks.first : nil
          content = block&.dig("content") || msg.content_text
          is_error = block&.dig("is_error")
          if content.present?
            current_turn[:parts] << { type: :tool_result, content: content.to_s, error: is_error }
          end
        end
      end
    end

    turns
  end

  def tool_call_summary(name, input)
    case name
    when "Bash" then input&.dig("command")&.truncate(120)
    when "Read", "Write", "Edit" then input&.dig("file_path")
    when "Glob" then input&.dig("pattern")
    when "Grep" then input&.dig("pattern")
    when "Agent" then input&.dig("description") || input&.dig("prompt")&.truncate(80)
    when "WebSearch" then input&.dig("query")
    when "WebFetch" then input&.dig("url")&.truncate(80)
    end
  end

  def extract_message_text(message)
    blocks = message.parsed_content
    if blocks.is_a?(Array)
      blocks.filter_map { |b| b["text"] if b["type"] == "text" }.join("\n\n")
    else
      message.content_text
    end
  end
end
