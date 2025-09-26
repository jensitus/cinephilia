class Movie < ApplicationRecord
  include TmdbUtility

  require "nokogiri"
  require "open-uri"
  require "net/http"
  require "json"

  has_and_belongs_to_many :genres
  has_many :schedules
  has_many :cinemas, through: :schedules

  BASE_MOVIE_URL = "https://efs-varnish.film.at/api/v1/cfs/filmat/screenings/nested/movie/"
  VIENNA = "Wien"
  DAYS_TO_FETCH = 7

  def self.set_date
    current_date = Date.today
    end_date = Date.today + DAYS_TO_FETCH
    fetch_movies_for_date_range(current_date, end_date)
    Schedule.delete_old_schedules(current_date)
    delete_movies_without_schedules
    Schedule.delete_schedules_without_movies
  end

  private

  def self.fetch_movies_for_date_range(start_date, end_date)
    start_date.upto(end_date - 1) do |date|
      fetch_movies_for_date(date)
    end
  end

  def self.fetch_movies_for_date(date)
    url = URI.parse("#{BASE_MOVIE_URL}#{date}")
    parsed_result = fetch_and_parse_movies(url)

    parsed_result.each do |movie_data|
      process_movie_data(movie_data)
    end
  end

  def self.process_movie_data(movie_data)
    return unless movie_belongs_to_vienna?(movie_data)

    film_at_uri = movie_data["parent"]["uri"].gsub("/filmat", "")
    movie_string_id = create_movie_id(movie_data["parent"]["title"]) # "m-#{movie_data["parent"]["title"].downcase.tr(" ", "-").gsub("---", "-").tr(",", "-")}"

    movie = find_or_create_movie(movie_string_id, film_at_uri, movie_data["parent"]["title"])
    associate_genres_with_movie(movie, movie_data["parent"]["genres"])
    Cinema.process_cinemas_and_schedules(movie_data, movie.id)
  end

  def self.associate_genres_with_movie(movie, genres)
    return unless genres.present?

    genres.each do |genre_name|
      genre = Genre.find_or_create_genre(genre_name)
      movie.genres << genre unless movie.genres.include?(genre)
    end
  end

  def self.movie_belongs_to_vienna?(movie_data)
    movie_data["nestedResults"].any? { |nested| nested["parent"]["county"] == VIENNA }
  end

  def self.fetch_and_parse_movies(url)

    response = Net::HTTP.get(url)
    JSON.parse(response)["result"]
=begin
    file = File.read("./public/2025-08-28.json")
    JSON.parse(file)["result"]
=end
  end

  scope :delete_movies_without_schedules, -> do
    left_outer_joins(:schedules).where(schedules: { id: nil }).find_each(&:destroy)
  end

  def self.find_or_create_movie(movie_string_id, film_at_uri, movie_title)
    movie = find_or_initialize_by(movie_id: movie_string_id)
    movie.title = movie_title if movie.new_record?
    movie.movie_id = movie_string_id if movie.new_record?

    if movie.tmdb_id.nil?
      movie.original_title = get_movie_query_title(film_at_uri, movie.title)
      update_movie_with_additional_info(film_at_uri, movie)
      tmdb_id = fetch_tmdb_id(movie.original_title, movie.title, movie.year)
      TmdbUtility.fetch_movie_info_from_tmdb(movie, tmdb_id) unless tmdb_id.nil?
    end
    movie.save if movie.changed?
    movie
  end

  scope :update_movie_with_additional_info, ->(uri, movie) do
    additional_info = get_additional_info(uri, "article div p span.release")
    return if additional_info.nil?
    add_info_squish = additional_info.squish
    additional_info_array = add_info_squish.split(",")
    year = additional_info_array.last.strip
    additional_info_array.delete_at(-1)
    countries = additional_info_array.join(", ")
    country_string = countries.chomp(", ").gsub("\n", "")
    movie.update(countries: country_string, year: year)
  end

  # def self.process_cinemas_and_schedules(movie_json, movie_id)
  #   movie_json["nestedResults"].each do |nested_result|
  #     next unless nested_result["parent"]["county"] == VIENNA
  #     cinema = find_or_create_cinema(nested_result["parent"])
  #     create_schedules_with_tags(nested_result["screenings"], movie_id, cinema.id)
  #   end
  # end

  # def self.create_schedules_with_tags(screenings, movie_id, cinema_id)
  #   screenings.each do |screening|
  #     schedule = Schedule.create_schedule(screening, movie_id, cinema_id)
  #     associate_tags_with_schedule(screening["tags"], schedule) if screening["tags"]
  #   end
  # end
  #
  # def self.associate_tags_with_schedule(tags, schedule)
  #   return unless schedule
  #
  #   tags.each do |tag_name|
  #     tag = Tag.find_or_create_tag(tag_name)
  #     schedule.tags << tag unless schedule.tags.include?(tag)
  #   end
  # end

  def self.get_additional_info(uri, html_parse_string)
    NokogiriService.call(uri, html_parse_string)
  end

  def self.fetch_tmdb_id(movie_original_title, movie_title, year)
    tmdb_id = get_movie_query_tmdb_url_and_further_get_tmdb_id(movie_original_title, movie_title, year)
    tmdb_id
  end

  def self.get_movie_query_title(uri, movie_title_json)
    movie_query_title = get_additional_info(uri, "article div p span.ov-title")
    if movie_query_title.nil? or movie_query_title == ""
      movie_query_title = movie_title_json
    end
    movie_query_title
  end

  def self.get_movie_query_tmdb_url_and_further_get_tmdb_id(movie_query_title, movie_title_json, year)
    query_string = NormalizeAndCleanService.call(movie_query_title)
    tmdb_url = TmdbUtility.create_movie_search_url(query_string, movie_title_json)
    if tmdb_url.nil?
      query_string = NormalizeAndCleanService.call(movie_title_json)
      tmdb_url = TmdbUtility.create_movie_search_url(query_string, movie_title_json)
    end
    TmdbUtility.fetch_tmdb_id(tmdb_url, year, query_string, movie_title_json)
  end

  def self.find_or_create_cinema(cinema)
    theater_id = "t-" + cinema["title"].gsub(" ", "-").downcase
    cinema = Cinema.find_or_create_by(cinema_id: theater_id)
    cinema.update(title: cinema["title"], county: cinema["county"], uri: get_cinema_url(cinema["uri"].gsub("/filmat", "")), cinema_id: theater_id) if cinema.new_record?
    cinema
  end

  def self.get_cinema_url(uri)
    cinema_url = nil
    content = get_additional_info(uri, "main div section div div p a")
    if content.start_with?("http")
      cinema_url = content
    end
    cinema_url
  end

  scope :create_movie_id, ->(title) { "m-#{title.downcase.tr(" ", "-").gsub("---", "-").tr(",", "-")}" }

end
