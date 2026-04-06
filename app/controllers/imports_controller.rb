class ImportsController < ApplicationController
  def create
    if params[:session_id].present?
      session = Session.includes(:source).find_by(id: params[:session_id])
      if session
        Recall::Importer.reimport_session(session)
        Turbo::StreamsChannel.broadcast_action_to(session, action: :refresh)
      end
    end

    ImportJob.perform_later

    head :ok
  end
end
