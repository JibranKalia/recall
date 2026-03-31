# Recall Codebase Guide

## Project Overview

**Recall** is a Rails 8.1 web application for searching and organizing Claude Code sessions, Codex conversations, and other AI assistant interactions. It provides a full-text searchable archive with web UI and CLI interfaces for retrieving past conversations.

**Tech Stack:**
- **Framework:** Rails 8.1
- **Language:** Ruby 3.4.5
- **Database:** SQLite3 (dev/test) with FTS5 for full-text search
- **Frontend:** Hotwire (Turbo + Stimulus), Propshaft asset pipeline
- **Job Queue:** Solid Queue
- **Cache:** Solid Cache
- **WebSocket:** Solid Cable
- **Deployment:** Kamal + Docker

---

## Architecture Overview

### Core Data Model

Three main entities:

1. **Project** (`app/models/project.rb`)
   - Represents a directory/source of conversations
   - Attributes: `name`, `path`, `source_type`, `sessions_count`
   - Sources: `claude_code` (personal/work) or `codex`
   - Has many sessions

2. **Session** (`app/models/session.rb`)
   - Represents a single conversation/thread
   - Imported from source files (JSONL)
   - Tracks: `external_id`, `source_path`, `source_checksum`, `title`, `model`, `started_at`, `ended_at`
   - Has many messages with counter cache

3. **Message** (`app/models/message.rb`)
   - Individual message in a session conversation
   - Roles: `user`, `assistant`, `system`, `tool_result`
   - Stores: `content_text` (searchable), `content_json` (original structured format)
   - Includes: `Searchable` concern for FTS5 integration

### Database Schema

**SQLite3 with FTS5 Virtual Table:**
- `projects`: Path + source_type unique index
- `sessions`: External_id + source_type unique index, started_at index
- `messages`: Session_id + position index
- `messages_fts`: FTS5 virtual table for full-text search

See: `/Users/jibran.kalia/work/recall/db/schema.rb`

---

## Key Architectural Patterns

### 1. Importers (`lib/recall/importers/`)

**Base Class** (`lib/recall/importers/base.rb`)
- Abstract class handling common import logic
- Deduplication via file checksums (SHA256)
- Transaction-based imports with error handling
- FTS index rebuilding

**Claude Code Importer** (`lib/recall/importers/claude_code.rb`)
- Source: `~/.claude/projects/**/*.jsonl` and `~/.claude-work/projects/**/*.jsonl`
- JSONL format with entry types: `user`, `assistant`, file-history-snapshot, etc.
- Extracts: title, model, git_branch, cwd, tokens
- Handles tool calls and thinking content via JSON content blocks

**Codex Importer** (`lib/recall/importers/codex.rb`)
- Source: `~/.codex/sessions/**/*.jsonl`
- Reads thread metadata from SQLite state DB
- Entry types: `response_item`, `event_msg`, `session_meta`, `turn_context`
- Normalizes roles: user, assistant, developer→system

**Import Orchestration** (`lib/recall/importer.rb`)
- Registers all sources and their importers
- Provides: `import_all`, `reimport_all`, `import_source(name)`
- Triggers FTS index rebuild after imports

### 2. Search System (`app/models/concerns/searchable.rb`)

- FTS5 integration via SQL snippet generation
- Class method: `Message.search(query, limit: 50)`
- Returns ordered results with HTML snippets and context
- Sanitizes quotes for safe FTS queries

### 3. Web UI

**Controllers** (`app/controllers/`)
- `ProjectsController`: Index (grouped by source) and show with pagination
- `SearchController`: Query-based search with session/project metadata
- `SessionsController`: (placeholder for session detail routes)

**Routes** (`config/routes.rb`)
```ruby
root "projects#index"
resources :projects, only: [:index, :show]
resources :sessions, only: [:show]
get "search", to: "search#index"
```

### 4. CLI Interface (`bin/recall`)

Commands:
- `recall search "query" [--source NAME] [--project NAME] [--limit N]`
- `recall import` / `recall import_codex` / `recall import_claude`
- `recall stats`: Show session/message counts by source
- `recall projects`: List projects
- `recall sessions`: List sessions

---

## Build, Test & Lint Commands

### Setup
```bash
bin/setup                    # Install dependencies, prepare DB, optional start server
bin/setup --reset           # Also reset database to clean state
bin/setup --skip-server     # Don't start server after setup
```

### Development Server
```bash
bin/dev                     # Start via Procfile.dev (uses foreman)
                           # Runs: bin/rails server on PORT (default 3000)
```

### Testing
```bash
bin/rails test                          # Run unit/integration tests
bin/rails test:system                   # Run system/browser tests (Capybara + Selenium)
bin/rails db:test:prepare               # Prepare test database
```

**Test Setup** (`test/test_helper.rb`)
- Parallel test workers enabled
- Fixtures support for all models
- Selenium WebDriver for system tests

### Linting & Security
```bash
bin/rubocop                 # Ruby style linting (Omakase Rails)
bin/rubocop -f github      # GitHub Actions format
bin/brakeman                # Security vulnerability scanner
bin/bundler-audit           # Gem security audit
bin/importmap audit         # JS dependency audit
```

