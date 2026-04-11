# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Recall

Rails 8.1 app for searching and browsing archived AI conversations (Claude Code, Codex). SQLite + FTS5 for full-text search. Web UI and CLI.

## Commands

```bash
bin/setup                              # Install deps, prepare DB, start server
bin/dev                                # Start dev server (port 3000)
bin/rails test                         # Run tests
bin/rails test test/models/message_test.rb      # Single file
bin/rails test test/models/message_test.rb:15   # Single test by line
bin/rails test:system                  # System tests (Capybara + Selenium)
bin/rubocop                            # Lint
bin/brakeman                           # Security scan
bin/rails recall:import                # Import all sources (incremental)
bin/rails recall:import_claude         # Import Claude Code (personal) only
bin/rails recall:import_claude_work    # Import Claude Code (work) only
bin/rails recall:import_codex          # Import Codex only
bin/rails recall:reimport              # Force re-import (ignore checksums)
bin/rails recall:generate_titles       # Enqueue title generation for untitled sessions
bin/rails recall:regenerate_titles     # Clear + re-generate all titles
bin/rails recall:stats                 # Show import stats
bin/recall search "query"              # CLI search
```

## Architecture

**Core models:** Project → Session → Message (each has many of the next).

- **Project**: a directory/repo that had conversations. Unique on `path`.
- **Session**: one conversation, imported from a JSONL file. Unique on `external_id`. Has `title` (auto-generated via Ollama) and `custom_title` (user-set). `display_title` resolves: custom_title → title → "Untitled session".
- **Message**: single turn in a session. Roles: `user`, `assistant`, `system`, `tool_result`.
- **Message::Content**: stores `content_text` (plain text for FTS) and `content_json` (structured blocks for rendering). One-to-one with Message. Table name is `message_contents`.
- **Session::Source**: import provenance — `source_name`, `source_type`, `source_path`, `source_checksum`, `source_size`. One-to-one with Session. Table name is `session_sources`.
- **Session::Summary**: AI-generated summary with `body` and `title`. Table name is `session_summaries`.
- **Session::Markdown**: non-DB model that renders a session as Markdown. Instantiated via `session.to_markdown`.
- **TokenUsage**: per-message token breakdown — `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `model`. One-to-one with Message. Supports `estimated_cost` via rate card lookup.
- **Experiment**: a prompt evaluated against one or more LLM providers. Belongs to Session (required). Has `name`, `prompt_text`, `system_prompt`, `status`, `session_id`. All LLM calls must go through `Experiment.complete!` (sync) or `RunProviderJob` (async) — never call `LLM::Provider` directly.
- **Experiment::Run**: one provider's execution of an experiment — `provider_key`, `model`, `status`, `response_text`, `tokens_in`, `tokens_out`, `estimated_cost`, `duration_ms`. Table name is `experiment_runs`.

**LLM provider layer** (`app/models/llm/`):
- `LLM::Provider` — base class. Subclasses implement `#complete(prompt, system:)` returning a `Result` (output, tokens_in, tokens_out, model, duration_ms).
- `LLM::Providers::Ollama` — HTTP to localhost:11434 (Ollama API). Default model: `qwen2.5:14b`.
- `LLM::Providers::ClaudeCode` — shells out to `claude -p --output-format json`. Parses usage from JSON.
- `LLM::Providers::OpenCode` — shells out to `opencode -p` (Kimi K2).
- `LLM::Providers::Codex` — shells out to `codex -q`.
- `LLM::PROVIDERS` registry maps string keys (e.g. `"ollama"`, `"claude_code:opus"`) to provider factories.
- `LLM::RATES` maps model names to per-token pricing for cost estimation.
- **Important**: All LLM calls must create an Experiment record. Use `Experiment.complete!` for synchronous calls or create an Experiment + Run and enqueue `RunProviderJob` for async.

**Import pipeline** (`lib/recall/`):
- `Importer` orchestrates imports from 3 registered sources, rebuilds FTS after each run.
- `Importers::Base` provides checksum-based dedup, transactional imports, UTF-8 sanitization. Each file import is wrapped in a transaction.
- `Importers::ClaudeCode` reads `~/.claude/projects/**/*.jsonl` and `~/.claude-work/projects/**/*.jsonl`. Skips `memory.jsonl` and non-message entry types.
- `Importers::Codex` reads `~/.codex/sessions/**/*.jsonl` plus SQLite state DB (`state_5.sqlite`) for metadata (title, tokens, model, git branch).
- `GenerateSummaryJob` is enqueued during import to auto-generate summaries + titles via `Experiment.complete!` (`Recall::Summarizer`). Each chunk summary and title generation creates its own Experiment record.

**FTS5 search** (`Searchable` concern):
- Two FTS virtual tables: `messages_fts` (content_text) and `sessions_fts` (title, custom_title, summary).
- `messages_fts` auto-synced via SQLite triggers on `message_contents` insert/update/delete.
- `sessions_fts` manually synced via `Session#sync_fts` (after_save hook). Uses `previously_new_record?` to skip the FTS delete on create (deleting a non-existent FTS entry causes SQLITE_CORRUPT).
- `Message.search(query)` searches both tables, returns messages with `snippet` attribute.
- **structure.sql caveat**: Rails schema dump includes FTS5 internal backing tables (`*_fts_data`, `*_fts_idx`, etc.) which must be removed — they're auto-created by `CREATE VIRTUAL TABLE` and duplicating them corrupts the FTS index on `db:schema:load`.

**Data directory**: Dev databases live in `~/.config/recall/` (configurable via `RECALL_DATA_DIR`), making the CLI work from any directory.

**Icons**: CSS mask-image system (copied from quranportal). SVG files in `app/assets/images/icons/`, CSS in `icons.css`, rendered via `icon_tag(:name)` helper. Icons inherit `currentColor` for easy styling. Never use inline SVGs — add new icons as `.svg` files and register in `icons.css`.

**Web UI**: Projects index → Project show (paginated sessions, 30/page) → Session show (messages with Markdown export). Global search page with live XHR results. Experiments page (`/experiments`) for creating and comparing multi-provider LLM runs with live Turbo Stream updates.

**CLI**: `bin/recall` — search, import, stats, projects, sessions commands. Loads Rails env but works from any directory.

## Testing

```bash
bin/rails test                                          # Run all tests
bin/rails test test/models/session/markdown_test.rb     # Single file
bin/rails test test/models/session/markdown_test.rb:13  # Single test by line
```

Test DB setup: `RAILS_ENV=test bin/rails db:drop db:create db:schema:load db:environment:set`. If FTS errors appear, delete `storage/test.sqlite3` and re-run.

## Tech Stack

Rails 8.1, Ruby 3.4.5, SQLite3 + FTS5, Hotwire (Turbo + Stimulus), Propshaft, Solid Queue/Cache/Cable, Kamal + Docker deployment.

## VCS

Use `jj` (Jujutsu), not git.
