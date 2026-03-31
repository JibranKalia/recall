module ApplicationHelper
  def message_bg_class(role)
    case role
    when "user" then "bg-gray-900 border border-gray-800"
    when "assistant" then "bg-gray-900/50 border border-gray-800/50"
    when "tool_result" then "bg-gray-950 border border-gray-800/30"
    when "system" then "bg-gray-900/30 border border-gray-800/30"
    else "bg-gray-900"
    end
  end

  def message_role_class(role)
    case role
    when "user" then "text-blue-400"
    when "assistant" then "text-green-400"
    when "tool_result" then "text-yellow-400"
    when "system" then "text-gray-500"
    else "text-gray-400"
    end
  end

  def render_assistant_content(message)
    blocks = message.parsed_content
    return content_tag(:div, message.content_text, class: "text-sm text-gray-200 whitespace-pre-wrap break-words") unless blocks.is_a?(Array)

    safe_join(blocks.map { |block| render_content_block(block) })
  end

  def render_content_block(block)
    case block["type"]
    when "text"
      content_tag(:div, block["text"], class: "text-sm text-gray-200 whitespace-pre-wrap break-words mb-2")
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

    content_tag(:details, class: "mb-2 text-xs") do
      content_tag(:summary, class: "cursor-pointer text-yellow-500 hover:text-yellow-400") do
        "#{name}: #{summary}".html_safe
      end +
      content_tag(:pre, JSON.pretty_generate(input), class: "mt-1 p-2 bg-gray-950 rounded text-gray-400 overflow-x-auto text-xs")
    end
  end

  def render_thinking(block)
    text = block["thinking"]
    return "".html_safe if text.blank?

    content_tag(:details, class: "mb-2 text-xs") do
      content_tag(:summary, "Thinking...", class: "cursor-pointer text-gray-600 hover:text-gray-400") +
      content_tag(:div, text, class: "mt-1 p-2 bg-gray-950 rounded text-gray-500 whitespace-pre-wrap text-xs")
    end
  end
end
