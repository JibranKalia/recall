class SearchController < ApplicationController
  BACKENDS = %w[fts algolia].freeze

  def index
    @query = params[:q].to_s.strip
    @backend = params[:backend].to_s
    @backend = "fts" unless BACKENDS.include?(@backend)
    @backend = "fts" if @backend == "algolia" && !Session.algolia_enabled?
    @algolia_available = Session.algolia_enabled?

    if @query.present?
      @results = run_search(@query, @backend)
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

  private

  def run_search(query, backend)
    case backend
    when "algolia"
      Recall::AlgoliaSearcher.search(query, limit: 50)
    else
      Message.search(query, limit: 50)
    end
  end
end
