class SearchController < ApplicationController
  def index
    @query = params[:q]
    @search = Search.new(@query)
    @results = @search.results
  end
end
