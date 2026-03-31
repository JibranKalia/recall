class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :session, null: false, foreign_key: true
      t.string :external_id
      t.string :parent_external_id
      t.string :role, null: false
      t.integer :position, null: false
      t.text :content_text
      t.text :content_json
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.datetime :timestamp

      t.timestamps
    end

    add_index :messages, [:session_id, :position]
  end
end
