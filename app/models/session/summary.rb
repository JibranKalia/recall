class Session::Summary < ApplicationRecord
  self.table_name = "session_summaries"

  belongs_to :session
  belongs_to :experiment_run, class_name: "Experiment::Run", optional: true

  delegate :model, to: :experiment_run, allow_nil: true
end
