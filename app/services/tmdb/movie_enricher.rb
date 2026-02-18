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
      description = fetch_description(id_string)
      poster_path = fetch_attribute(id_string, "poster_path")
      runtime = fetch_attribute(id_string, "runtime")
      credits = Tmdb::Client.get_credits(id_string)

      MovieConcerns.assign_movie_attributes(movie, tmdb_id, description, poster_path, credits, runtime)
    end

    private

    def fetch_description(id_string)
      description = fetch_attribute(id_string, "overview")
      return description if description.present?

      fetch_attribute(id_string, "overview", without_language: true)
    end

    def fetch_attribute(id_string, attribute, without_language: false)
      movie_data = Tmdb::Client.get_movie(id_string, with_language: !without_language)
      return nil if movie_data.nil?

      movie_data[attribute]
    end
  end
end
