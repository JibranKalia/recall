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

ActiveRecord::Schema[8.1].define(version: 2026_04_28_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "experiment_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.float "estimated_cost"
    t.bigint "experiment_id", null: false
    t.string "model", null: false
    t.string "provider_key", null: false
    t.text "response_text"
    t.string "status", default: "pending", null: false
    t.integer "tokens_in"
    t.integer "tokens_out"
    t.datetime "updated_at", null: false
    t.index ["experiment_id"], name: "index_experiment_runs_on_experiment_id"
  end

  create_table "experiments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "prompt_text", null: false
    t.bigint "session_id", null: false
    t.string "status", default: "pending", null: false
    t.text "system_prompt"
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_experiments_on_session_id"
  end

  create_table "import_runs", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "started_at", null: false
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at"], name: "index_import_runs_on_completed_at"
    t.index ["status"], name: "index_import_runs_on_status"
  end

  create_table "message_contents", force: :cascade do |t|
    t.text "content_json"
    t.text "content_text"
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.virtual "tsv", type: :tsvector, as: "to_tsvector('english'::regconfig, COALESCE(content_text, ''::text))", stored: true
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_message_contents_on_message_id", unique: true
    t.index ["tsv"], name: "index_message_contents_on_tsv", using: :gin
  end

  create_table "messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id"
    t.boolean "hidden", default: false, null: false
    t.integer "input_tokens"
    t.string "model"
    t.integer "output_tokens"
    t.string "parent_external_id"
    t.integer "position", null: false
    t.string "role", null: false
    t.bigint "session_id", null: false
    t.datetime "timestamp"
    t.datetime "updated_at", null: false
    t.index ["session_id", "position"], name: "index_messages_on_session_id_and_position"
    t.index ["session_id"], name: "index_messages_on_session_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain", default: "personal", null: false
    t.string "name", null: false
    t.string "path", null: false
    t.integer "sessions_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["path"], name: "index_projects_on_path", unique: true
  end

  create_table "session_sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_synced_at"
    t.bigint "session_id", null: false
    t.string "source_checksum", null: false
    t.string "source_name", null: false
    t.string "source_path", null: false
    t.integer "source_size", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_session_sources_on_session_id", unique: true
  end

  create_table "session_summaries", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "experiment_run_id"
    t.integer "message_count"
    t.bigint "session_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["experiment_run_id"], name: "index_session_summaries_on_experiment_run_id"
    t.index ["session_id"], name: "index_session_summaries_on_session_id"
  end

  create_table "session_tombstones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "original_title"
    t.string "reason"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_session_tombstones_on_external_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "custom_title"
    t.string "cwd"
    t.datetime "ended_at"
    t.string "external_id", null: false
    t.string "git_branch"
    t.integer "messages_count", default: 0, null: false
    t.string "model"
    t.bigint "project_id", null: false
    t.datetime "started_at"
    t.text "summary"
    t.string "title"
    t.integer "total_input_tokens", default: 0
    t.integer "total_output_tokens", default: 0
    t.virtual "tsv", type: :tsvector, as: "to_tsvector('english'::regconfig, (((((COALESCE(title, ''::character varying))::text || ' '::text) || (COALESCE(custom_title, ''::character varying))::text) || ' '::text) || (COALESCE(external_id, ''::character varying))::text))", stored: true
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_sessions_on_external_id", unique: true
    t.index ["project_id"], name: "index_sessions_on_project_id"
    t.index ["started_at"], name: "index_sessions_on_started_at"
    t.index ["tsv"], name: "index_sessions_on_tsv", using: :gin
  end

  create_table "token_usages", force: :cascade do |t|
    t.integer "cache_creation_input_tokens", default: 0, null: false
    t.integer "cache_read_input_tokens", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "input_tokens", default: 0, null: false
    t.bigint "message_id", null: false
    t.string "model"
    t.integer "output_tokens", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_token_usages_on_message_id", unique: true
  end

  add_foreign_key "experiment_runs", "experiments"
  add_foreign_key "experiments", "sessions"
  add_foreign_key "message_contents", "messages"
  add_foreign_key "messages", "sessions"
  add_foreign_key "session_sources", "sessions"
  add_foreign_key "session_summaries", "experiment_runs"
  add_foreign_key "session_summaries", "sessions"
  add_foreign_key "sessions", "projects"
  add_foreign_key "token_usages", "messages"
end
