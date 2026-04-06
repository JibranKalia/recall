class AddSessionToExperiments < ActiveRecord::Migration[8.1]
  def change
    add_reference :experiments, :session, null: true, foreign_key: true
    add_column :experiments, :kind, :string, null: false, default: "prompt"
  end
end
