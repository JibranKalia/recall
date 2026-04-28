#!/usr/bin/env ruby
# Compare a SQLite source DB to the current Postgres primary DB.
# Limits comparisons to id <= max(id) in SQLite so post-copy reimport
# additions don't show up as drift.
require_relative "../config/environment"
require "sqlite3"
require "digest"

src_path = ENV["SQLITE_PATH"] || File.join(Dir.home, ".config", "recall", "development.sqlite3")
abort "Source not found: #{src_path}" unless File.exist?(src_path)

sqlite = SQLite3::Database.new(src_path, readonly: true)
sqlite.results_as_hash = true
pg = ActiveRecord::Base.connection

TABLES = %w[
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
].freeze

puts "Comparing #{src_path} <-> Postgres #{pg.current_database}"
puts ""
puts "%-22s %12s %12s %10s" % ["table", "sqlite", "pg(<=max)", "delta"]
puts "-" * 60

issues = []

TABLES.each do |table|
  sqlite_count = sqlite.execute("SELECT COUNT(*) AS c FROM #{table}").first["c"]
  sqlite_max_id = sqlite.execute("SELECT MAX(id) AS m FROM #{table}").first["m"]

  if sqlite_max_id.nil?
    puts "%-22s %12s %12s %10s" % [table, sqlite_count, "—", "(empty)"]
    next
  end

  pg_count = pg.select_value("SELECT COUNT(*) FROM #{pg.quote_table_name(table)} WHERE id <= #{sqlite_max_id}").to_i
  delta = pg_count - sqlite_count
  marker = delta.zero? ? "ok" : "DRIFT"

  puts "%-22s %12d %12d %10s" % [table, sqlite_count, pg_count, marker]

  issues << "#{table}: sqlite=#{sqlite_count} pg=#{pg_count}" unless delta.zero?
end

puts ""
puts "Spot-checking 5 random message_contents.content_text rows..."
ids = sqlite.execute("SELECT id FROM message_contents ORDER BY RANDOM() LIMIT 5").map { |r| r["id"] }
mismatches = 0
ids.each do |id|
  s_row = sqlite.execute("SELECT content_text, content_json FROM message_contents WHERE id = ?", [id]).first
  p_row = pg.exec_query("SELECT content_text, content_json FROM message_contents WHERE id = $1", "spot", [id]).first
  if p_row.nil?
    puts "  id=#{id}: MISSING in PG"
    mismatches += 1
    next
  end
  txt_match = s_row["content_text"] == p_row["content_text"]
  json_match = s_row["content_json"] == p_row["content_json"]
  status = (txt_match && json_match) ? "ok" : "MISMATCH"
  puts "  id=#{id}: #{status} text_len(sqlite=#{s_row['content_text']&.bytesize} pg=#{p_row['content_text']&.bytesize})"
  mismatches += 1 unless txt_match && json_match
end

puts ""
puts "Comparing message_contents content_text checksum (sample of 100 random ids)..."
sample_ids = sqlite.execute("SELECT id FROM message_contents ORDER BY RANDOM() LIMIT 100").map { |r| r["id"] }
checksum_mismatches = 0
sample_ids.each do |id|
  s = sqlite.execute("SELECT content_text FROM message_contents WHERE id = ?", [id]).first["content_text"]
  p = pg.select_value("SELECT content_text FROM message_contents WHERE id = #{id}")
  checksum_mismatches += 1 if Digest::SHA256.hexdigest(s.to_s) != Digest::SHA256.hexdigest(p.to_s)
end
puts "  mismatches: #{checksum_mismatches}/100"

puts ""
if issues.empty? && mismatches.zero? && checksum_mismatches.zero?
  puts "All checks passed."
else
  puts "Issues:"
  issues.each { |i| puts "  - #{i}" }
  puts "  - spot-check mismatches: #{mismatches}/5" if mismatches > 0
  puts "  - sample checksum mismatches: #{checksum_mismatches}/100" if checksum_mismatches > 0
end
