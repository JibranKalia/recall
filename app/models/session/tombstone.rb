class Session::Tombstone < ApplicationRecord
  self.table_name = "session_tombstones"

  validates :external_id, presence: true, uniqueness: true

  # Archive a session: create tombstone, then destroy the session
  def self.archive!(session, reason: nil)
    transaction do
      create!(
        external_id: session.external_id,
        reason: reason,
        original_title: session.display_title
      )
      # Destroy dependents with FK constraints before the session
      session.summaries.destroy_all
      session.experiments.destroy_all
      session.destroy!
    end
  end

  # Check if an external_id has been tombstoned (used by importers to skip)
  def self.tombstoned?(external_id)
    exists?(external_id: external_id)
  end
end
