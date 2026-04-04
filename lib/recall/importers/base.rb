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

        entries = parse_jsonl(path)
        session_attrs = extract_session_attrs(entries, path, checksum, size)
        return if session_attrs.nil?

        ActiveRecord::Base.transaction do
          if existing
            update_session(existing, entries, session_attrs, checksum, size)
          else
            create_session(entries, session_attrs)
          end
        end

        @stats[:imported] += 1
      end

      def create_session(entries, session_attrs)
        project = find_or_create_project(session_attrs[:cwd])
        session = project.sessions.create!(session_attrs.except(:cwd))
        insert_messages(session, extract_messages(entries))
        update_session_timestamps(session)
        generate_title(session)
      end

      def update_session(session, entries, session_attrs, checksum, size)
        session.update!(
          source_checksum: checksum,
          source_size: size,
          title: session_attrs[:title],
          model: session_attrs[:model],
          total_input_tokens: session_attrs[:total_input_tokens],
          total_output_tokens: session_attrs[:total_output_tokens]
        )

        existing_ids = session.messages.pluck(:external_id).to_set
        new_messages = extract_messages(entries).reject { |m| existing_ids.include?(m[:external_id]) }
        insert_messages(session, new_messages)
        update_session_timestamps(session)
        generate_title(session) if new_messages.any?
      end

      def insert_messages(session, messages)
        messages.each do |attrs|
          if attrs[:content_text]
            attrs[:content_text] = attrs[:content_text]
              .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
              .gsub("\x00", "")
          end
          session.messages.create!(attrs)
        end
      end

      def update_session_timestamps(session)
        session.update_columns(
          started_at: session.messages.minimum(:timestamp),
          ended_at: session.messages.maximum(:timestamp)
        )
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

      def generate_title(session)
        GenerateSummaryJob.perform_later(session)
      end

      def log_stats
        puts "  #{source_name}: scanned=#{@stats[:scanned]} imported=#{@stats[:imported]} skipped=#{@stats[:skipped]} errors=#{@stats[:errors]}"
      end
    end
  end
end
