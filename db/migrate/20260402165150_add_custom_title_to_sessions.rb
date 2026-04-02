class AddCustomTitleToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :custom_title, :string
  end
end
