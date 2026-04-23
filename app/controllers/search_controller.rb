class SearchController < ApplicationController
  BACKENDS = %w[fts algolia].freeze

  def index
    @query = params[:q].to_s.strip
    @algolia_available = Session.algolia_enabled?
    # Default to Algolia in the UI when it's configured; fall back to FTS5
    # otherwise (and when the user explicitly picks an invalid backend).
    @backend = params[:backend].presence || (@algolia_available ? "algolia" : "fts")
    @backend = "fts" unless BACKENDS.include?(@backend)
    @backend = "fts" if @backend == "algolia" && !@algolia_available

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
