class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip

    if @query.present?
      @results = Message.search(@query, limit: 50)
      @sessions_by_id = Session.where(id: @results.map(&:session_id).uniq)
        .includes(:project)
        .index_by(&:id)

      if request.xhr?
        render partial: "search/results", layout: false
        return
      end
    end

    render formats: [:html]
  end
end
