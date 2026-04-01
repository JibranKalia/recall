# Ensure the data directory exists for SQLite databases.
# Development databases live in ~/.config/recall/ so the CLI
# works from any working directory.
data_dir = ENV.fetch("RECALL_DATA_DIR") { File.join(Dir.home, ".config", "recall") }
FileUtils.mkdir_p(data_dir) unless Rails.env.test?
