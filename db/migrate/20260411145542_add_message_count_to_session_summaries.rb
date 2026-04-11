class AddMessageCountToSessionSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :session_summaries, :message_count, :integer
  end
end
