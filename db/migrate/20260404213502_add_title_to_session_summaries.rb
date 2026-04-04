class AddTitleToSessionSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :session_summaries, :title, :string
  end
end
