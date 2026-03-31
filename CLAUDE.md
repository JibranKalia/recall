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
bin/rails recall:import                # Import all sources
bin/rails recall:reimport              # Force re-import (ignore checksums)
bin/rails recall:stats                 # Show import stats
bin/recall search "query"              # CLI search
```

## Architecture

**Three models:** Project → Session → Message (each has many of the next).

- **Project**: a directory/repo that had conversations. Unique on `(path, source_type)`.
- **Session**: one conversation, imported from a JSONL file. Unique on `(external_id, source_type)`. Tracks checksum for dedup.
- **Message**: single turn in a session. Has `content_text` (searchable) and `content_json` (structured). FTS5 via `Searchable` concern.

**Import pipeline** (`lib/recall/`):
- `Importer` orchestrates imports from registered sources, rebuilds FTS after each run.
- `Importers::Base` provides checksum-based dedup, transactional imports, UTF-8 sanitization.
- `Importers::ClaudeCode` reads `~/.claude/projects/**/*.jsonl` and `~/.claude-work/projects/**/*.jsonl`.
- `Importers::Codex` reads `~/.codex/sessions/**/*.jsonl` plus SQLite state DB for metadata.

**Search**: `Message.search(query)` uses FTS5 `snippet()` for highlighted results ranked by relevance.

**Web UI**: Projects index (grouped by source) → Project show (paginated sessions) → Session show (messages). Search page with filtering.

**CLI**: `bin/recall` — search, import, stats, projects, sessions commands.

## Tech Stack

Rails 8.1, Ruby 3.4.5, SQLite3 + FTS5, Hotwire (Turbo + Stimulus), Propshaft, Solid Queue/Cache/Cable, Kamal + Docker deployment.

## VCS

Use `jj` (Jujutsu), not git.
