module Recall
  module Importers
    class ClaudeCode < Base
      SKIP_TYPES = %w[file-history-snapshot last-prompt permission-mode queue-operation].freeze

      def initialize(base_dir:, source_name:)
        super()
        @base_dir = File.expand_path(base_dir)
        @source_name_value = source_name
      end

      private

      def each_session_file(&block)
        projects_dir = File.join(@base_dir, "projects")
        return unless Dir.exist?(projects_dir)

        Dir.glob(File.join(projects_dir, "**", "*.jsonl")).each do |path|
          next if File.basename(path) == "memory.jsonl"
          yield path
        end
      end

      def source_name
        @source_name_value
      end

      def source_type
        "claude_code"
      end

      def extract_session_attrs(entries, path, checksum, size)
        message_entries = entries.reject { |e| SKIP_TYPES.include?(e["type"]) }
        return nil if message_entries.empty?

        first_msg = message_entries.first
        # Use path relative to base_dir as external_id — subagents share parent's sessionId,
        # and short filenames like agent-ab12c8b can collide across projects
        session_id = path.delete_prefix(@base_dir + "/")

        # Find first user message for title
        first_user = message_entries.find { |e| e["type"] == "user" && e.dig("message", "role") == "user" }
        title = extract_text_content(first_user&.dig("message", "content"))&.truncate(500)

        # Find model from first assistant message
        first_assistant = message_entries.find { |e| e["type"] == "assistant" }
        model = first_assistant&.dig("message", "model")

        # Aggregate tokens
        input_tokens = 0
        output_tokens = 0
        message_entries.select { |e| e["type"] == "assistant" }.each do |e|
          usage = e.dig("message", "usage")
          next unless usage
          input_tokens += usage["input_tokens"].to_i
          output_tokens += usage["output_tokens"].to_i
        end

        {
          external_id: session_id,
          source_name: source_name,
          source_type: source_type,
          source_path: path,
          source_checksum: checksum,
          source_size: size,
          title: title,
          model: model,
          git_branch: first_msg["gitBranch"],
          cwd: first_msg["cwd"] || entries.lazy.filter_map { |e| e["cwd"] }.first,
          total_input_tokens: input_tokens,
          total_output_tokens: output_tokens
        }
      end

      def extract_messages(entries)
        message_entries = entries.reject { |e| SKIP_TYPES.include?(e["type"]) }
        messages = []
        position = 0

        message_entries.each do |entry|
          type = entry["type"]
          next unless %w[user assistant].include?(type)

          message = entry["message"]
          next unless message

          role = if type == "user" && has_tool_results?(message["content"])
            "tool_result"
          else
            message["role"] || type
          end

          content_text = extract_text_content(message["content"])
          next if content_text.blank? && role != "tool_result"

          # For tool_results, also grab the output text
          if role == "tool_result"
            content_text = extract_tool_result_text(message["content"], entry["toolUseResult"])
          end

          timestamp = entry["timestamp"] ? Time.parse(entry["timestamp"]) : nil

          messages << {
            external_id: entry["uuid"],
            parent_external_id: entry["parentUuid"],
            role: role,
            position: position,
            content_text: content_text,
            content_json: message["content"].to_json,
            model: message["model"],
            input_tokens: message.dig("usage", "input_tokens"),
            output_tokens: message.dig("usage", "output_tokens"),
            timestamp: timestamp
          }
          position += 1
        end

        messages
      end

      def extract_text_content(content)
        return content if content.is_a?(String)
        return nil unless content.is_a?(Array)

        parts = content.filter_map do |block|
          case block["type"]
          when "text"
            block["text"]
          when "thinking"
            block["thinking"].presence
          when "tool_use"
            "[Tool: #{block['name']}]"
          end
        end
        parts.join("\n").presence
      end

      def extract_tool_result_text(content, tool_use_result)
        parts = []

        if content.is_a?(Array)
          content.each do |block|
            next unless block["type"] == "tool_result"
            parts << block["content"].to_s if block["content"].present?
          end
        end

        if tool_use_result.is_a?(Hash)
          parts << tool_use_result["stdout"] if tool_use_result["stdout"].present?
          parts << tool_use_result["stderr"] if tool_use_result["stderr"].present?
        elsif tool_use_result.is_a?(String)
          parts << tool_use_result
        end

        parts.join("\n").presence
      end

      def has_tool_results?(content)
        return false unless content.is_a?(Array)
        content.any? { |b| b["type"] == "tool_result" }
      end
    end
  end
end
