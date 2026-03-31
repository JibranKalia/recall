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
      puts "Done."
    end

    def self.reimport_all
      puts "Recall: force re-importing all conversations..."
      SOURCES.each do |source|
        importer = source[:class].new(**source[:args])
        importer.reimport_all
      end
      puts "Done."
    end

    def self.import_source(name)
      source = SOURCES.find { |s|
        s[:args][:source_name] == name || s[:class].name.demodulize.underscore == name
      }
      raise "Unknown source: #{name}" unless source

      puts "Recall: importing #{name}..."
      importer = source[:class].new(**source[:args])
      importer.import_all
      puts "Done."
    end
  end
end
