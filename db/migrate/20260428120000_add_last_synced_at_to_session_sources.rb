class AddLastSyncedAtToSessionSources < ActiveRecord::Migration[8.1]
  def change
    add_column :session_sources, :last_synced_at, :datetime
  end
end
