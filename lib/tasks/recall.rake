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

  desc "Import only OpenCode conversations"
  task import_open_code: :environment do
    Recall::Importer.import_source("open_code")
  end

  desc "Force re-import everything (ignores checksums)"
  task reimport: :environment do
    Recall::Importer.reimport_all
  end

  desc "Generate titles for sessions missing them (enqueues background jobs)"
  task generate_titles: :environment do
    batch_size = (ENV["BATCH_SIZE"] || 50).to_i
    sessions = Session.where(custom_title: nil).order(started_at: :desc).limit(batch_size)
    count = sessions.count
    sessions.each { |s| GenerateSummaryJob.perform_later(s) }
    puts "Enqueued #{count} title generation jobs."
  end

  desc "Regenerate all session titles (enqueues background jobs)"
  task regenerate_titles: :environment do
    batch_size = (ENV["BATCH_SIZE"] || 50).to_i
    Session.where.not(custom_title: nil).update_all(custom_title: nil)
    Session::Summary.delete_all
    sessions = Session.where(custom_title: nil).order(started_at: :desc).limit(batch_size)
    count = sessions.count
    sessions.each { |s| GenerateSummaryJob.perform_later(s) }
    puts "Enqueued #{count} title generation jobs."
  end

  desc "Reindex all sessions into Algolia"
  task algolia_reindex: :environment do
    unless Session.algolia_enabled?
      abort "Algolia not configured. Set ALGOLIA_WRITE_API_KEY (and optionally ALGOLIA_APP_ID)."
    end

    batch_size = (ENV["BATCH_SIZE"] || 500).to_i
    puts "Reindexing #{Session.count} sessions into Algolia..."
    Session.algolia_reindex!(batch_size)
    puts "Done."
  end

  desc "Clear the Algolia index for the current Rails env"
  task algolia_clear: :environment do
    unless Session.algolia_enabled?
      abort "Algolia not configured. Set ALGOLIA_WRITE_API_KEY (and optionally ALGOLIA_APP_ID)."
    end
    Session.algolia_clear_index!
    puts "Cleared Algolia index."
  end

  desc "Show import stats"
  task stats: :environment do
    puts "Recall Stats"
    puts "-" * 40
    Session::Source.group(:source_name).count.each do |source, count|
      puts "  #{source}: #{count} sessions"
    end
    puts "  Total: #{Session.count} sessions, #{Message.count} messages"
    puts ""
    puts "Projects: #{Project.count}"
    Project.order(:name).each do |project|
      types = project.source_types.join(", ")
      puts "  #{project.name} (#{types}) — #{project.sessions_count} sessions"
    end
  end
end
