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

**Core models:** Project → Session → Message (each has many of the next). Session also `has_many :summaries` (Session::Summary).

- **Project**: a directory/repo that had conversations. Unique on `(path, source_type)`.
- **Session**: one conversation, imported from a JSONL file. Unique on `(external_id, source_type)`. Tracks checksum for dedup. Has `title` (auto-generated via Ollama) and `custom_title` (user-set). `display_title` resolves: custom_title → title → "Untitled session".
- **Message**: single turn in a session. Roles: `user`, `assistant`, `system`, `tool_result`. Stores both `content_text` (plain text for FTS) and `content_json` (structured blocks for rendering).
- **Session::Summary**: AI-generated summary with `body` and `title`. Table name is `session_summaries`.

**Import pipeline** (`lib/recall/`):
- `Importer` orchestrates imports from 3 registered sources, rebuilds FTS after each run.
- `Importers::Base` provides checksum-based dedup, transactional imports, UTF-8 sanitization. Each file import is wrapped in a transaction.
- `Importers::ClaudeCode` reads `~/.claude/projects/**/*.jsonl` and `~/.claude-work/projects/**/*.jsonl`. Skips `memory.jsonl` and non-message entry types.
- `Importers::Codex` reads `~/.codex/sessions/**/*.jsonl` plus SQLite state DB (`state_5.sqlite`) for metadata (title, tokens, model, git branch).
- `GenerateSummaryJob` is enqueued during import to auto-generate summaries + titles via Ollama (`Recall::Summarizer`).

**FTS5 search** (`Searchable` concern):
- Two FTS virtual tables: `messages_fts` (content_text) and `sessions_fts` (title, custom_title, summary).
- `messages_fts` auto-synced via SQLite triggers on insert/update/delete.
- `sessions_fts` manually synced via `Session#sync_fts` (after_save hook).
- `Message.search(query)` searches both tables, returns messages with `snippet` attribute.

**Data directory**: Dev databases live in `~/.config/recall/` (configurable via `RECALL_DATA_DIR`), making the CLI work from any directory.

**Web UI**: Projects index → Project show (paginated sessions, 30/page) → Session show (messages with Markdown export). Global search page with live XHR results.

**CLI**: `bin/recall` — search, import, stats, projects, sessions commands. Loads Rails env but works from any directory.

## Tech Stack

Rails 8.1, Ruby 3.4.5, SQLite3 + FTS5, Hotwire (Turbo + Stimulus), Propshaft, Solid Queue/Cache/Cable, Kamal + Docker deployment.

## VCS

Use `jj` (Jujutsu), not git.
