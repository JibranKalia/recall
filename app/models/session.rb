class Session < ApplicationRecord
  belongs_to :project, counter_cache: true
  has_many :messages, dependent: :destroy

  validates :external_id, presence: true, uniqueness: { scope: :source_type }
  validates :source_name, presence: true
  validates :source_type, presence: true
  validates :source_path, presence: true
  validates :source_checksum, presence: true
  validates :source_size, presence: true

  after_save :sync_fts, if: -> { saved_change_to_title? || saved_change_to_custom_title? || saved_change_to_summary? }
  after_destroy :remove_from_fts

  scope :recent, -> { order(ended_at: :desc) }
  scope :by_source, ->(name) { where(source_name: name) }
  scope :page, ->(num, per: 30) { limit(per).offset([(num.to_i - 1), 0].max * per) }

  def display_title
    custom_title.presence || title.presence&.truncate(120) || "Untitled session"
  end

  def duration
    return nil unless started_at && ended_at
    ended_at - started_at
  end

  def total_tokens
    (total_input_tokens || 0) + (total_output_tokens || 0)
  end

  def to_markdown(thinking: false, tool_details: false)
    lines = []
    lines << "# #{display_title}"
    lines << ""
    lines << "**Session ID:** #{external_id}"
    lines << "**Project:** #{project.path}"
    lines << "**Created:** #{started_at&.strftime('%Y-%m-%d %H:%M')}" if started_at
    lines << "**Model:** #{model}" if model.present?
    lines << ""
    lines << "---"
    lines << ""

    messages.ordered.each do |msg|
      case msg.role
      when "user"
        text = extract_message_text(msg)
        next if text.blank?
        lines << "## User"
        lines << ""
        lines << text
        lines << ""
        lines << "---"
        lines << ""
      when "assistant"
        text = extract_message_text(msg)
        tool_uses = msg.tool_calls
        thinking_text = thinking ? msg.thinking_text : nil

        if text.present? || thinking_text.present?
          lines << "## Assistant"
          lines << ""
          if thinking_text.present?
            lines << "_Thinking:_"
            lines << ""
            lines << thinking_text
            lines << ""
          end
          lines << text if text.present?
          lines << ""
        end

        tool_uses.each do |tc|
          lines << "**Tool: #{tc['name']}**"
          if tool_details && tc["input"]
            lines << ""
            lines << "**Input:**"
            lines << "```json"
            lines << JSON.pretty_generate(tc["input"])
            lines << "```"
          end
          lines << ""
        end
        lines << "---"
        lines << ""
      when "tool_result"
        next unless tool_details
        blocks = msg.parsed_content
        block = blocks.is_a?(Array) ? blocks.first : nil
        content = block&.dig("content") || msg.content_text
        is_error = block&.dig("is_error")

        if content.present?
          lines << "**#{is_error ? 'Error' : 'Output'}:**"
          lines << "```"
          lines << content.to_s.truncate(2000)
          lines << "```"
          lines << ""
        end
      end
    end

    lines.join("\n")
  end

  private

  def extract_message_text(message)
    blocks = message.parsed_content
    if blocks.is_a?(Array)
      blocks.filter_map { |b| b["text"] if b["type"] == "text" }.join("\n\n")
    else
      message.content_text
    end
  end

  def sync_fts
    conn = self.class.connection
    conn.execute(sanitize_sql(["INSERT INTO sessions_fts(sessions_fts, rowid, title, custom_title, summary) VALUES ('delete', ?, ?, ?, ?)",
      id, title_before_last_save, custom_title_before_last_save, summary_before_last_save]))
    conn.execute(sanitize_sql(["INSERT INTO sessions_fts(rowid, title, custom_title, summary) VALUES (?, ?, ?, ?)",
      id, title, custom_title, summary]))
  end

  def remove_from_fts
    self.class.connection.execute(sanitize_sql(
      ["INSERT INTO sessions_fts(sessions_fts, rowid, title, custom_title, summary) VALUES ('delete', ?, ?, ?, ?)",
        id, title, custom_title, summary]))
  end

  def sanitize_sql(args)
    self.class.sanitize_sql_array(args)
  end
end
