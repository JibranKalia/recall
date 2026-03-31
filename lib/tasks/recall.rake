namespace :recall do
  desc "Import all conversations from all sources"
  task import: :environment do
    Recall::Importer.import_all
  end

  desc "Import only Claude Code conversations (personal)"
  task import_claude: :environment do
    Recall::Importer.import_source("claude")
  end

  desc "Import only Claude Code conversations (work)"
  task import_claude_work: :environment do
    Recall::Importer.import_source("claude_work")
  end

  desc "Import only Codex conversations"
  task import_codex: :environment do
    Recall::Importer.import_source("codex")
  end

  desc "Force re-import everything (ignores checksums)"
  task reimport: :environment do
    Recall::Importer.reimport_all
  end

  desc "Show import stats"
  task stats: :environment do
    puts "Recall Stats"
    puts "-" * 40
    Session.group(:source_name).count.each do |source, count|
      puts "  #{source}: #{count} sessions"
    end
    puts "  Total: #{Session.count} sessions, #{Message.count} messages"
    puts ""
    puts "Projects: #{Project.count}"
    Project.includes(:sessions).order(:name).each do |project|
      puts "  #{project.name} (#{project.source_type}) — #{project.sessions_count} sessions"
    end
  end
end
