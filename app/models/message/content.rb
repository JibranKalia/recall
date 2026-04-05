class Message::Content < ApplicationRecord
  self.table_name = "message_contents"

  belongs_to :message

  def parsed
    return nil if content_json.blank?
    JSON.parse(content_json)
  rescue JSON::ParserError
    nil
  end
end
