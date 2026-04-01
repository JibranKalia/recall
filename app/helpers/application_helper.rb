module ApplicationHelper
  def message_css_class(role)
    case role
    when "user" then "message-user"
    when "assistant" then "message-assistant"
    when "tool_result" then "message-tool-result"
    when "system" then "message-system"
    else "message-user"
    end
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

  def render_assistant_content(message)
    blocks = message.parsed_content
    return content_tag(:div, message.content_text, class: "message-content") unless blocks.is_a?(Array)

    safe_join(blocks.map { |block| render_content_block(block) })
  end

  def render_content_block(block)
    case block["type"]
    when "text"
      content_tag(:div, block["text"], class: "message-content mb-2")
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
    summary = case name
    when "Bash" then input&.dig("command")&.truncate(80)
    when "Read" then input&.dig("file_path")
    when "Write" then input&.dig("file_path")
    when "Edit" then input&.dig("file_path")
    when "Glob" then input&.dig("pattern")
    when "Grep" then input&.dig("pattern")
    else input&.to_json&.truncate(80)
    end

    content_tag(:details) do
      content_tag(:summary, "#{name}: #{summary}", class: "tool-summary") +
      content_tag(:pre, JSON.pretty_generate(input), class: "detail-content")
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

  def render_thinking(block)
    text = block["thinking"]
    return "".html_safe if text.blank?

    content_tag(:details) do
      content_tag(:summary, "Thinking...", class: "thinking-summary") +
      content_tag(:div, text, class: "detail-content")
    end
  end
end
