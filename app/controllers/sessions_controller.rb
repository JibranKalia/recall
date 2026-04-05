class SessionsController < ApplicationController
  def show
    @session = Session.includes(:project, :source).find(params[:id])
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
    GenerateSummaryJob.perform_later(@session)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.update("session_summary",
          html: '<div class="session-summary-generating">Generating summary... this will update automatically when ready.</div>'.html_safe
        )
      }
      format.html { redirect_to @session }
    end
  end
end
