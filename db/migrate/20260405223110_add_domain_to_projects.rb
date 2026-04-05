class AddDomainToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :domain, :string, null: false, default: "personal"
  end
end
