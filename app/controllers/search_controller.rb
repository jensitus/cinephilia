class SearchController < ApplicationController
  def index
    @query = params[:q]
    @search = Search.new(@query)
    @results = @search.results

    if @results[:genres]&.any?
      @results[:genres] = @results[:genres].includes(movies: :schedules)
    end

    if @results[:people]&.any?
      @results[:people] = @results[:people].includes(:movies, :credits)
    end
  end

  def autocomplete
    query = params[:q]

    if query.blank?
      render json: []
      return
    end

    results = []

    Movie.search(query).in_county(current_county).limit(3).each do |movie|
      results << {
        type: "Movie",
        title: movie.title,
        subtitle: movie.year,
        url: movie_path(movie)
      }
    end

    Person.search(query).includes(:credits).limit(3).each do |person|
      acting_count = person.credits.count { |c| c.role == "cast" }
      directing_count = person.credits.count { |c| c.role == "crew" && c.job == "Director" }
      results << {
        type: "Person",
        title: person.name,
        subtitle: "#{acting_count} acting, #{directing_count} directing",
        url: search_path(q: person.name)
      }
    end

    Genre.search(query).includes(:movies).limit(2).each do |genre|
      results << {
        type: "Genre",
        title: genre.name,
        subtitle: "#{genre.movies.size} movies",
        url: search_path(q: genre.name)
      }
    end

    Cinema.search(query).in_county(current_county).limit(2).each do |cinema|
      results << {
        type: "Cinema",
        title: cinema.title,
        subtitle: cinema.street.presence,
        url: cinema_path(cinema)
      }
    end

    render json: results.take(10)
  end
end
