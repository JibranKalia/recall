class SessionsController < ApplicationController
  def show
    @session = Session.includes(:project).find(params[:id])
    @messages = @session.messages.ordered
  end

  def markdown
    @session = Session.includes(:project, :messages).find(params[:id])
    options = {
      thinking: params[:thinking] == "1",
      tool_details: params[:tool_details] == "1"
    }
    render plain: @session.to_markdown(**options), content_type: "text/markdown"
  end

  def regenerate_title
    @session = Session.find(params[:id])
    GenerateTitleJob.perform_later(@session)
    redirect_to @session
  end
end
