class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    return if @query.blank?

    @results = Message.search(@query, limit: 50)
    @sessions_by_id = Session.where(id: @results.map(&:session_id).uniq)
      .includes(:project)
      .index_by(&:id)

    if request.headers["Accept"]&.include?("text/vnd.turbo-stream.html")
      render partial: "search/results", layout: false, formats: [:html]
    end
  end
end
