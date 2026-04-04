class CreateSessionSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :session_summaries do |t|
      t.references :session, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end
  end
end
