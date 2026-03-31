# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_31_190442) do
  create_table "messages", force: :cascade do |t|
    t.text "content_json"
    t.text "content_text"
    t.datetime "created_at", null: false
    t.string "external_id"
    t.integer "input_tokens"
    t.string "model"
    t.integer "output_tokens"
    t.string "parent_external_id"
    t.integer "position", null: false
    t.string "role", null: false
    t.integer "session_id", null: false
    t.datetime "timestamp"
    t.datetime "updated_at", null: false
    t.index ["session_id", "position"], name: "index_messages_on_session_id_and_position"
    t.index ["session_id"], name: "index_messages_on_session_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "path", null: false
    t.integer "sessions_count", default: 0, null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.index ["path", "source_type"], name: "index_projects_on_path_and_source_type", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cwd"
    t.datetime "ended_at"
    t.string "external_id", null: false
    t.string "git_branch"
    t.integer "messages_count", default: 0, null: false
    t.string "model"
    t.integer "project_id", null: false
    t.string "source_checksum", null: false
    t.string "source_name", null: false
    t.string "source_path", null: false
    t.integer "source_size", null: false
    t.string "source_type", null: false
    t.datetime "started_at"
    t.string "title"
    t.integer "total_input_tokens", default: 0
    t.integer "total_output_tokens", default: 0
    t.datetime "updated_at", null: false
    t.index ["external_id", "source_type"], name: "index_sessions_on_external_id_and_source_type", unique: true
    t.index ["project_id"], name: "index_sessions_on_project_id"
    t.index ["started_at"], name: "index_sessions_on_started_at"
  end

  add_foreign_key "messages", "sessions"
  add_foreign_key "sessions", "projects"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
