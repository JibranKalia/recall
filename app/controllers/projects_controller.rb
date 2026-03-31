class ProjectsController < ApplicationController
  def index
    @projects_by_source = Project.order(:name).group_by(&:source_type)
  end

  def show
    @project = Project.find(params[:id])
    @sessions = @project.sessions.recent.page(params[:page])
  end
end
