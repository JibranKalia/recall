module ApplicationHelper
  include MarkdownHelper

  def message_css_class(message)
    case message.role
    when "user" then "message-user"
    when "assistant"
      assistant_has_text?(message) ? "message-assistant" : "message-assistant message-assistant-tool-only"
    when "tool_result" then "message-tool-result"
    when "system" then "message-system"
    else "message-user"
    end
  end

  def assistant_has_text?(message)
    blocks = message.parsed_content
    return message.content_text.present? unless blocks.is_a?(Array)
    blocks.any? { |b| %w[text output_text].include?(b["type"]) && b["text"].present? }
  end

  def role_css_class(role)
    case role
    when "user" then "role-user"
    when "assistant" then "role-assistant"
    when "tool_result" then "role-tool-result"
    when "system" then "role-system"
    else "role-system"
    end
  end

  def render_message_content(message)
    case message.role
    when "assistant"
      render_assistant_content(message)
    when "tool_result"
      render_tool_result_content(message)
    when "user"
      render_user_content(message)
    else
      content_tag(:div, render_markdown(message.content_text), class: "message-content prose")
    end
  end

  def render_user_content(message)
    blocks = message.parsed_content

    if blocks.is_a?(Array)
      safe_join(blocks.map { |block|
        case block["type"]
        when "text", "input_text"
          content_tag(:div, render_markdown(block["text"]), class: "message-content prose")
        when "image"
          content_tag(:div, content_tag(:span, "Image attachment", class: "image-placeholder"), class: "message-content")
        else
          content_tag(:div, render_markdown(block.to_s), class: "message-content prose")
        end
      })
    elsif blocks.is_a?(String)
      content_tag(:div, render_markdown(blocks), class: "message-content prose")
    else
      content_tag(:div, render_markdown(message.content_text), class: "message-content prose")
    end
  end

  def render_assistant_content(message)
    blocks = message.parsed_content
    return content_tag(:div, render_markdown(message.content_text), class: "message-content prose") unless blocks.is_a?(Array)

    safe_join(blocks.map { |block| render_content_block(block) })
  end

  def render_content_block(block)
    case block["type"]
    when "text", "output_text"
      content_tag(:div, render_markdown(block["text"]), class: "message-content prose")
    when "tool_use"
      render_tool_use(block)
    when "thinking"
      render_thinking(block)
    else
      "".html_safe
    end
  end

  def render_tool_use(block)
    name = block["name"]
    input = block["input"]
    icon = tool_icon(name)
    summary_text = tool_use_summary(name, input)

    content_tag(:details, class: "tool-call") do
      content_tag(:summary, class: "tool-summary") do
        content_tag(:span, icon, class: "tool-icon") +
        content_tag(:span, name, class: "tool-name") +
        content_tag(:span, summary_text, class: "tool-detail")
      end +
      content_tag(:pre, JSON.pretty_generate(input), class: "detail-content")
    end
  end

  def render_tool_result_content(message)
    blocks = message.parsed_content
    block = blocks.is_a?(Array) ? blocks.first : nil

    is_error = block&.dig("is_error")
    content = block&.dig("content") || message.content_text
    # Truncate for summary line
    summary_line = content.to_s.lines.first&.strip&.truncate(100) || "Result"

    css_class = is_error ? "tool-result-block tool-result-error" : "tool-result-block"

    content_tag(:details, class: css_class) do
      content_tag(:summary, class: is_error ? "tool-result-summary tool-result-summary-error" : "tool-result-summary") do
        content_tag(:span, is_error ? "Error" : "Result", class: "tool-result-label") +
        content_tag(:span, summary_line, class: "tool-result-preview")
      end +
      content_tag(:pre, content, class: "detail-content")
    end
  end

  def render_thinking(block)
    text = block["thinking"]
    return "".html_safe if text.blank?

    word_count = text.split.size
    label = "Thinking (#{number_with_delimiter(word_count)} words)"

    content_tag(:details, class: "thinking-block") do
      content_tag(:summary, label, class: "thinking-summary") +
      content_tag(:div, render_markdown(text), class: "detail-content prose prose-sm")
    end
  end

  def resume_command(session)
    dir = session.project.path
    session_id = session.external_id[/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/, 1]

    case session.source_type
    when "claude_code"
      session_id ? "cd #{dir} && claude --resume #{session_id}" : "cd #{dir}"
    when "codex"
      session_id ? "cd #{dir} && codex resume #{session_id}" : "cd #{dir}"
    else
      "cd #{dir}"
    end
  end

  private

  def tool_icon(name)
    case name
    when "Bash", "exec_command" then "$"
    when "Read", "read_file" then "R"
    when "Write", "write_file" then "W"
    when "Edit", "apply_diff" then "E"
    when "Glob" then "G"
    when "Grep" then "S"
    when "Agent" then "A"
    when "WebSearch" then "W"
    when "WebFetch" then "F"
    else "T"
    end
  end

  def tool_use_summary(name, input)
    case name
    when "Bash" then input&.dig("command")&.truncate(120)
    when "exec_command" then input&.dig("cmd")&.truncate(120)
    when "Read", "read_file" then input&.dig("file_path")
    when "Write", "write_file" then input&.dig("file_path")
    when "Edit", "apply_diff" then input&.dig("file_path")
    when "Glob" then input&.dig("pattern")
    when "Grep" then input&.dig("pattern")
    when "Agent" then input&.dig("description") || input&.dig("prompt")&.truncate(80)
    when "WebSearch" then input&.dig("query")
    when "WebFetch" then input&.dig("url")&.truncate(80)
    else input&.to_json&.truncate(80)
    end
  end
end
