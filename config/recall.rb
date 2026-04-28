# ============================================================================
# Recall configuration
# ============================================================================
#
# INSTRUCTIONS FOR AI ASSISTANTS
#
# This file is meant to be edited. It sets where Recall looks for
# conversation data, how to classify projects into domains, and which local
# LLMs to use by default.
#
# Two files are loaded, in order:
#
#   1. config/recall.rb        <- this file, checked into git
#   2. config/recall.local.rb  <- optional, gitignored; a good home for
#                                 personal paths you don't want committed
#
# Both use the same DSL via `Recall.configure`. List-type settings
# accumulate across the two files: calling `c.claude_code "..."` in each
# adds to the list rather than replacing. Scalars (e.g. `c.default_domain =
# "..."`) overwrite on each assignment.
#
# To reset a list from the local file, assign an empty array first:
#   c.claude_code_dirs = []
# then add fresh entries with the DSL.
#
# Missing source paths are skipped silently at import time, so a config
# entry for a tool that isn't installed on this machine is safe.
#
# After editing, restart the Rails server (bin/dev) so the new config loads.
# ============================================================================

Recall.configure do |c|
  # --- Import sources ------------------------------------------------------

  # Each `claude_code` line adds a Claude Code data directory to scan. The
  # `as:` name is the source tag shown in the UI and CLI — keep it unique.
  c.claude_code "~/.claude", as: "claude"

  # Codex state directory. Comment out to disable.
  c.codex "~/.codex"

  # OpenCode SQLite DB. Comment out to disable.
  c.opencode "~/.local/share/opencode/opencode.db"

  # --- Project domain classification ---------------------------------------

  # Imported sessions carry a `cwd`. Each `domain` line maps a cwd pattern
  # to a domain name; first match wins. Anything unmatched gets the
  # `default_domain`. Domains appear as filters in the UI and CLI.
  #
  # c.domain "work", matching: %r{/work/}
  # c.domain "side", matching: %r{/side/}
  # c.default_domain = "personal"

  # --- LLM providers -------------------------------------------------------

  # Ollama powers auto-summarization and title generation. Pull the model
  # with `ollama pull <name>` before running imports.
  # c.ollama_host          = "http://localhost:11434"
  # c.ollama_default_model = "qwen2.5:14b"

  # Defaults used by the Experiments feature when a provider key doesn't
  # pin a specific model.
  # c.claude_code_default_model = "claude-sonnet-4-20250514"
  # c.opencode_default_model    = "kimi-k2.5"
  # c.codex_default_model       = "codex"

  # Binary the ClaudeCode provider shells out to for experiments. Override
  # if you wrap `claude` in a script (e.g. one that picks CLAUDE_CONFIG_DIR
  # based on the current directory).
  # c.claude_code_command = "claude"

  # --- Data directory ------------------------------------------------------

  # Where Recall stores its SQLite DBs. The RECALL_DATA_DIR env var takes
  # precedence (it has to — database.yml reads it at boot, before this file
  # loads). Setting `c.data_dir` only affects the mkdir-p call.
  # c.data_dir = File.join(Dir.home, ".config", "recall")
end
