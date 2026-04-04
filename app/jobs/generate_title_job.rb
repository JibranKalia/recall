class GenerateTitleJob < ApplicationJob
  queue_as :default

  def perform(session)
    Recall::TitleGenerator.generate(session)
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
