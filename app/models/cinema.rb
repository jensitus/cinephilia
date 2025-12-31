class Cinema < ApplicationRecord
  has_many :schedules
  has_many :movies, through: :schedules
  # has_and_belongs_to_many :tags

  VIENNA = "Wien"

  VOTIV_KINO = "Votiv Kino"
  DE_FRANCE = "De France"
  SCHIKANEDER = "Schikaneder"
  BURG_KINO = "Burg Kino"

  def self.get_random_movie_for_start_page(cinema)
    Movie.distinct.joins(schedules: :cinema)
         .where(cinemas: { title: [ cinema ] })
         .select("movies.title, movies.id, movies.description, movies.poster_path, cinemas.title AS cinema_title")
  end

  scope :process_cinemas_and_schedules, ->(movie_json, movie_id) do
    movie_json["nestedResults"].each do |nested_result|
      next unless nested_result["parent"]["county"] == VIENNA
      cinema = find_or_create_cinema(nested_result["parent"])
      Schedule.create_schedules_with_tags(nested_result["screenings"], movie_id, cinema.id)
    end
  end

  scope :find_or_create_cinema, ->(cinema_) do
    theater_id = "t-" + cinema_["title"].gsub(" ", "-").downcase
    cinema = find_or_create_by(cinema_id: theater_id)
    cinema_url = get_cinema_url(cinema_["uri"].gsub("/filmat", ""))
    if cinema_url.class != String
      cinema_url = nil
    end
    if cinema.title.nil?
      cinema.update(title: cinema_["title"], county: cinema_["county"], uri: cinema_url, cinema_id: theater_id)
    end
    cinema
  end

  scope :get_cinema_url, ->(uri) do
    cinema_url = nil
    content = NokogiriService.call(uri, "main div section div div p a") # get_additional_info(uri, "main div section div div p a")
    if content.start_with?("http")
      cinema_url = content
    end unless content.nil?
    cinema_url
  end
end
