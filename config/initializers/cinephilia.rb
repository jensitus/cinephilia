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

    FEATURED_CINEMAS = begin
      by_county = {
        "Wien" => [
        "Votiv Kino",
        "Top Kino",
        "De France",
        "Gartenbaukino",
        "Burg Kino",
        "Schikaneder",
        "Filmmuseum",
        "Metro Kinokulturhaus"
      ],
      "Niederösterreich" => [
        "Kino im Kesselhaus",
        "Cinema Paradiso St. Poelten"
      ],
      "Tirol" => [
        "Cinematograph Innsbruck",
        "Leokino",
        "Kino Fulpmes"
      ],
      "Oberösterreich" => [
        "City-Kino",
        "Moviemento Linz",
        "Programmkino Wels",
        "City Kino Steyr"
      ],
      "Salzburg" => [
        "Das Kino",
        "Lichtspiele Mittersill"
      ],
      "Steiermark" => [
        "KIZ RoyalKino",
        "Stadtkino Bruck an der Mur",
        "Filmzentrum im Rechbauerkino"
      ],
      "Kärnten" => [
        "Neues Volkskino",
        "Filmstudio Villach",
        "Wulfenia Kinozentrum",
        "Volkskino Klagenfurt"
      ],
      "Vorarlberg" => [
        "Cinema Dornbirn",
        "Kino Bludenz",
        "GUK Kino Feldkirch",
        "Spielboden",
        "Kinothek Lustenau"
      ]
      }
      all = by_county.sort_by { |county, _| county }.flat_map { |_, cinemas| cinemas }
      by_county.merge("Österreich" => all).freeze
    end

    # Cinemas covered by dedicated crawlers — excluded from the film.at API import
    # to avoid duplicate schedules.
    FILM_AT_EXCLUDED_CINEMAS = [ "Metro Kinokulturhaus", "Votiv Kino", "De France", "Filmmuseum", "Cineplexx Spittal",
                                 "Cinepoint Seefeld", "Kino Fulpmes", "Leokino", "Cinematograph Innsbruck" ].freeze

    FILM_AT_API_BASE_URL = "https://efs-varnish.film.at/api/v1/cfs/filmat/screenings/nested/movie/".freeze

    FILM_AT_FIXTURE_PATH = Rails.root.join("public", "film_at_fixture.json").freeze

    DAYS_TO_FETCH = Rails.env.development? ? 2 : 17
  end
end
