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

        all_messages = extract_messages(entries)
        existing_ids = session.messages.pluck(:external_id).compact.to_set
        has_nil_ids = all_messages.any? { |m| m[:external_id].nil? }

        if has_nil_ids || existing_ids.empty?
          # Some messages lack external_ids — replace all to avoid duplicates
          old_count = session.messages.count
          TokenUsage.where(message_id: session.message_ids).delete_all
          session.messages.delete_all
          insert_messages(session, all_messages)
          new_content = all_messages.size != old_count
        else
          new_messages = all_messages.reject { |m| existing_ids.include?(m[:external_id]) }
          insert_messages(session, new_messages)
          backfill_token_usages(session, all_messages)
          new_content = new_messages.any?
        end

        update_session_timestamps(session)
        generate_title(session) if new_content
      end

      def insert_messages(session, messages)
        messages.each do |attrs|
          if attrs[:content_text]
            attrs[:content_text] = attrs[:content_text]
              .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
              .gsub("\x00", "")
          end
          token_usage_attrs = attrs.delete(:token_usage)
          message = session.messages.create!(attrs)
          if token_usage_attrs
            message.create_token_usage!(token_usage_attrs)
          end
        end
      end

      def backfill_token_usages(session, all_messages)
        existing_message_ids = TokenUsage.where(message_id: session.message_ids).pluck(:message_id).to_set
        messages_by_ext_id = session.messages.where.not(external_id: nil).index_by(&:external_id)

        all_messages.each do |attrs|
          tu_attrs = attrs[:token_usage]
          next unless tu_attrs
          next unless attrs[:external_id]

          message = messages_by_ext_id[attrs[:external_id]]
          next unless message
          next if existing_message_ids.include?(message.id)

          message.create_token_usage!(tu_attrs)
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
        Project.find_or_create_by!(path: path) do |p|
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
