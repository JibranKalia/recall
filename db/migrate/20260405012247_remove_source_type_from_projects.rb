class RemoveSourceTypeFromProjects < ActiveRecord::Migration[8.1]
  def up
    # Merge duplicate projects (same path, different source_type)
    # Keep the one with the most sessions, reassign the rest
    dupes = execute("SELECT path FROM projects GROUP BY path HAVING COUNT(*) > 1").map { |r| r["path"] }

    dupes.each do |path|
      projects = execute("SELECT id FROM projects WHERE path = '#{path}' ORDER BY (SELECT COUNT(*) FROM sessions WHERE sessions.project_id = projects.id) DESC")
      keeper_id = projects.first["id"]

      projects.drop(1).each do |row|
        execute("UPDATE sessions SET project_id = #{keeper_id} WHERE project_id = #{row['id']}")
        execute("DELETE FROM projects WHERE id = #{row['id']}")
      end
    end

    remove_index :projects, [:path, :source_type]
    remove_column :projects, :source_type, :string
    add_index :projects, :path, unique: true
  end

  def down
    remove_index :projects, :path
    add_column :projects, :source_type, :string
    add_index :projects, [:path, :source_type], unique: true

    # Backfill source_type from sessions
    execute("UPDATE projects SET source_type = (SELECT source_type FROM sessions WHERE sessions.project_id = projects.id LIMIT 1)")
    change_column_null :projects, :source_type, false
  end
end
