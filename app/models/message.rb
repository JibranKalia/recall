class Message < ApplicationRecord
  include Searchable

  belongs_to :session, counter_cache: true

  validates :role, presence: true, inclusion: { in: %w[user assistant system tool_result] }
  validates :position, presence: true

  scope :ordered, -> { order(:position) }

  def parsed_content
    return nil if content_json.blank?
    JSON.parse(content_json)
  rescue JSON::ParserError
    nil
  end

  def tool_calls
    blocks = parsed_content
    return [] unless blocks.is_a?(Array)
    blocks.select { |b| b["type"] == "tool_use" }
  end

  def thinking_text
    blocks = parsed_content
    return nil unless blocks.is_a?(Array)
    blocks.select { |b| b["type"] == "thinking" }.map { |b| b["thinking"] }.compact.join("\n")
  end
end
