module Tmdb
  class MovieEnricher
    attr_reader :movie, :tmdb_id

    def initialize(movie, tmdb_id = nil)
      @movie = movie
      @tmdb_id = tmdb_id || movie.tmdb_id
    end

    def enrich
      return unless tmdb_id

      id_string = tmdb_id.to_s
      movie_data = Tmdb::Client.get_movie(id_string)
      credits = Tmdb::Client.get_credits(id_string)

      description = movie_data&.dig("overview").presence ||
                    Tmdb::Client.get_movie(id_string, with_language: false)&.dig("overview")

      MovieConcerns.assign_movie_attributes(
        movie, tmdb_id,
        description:  description,
        poster_path:  movie_data&.dig("poster_path"),
        credits:      credits,
        runtime:      movie_data&.dig("runtime"),
        year:         movie_data&.dig("release_date")&.slice(0, 4),
        countries:    movie_data&.dig("production_countries")&.map { |c| c["iso_3166_1"] }&.join(", ")
      )
    end
  end
end
