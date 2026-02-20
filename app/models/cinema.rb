class Cinema < ApplicationRecord
  include Searchable

  has_many :schedules
  has_many :movies, through: :schedules

  validates :cinema_id, :title, :county, presence: true

  scope :in_county, ->(county) { where(county: county) }

  def self.get_random_movie_for_start_page(cinema)
    Movie.distinct.joins(schedules: :cinema)
         .where(cinemas: { title: [ cinema ] })
         .select("movies.title, movies.id, movies.description, movies.poster_path, cinemas.title AS cinema_title")
  end

  def self.process_cinemas_and_schedules(movie_json, movie_id)
    movie_json["nestedResults"].each do |nested_result|
      cinema = find_or_create_cinema(nested_result["parent"])
      Schedule.create_schedules_with_tags(nested_result["screenings"], movie_id, cinema.id)
    end
  end

  def self.find_or_create_cinema(cinema_data)
    theater_id = "t-#{cinema_data['title'].gsub(' ', '-').downcase}"
    cinema = find_or_create_by(cinema_id: theater_id)
    cinema_url = get_cinema_url(cinema_data["uri"].gsub("/filmat", ""))
    cinema_url = nil unless cinema_url.is_a?(String)

    if cinema.title.blank?
      cinema.update(title: cinema_data["title"], county: cinema_data["county"], uri: cinema_url, cinema_id: theater_id)
    end

    cinema
  end

  def self.get_cinema_url(uri)
    content = NokogiriService.call(uri, "main div section div div p a")
    return nil if content.blank?

    content.start_with?("http") ? content : nil
  end
end
