class ImportJob < ApplicationJob
  queue_as :imports

  def perform
    Recall::Importer.import_all

    Turbo::StreamsChannel.broadcast_update_to(
      "imports",
      target: "nav_stats",
      html: "#{Session.count} sessions &middot; #{Message.count} messages"
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "imports",
      target: "import_btn",
      partial: "imports/button"
    )
  end
end
