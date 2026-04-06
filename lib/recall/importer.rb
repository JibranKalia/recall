module Recall
  class Importer
    SOURCES = [
      { class: Importers::ClaudeCode, args: { base_dir: "~/.claude", source_name: "claude" } },
      { class: Importers::ClaudeCode, args: { base_dir: "~/.claude-work", source_name: "claude_work" } },
      { class: Importers::Codex, args: {} }
    ].freeze

    def self.import_all
      puts "Recall: importing conversations..."
      SOURCES.each do |source|
        importer = source[:class].new(**source[:args])
        importer.import_all
      end
      rebuild_fts
      puts "Done."
    end

    def self.reimport_all
      puts "Recall: force re-importing all conversations..."
      SOURCES.each do |source|
        importer = source[:class].new(**source[:args])
        importer.reimport_all
      end
      rebuild_fts
      puts "Done."
    end

    def self.reimport_session(session)
      source = session.source
      return unless source&.source_path

      importer_config = SOURCES.find { |s| s[:args][:source_name].to_s == source.source_name.to_s } ||
                        SOURCES.find { |s| s[:class].name.demodulize.underscore == source.source_type.to_s }
      return unless importer_config

      importer = importer_config[:class].new(**importer_config[:args])
      importer.send(:import_file, source.source_path, force: true)
      rebuild_fts
    end

    def self.import_source(name)
      source = SOURCES.find { |s|
        s[:args][:source_name] == name || s[:class].name.demodulize.underscore == name
      }
      raise "Unknown source: #{name}" unless source

      puts "Recall: importing #{name}..."
      importer = source[:class].new(**source[:args])
      importer.import_all
      rebuild_fts
      puts "Done."
    end

    def self.rebuild_fts
      print "  Rebuilding message search index..."
      ActiveRecord::Base.connection.execute("INSERT INTO messages_fts(messages_fts) VALUES('rebuild')")
      puts " done."
      print "  Rebuilding session search index..."
      ActiveRecord::Base.connection.execute("INSERT INTO sessions_fts(sessions_fts) VALUES('rebuild')")
      puts " done."
    end
  end
end
