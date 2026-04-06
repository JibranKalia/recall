class GenerateSummaryJob < ApplicationJob
  queue_as :default

  def perform(session, provider_key: "claude_code:sonnet")
    Recall::Summarizer.new(session, provider_key: provider_key).generate
    session.reload

    Turbo::StreamsChannel.broadcast_update_to(
      session,
      target: "session_title",
      html: session.display_title
    )

    Turbo::StreamsChannel.broadcast_update_to(
      session,
      target: "session_summary",
      partial: "sessions/summary",
      locals: { session: session }
    )
  end
end
