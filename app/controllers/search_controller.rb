class SearchController < ApplicationController
  def index
    @query = params[:q]
    @search = Search.new(@query)
    @results = @search.results

    if @results[:genres]&.any?
      @results[:genres] = @results[:genres].includes(movies: :schedules)
    end

    if @results[:people]&.any?
      @results[:people] = @results[:people].includes(:movies)
    end
  end

  def autocomplete
    query = params[:q]

    if query.blank?
      render json: []
      return
    end

    results = []

    # Get top results from each category
    Movie.search(query).limit(3).each do |movie|
      results << {
        type: "Movie",
        title: movie.title,
        subtitle: movie.year,
        url: movie_path(movie)
      }
    end

    Person.search(query).limit(3).each do |person|
      results << {
        type: "Person",
        title: person.name,
        subtitle: "#{person.credits.where(role: 'cast').count} acting, #{person.credits.where(role: 'crew', job: 'Director').count} directing",
        url: search_path(q: person.name) # Link to search results
      }
    end

    Genre.search(query).limit(2).each do |genre|
      results << {
        type: "Genre",
        title: genre.name,
        subtitle: "#{genre.movies.count} movies",
        url: search_path(q: genre.name) # Link to search results
      }
    end

    Cinema.search(query).limit(2).each do |cinema|
      results << {
        type: "Cinema",
        title: cinema.title,
        subtitle: cinema.street ? cinema.street : nil,
        url: cinema_path(cinema)
      }
    end

    render json: results.take(10)
  end
end
