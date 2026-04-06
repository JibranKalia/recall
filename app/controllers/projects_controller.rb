class ProjectsController < ApplicationController
  before_action :trigger_import_if_stale, only: [ :index, :show ]

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

  private

  def trigger_import_if_stale
    return if ImportRun.any_running?
    return if SolidQueue::Job.where(class_name: "ImportJob", finished_at: nil).exists?
    last_at = ImportRun.last_completed_at
    return if last_at && last_at > 30.minutes.ago
    ImportJob.perform_later
  end
end
