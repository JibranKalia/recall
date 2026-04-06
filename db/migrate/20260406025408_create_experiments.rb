class CreateExperiments < ActiveRecord::Migration[8.1]
  def change
    create_table :experiments do |t|
      t.string :name, null: false
      t.text :prompt_text, null: false
      t.text :system_prompt
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    create_table :experiment_runs do |t|
      t.references :experiment, null: false, foreign_key: true
      t.string :provider_key, null: false
      t.string :model, null: false
      t.string :status, null: false, default: "pending"
      t.text :response_text
      t.integer :tokens_in
      t.integer :tokens_out
      t.float :estimated_cost
      t.integer :duration_ms
      t.text :error_message

      t.timestamps
    end
  end
end
