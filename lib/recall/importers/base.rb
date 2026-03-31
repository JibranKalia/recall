module Recall
  module Importers
    class Base
      attr_reader :stats

      def initialize
        @stats = { scanned: 0, imported: 0, skipped: 0, errors: 0 }
      end

      def import_all
        each_session_file do |path|
          @stats[:scanned] += 1
          import_if_changed(path)
        end
        log_stats
      end

      def reimport_all
        each_session_file do |path|
          @stats[:scanned] += 1
          import_file(path, force: true)
        end
        log_stats
      end

      private

      def each_session_file(&block)
        raise NotImplementedError
      end

      def source_name
        raise NotImplementedError
      end

      def source_type
        raise NotImplementedError
      end

      def import_if_changed(path)
        size = File.size(path)
        existing = Session.find_by(source_path: path)

        if existing && existing.source_size == size
          checksum = Digest::SHA256.file(path).hexdigest
          if existing.source_checksum == checksum
            @stats[:skipped] += 1
            return
          end
        end

        import_file(path)
      rescue => e
        @stats[:errors] += 1
        warn "  Error importing #{path}: #{e.message}"
      end

      def import_file(path, force: false)
        checksum = Digest::SHA256.file(path).hexdigest
        size = File.size(path)

        existing = Session.find_by(source_path: path)
        unless force
          if existing&.source_checksum == checksum
            @stats[:skipped] += 1
            return
          end
        end

        ActiveRecord::Base.transaction do
          existing&.destroy!

          entries = parse_jsonl(path)
          session_attrs = extract_session_attrs(entries, path, checksum, size)
          return if session_attrs.nil?

          project = find_or_create_project(session_attrs[:cwd])
          session = project.sessions.create!(session_attrs.except(:cwd))

          messages = extract_messages(entries)
          messages.each do |attrs|
            # Strip null bytes and invalid UTF-8 that break SQLite FTS5 triggers
            if attrs[:content_text]
              attrs[:content_text] = attrs[:content_text]
                .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
                .gsub("\x00", "")
            end
            session.messages.create!(attrs)
          end

          session.update_columns(
            started_at: session.messages.minimum(:timestamp),
            ended_at: session.messages.maximum(:timestamp)
          )
        end

        @stats[:imported] += 1
      end

      def parse_jsonl(path)
        entries = []
        File.foreach(path) do |line|
          line.strip!
          next if line.empty?
          entries << JSON.parse(line)
        rescue JSON::ParserError
          next
        end
        entries
      end

      def find_or_create_project(cwd)
        path = cwd || "unknown"
        name = File.basename(path)
        Project.find_or_create_by!(path: path, source_type: source_type) do |p|
          p.name = name
        end
      end

      def log_stats
        puts "  #{source_name}: scanned=#{@stats[:scanned]} imported=#{@stats[:imported]} skipped=#{@stats[:skipped]} errors=#{@stats[:errors]}"
      end
    end
  end
end
