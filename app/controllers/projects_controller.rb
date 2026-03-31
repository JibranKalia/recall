class ProjectsController < ApplicationController
  def index
    @projects_by_source = Project.order(:name).group_by(&:source_type)

    @query = params[:q].to_s.strip
    if @query.present?
      @results = Message.search(@query, limit: 50)
      @sessions_by_id = Session.where(id: @results.map(&:session_id).uniq)
        .includes(:project)
        .index_by(&:id)
    end
  end

  def show
    @project = Project.find(params[:id])
    @sessions = @project.sessions.recent.page(params[:page])
  end
end
