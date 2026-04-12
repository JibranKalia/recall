module Recall
  module Importers
    class OpenCode < Base
      OPENCODE_DB = File.expand_path("~/.local/share/opencode/opencode.db")

      def initialize
        super
      end

      def import_all
        return unless File.exist?(OPENCODE_DB)

        db = open_db
        sessions = db.execute(<<~SQL)
          SELECT s.id, s.title, s.directory, s.time_created, s.time_updated,
                 p.worktree
          FROM session s
          LEFT JOIN project p ON p.id = s.project_id
          ORDER BY s.time_created
        SQL

        sessions.each do |row|
          @stats[:scanned] += 1
          import_session(db, row)
        rescue => e
          @stats[:errors] += 1
          warn "  Error importing OpenCode session #{row[0]}: #{e.message}"
        end

        db.close
        log_stats
      end

      def reimport_all
        return unless File.exist?(OPENCODE_DB)

        db = open_db
        sessions = db.execute(<<~SQL)
          SELECT s.id, s.title, s.directory, s.time_created, s.time_updated,
                 p.worktree
          FROM session s
          LEFT JOIN project p ON p.id = s.project_id
          ORDER BY s.time_created
        SQL

        sessions.each do |row|
          @stats[:scanned] += 1
          import_session(db, row, force: true)
        rescue => e
          @stats[:errors] += 1
          warn "  Error importing OpenCode session #{row[0]}: #{e.message}"
        end

        db.close
        log_stats
      end

      private

      def source_name
        "open_code"
      end

      def source_type
        "open_code"
      end

      def open_db
        db = SQLite3::Database.new(OPENCODE_DB, readonly: true)
        db.results_as_hash = true
        db
      end

      def import_session(db, row, force: false)
        session_id = row["id"]
        time_updated = row["time_updated"].to_s

        # Use source_path as "open_code:<session_id>" for dedup
        source_path = "open_code:#{session_id}"
        existing = find_session_by_source_path(source_path)

        if Session::Tombstone.tombstoned?(session_id)
          @stats[:skipped] += 1
          return
        end

        # Use time_updated as checksum proxy — if unchanged, skip
        unless force
          if existing&.source_checksum == time_updated
            @stats[:skipped] += 1
            return
          end
        end

        messages_data = load_messages(db, session_id)
        parts_data = load_parts(db, session_id)

        recall_messages = build_messages(messages_data, parts_data)
        return if recall_messages.empty?

        # Determine model from first assistant message
        first_assistant = messages_data.find { |m| m.dig("role") == "assistant" }
        model_id = first_assistant&.dig("modelID")
        provider_id = first_assistant&.dig("providerID")
        model = [provider_id, model_id].compact.join("/").presence

        # Aggregate tokens
        total_input = 0
        total_output = 0
        messages_data.each do |m|
          tokens = m["tokens"]
          next unless tokens
          total_input += tokens["input"].to_i + tokens.dig("cache", "read").to_i
          total_output += tokens["output"].to_i
        end

        cwd = row["worktree"] || row["directory"]

        session_attrs = {
          external_id: session_id,
          source_name: source_name,
          source_type: source_type,
          source_path: source_path,
          source_checksum: time_updated,
          source_size: 0,
          title: row["title"],
          model: model,
          cwd: cwd,
          total_input_tokens: total_input,
          total_output_tokens: total_output
        }

        session = with_retry do
          ActiveRecord::Base.transaction do
            if existing
              update_session(existing, nil, session_attrs, time_updated, 0)
            else
              create_session_from_attrs(recall_messages, session_attrs)
            end
          end
        end

        if session
          @imported_session_ids << session.id
          generate_title(session)
        end

        @stats[:imported] += 1
      end

      def create_session_from_attrs(messages, session_attrs)
        project = find_or_create_project(session_attrs[:cwd])
        source_attrs = session_attrs.slice(:source_name, :source_type, :source_path, :source_checksum, :source_size)
        session = project.sessions.create!(session_attrs.except(:cwd, :source_name, :source_type, :source_path, :source_checksum, :source_size))
        session.create_source!(source_attrs)
        insert_messages(session, messages)
        update_session_timestamps(session)
        session
      end

      def update_session(session, _entries, session_attrs, checksum, size)
        session.update!(
          title: session_attrs[:title],
          model: session_attrs[:model],
          total_input_tokens: session_attrs[:total_input_tokens],
          total_output_tokens: session_attrs[:total_output_tokens]
        )

        session.source.update!(
          source_checksum: checksum,
          source_size: size
        )

        # OpenCode messages have stable external_ids — use append strategy
        all_messages = session_attrs[:_messages] || []

        # If we don't have messages cached, we need to rebuild
        # For updates triggered through this importer, we replace all messages
        old_count = session.messages.count
        msg_ids = session.message_ids
        TokenUsage.where(message_id: msg_ids).delete_all
        Message::Content.where(message_id: msg_ids).delete_all
        session.messages.delete_all

        # Re-extract messages from DB — caller should pass via session_attrs
        # but for safety, return session if counts differ
        session if old_count > 0
      end

      def load_messages(db, session_id)
        rows = db.execute(
          "SELECT id, data, time_created, time_updated FROM message WHERE session_id = ? ORDER BY time_created",
          [session_id]
        )
        rows.map do |row|
          data = JSON.parse(row["data"])
          data["_id"] = row["id"]
          data["_time_created"] = row["time_created"]
          data
        end
      end

      def load_parts(db, session_id)
        rows = db.execute(
          "SELECT id, message_id, data, time_created FROM part WHERE session_id = ? ORDER BY time_created",
          [session_id]
        )
        parts_by_message = Hash.new { |h, k| h[k] = [] }
        rows.each do |row|
          data = JSON.parse(row["data"])
          data["_id"] = row["id"]
          data["_time_created"] = row["time_created"]
          parts_by_message[row["message_id"]] << data
        end
        parts_by_message
      end

      def build_messages(messages_data, parts_data)
        recall_messages = []
        position = 0

        messages_data.each do |msg|
          msg_id = msg["_id"]
          role = msg["role"]
          next unless %w[user assistant].include?(role)

          parts = parts_data[msg_id] || []
          timestamp = msg["_time_created"] ? Time.at(msg["_time_created"] / 1000.0) : nil

          # Model info for token usage
          model_id = msg["modelID"]
          provider_id = msg["providerID"]
          model_str = [provider_id, model_id].compact.join("/").presence

          # Token usage from message data
          tokens = msg["tokens"]
          token_usage = nil
          if tokens && role == "assistant"
            cache = tokens["cache"] || {}
            input_tokens = tokens["input"].to_i
            cached_input = cache["read"].to_i
            token_usage = {
              input_tokens: input_tokens,
              output_tokens: tokens["output"].to_i,
              cache_creation_input_tokens: cache["write"].to_i,
              cache_read_input_tokens: cached_input,
              model: model_str
            }
          end

          # Build content from parts
          text_parts = []
          content_blocks = []

          parts.each do |part|
            case part["type"]
            when "text"
              text = part["text"]
              next if text.blank?
              text_parts << text
              content_blocks << { "type" => "text", "text" => text }

            when "tool"
              tool_name = part["tool"]
              call_id = part["callID"]
              state = part["state"] || {}
              input = state["input"]
              output = state["output"]

              # Tool use message (assistant requesting tool)
              tool_text = "[Tool: #{tool_name}]"
              tool_text += "\n#{input.to_json}" if input
              text_parts << tool_text

              content_blocks << {
                "type" => "tool_use",
                "name" => tool_name,
                "input" => input || {},
                "call_id" => call_id
              }

              # Tool result (output) as separate message
              if output.present?
                output_text = output.is_a?(String) ? output : output.to_json
                recall_messages << {
                  external_id: "#{call_id}_output",
                  parent_external_id: call_id,
                  role: "tool_result",
                  position: position,
                  content_text: output_text.truncate(10_000),
                  content_json: [{ "type" => "tool_result", "call_id" => call_id, "output" => output_text }].to_json,
                  timestamp: timestamp
                }
                position += 1
              end

            when "patch", "file"
              # Code changes — include as text
              file_path = part.dig("state", "input", "filePath") || part.dig("state", "input", "file") || "unknown"
              text_parts << "[#{part['type'].capitalize}: #{file_path}]"
              content_blocks << { "type" => "text", "text" => "[#{part['type'].capitalize}: #{file_path}]" }

            when "reasoning"
              # Skip reasoning blocks (internal model thought)
              next

            when "step-start", "step-finish", "compaction", "agent", "subtask"
              # Control flow parts — skip
              next
            end
          end

          content_text = text_parts.join("\n").presence
          next if content_text.blank? && content_blocks.empty?

          # If we only have tool blocks with no text, still create the message
          content_text ||= content_blocks.map { |b| b["text"] || "[#{b['type']}]" }.join("\n")

          recall_messages << {
            external_id: msg_id,
            parent_external_id: nil,
            role: role,
            position: position,
            content_text: content_text,
            content_json: content_blocks.any? ? content_blocks.to_json : nil,
            timestamp: timestamp,
            token_usage: token_usage
          }
          position += 1
        end

        recall_messages
      end

      # Override — not used for SQLite-based import
      def each_session_file(&block); end
      def extract_session_attrs(entries, path, checksum, size); end
      def extract_messages(entries); end
    end
  end
end
