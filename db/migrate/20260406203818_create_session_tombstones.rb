class CreateSessionTombstones < ActiveRecord::Migration[8.1]
  def change
    create_table :session_tombstones do |t|
      t.string :external_id, null: false, index: { unique: true }
      t.string :reason
      t.string :original_title

      t.timestamps
    end
  end
end
