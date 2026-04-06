class RemoveSessionAndKindFromExperiments < ActiveRecord::Migration[8.1]
  def change
    remove_reference :experiments, :session, foreign_key: true
    remove_column :experiments, :kind, :string
  end
end
