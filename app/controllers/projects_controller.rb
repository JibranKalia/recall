class ProjectsController < ApplicationController
  def index
    @projects = Project
      .joins(sessions: :source)
      .select("projects.*, MAX(sessions.ended_at) AS latest_session_at, GROUP_CONCAT(DISTINCT session_sources.source_type) AS source_types_csv")
      .group("projects.id")
      .order("latest_session_at DESC")

    @query = params[:q].to_s.strip
    if @query.present?
      @results = Message.search(@query, limit: 50)
      @sessions_by_id = Session.where(id: @results.map(&:session_id).uniq)
        .includes(:project, :source)
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
    @query = params[:q].to_s.strip

    if @query.present?
      @results = Message.search(@query, limit: 50, project_id: @project.id)
      @sessions_by_id = Session.where(id: @results.map(&:session_id).uniq)
        .includes(:project, :source)
        .index_by(&:id)

      if request.xhr?
        render partial: "search/results", layout: false
        return
      end
    end

    @sessions = @project.sessions.includes(:token_usages).recent.page(params[:page])
  end
end
