class ProjectsController < ApplicationController
  def index
    @projects = Project
      .joins(:sessions)
      .select("projects.*, MAX(sessions.started_at) AS latest_session_at")
      .group("projects.id")
      .order("latest_session_at DESC")

    @query = params[:q].to_s.strip
    if @query.present?
      @results = Message.search(@query, limit: 50)
      @sessions_by_id = Session.where(id: @results.map(&:session_id).uniq)
        .includes(:project)
        .index_by(&:id)

      if request.xhr?
        render partial: "projects/search_results", layout: false
        return
      end
    end

    render formats: [:html]
  end

  def show
    @project = Project.find(params[:id])
    @sessions = @project.sessions.recent.page(params[:page])
  end
end
