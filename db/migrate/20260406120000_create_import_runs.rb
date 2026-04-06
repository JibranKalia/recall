class CreateImportRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :import_runs do |t|
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :import_runs, :status
    add_index :import_runs, :completed_at
  end
end
