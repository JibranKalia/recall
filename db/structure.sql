CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "projects" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "path" varchar NOT NULL, "sessions_count" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "domain" varchar DEFAULT 'personal' NOT NULL /*application='Recall'*/);
CREATE UNIQUE INDEX "index_projects_on_path" ON "projects" ("path") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "token_usages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "message_id" integer NOT NULL, "input_tokens" integer DEFAULT 0 NOT NULL, "output_tokens" integer DEFAULT 0 NOT NULL, "cache_creation_input_tokens" integer DEFAULT 0 NOT NULL, "cache_read_input_tokens" integer DEFAULT 0 NOT NULL, "model" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_003a7b46d9"
FOREIGN KEY ("message_id")
  REFERENCES "messages" ("id")
);
CREATE UNIQUE INDEX "index_token_usages_on_message_id" ON "token_usages" ("message_id") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "session_sources" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "session_id" integer NOT NULL, "source_name" varchar NOT NULL, "source_type" varchar NOT NULL, "source_path" varchar NOT NULL, "source_checksum" varchar NOT NULL, "source_size" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_42c2654726"
FOREIGN KEY ("session_id")
  REFERENCES "sessions" ("id")
);
CREATE UNIQUE INDEX "index_session_sources_on_session_id" ON "session_sources" ("session_id") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "project_id" integer NOT NULL, "external_id" varchar NOT NULL, "title" varchar, "model" varchar, "git_branch" varchar, "cwd" varchar, "started_at" datetime(6), "ended_at" datetime(6), "messages_count" integer DEFAULT 0 NOT NULL, "total_input_tokens" integer DEFAULT 0, "total_output_tokens" integer DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "custom_title" varchar, "summary" text, CONSTRAINT "fk_rails_788eded806"
FOREIGN KEY ("project_id")
  REFERENCES "projects" ("id")
);
CREATE INDEX "index_sessions_on_project_id" ON "sessions" ("project_id") /*application='Recall'*/;
CREATE INDEX "index_sessions_on_started_at" ON "sessions" ("started_at") /*application='Recall'*/;
CREATE UNIQUE INDEX "index_sessions_on_external_id" ON "sessions" ("external_id") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "message_contents" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "message_id" integer NOT NULL, "content_text" text, "content_json" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_cd506865cb"
FOREIGN KEY ("message_id")
  REFERENCES "messages" ("id")
);
CREATE UNIQUE INDEX "index_message_contents_on_message_id" ON "message_contents" ("message_id") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "messages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "session_id" integer NOT NULL, "external_id" varchar, "parent_external_id" varchar, "role" varchar NOT NULL, "position" integer NOT NULL, "model" varchar, "input_tokens" integer, "output_tokens" integer, "timestamp" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "hidden" boolean DEFAULT FALSE NOT NULL, CONSTRAINT "fk_rails_1ee2a92df0"
FOREIGN KEY ("session_id")
  REFERENCES "sessions" ("id")
);
CREATE INDEX "index_messages_on_session_id" ON "messages" ("session_id") /*application='Recall'*/;
CREATE INDEX "index_messages_on_session_id_and_position" ON "messages" ("session_id", "position") /*application='Recall'*/;
CREATE VIRTUAL TABLE messages_fts USING fts5(
  content_text,
  content='message_contents',
  content_rowid='message_id',
  tokenize='porter unicode61'
)
/* messages_fts(content_text) */;
CREATE TABLE IF NOT EXISTS "experiment_runs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "experiment_id" integer NOT NULL, "provider_key" varchar NOT NULL, "model" varchar NOT NULL, "status" varchar DEFAULT 'pending' NOT NULL, "response_text" text, "tokens_in" integer, "tokens_out" integer, "estimated_cost" float, "duration_ms" integer, "error_message" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_6c02fc6d5d"
FOREIGN KEY ("experiment_id")
  REFERENCES "experiments" ("id")
);
CREATE INDEX "index_experiment_runs_on_experiment_id" ON "experiment_runs" ("experiment_id") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "experiments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "prompt_text" text NOT NULL, "system_prompt" text, "status" varchar DEFAULT 'pending' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "session_id" integer NOT NULL, CONSTRAINT "fk_rails_5b2527e447"
FOREIGN KEY ("session_id")
  REFERENCES "sessions" ("id")
);
CREATE INDEX "index_experiments_on_session_id" ON "experiments" ("session_id") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "import_runs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "status" varchar DEFAULT 'running' NOT NULL, "started_at" datetime(6) NOT NULL, "completed_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_import_runs_on_status" ON "import_runs" ("status") /*application='Recall'*/;
CREATE INDEX "index_import_runs_on_completed_at" ON "import_runs" ("completed_at") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "session_summaries" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "session_id" integer NOT NULL, "body" text NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "title" varchar, "experiment_run_id" integer, "message_count" integer /*application='Recall'*/, CONSTRAINT "fk_rails_3c0482b265"
FOREIGN KEY ("session_id")
  REFERENCES "sessions" ("id")
, CONSTRAINT "fk_rails_af1710e7be"
FOREIGN KEY ("experiment_run_id")
  REFERENCES "experiment_runs" ("id")
);
CREATE INDEX "index_session_summaries_on_session_id" ON "session_summaries" ("session_id") /*application='Recall'*/;
CREATE INDEX "index_session_summaries_on_experiment_run_id" ON "session_summaries" ("experiment_run_id") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "session_tombstones" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "external_id" varchar NOT NULL, "reason" varchar, "original_title" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_session_tombstones_on_external_id" ON "session_tombstones" ("external_id") /*application='Recall'*/;
CREATE VIRTUAL TABLE sessions_fts USING fts5(
  title,
  custom_title,
  summary,
  external_id,
  content='sessions',
  content_rowid='id',
  tokenize='porter unicode61'
)
/* sessions_fts(title,custom_title,summary,external_id) */;
INSERT INTO "schema_migrations" (version) VALUES
('20260411145542'),
('20260408193404'),
('20260406203818'),
('20260406202419'),
('20260406201105'),
('20260406120000'),
('20260406105320'),
('20260406105036'),
('20260406031055'),
('20260406030624'),
('20260406025408'),
('20260405223110'),
('20260405013407'),
('20260405012247'),
('20260404232000'),
('20260404231000'),
('20260404230000'),
('20260404213502'),
('20260404213006'),
('20260402174821'),
('20260402172727'),
('20260402165150'),
('20260331190442'),
('20260331190430'),
('20260331190404'),
('20260331190335'),
('1');

