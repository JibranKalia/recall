class ProjectsController < ApplicationController
  def index
    @projects = Project
      .joins(sessions: :source)
      .select("projects.*, MAX(sessions.ended_at) AS latest_session_at, GROUP_CONCAT(DISTINCT session_sources.source_type) AS source_types_csv")
      .group("projects.id")
      .order("latest_session_at DESC")

    @query = params[:q].to_s.strip
    resolve_backend!

    if @query.present?
      @results = run_search(@query, @backend)
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
    resolve_backend!

    if @query.present?
      @results = run_search(@query, @backend, project_id: @project.id)
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

  private

  def resolve_backend!
    @backend = params[:backend].to_s
    @backend = "fts" unless SearchController::BACKENDS.include?(@backend)
    @backend = "fts" if @backend == "algolia" && !Session.algolia_enabled?
    @algolia_available = Session.algolia_enabled?
  end

  def run_search(query, backend, project_id: nil)
    case backend
    when "algolia"
      Recall::AlgoliaSearcher.search(query, limit: 50, project_id: project_id)
    else
      Message.search(query, limit: 50, project_id: project_id)
    end
  end
end
