class Session::Summary < ApplicationRecord
  self.table_name = "session_summaries"

  belongs_to :session
end
