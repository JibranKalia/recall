class MakeSessionRequiredOnExperiments < ActiveRecord::Migration[8.1]
  def change
    change_column_null :experiments, :session_id, false
  end
end
