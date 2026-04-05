class Session::Source < ApplicationRecord
  self.table_name = "session_sources"

  belongs_to :session

  validates :source_name, presence: true
  validates :source_type, presence: true
  validates :source_path, presence: true
  validates :source_checksum, presence: true
  validates :source_size, presence: true
end
