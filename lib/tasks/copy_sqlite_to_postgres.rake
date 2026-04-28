namespace :recall do
  desc "Copy legacy SQLite data into the current (Postgres) primary database"
  task copy_sqlite_to_postgres: :environment do
    require "sqlite3"

    src_path = ENV["SQLITE_PATH"] || File.join(Dir.home, ".config", "recall", "development.sqlite3")
    abort "Source not found: #{src_path}" unless File.exist?(src_path)

    pg = ActiveRecord::Base.connection
    abort "Target is not Postgres (#{pg.adapter_name})" unless pg.adapter_name == "PostgreSQL"

    sqlite = SQLite3::Database.new(src_path, readonly: true)
    sqlite.results_as_hash = true

    # Order respects FK dependencies; nullable FKs (e.g.
    # session_summaries.experiment_run_id) drive the placement of dependents.
    tables = %w[
      projects
      sessions
      session_sources
      messages
      message_contents
      token_usages
      experiments
      experiment_runs
      session_summaries
      session_tombstones
      import_runs
    ]

    puts "Copying from #{src_path} to Postgres database #{pg.current_database}"
    puts ""

    tables.each { |t| copy_table(sqlite, pg, t) }

    puts ""
    puts "Done."
  end

  def copy_table(sqlite, pg, table)
    total = sqlite.execute("SELECT COUNT(*) AS c FROM #{table}").first["c"]
    if total.zero?
      puts "  #{table}: empty, skipped"
      return
    end

    pg_columns = pg.columns(table).index_by(&:name)
    src_columns = sqlite.execute("PRAGMA table_info(#{table})").map { |r| r["name"] }
    shared = src_columns & pg_columns.keys
    quoted_table = pg.quote_table_name(table)
    quoted_cols = shared.map { |c| pg.quote_column_name(c) }.join(",")

    pg.execute("TRUNCATE TABLE #{quoted_table} RESTART IDENTITY CASCADE")

    copied = 0
    offset = 0
    batch_size = 500

    loop do
      rows = sqlite.execute(
        "SELECT * FROM #{table} ORDER BY id LIMIT ? OFFSET ?",
        [batch_size, offset]
      )
      break if rows.empty?

      values = rows.map do |row|
        casted = shared.map { |c| pg.quote(cast_value(row[c], pg_columns[c])) }
        "(#{casted.join(',')})"
      end

      pg.execute("INSERT INTO #{quoted_table} (#{quoted_cols}) VALUES #{values.join(',')}")

      copied += rows.size
      offset += rows.size
      print "\r  #{table}: #{copied}/#{total}"
      $stdout.flush
    end
    puts ""

    # Reset the id sequence so future Rails-side inserts don't collide with
    # copied rows.
    seq = pg.select_value("SELECT pg_get_serial_sequence(#{pg.quote(table)}, 'id')")
    if seq
      max_id = pg.select_value("SELECT MAX(id) FROM #{quoted_table}").to_i
      pg.execute("SELECT setval(#{pg.quote(seq)}, #{[max_id, 1].max})")
    end
  end

  def cast_value(value, column)
    return nil if value.nil?

    case column.sql_type_metadata.type
    when :boolean
      # SQLite stores booleans as 0/1.
      value == 1 || value == true || value == "t" || value == "true"
    else
      value
    end
  end
end
