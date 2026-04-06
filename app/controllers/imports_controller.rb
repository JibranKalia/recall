class ImportsController < ApplicationController
  def create
    if params[:session_id].present?
      session = Session.includes(:source).find_by(id: params[:session_id])
      Recall::Importer.reimport_session(session) if session
    end

    ImportJob.perform_later

    head :ok
  end
end
