class PushTitleToClaudeCodeJob < ApplicationJob
  queue_as :default

  CLAUDE_SOURCES = %w[claude claude_work].freeze
  ACTIVE_SESSION_WINDOW = 60.seconds

  def perform(session)
    source = session.source
    return unless source && CLAUDE_SOURCES.include?(source.source_name)

    path = source.source_path
    return if path.blank? || !File.exist?(path)
    return if path.include?("/subagents/")
    return if File.mtime(path) > ACTIVE_SESSION_WINDOW.ago

    title = session.latest_summary&.title.presence || session.custom_title.presence
    return if title.blank?

    write_ai_title(path, File.basename(path, ".jsonl"), title)
  end

  private

  def write_ai_title(path, session_id, title)
    first_line = File.open(path, "r", &:gets)
    return if first_line.nil?

    new_line = JSON.generate(type: "ai-title", aiTitle: title, sessionId: session_id) + "\n"
    existing = parse_json(first_line)

    if existing && existing["type"] == "ai-title"
      return if existing["aiTitle"] == title
      rewrite(path, new_line, skip_first: true)
    else
      rewrite(path, new_line, skip_first: false)
    end
  end

  def parse_json(line)
    JSON.parse(line)
  rescue JSON::ParserError
    nil
  end

  def rewrite(path, new_first_line, skip_first:)
    tmp = "#{path}.recall-title.#{Process.pid}"
    File.open(tmp, "w") do |out|
      out.write(new_first_line)
      File.open(path, "r") do |inp|
        inp.gets if skip_first
        IO.copy_stream(inp, out)
      end
    end
    File.rename(tmp, path)
  end
end
