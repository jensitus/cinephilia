module Cinephilia
  module Config
    FEATURED_CINEMAS = [
      "Votiv Kino",
      "Top Kino",
      "De France",
      "Gartenbaukino",
      "Burg Kino",
      "Schikaneder"
    ].freeze

    FILM_AT_API_BASE_URL = "https://efs-varnish.film.at/api/v1/cfs/filmat/screenings/nested/movie/".freeze

    DAYS_TO_FETCH = 17

    VIENNA = "Wien".freeze
  end
end
