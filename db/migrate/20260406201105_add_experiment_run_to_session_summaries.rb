class AddExperimentRunToSessionSummaries < ActiveRecord::Migration[8.1]
  def change
    add_reference :session_summaries, :experiment_run, null: true, foreign_key: true
  end
end
