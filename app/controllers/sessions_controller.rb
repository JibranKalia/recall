class SessionsController < ApplicationController
  def show
    @session = Session.includes(:project).find(params[:id])
    @messages = @session.messages.ordered
  end
end
