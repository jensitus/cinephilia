class Movie < ApplicationRecord
  include Searchable
  include TmdbUtility

  require "nokogiri"
  require "open-uri"
  require "net/http"
  require "json"

  has_and_belongs_to_many :genres
  has_many :schedules
  has_many :cinemas, through: :schedules

  has_many :credits, dependent: :destroy
  has_many :people, through: :credits

  validates :movie_id, :title, presence: true

  scope :currently_showing, -> {
    where("EXISTS (SELECT 1 FROM schedules WHERE schedules.movie_id = movies.id AND schedules.time >= ?)", Date.today)
  }

  scope :not_currently_showing, -> {
    where.not(id: currently_showing.select(:id))
  }

  scope :without_schedules, -> {
    left_outer_joins(:schedules).where(schedules: { id: nil })
  }

  scope :in_county, ->(county) {
    joins(schedules: :cinema).where(cinemas: { county: county }).distinct
  }

  def currently_showing?
    schedules.where("time >= ?", Date.today).exists?
  end

  def self.movies_with_cinemas_for_startpage(cinema_titles)
    Movie.distinct
         .joins(schedules: :cinema)
         .where(cinemas: { title: cinema_titles })
         .includes(:cinemas)
         .map do |movie|
      cinema_names = movie.cinemas.where(title: cinema_titles).distinct.pluck(:title)
      { movie: movie, cinemas: cinema_names }
    end
  end

  def cast_members
    credits.where(role: "cast").includes(:person).order(:order)
  end

  def crew_members
    credits.where(role: "crew").includes(:person)
  end

  def directors
    people.joins(:credits).where(credits: { role: "crew", job: "Director" })
  end

  def self.set_date
    current_date = Date.today
    end_date = Date.today + Cinephilia::Config::DAYS_TO_FETCH
    # fetch_movies_for_date_range(current_date, end_date)
    failures = []
    crawlers = Crawlers::BaseCrawlerService.all_crawlers
    crawlers.each do |crawler|
      Rails.logger.info "Running #{crawler.name}..."
      crawler.call
    rescue StandardError => e
      backtrace = e.backtrace&.first(5) || []
      Rails.logger.error "#{crawler.name} failed: #{e.message}\n#{backtrace.join("\n")}"
      failures << { crawler: crawler.name, error: e.message, backtrace: backtrace }
    end
    CrawlerRun.create!(ran_at: Time.current, crawler_count: crawlers.size, failures: failures)
    CrawlerMailer.failure_report(failures).deliver_now if failures.any?
    Schedule.delete_old_schedules(current_date)
    Schedule.delete_schedules_without_movies
  end

  def self.delete_movies_without_schedules
    without_schedules.find_each(&:destroy)
  end

  private

  def self.fetch_movies_for_date_range(start_date, end_date)
    start_date.upto(end_date - 1) do |date|
      fetch_movies_for_date(date)
    end
  end

  def self.fetch_movies_for_date(date)
    url = URI.parse("#{Cinephilia::Config::FILM_AT_API_BASE_URL}#{date}")
    parsed_result = fetch_and_parse_movies(url)

    parsed_result.each do |movie_data|
      process_movie_data(movie_data)
    end
  end

  def self.process_movie_data(movie_data)
    film_at_uri = movie_data["parent"]["uri"].gsub("/filmat", "")
    movie_string_id = create_movie_id(movie_data["parent"]["title"])

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

  def self.fetch_and_parse_movies(url)
    response = Net::HTTP.get(url)
    JSON.parse(response)["result"]
=begin
    file = File.read("./public/2025-08-28.json")
    JSON.parse(file)["result"]
=end
  end

  def self.find_or_create_movie(movie_string_id, film_at_uri, movie_title)
    movie = find_or_initialize_by(movie_id: movie_string_id)
    movie.title = movie_title if movie.new_record?
    movie.movie_id = movie_string_id if movie.new_record?

    if movie.tmdb_id.blank?
      movie.original_title = get_movie_query_title(film_at_uri, movie.title)
      update_movie_with_additional_info(film_at_uri, movie)
      tmdb_id = fetch_tmdb_id(movie.original_title, movie.title, movie.year)
      if tmdb_id.blank?
        tmdb_url = TmdbUtility.create_movie_search_url(movie.original_title, movie.title)
        tmdb_id = TmdbUtility.fallback_tmdb_id(tmdb_url, movie.original_title, movie.title, movie.year, film_at_uri)
      end
      TmdbUtility.fetch_movie_info_from_tmdb(movie, tmdb_id) if tmdb_id.present?
    end

    if movie.description.blank?
      TmdbUtility.fetch_movie_info_from_tmdb(movie, tmdb_id)
    end

    movie.save if movie.changed?
    movie
  end

  def self.update_movie_with_additional_info(uri, movie)
    additional_info = get_additional_info(uri, "article div p span.release")
    return if additional_info.blank?

    info_parts = additional_info.squish.split(",").map(&:strip)
    year = info_parts.pop
    countries = info_parts.join(", ").chomp(", ").gsub("\n", "")
    movie.update(countries: countries, year: year)
  end

  def self.get_additional_info(uri, html_parse_string)
    NokogiriService.call(uri, html_parse_string)
  end

  def self.fetch_tmdb_id(movie_original_title, movie_title, year)
    tmdb_url = create_tmdb_url(movie_original_title, movie_title)
    query_string = NormalizeAndCleanService.call(movie_original_title)
    TmdbUtility.fetch_tmdb_id(tmdb_url, year, query_string, movie_title)
  end

  def self.get_movie_query_title(uri, movie_title_json)
    movie_query_title = get_additional_info(uri, "article div p span.ov-title")
    movie_query_title.presence || movie_title_json
  end

  def self.try_fetch_tmdb_id(movie_query_title, movie_title_json, year)
    tmdb_url = create_tmdb_url(movie_query_title, movie_title_json)
    query_string = NormalizeAndCleanService.call(movie_query_title)
    TmdbUtility.fetch_tmdb_id(tmdb_url, year, query_string, movie_title_json)
  end

  def self.create_movie_id(title)
    "m-#{title.downcase.tr(' ', '-').gsub('---', '-').tr(',', '-')}"
  end

  def self.create_tmdb_url(movie_query_title, movie_title_json)
    query_string = NormalizeAndCleanService.call(movie_query_title)
    if query_string.count("?") > 2
      query_string = movie_title_json
    end
    tmdb_url = TmdbUtility.create_movie_search_url(query_string, movie_title_json)
    if tmdb_url.blank?
      query_string = NormalizeAndCleanService.call(movie_title_json)
      TmdbUtility.create_movie_search_url(query_string, movie_title_json)
    end
    tmdb_url
  end
end
