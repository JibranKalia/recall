class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :project, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :source_name, null: false
      t.string :source_type, null: false
      t.string :source_path, null: false
      t.string :source_checksum, null: false
      t.integer :source_size, null: false
      t.string :title
      t.string :model
      t.string :git_branch
      t.string :cwd
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :messages_count, default: 0, null: false
      t.integer :total_input_tokens, default: 0
      t.integer :total_output_tokens, default: 0

      t.timestamps
    end

    add_index :sessions, [:external_id, :source_type], unique: true
    add_index :sessions, :started_at
  end
end
