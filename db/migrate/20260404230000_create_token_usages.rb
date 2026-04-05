class CreateTokenUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :token_usages do |t|
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      t.integer :input_tokens, default: 0, null: false
      t.integer :output_tokens, default: 0, null: false
      t.integer :cache_creation_input_tokens, default: 0, null: false
      t.integer :cache_read_input_tokens, default: 0, null: false
      t.string :model

      t.timestamps
    end
  end
end
