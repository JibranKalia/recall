class Message::Content < ApplicationRecord
  include PgSearch::Model

  self.table_name = "message_contents"

  belongs_to :message

  pg_search_scope :search_full_text,
    against: :content_text,
    using: {
      tsearch: {
        dictionary: "english",
        tsvector_column: "tsv",
        highlight: {
          StartSel: "<mark>",
          StopSel: "</mark>",
          MaxWords: 35,
          MinWords: 15,
          ShortWord: 3,
          FragmentDelimiter: "...",
          MaxFragments: 1
        }
      }
    }

  def parsed
    return nil if content_json.blank?
    JSON.parse(content_json)
  rescue JSON::ParserError
    nil
  end
end
