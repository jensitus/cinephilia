module Cinephilia
  module Config
    COUNTIES = [
      "Wien",
      "Niederösterreich",
      "Oberösterreich",
      "Steiermark",
      "Tirol",
      "Kärnten",
      "Salzburg",
      "Vorarlberg",
      "Burgenland"
    ].freeze

    DEFAULT_COUNTY = "Wien".freeze

    FEATURED_CINEMAS = {
      "Wien" => [
        "Votiv Kino",
        "Top Kino",
        "De France",
        "Gartenbaukino",
        "Burg Kino",
        "Schikaneder"
      ]
    }.freeze

    FILM_AT_API_BASE_URL = "https://efs-varnish.film.at/api/v1/cfs/filmat/screenings/nested/movie/".freeze

    DAYS_TO_FETCH = 17
  end
end
