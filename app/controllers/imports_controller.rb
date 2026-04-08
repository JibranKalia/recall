class ImportsController < ApplicationController
  def create
    if params[:session_id].present?
      session = Session.includes(:source).find_by(id: params[:session_id])
      if session
        Recall::Importer.reimport_session(session)
        Turbo::StreamsChannel.broadcast_action_to(session, action: :refresh)
      end
    end

    unless ImportRun.any_running?
      ImportJob.perform_later
    end

    head :ok
  end
end
