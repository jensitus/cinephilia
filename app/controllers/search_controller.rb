class SearchController < ApplicationController
  prepend_before_action :use_all_counties

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

    @tmdb_by_local_movie = {}
    @tmdb_only_results = []

    if @query.present?
      tmdb_response = Tmdb::Client.search_movies(@query)
      tmdb_results = tmdb_response&.dig("results") || []
      tmdb_ids = tmdb_results.map { |r| r["id"].to_s }
      local_by_tmdb_id = Movie.where(tmdb_id: tmdb_ids).index_by(&:tmdb_id)

      tmdb_results.each do |result|
        if (local_movie = local_by_tmdb_id[result["id"].to_s])
          @tmdb_by_local_movie[local_movie.id] = result
        else
          @tmdb_only_results << result
        end
      end
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

    Cinema.search(query).in_county(current_county).limit(12).each do |cinema|
      location = [ cinema.street, cinema.city || cinema.county ].compact.join(", ")
      results << {
        type: "Cinema",
        title: cinema.title,
        subtitle: location.presence,
        url: cinema_path(cinema)
      }
    end

    render json: results.take(10)
  end

  private

  def use_all_counties
    params[:county] = "Österreich"
  end
end
