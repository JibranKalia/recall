require "optparse"
require_relative "../../config/environment"

class RecallCLI
  def initialize(args)
    @command = args.shift
    @args = args
    @options = {}
  end

  def run
    case @command
    when "search", "s"
      search
    when "import", "i"
      import
    when "stats"
      stats
    when "projects"
      projects
    when "sessions"
      sessions
    when "show"
      show
    else
      usage
    end
  end

  private

  def search
    parse_options! do |opts|
      opts.banner = "Usage: recall search \"query\" [options]"
      opts.on("--source NAME", "Filter by source (claude, claude_work, codex)") { |v| @options[:source] = v }
      opts.on("--project NAME", "Filter by project name") { |v| @options[:project] = v }
      opts.on("--limit N", Integer, "Max results (default 20)") { |v| @options[:limit] = v }
    end

    query = @args.join(" ")
    if query.blank?
      puts @parser
      return
    end

    limit = @options[:limit] || 20
    results = Message.search(query, limit: limit)

    source = @options[:source]
    project = @options[:project]

    if source || project
      session_ids = results.map(&:session_id).uniq
      sessions = Session.where(id: session_ids).includes(:project)
      sessions = sessions.joins(:source).where(session_sources: { source_name: source }) if source
      sessions = sessions.joins(:project).where(projects: { name: project }) if project
      allowed_ids = sessions.pluck(:id).to_set
      results = results.select { |m| allowed_ids.include?(m.session_id) }
    end

    if results.empty?
      puts "No results for: #{query}"
      return
    end

    session_map = Session.where(id: results.map(&:session_id).uniq).includes(:project).index_by(&:id)

    results.each do |msg|
      session = session_map[msg.session_id]
      next unless session

      date = session.started_at&.strftime("%Y-%m-%d %H:%M") || "unknown"
      project_name = session.project&.name || "unknown"
      short_id = session.external_id[0..7]

      puts "\033[36m[#{session.source_name}]\033[0m #{project_name} | #{date} | session #{short_id}"
      puts "  > #{session.display_title}"
      snippet = msg.respond_to?(:snippet) ? msg.snippet : msg.content_text&.truncate(200)
      if snippet
        formatted = snippet.gsub("<mark>", "\033[1m").gsub("</mark>", "\033[0m")
        puts "  #{formatted}"
      end
      puts ""
    end

    puts "#{results.size} result(s)"
  end

  def import
    parse_options! do |opts|
      opts.banner = "Usage: recall import [options]"
      opts.on("--source NAME", "Import only one source") { |v| @options[:source] = v }
      opts.on("--force", "Re-import everything") { @options[:force] = true }
    end

    if @options[:force]
      Recall::Importer.reimport_all
    elsif @options[:source]
      Recall::Importer.import_source(@options[:source])
    else
      Recall::Importer.import_all
    end
  end

  def stats
    puts "Recall Stats"
    puts "-" * 40
    Session::Source.group(:source_name).count.each do |source, count|
      puts "  #{source}: #{count} sessions"
    end
    puts "  Total: #{Session.count} sessions, #{Message.count} messages"
  end

  def projects
    parse_options! do |opts|
      opts.banner = "Usage: recall projects [options]"
      opts.on("--domain NAME", Project::DOMAINS, "Filter by domain (#{Project::DOMAINS.join(', ')})") { |v| @options[:domain] = v }
    end

    scope = Project.order(:name)
    scope = scope.by_domain(@options[:domain]) if @options[:domain]

    scope.each do |p|
      types = p.source_types.join(", ")
      puts "  [#{p.domain}] #{p.name} (#{types}) — #{p.sessions_count} sessions"
    end
  end

  def sessions
    parse_options! do |opts|
      opts.banner = "Usage: recall sessions [PROJECT_NAME] [options]"
      opts.on("--domain NAME", Project::DOMAINS, "Filter by domain (#{Project::DOMAINS.join(', ')})") { |v| @options[:domain] = v }
      opts.on("--from DATE", "Start date in CST (e.g. 2026-04-01)") { |v| @options[:from] = v }
      opts.on("--to DATE", "End date in CST (e.g. 2026-04-05)") { |v| @options[:to] = v }
      opts.on("--limit N", Integer, "Max results (default 50)") { |v| @options[:limit] = v }
    end

    project_name = @args.first
    limit = @options[:limit] || 50

    scope = Session.includes(:project).recent
    scope = scope.joins(:project).where(projects: { name: project_name }) if project_name
    scope = scope.joins(:project).where(projects: { domain: @options[:domain] }) if @options[:domain]

    cst = ActiveSupport::TimeZone["America/Chicago"]
    if @options[:from]
      scope = scope.where("sessions.started_at >= ?", cst.parse(@options[:from]).beginning_of_day)
    end
    if @options[:to]
      scope = scope.where("sessions.started_at <= ?", cst.parse(@options[:to]).end_of_day)
    end

    scope.limit(limit).each do |s|
      date = s.started_at&.in_time_zone("America/Chicago")&.strftime("%Y-%m-%d %H:%M") || "unknown"
      puts "  [#{s.source_name}] #{date} | #{s.display_title}"
    end
  end

  def show
    parse_options! do |opts|
      opts.banner = "Usage: recall show <session_id_or_url> [options]"
      opts.on("--thinking", "Include thinking blocks") { @options[:thinking] = true }
      opts.on("--tools", "Include tool results") { @options[:tools] = true }
    end

    identifier = @args.first
    if identifier.blank?
      puts @parser
      return
    end

    session_id = identifier[%r{/sessions/(\d+)}, 1] || identifier
    session = Session.find_by(id: session_id)

    unless session
      puts "Session not found: #{identifier}"
      return
    end

    puts "# #{session.display_title}"
    puts ""
    puts "Session ID: #{session.external_id}"
    puts "Project:    #{session.project&.path}"
    puts "Started:    #{session.started_at&.in_time_zone('America/Chicago')&.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    puts "Ended:      #{session.ended_at&.in_time_zone('America/Chicago')&.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    puts "Duration:   #{format_duration(session.duration)}" if session.duration
    puts "Model:      #{session.model}" if session.model.present?
    puts "Cost:       #{session.estimated_cost_formatted}" if session.estimated_cost_formatted
    puts ""
    puts "=" * 80
    puts ""

    session.messages.ordered.includes(:content).each do |msg|
      next if msg.role == "system"
      next if msg.role == "tool_result" && !@options[:tools]

      ts = msg.timestamp&.in_time_zone("America/Chicago")&.strftime("%Y-%m-%d %H:%M:%S") || ""
      role_label = format_role(msg.role)

      puts "\033[2m[#{ts}]\033[0m #{role_label}"
      puts ""

      blocks = msg.parsed_content
      if blocks.is_a?(Array)
        blocks.each do |block|
          case block["type"]
          when "text"
            next if block["text"].blank?
            puts block["text"]
            puts ""
          when "thinking"
            next unless @options[:thinking]
            puts "\033[2m[thinking] #{block['thinking']&.truncate(500)}\033[0m"
            puts ""
          when "tool_use"
            summary = tool_call_summary(block["name"], block["input"])
            line = "  \033[33m▶ #{block['name']}\033[0m"
            line += " #{summary}" if summary.present?
            puts line
          end
        end
      elsif msg.content_text.present?
        puts msg.content_text
        puts ""
      end

      puts "-" * 80
      puts ""
    end
  end

  def format_role(role)
    case role
    when "user"        then "\033[36m## User\033[0m"
    when "assistant"   then "\033[32m## Assistant\033[0m"
    when "tool_result" then "\033[33m## Tool Result\033[0m"
    else role
    end
  end

  def format_duration(seconds)
    return nil unless seconds
    hours = (seconds / 3600).to_i
    mins = ((seconds % 3600) / 60).to_i
    secs = (seconds % 60).to_i
    if hours > 0
      "#{hours}h #{mins}m #{secs}s"
    elsif mins > 0
      "#{mins}m #{secs}s"
    else
      "#{secs}s"
    end
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

  def parse_options!
    @parser = OptionParser.new do |opts|
      yield opts
    end
    @parser.parse!(@args)
  end

  def usage
    puts <<~USAGE
      Usage: recall <command> [options]

      Commands:
        search "query"    Full-text search across all conversations
        import            Import/update all sources
        stats             Show counts by source
        projects          List all projects
        sessions [NAME]   List recent sessions (optionally filter by project)
        show <id|url>     Show full session transcript

      Run `recall <command> --help` for command-specific options.
    USAGE
  end
end

RecallCLI.new(ARGV.dup).run
