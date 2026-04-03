module Recall
  module Importers
    class Codex < Base
      CODEX_DIR = File.expand_path("~/.codex")
      STATE_DB = File.join(CODEX_DIR, "state_5.sqlite")

      def initialize
        super
        @thread_metadata = load_thread_metadata
      end

      private

      def each_session_file(&block)
        sessions_dir = File.join(CODEX_DIR, "sessions")
        return unless Dir.exist?(sessions_dir)

        Dir.glob(File.join(sessions_dir, "**", "*.jsonl")).each do |path|
          yield path
        end
      end

      def source_name
        "codex"
      end

      def source_type
        "codex"
      end

      def extract_session_attrs(entries, path, checksum, size)
        meta_entry = entries.find { |e| e["type"] == "session_meta" }
        payload = meta_entry&.dig("payload") || {}

        session_id = payload["id"] || extract_session_id_from_path(path)
        return nil if session_id.nil?

        # Get thread metadata from SQLite
        thread = @thread_metadata[session_id] || {}

        # Find model from turn_context
        turn_context = entries.find { |e| e["type"] == "turn_context" }
        model = turn_context&.dig("payload", "model") || thread["model"]

        # Find first user message for title
        title = thread["title"].presence || find_first_user_text(entries)&.truncate(500)

        # Token count from thread metadata
        tokens_used = thread["tokens_used"].to_i

        {
          external_id: session_id,
          source_name: source_name,
          source_type: source_type,
          source_path: path,
          source_checksum: checksum,
          source_size: size,
          title: title,
          model: model,
          git_branch: thread["git_branch"],
          cwd: payload["cwd"] || thread["cwd"],
          total_input_tokens: tokens_used / 2,  # approximate split
          total_output_tokens: tokens_used / 2
        }
      end

      def extract_messages(entries)
        messages = []
        position = 0

        entries.each do |entry|
          case entry["type"]
          when "response_item"
            msg = extract_response_item(entry, position)
            if msg
              messages << msg
              position += 1
            end
          when "event_msg"
            msg = extract_event_message(entry, position)
            if msg
              messages << msg
              position += 1
            end
          end
        end

        messages
      end

      def extract_response_item(entry, position)
        payload = entry["payload"] || {}
        role = normalize_role(payload["role"])
        return nil unless role
        return nil if payload["type"] == "reasoning"

        content = payload["content"]
        return nil unless content.is_a?(Array)

        text_parts = content.filter_map do |block|
          case block["type"]
          when "input_text", "output_text"
            block["text"]
          when "tool_use"
            "[Tool: #{block['name']}]"
          end
        end

        content_text = text_parts.join("\n").presence
        return nil if content_text.blank?

        # Normalize block types: input_text/output_text → text for consistent rendering
        normalized_content = content.map do |block|
          case block["type"]
          when "input_text", "output_text"
            block.merge("type" => "text", "text" => block["text"])
          else
            block
          end
        end

        timestamp = entry["timestamp"] ? Time.parse(entry["timestamp"]) : nil

        {
          external_id: nil,
          parent_external_id: nil,
          role: role,
          position: position,
          content_text: content_text,
          content_json: normalized_content.to_json,
          model: nil,
          input_tokens: nil,
          output_tokens: nil,
          timestamp: timestamp
        }
      end

      def extract_event_message(entry, position)
        payload = entry["payload"] || {}
        return nil unless payload["type"] == "agent_message"
        return nil if payload["phase"] == "thinking"

        text = payload["message"]
        return nil if text.blank?

        timestamp = entry["timestamp"] ? Time.parse(entry["timestamp"]) : nil

        {
          external_id: nil,
          parent_external_id: nil,
          role: "assistant",
          position: position,
          content_text: text,
          content_json: [{ "type" => "text", "text" => text, "phase" => payload["phase"] }].to_json,
          model: nil,
          input_tokens: nil,
          output_tokens: nil,
          timestamp: timestamp
        }
      end

      def normalize_role(role)
        case role
        when "user" then "user"
        when "assistant" then "assistant"
        when "developer" then "system"
        else nil
        end
      end

      def find_first_user_text(entries)
        entry = entries.find { |e|
          e["type"] == "event_msg" && e.dig("payload", "type") == "user_message"
        }
        entry&.dig("payload", "message")
      end

      def extract_session_id_from_path(path)
        # rollout-2026-03-20T06-13-15-019d0af3-1359-7043-a44f-09566839d49d.jsonl
        basename = File.basename(path, ".jsonl")
        match = basename.match(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i)
        match&.[](1)
      end

      def load_thread_metadata
        return {} unless File.exist?(STATE_DB)

        db = SQLite3::Database.new(STATE_DB, readonly: true)
        db.results_as_hash = true
        rows = db.execute("SELECT id, title, cwd, model, git_branch, git_sha, tokens_used FROM threads")
        db.close

        rows.each_with_object({}) { |row, hash| hash[row["id"]] = row }
      rescue => e
        warn "  Warning: Could not read Codex state DB: #{e.message}"
        {}
      end
    end
  end
end
