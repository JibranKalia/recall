module Recall
  class Importer
    def self.sources
      sources = []
      Array(Recall::Config.claude_code_dirs).each do |entry|
        sources << { class: Importers::ClaudeCode, args: { base_dir: entry[:path], source_name: entry[:name] } }
      end
      sources << { class: Importers::Codex, args: {} } if Recall::Config.codex_dir
      sources << { class: Importers::OpenCode, args: {} } if Recall::Config.opencode_db
      sources
    end

    def self.import_all
      with_import_run do
        puts "Recall: importing conversations..."
        session_ids = []
        sources.each do |source|
          importer = source[:class].new(**source[:args])
          importer.import_all
          session_ids.concat(importer.imported_session_ids)
        end
        sync_search_backends(session_ids)
        puts "Done."
      end
    end

    def self.reimport_all
      with_import_run do
        puts "Recall: force re-importing all conversations..."
        sources.each do |source|
          importer = source[:class].new(**source[:args])
          importer.reimport_all
        end
        rebuild_search_backends
        puts "Done."
      end
    end

    def self.import_source(name)
      source = sources.find { |s|
        s[:args][:source_name] == name || s[:class].name.demodulize.underscore == name
      }
      raise "Unknown source: #{name}" unless source

      with_import_run do
        puts "Recall: importing #{name}..."
        importer = source[:class].new(**source[:args])
        importer.import_all
        sync_search_backends(importer.imported_session_ids)
        puts "Done."
      end
    end

    def self.reimport_session(session)
      source = session.source
      return unless source&.source_path

      current_sources = sources
      importer_config = current_sources.find { |s| s[:args][:source_name].to_s == source.source_name.to_s } ||
                        current_sources.find { |s| s[:class].name.demodulize.underscore == source.source_type.to_s }
      return unless importer_config

      importer = importer_config[:class].new(**importer_config[:args])
      importer.send(:import_file, source.source_path, force: true)
      sync_search_backends([ session.id ])
    end

    # Incremental sync of every search backend for the given changed sessions.
    # Postgres tsvector columns are GENERATED, so they self-maintain on
    # insert/update — only Algolia needs an explicit push.
    def self.sync_search_backends(session_ids)
      sync_algolia(session_ids)
    end

    # Full rebuild of every search backend. Used by `reimport_all` when
    # checksums are bypassed and the full corpus has been re-written.
    def self.rebuild_search_backends
      rebuild_algolia
    end

    # Incremental Algolia sync — only indexes messages whose session was
    # touched during this import run. Full reindex of all ~32K records
    # every import is wasteful (320x overkill for a typical delta); this
    # ships just the N messages that actually changed.
    def self.sync_algolia(session_ids)
      return unless Session.algolia_enabled?
      return if session_ids.empty?

      messages = Message.where(session_id: session_ids).includes(:content, session: :source).to_a
      indexable = messages.select(&:algolia_indexable?)

      if indexable.empty?
        puts "  Algolia: nothing indexable in #{session_ids.size} session(s)."
        return
      end

      print "  Algolia: pushing #{indexable.size} messages from #{session_ids.size} session(s)..."
      indexable.each_slice(500) do |batch|
        Message.algolia_index_objects(batch)
      end
      puts " done."
    end

    def self.rebuild_algolia
      return unless Session.algolia_enabled?
      print "  Rebuilding Algolia message index..."
      Message.algolia_reindex!
      puts " done."
    end

    def self.with_import_run
      run = ImportRun.create!(started_at: Time.current)
      yield
      run.complete!
    rescue => e
      run&.fail!
      raise
    end
  end
end
