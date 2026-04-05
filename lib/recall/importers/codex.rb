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

        # Collect token_count events to attach to the preceding response_item
        token_counts = extract_token_counts(entries)

        # Find model from turn_context for token_usage records
        turn_context = entries.find { |e| e["type"] == "turn_context" }
        codex_model = turn_context&.dig("payload", "model")

        entries.each_with_index do |entry, idx|
          case entry["type"]
          when "response_item"
            msg = extract_response_item(entry, position)
            if msg
              # Find the next token_count event after this response_item
              tc = token_counts[idx]
              if tc
                last_usage = tc["last_token_usage"] || {}
                msg[:token_usage] = {
                  input_tokens: last_usage["input_tokens"].to_i,
                  output_tokens: last_usage["output_tokens"].to_i,
                  cache_creation_input_tokens: 0,
                  cache_read_input_tokens: last_usage["cached_input_tokens"].to_i,
                  model: codex_model
                }
              end
              messages << msg
              position += 1
            end
          end
        end

        messages
      end

      def extract_response_item(entry, position)
        payload = entry["payload"] || {}
        ptype = payload["type"]

        return nil if ptype == "reasoning"

        case ptype
        when "message"
          extract_message_item(payload, entry, position)
        when "function_call"
          extract_function_call(payload, entry, position)
        when "function_call_output"
          extract_function_call_output(payload, entry, position)
        end
      end

      def extract_message_item(payload, entry, position)
        role = normalize_role(payload["role"])
        return nil unless role

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
          timestamp: timestamp,
          hidden: boilerplate_message?(role, content_text)
        }
      end

      def extract_function_call(payload, entry, position)
        name = payload["name"]
        args = payload["arguments"]
        call_id = payload["call_id"]
        content_text = "[Tool: #{name}]\n#{args}"

        # Parse arguments JSON so render_tool_use can display it
        input = begin
          JSON.parse(args)
        rescue
          { "raw" => args }
        end

        timestamp = entry["timestamp"] ? Time.parse(entry["timestamp"]) : nil

        {
          external_id: call_id,
          parent_external_id: nil,
          role: "assistant",
          position: position,
          content_text: content_text,
          content_json: [{ "type" => "tool_use", "name" => name, "input" => input, "call_id" => call_id }].to_json,
          model: nil,
          input_tokens: nil,
          output_tokens: nil,
          timestamp: timestamp
        }
      end

      def extract_function_call_output(payload, entry, position)
        call_id = payload["call_id"]
        output = payload["output"].to_s
        content_text = output.truncate(10_000)

        timestamp = entry["timestamp"] ? Time.parse(entry["timestamp"]) : nil

        {
          external_id: "#{call_id}_output",
          parent_external_id: call_id,
          role: "tool_result",
          position: position,
          content_text: content_text,
          content_json: [{ "type" => "tool_result", "call_id" => call_id, "output" => output }].to_json,
          model: nil,
          input_tokens: nil,
          output_tokens: nil,
          timestamp: timestamp
        }
      end

      # Detect Codex boilerplate: developer system instructions, environment_context, AGENTS.md
      def boilerplate_message?(role, content_text)
        return true if role == "system"  # developer instructions are always boilerplate
        return false unless role == "user"
        content_text&.start_with?("<environment_context>") ||
          content_text&.start_with?("# AGENTS.md instructions for")
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

      # Map each response_item index to its following token_count event
      def extract_token_counts(entries)
        counts = {}
        last_response_idx = nil

        entries.each_with_index do |entry, idx|
          case entry["type"]
          when "response_item"
            last_response_idx = idx
          when "event_msg"
            if last_response_idx && entry.dig("payload", "type") == "token_count"
              counts[last_response_idx] = entry.dig("payload", "info") || {}
              last_response_idx = nil
            end
          end
        end

        counts
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
