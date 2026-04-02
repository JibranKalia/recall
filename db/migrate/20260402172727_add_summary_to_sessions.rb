class AddSummaryToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :summary, :text
  end
end
