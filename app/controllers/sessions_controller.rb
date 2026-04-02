class SessionsController < ApplicationController
  def show
    @session = Session.includes(:project).find(params[:id])
    @messages = @session.messages.ordered
  end

  def regenerate_title
    @session = Session.find(params[:id])
    title = Recall::TitleGenerator.generate(@session)
    @session.update_column(:custom_title, title) if title.present?
    redirect_to @session
  end
end
