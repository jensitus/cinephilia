module Cinephilia
  module Config
    COUNTIES = [
      "Österreich",
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
        "Schikaneder",
        "Filmmuseum",
        "Metro Kinokulturhaus"
      ]
    }.freeze

    # Cinemas covered by dedicated crawlers — excluded from the film.at API import
    # to avoid duplicate schedules.
    FILM_AT_EXCLUDED_CINEMAS = [ "Metro Kinokulturhaus", "Votiv Kino", "De France", "Filmmuseum" ].freeze

    FILM_AT_API_BASE_URL = "https://efs-varnish.film.at/api/v1/cfs/filmat/screenings/nested/movie/".freeze

    DAYS_TO_FETCH = 17
  end
end
