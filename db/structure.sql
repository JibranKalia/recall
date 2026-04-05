CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "project_id" integer NOT NULL, "external_id" varchar NOT NULL, "source_name" varchar NOT NULL, "source_type" varchar NOT NULL, "source_path" varchar NOT NULL, "source_checksum" varchar NOT NULL, "source_size" integer NOT NULL, "title" varchar, "model" varchar, "git_branch" varchar, "cwd" varchar, "started_at" datetime(6), "ended_at" datetime(6), "messages_count" integer DEFAULT 0 NOT NULL, "total_input_tokens" integer DEFAULT 0, "total_output_tokens" integer DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "custom_title" varchar /*application='Recall'*/, "summary" text /*application='Recall'*/, CONSTRAINT "fk_rails_788eded806"
FOREIGN KEY ("project_id")
  REFERENCES "projects" ("id")
);
CREATE INDEX "index_sessions_on_project_id" ON "sessions" ("project_id") /*application='Recall'*/;
CREATE UNIQUE INDEX "index_sessions_on_external_id_and_source_type" ON "sessions" ("external_id", "source_type") /*application='Recall'*/;
CREATE INDEX "index_sessions_on_started_at" ON "sessions" ("started_at") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "messages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "session_id" integer NOT NULL, "external_id" varchar, "parent_external_id" varchar, "role" varchar NOT NULL, "position" integer NOT NULL, "content_text" text, "content_json" text, "model" varchar, "input_tokens" integer, "output_tokens" integer, "timestamp" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "hidden" boolean DEFAULT FALSE NOT NULL /*application='Recall'*/, CONSTRAINT "fk_rails_1ee2a92df0"
FOREIGN KEY ("session_id")
  REFERENCES "sessions" ("id")
);
CREATE INDEX "index_messages_on_session_id" ON "messages" ("session_id") /*application='Recall'*/;
CREATE INDEX "index_messages_on_session_id_and_position" ON "messages" ("session_id", "position") /*application='Recall'*/;
CREATE VIRTUAL TABLE messages_fts USING fts5(
  content_text,
  content='messages',
  content_rowid='id',
  tokenize='porter unicode61'
)
/* messages_fts(content_text) */;
CREATE TABLE IF NOT EXISTS 'messages_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'messages_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'messages_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'messages_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE VIRTUAL TABLE sessions_fts USING fts5(
  title,
  custom_title,
  summary,
  content='sessions',
  content_rowid='id',
  tokenize='porter unicode61'
)
/* sessions_fts(title,custom_title,summary) */;
CREATE TABLE IF NOT EXISTS 'sessions_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'sessions_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'sessions_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'sessions_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "session_summaries" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "session_id" integer NOT NULL, "body" text NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "title" varchar /*application='Recall'*/, CONSTRAINT "fk_rails_3c0482b265"
FOREIGN KEY ("session_id")
  REFERENCES "sessions" ("id")
);
CREATE INDEX "index_session_summaries_on_session_id" ON "session_summaries" ("session_id") /*application='Recall'*/;
CREATE TABLE IF NOT EXISTS "projects" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "path" varchar NOT NULL, "sessions_count" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_projects_on_path" ON "projects" ("path") /*application='Recall'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260405013407'),
('20260405012247'),
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

