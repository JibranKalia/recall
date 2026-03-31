class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :path, null: false
      t.string :source_type, null: false
      t.integer :sessions_count, default: 0, null: false

      t.timestamps
    end

    add_index :projects, [:path, :source_type], unique: true
  end
end
