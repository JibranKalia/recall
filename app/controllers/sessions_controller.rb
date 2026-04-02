class SessionsController < ApplicationController
  def show
    @session = Session.includes(:project).find(params[:id])
    @messages = @session.messages.ordered
  end

  def regenerate_title
    @session = Session.find(params[:id])
    Recall::TitleGenerator.generate(@session)
    redirect_to @session
  end
end
