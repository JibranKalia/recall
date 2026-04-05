class AddHiddenToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :hidden, :boolean, default: false, null: false
  end
end
