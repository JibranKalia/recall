# Recall

Search and browse your archived AI conversations. Imports sessions from **Claude Code** and **OpenAI Codex**, indexes them with SQLite FTS5 full-text search, and serves a web UI and CLI for finding past conversations.

## Features

- **Full-text search** across all your AI conversations with highlighted snippets
- **Multi-source import** — Claude Code (`~/.claude/projects/`) and OpenAI Codex (`~/.codex/sessions/`)
- **Checksum-based dedup** — re-run imports without duplicating data
- **Web UI** — browse projects, sessions, and messages with search and filtering
- **CLI** — search, import, and inspect from the terminal

## Quick Start

```bash
bin/setup              # Install deps, prepare DB
bin/rails recall:import   # Import conversations
bin/dev                # Start dev server (http://localhost:3000)
```

## Architecture

Three models: **Project → Session → Message**.

| Model | Description |
|-------|-------------|
| **Project** | A directory/repo that had conversations. Unique on `(path, source_type)`. |
| **Session** | One conversation, imported from a JSONL file. Tracks checksum for dedup. |
| **Message** | Single turn in a session. `content_text` is FTS5-indexed for search. |

The import pipeline lives in `lib/recall/`:
- `Importer` orchestrates imports from registered sources and rebuilds the FTS index.
- `Importers::Base` provides checksum-based dedup, transactional imports, and UTF-8 sanitization.
- Source-specific importers (`ClaudeCode`, `Codex`) handle file discovery and parsing.

## CLI

```bash
bin/recall search "query"    # Search across all messages
bin/recall import            # Import from all sources
bin/recall stats             # Show import statistics
bin/recall projects          # List projects
bin/recall sessions          # List sessions
```

## Development

```bash
bin/rails test               # Run tests
bin/rails test:system        # System tests (Capybara + Selenium)
bin/rubocop                  # Lint
bin/brakeman                 # Security scan
```

## Tech Stack

- **Rails 8.1** / Ruby 3.4.5
- **SQLite3 + FTS5** for storage and full-text search
- **Hotwire** (Turbo + Stimulus) for the web UI
- **Propshaft** for asset pipeline
- **Solid Queue / Cache / Cable** for background jobs and caching
- **Kamal + Docker** for deployment