### Database
```bash
bin/rails db:prepare        # Create/migrate/seed
bin/rails db:migrate        # Run migrations
bin/rails db:reset         # Drop, create, migrate, seed
bin/rails log:clear tmp:clear  # Clean logs/temp files
```

### Import Tasks (Rake)
```bash
bin/rails recall:import              # Import all sources
bin/rails recall:import_claude       # Import personal (~/.claude)
bin/rails recall:import_claude_work  # Import work (~/.claude-work)
bin/rails recall:import_codex        # Import Codex (~/.codex)
bin/rails recall:reimport            # Force re-import (ignore checksums)
bin/rails recall:stats               # Show stats: projects, sessions, messages
```

### CI/CD
**GitHub Actions** (`.github/workflows/ci.yml`)
- `scan_ruby`: Brakeman + Bundler Audit
- `scan_js`: Importmap audit
- `lint`: RuboCop style checking
- `test`: Unit/integration tests
- `system-test`: Browser tests with artifact upload

---

## Directory Structure

```
recall/
├── app/
│   ├── controllers/          # Request handling
│   │   ├── application_controller.rb
│   │   ├── projects_controller.rb
│   │   ├── search_controller.rb
│   │   └── sessions_controller.rb
│   ├── models/              # ActiveRecord models
│   │   ├── application_record.rb
│   │   ├── project.rb
│   │   ├── message.rb
│   │   ├── session.rb
│   │   └── concerns/
│   │       └── searchable.rb
│   ├── views/              # ERB templates
│   ├── assets/             # CSS/images
│   ├── javascript/         # Stimulus controllers
│   ├── jobs/              # ActiveJob classes
│   └── mailers/           # ActionMailer
│
├── lib/
│   ├── recall/            # Application library
│   │   ├── importer.rb                        # Orchestrator
│   │   └── importers/                         # Source-specific importers
│   │       ├── base.rb                        # Common logic
│   │       ├── claude_code.rb                 # Claude Code sessions
│   │       └── codex.rb                       # Codex sessions
│   └── tasks/
│       └── recall.rake     # Import and stats tasks
│
├── config/
│   ├── application.rb      # Rails configuration
│   ├── routes.rb          # URL routing
│   ├── database.yml       # DB connections (SQLite)
│   ├── puma.rb            # Web server config
│   ├── storage.yml        # Active Storage config
│   ├── deploy.yml         # Kamal deployment
│   ├── environments/      # Environment-specific configs
│   ├── initializers/      # Startup hooks
│   └── secrets/           # Encrypted credentials
│
├── db/
│   ├── migrate/           # Migrations
│   ├── schema.rb          # Current schema (auto-generated)
│   ├── structure.sql      # SQL schema dump
│   └── seeds.rb           # Initial data
│
├── bin/                   # Executable scripts
│   ├── setup              # Initial setup
│   ├── dev                # Development server launcher
│   ├── recall             # CLI tool
│   ├── recall-server      # Daemon server
│   ├── rails              # Rails CLI
│   ├── rake               # Rake CLI
│   ├── ci                 # CI runner
│   └── [other utilities]
│
├── test/                  # Test suite
│   ├── models/            # Model tests
│   ├── controllers/       # Controller tests
│   ├── integration/       # Integration tests
│   ├── system/           # Browser/system tests
│   └── test_helper.rb    # Test configuration
│
├── public/               # Static assets
├── storage/              # SQLite databases (gitignored)
│
├── Gemfile               # Ruby dependencies
├── Procfile.dev          # Development process file
├── Dockerfile            # Production container image
├── .rubocop.yml         # Linting rules
├── .ruby-version        # Ruby 3.4.5
├── .github/
│   └── workflows/
│       └── ci.yml       # GitHub Actions CI
│
├── README.md            # (Minimal, update as needed)
└── CLAUDE.md            # This file
```

---

## Configuration Files

### `Gemfile`
Key gems:
- `rails ~> 8.1.2`
- `sqlite3 >= 2.1` — SQLite adapter
- `puma >= 5.0` — Web server
- `turbo-rails`, `stimulus-rails` — Hotwire frontend
- `importmap-rails` — ES modules
- `solid_cache`, `solid_queue`, `solid_cable` — Rails 8 defaults
- `image_processing ~> 1.2` — For variants
- `kamal` — Docker deployment
- **Dev/Test:** `debug`, `brakeman`, `bundler-audit`, `rubocop-rails-omakase`, `capybara`, `selenium-webdriver`

### `database.yml`
- **Development:** `storage/development.sqlite3`
- **Test:** `storage/test.sqlite3`
- **Production:** Three databases:
  - Primary: `storage/production.sqlite3`
  - Cache: `storage/production_cache.sqlite3`
  - Queue: `storage/production_queue.sqlite3`
  - Cable: `storage/production_cable.sqlite3`

### `Procfile.dev`
```
web: bin/rails server
```
Started via `foreman` by `bin/dev`

