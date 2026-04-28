class Message < ApplicationRecord
  include Searchable
  include AlgoliaIndex

  belongs_to :session, counter_cache: true
  has_one :content, dependent: :destroy
  has_one :token_usage, dependent: :destroy

  validates :role, presence: true, inclusion: { in: %w[user assistant system tool_result] }
  validates :position, presence: true

  scope :ordered, -> { order(:position) }
  scope :for_summarization, -> { includes(:content).where.not(role: "tool_result").ordered }

  attr_accessor :search_source

  # `with_pg_search_highlight` adds a `pg_search_highlight` AR attribute on
  # content-search hits. Session-level hits don't have one. Callers (views,
  # CLI) ask for `snippet`; bridge both cases here.
  def snippet
    return @snippet if defined?(@snippet)
    return attributes["pg_search_highlight"] if has_attribute?("pg_search_highlight")
    nil
  end

  def tool_only?
    return false unless role == "assistant"
    content_text.to_s.strip.match?(/\A\[Tool: .+\]\z/)
  end

  delegate :content_text, :content_json, to: :content, allow_nil: true

  def parsed_content
    content&.parsed
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
