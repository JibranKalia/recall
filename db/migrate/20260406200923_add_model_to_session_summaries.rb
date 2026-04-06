class AddModelToSessionSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :session_summaries, :model, :string
  end
end