### `puma.rb`
- Max threads: 5 (dev) / ENV controlled
- Min threads: 1 (dev)
- Port: ENV['PORT'] or 3000
- Pidfile handling for daemonization

### `config/application.rb`
- Rails 8.1 defaults
- Autoload `lib/` (except assets/tasks)
- SQL schema format (not Ruby)
- No timezone override (UTC)

### `.rubocop.yml`
Uses Rails Omakase style guide

---

## Deployment

### Docker & Kamal

**Docker Image:**
- Base: Ruby 3.4.5 slim
- Multi-stage build (base → build → final)
- Jemalloc for memory optimization
- Production env vars: `RAILS_ENV=production`, `BUNDLE_DEPLOYMENT=1`

**Kamal Config** (`config/deploy.yml`)
- Service: `recall`
- Servers: 192.168.0.1 (web)
- Registry: localhost:5555 (local Docker registry)
- Solid Queue in Puma for jobs
- Optional job server and load balancer

**Environment Secrets:**
- `RAILS_MASTER_KEY` (from config/master.key)
- Can set: `WEB_CONCURRENCY`, `JOB_CONCURRENCY`, `DB_HOST`, `RAILS_LOG_LEVEL`

**Build & Deploy:**
```bash
bin/kamal build        # Build Docker image
bin/kamal deploy       # Deploy to servers
bin/kamal logs         # Tail logs
```

---

## Key Features

### Import System
- **Checksums:** SHA256-based deduplication
- **Incremental:** Only imports changed files
- **Transactions:** All-or-nothing per session
- **Validation:** UTF-8 encoding, null byte stripping for FTS
- **Multi-source:** Claude Code (personal + work) + Codex

### Search
- **Full-Text Search:** SQLite FTS5 index
- **Snippets:** Context-aware highlights with `snippet()` function
- **Filtering:** By source, project, optional limit
- **Ranking:** SQLite FTS rank ordering

### Web UI
- **Home:** Projects index grouped by source type
- **Project View:** Sessions list (paginated, 30 per page) sorted by recent
- **Search:** Query results with session metadata
- **Session Detail:** Message list with content + tokens

---

## Development Workflow

1. **Setup Environment**
   ```bash
   bin/setup              # Install gems, prepare DB
   bin/dev               # Start server
   # Visit http://localhost:3000
   ```

2. **Import Data**
   ```bash
   bin/rails recall:import              # Import all
   # Or specific source:
   bin/rails recall:import_claude       # Personal Claude Code
   bin/rails recall:import_claude_work  # Work Claude Code
   bin/rails recall:import_codex        # Codex
   ```

3. **Run Tests**
   ```bash
   bin/rails test                 # Unit/integration
   bin/rails test:system         # Browser tests (Selenium)
   ```

4. **Lint Code**
   ```bash
   bin/rubocop                   # Check style
   bin/brakeman                  # Security scan
   ```

5. **Use CLI**
   ```bash
   bin/recall search "my query"
   bin/recall stats
   bin/recall projects
   ```

---

## Testing

**Fixtures:** `test/fixtures/` (YAML)
**Parallel:** Enabled (workers: :number_of_processors)
**System Tests:** Capybara + Selenium WebDriver

Run:
```bash
bin/rails test                    # All tests
bin/rails test test/models       # Only model tests
bin/rails test test/system       # Only system tests
```

---

## Security

**Static Analysis:**
- Brakeman: Rails-specific vulnerabilities
- Bundler Audit: Gem CVEs
- RuboCop: Code quality

**Credentials:**
- `config/master.key`: Main decryption key (in .gitignore)
- `config/credentials.yml.enc`: Encrypted secrets
- Kamal uses `RAILS_MASTER_KEY` env var

**CORS/CSP:**
- Content Security Policy configured in `config/initializers/content_security_policy.rb`
- Allows modern browsers only (webp, web push, badges, import maps, CSS nesting, :has)

---

## Common Tasks

### Add a New Model
```ruby
# Create migration
bin/rails g model ModelName field:type

# Then run
bin/rails db:migrate
```

### Add a View/Controller
```ruby
# Generate controller with views
bin/rails g controller ControllerName action1 action2
```

### Run Specific Test
```bash
bin/rails test test/models/message_test.rb
bin/rails test test/models/message_test.rb:15  # Specific line
```

### Rebuild FTS Index
```bash
bin/rails c
> Recall::Importer.rebuild_fts
```

### Export Database
```bash
sqlite3 storage/development.sqlite3 .dump > backup.sql
```

---

## Notes

- **Storage:** All SQLite databases in `storage/` (gitignored)
- **Logs:** `log/` directory (gitignored)
- **Assets:** Propshaft pipeline (no Sprockets)
- **Jobs:** Solid Queue (database-backed, no Redis needed)
- **No External Services:** Everything is file/DB-based
- **FTS Limitations:** SQLite FTS5 features only (no complex queries)

---

## References

- Rails 8.1: https://guides.rubyonrails.org
- SQLite FTS5: https://www.sqlite.org/fts5.html
- Solid Queue: https://github.com/rails/solid_queue
- Kamal: https://kamal-deploy.org
- Hotwire: https://hotwired.dev
