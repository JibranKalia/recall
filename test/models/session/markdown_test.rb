require "test_helper"

class Session::MarkdownTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "test-project", path: "/tmp/test-project", domain: "personal")
    @session = @project.sessions.create!(
      external_id: "markdown-test-#{SecureRandom.hex(4)}",
      title: "Test Session",
      started_at: Time.current
    )
  end

  test "conversation only excludes tool_use lines" do
    add_user_message("How do I fix this?")
    add_assistant_message([
      { "type" => "text", "text" => "Let me check the file." },
      { "type" => "tool_use", "name" => "Read", "input" => { "file_path" => "/tmp/foo.rb" } }
    ])
    add_tool_result("File contents here")
    add_assistant_message([{ "type" => "text", "text" => "The fix is to change line 5." }])

    md = @session.to_markdown(thinking: false, tool_details: false)

    assert_includes md, "Let me check the file."
    assert_includes md, "The fix is to change line 5."
    assert_not_includes md, "**Tool: Read**"
    assert_not_includes md, "File contents here"
  end

  test "conversation only skips tool-only assistant turns entirely" do
    add_user_message("Run the tests")
    # Assistant turn with only tool calls, no text
    add_assistant_message([{ "type" => "tool_use", "name" => "Bash", "input" => { "command" => "bin/rails test" } }])
    add_tool_result("3 tests, 0 failures")
    add_assistant_message([{ "type" => "text", "text" => "All tests pass." }])

    md = @session.to_markdown(thinking: false, tool_details: false)

    assert_not_includes md, "**Tool: Bash**"
    assert_not_includes md, "bin/rails test"
    assert_not_includes md, "3 tests, 0 failures"
    assert_includes md, "All tests pass."

    # Should have exactly 2 "## Assistant" headers (not 3)
    # One for the tool-only turn should be skipped
    assert_equal 1, md.scan("## Assistant").count
  end

  test "tool details mode includes tool_use and tool_result" do
    add_user_message("Check the file")
    add_assistant_message([
      { "type" => "text", "text" => "Reading it now." },
      { "type" => "tool_use", "name" => "Read", "input" => { "file_path" => "/tmp/foo.rb" } }
    ])
    add_tool_result("class Foo; end")

    md = @session.to_markdown(thinking: false, tool_details: true)

    assert_includes md, "Reading it now."
    assert_includes md, "**Tool: Read**"
    assert_includes md, "/tmp/foo.rb"
    assert_includes md, "**Output:**"
    assert_includes md, "class Foo; end"
  end

  test "thinking mode includes thinking blocks" do
    add_user_message("Explain this")
    add_assistant_message([
      { "type" => "thinking", "thinking" => "Let me reason about this." },
      { "type" => "text", "text" => "Here is the explanation." }
    ])

    without_thinking = @session.to_markdown(thinking: false, tool_details: false)
    assert_not_includes without_thinking, "Let me reason about this."
    assert_includes without_thinking, "Here is the explanation."

    with_thinking = @session.to_markdown(thinking: true, tool_details: false)
    assert_includes with_thinking, "_Thinking:_"
    assert_includes with_thinking, "Let me reason about this."
    assert_includes with_thinking, "Here is the explanation."
  end

  test "tool error results show Error label" do
    add_user_message("Run it")
    add_assistant_message([{ "type" => "tool_use", "name" => "Bash", "input" => { "command" => "exit 1" } }])
    add_tool_result("command failed", error: true)

    md = @session.to_markdown(thinking: false, tool_details: true)

    assert_includes md, "**Error:**"
    assert_includes md, "command failed"
  end

  test "consecutive assistant messages merge into one turn" do
    add_user_message("Fix the bug")
    add_assistant_message([{ "type" => "text", "text" => "First part." }])
    add_assistant_message([{ "type" => "text", "text" => "Second part." }])

    md = @session.to_markdown(thinking: false, tool_details: false)

    assert_equal 1, md.scan("## Assistant").count
    assert_includes md, "First part."
    assert_includes md, "Second part."
  end

  private

  def add_user_message(text)
    msg = @session.messages.create!(
      role: "user",
      position: next_position
    )
    msg.create_content!(
      content_text: text,
      content_json: [{ "type" => "text", "text" => text }].to_json
    )
    msg
  end

  def add_assistant_message(blocks)
    text_parts = blocks.filter_map { |b| b["text"] if b["type"] == "text" }
    tool_parts = blocks.filter_map { |b| "[Tool: #{b['name']}]" if b["type"] == "tool_use" }
    content_text = (text_parts + tool_parts).join("\n")

    msg = @session.messages.create!(
      role: "assistant",
      position: next_position
    )
    msg.create_content!(
      content_text: content_text,
      content_json: blocks.to_json
    )
    msg
  end

  def add_tool_result(output, error: false)
    msg = @session.messages.create!(
      role: "tool_result",
      position: next_position
    )
    msg.create_content!(
      content_text: output,
      content_json: [{ "type" => "tool_result", "content" => output, "is_error" => error }].to_json
    )
    msg
  end

  def next_position
    @position_counter = (@position_counter || -1) + 1
  end
end
