class ImportsController < ApplicationController
  def status
    render json: {
      last_import_at: ImportRun.last_completed_at&.iso8601,
      running: ImportRun.any_running?
    }
  end

  def create
    if params[:session_id].present?
      session = Session.includes(:source).find_by(id: params[:session_id])
      if session
        Recall::Importer.reimport_session(session)
        Turbo::StreamsChannel.broadcast_action_to(session, action: :refresh)
      end
      head :ok
      return
    end

    unless ImportRun.any_running?
      ImportJob.perform_later
    end

    head :ok
  end
end
