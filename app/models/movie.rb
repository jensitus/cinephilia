class Movie < ApplicationRecord
  include TmdbUtility

  require "nokogiri"
  require "open-uri"
  require "net/http"
  require "json"

  has_and_belongs_to_many :genres
  has_many :schedules
  has_many :cinemas, through: :schedules

  VIENNA = "Wien"
  SEVEN_DAYS = 3

  def self.set_date
    date = Date.today
    condition_date = Date.today.plus_with_duration(SEVEN_DAYS)
    while date < condition_date do
      url = URI.parse("https://efs-varnish.film.at/api/v1/cfs/filmat/screenings/nested/movie/" + date.to_s)
      date = date.plus_with_duration(1)
      fetch_movie(url)
    end
    delete_old_schedules(date)
    delete_movies_without_schedules
  end

  def self.delete_old_schedules(date)
    schedules_to_delete = Schedule.where("time < ?", Date.today)
    schedules_to_delete.destroy_all unless schedules_to_delete.empty?
  end

  def self.delete_movies_without_schedules
    Movie.left_outer_joins(:schedules).where(schedules: { id: nil }).find_each(&:destroy)
  end

  def self.fetch_movie(url)

=begin
    file = File.read("./public/2025-08-28.json")
    parsed_result = JSON.parse(file)["result"]
=end

    response = Net::HTTP.get(url)
    parsed_result = JSON.parse(response)["result"]

    parsed_result.each do |movie_data|

      should_fetch_movie = movie_data["nestedResults"].any? do |nested_result|
        nested_result["parent"]["county"] == VIENNA
      end

      next unless should_fetch_movie

      film_at_uri = movie_data["parent"]["uri"].gsub("/filmat", "")
      movie_string_id = "m-#{movie_data["parent"]["title"].downcase.tr(" ", "-").gsub("---", "-").tr(",", "-")}"
      movie_created = find_or_create_movie(movie_string_id, film_at_uri, movie_data["parent"]["title"])
      if movie_data["parent"]["genres"].present?
        create_genres(movie_data["parent"]["genres"], movie_created)
      end
      get_cinema_and_schedule(movie_data, movie_created.id)

    end
  end

  private

  def self.find_or_create_movie(movie_string_id, film_at_uri, movie_title)
    movie = Movie.find_or_initialize_by(movie_id: movie_string_id)
    movie.title = movie_title if movie.new_record?
    movie.movie_id = movie_string_id if movie.new_record?
    if movie.tmdb_id.nil?
      tmdb_id = update_movie_and_return_tmdb_id(movie, film_at_uri)
      TmdbUtility.fetch_movie_info_from_tmdb(movie, tmdb_id) unless tmdb_id.nil?
    end
    movie.save if movie.changed?
    movie
  end

  def self.get_cinema_and_schedule(movie_json, movie_id)
    movie_json["nestedResults"].each do |nested_result|
      if nested_result["parent"]["county"] == VIENNA
        cinema = create_cinema(nested_result["parent"])
        nested_result["screenings"].each do |screening|
          schedule = create_schedule(screening, movie_id, cinema.id)
          if screening["tags"] != nil
            screening["tags"].each do |tag|
              t = create_tag(tag)
              if t != nil
                if schedule != nil && !schedule.tags.include?(t)
                  schedule.tags.push(t)
                end
              end
            end
          end
        end
      end
    end
  end

  def self.create_genres(genres, movie_created)
    genres.each do |genre_json|
      genre = create_genre(genre_json)
      unless movie_created.genres.include?(genre)
        movie_created.genres.push(genre)
      end
    end
  end

  def self.get_additional_info(uri, html_parse_string)
    NokogiriService.call(uri, html_parse_string)
  end

  def self.update_movie_and_return_tmdb_id(movie, uri)
    tmdb_id = nil

    movie_original_title = get_movie_query_title(uri, movie.title)
    movie.update(original_title: movie_original_title) unless movie_original_title.nil?

    additional_info = get_additional_info(uri, "article div p span.release")
    add_info_squish = additional_info.squish
    additional_info_array = add_info_squish.split(",")
    year = additional_info_array.last.strip
    additional_info_array.delete_at(-1)

    countries = additional_info_array.join(", ")
    country_string = countries.chomp(", ").gsub("\n", "")
    movie.update(countries: country_string, year: year)
    tmdb_id = get_movie_query_tmdb_url_and_further_get_tmdb_id(movie_original_title, movie.title, year)
    tmdb_id
  end

  def self.create_url_tmdb_id(movie_query_string)
    begin
      url = URI("https://api.themoviedb.org/3/search/movie?query=" + movie_query_string + "&language=de-DE&region=DE")
      url
    rescue URI::InvalidURIError
      Rails.logger.error "invalid uri"
      nil
    end
  end

  def self.get_movie_query_title(uri, movie_title_json)
    movie_query_title = get_additional_info(uri, "article div p span.ov-title")
    if movie_query_title.nil? or movie_query_title == ""
      movie_query_title = movie_title_json
    end
    movie_query_title
  end

  def self.get_movie_query_tmdb_url_and_further_get_tmdb_id(movie_query_title, movie_title_json, year)
    query_string = change_umlaut_to_vowel(movie_query_title)
    tmdb_url = TmdbUtility.create_movie_search_url(query_string, movie_title_json)
    if tmdb_url.nil?
      query_string = change_umlaut_to_vowel(movie_title_json)
      tmdb_url = TmdbUtility.create_movie_search_url(query_string, movie_title_json)
    end
    TmdbUtility.fetch_tmdb_id(tmdb_url, year, query_string, movie_title_json)
  end

  def self.get_additional_info_from_tmdb(tmdb_id, kind_of_info)
    url = URI("https://api.themoviedb.org/3/movie/" + tmdb_id + "?language=de-DE&region=DE")
    tmdb_results = get_tmdb_results(url)
    additional_info = tmdb_results["#{kind_of_info}"]
    additional_info
  end

  def self.change_umlaut_to_vowel(querystring)
    q = I18n.transliterate(querystring).downcase.gsub("ä", "a").gsub("ö", "o").gsub("ü", "u").gsub("ß", "ss").gsub(" -", "").gsub(":", "").gsub("'", "")
    querystring = q
  end

  def self.create_genre(genre_name)
    genre_id = "g-" + genre_name.downcase.gsub(" ", "-")
    if Genre.where(genre_id: genre_id).exists? == false
      genre = Genre.create!(genre_id: genre_id,
                            name: genre_name)
    else
      genre = Genre.find_by(genre_id: genre_id)
    end
    genre
  end

  def self.create_cinema(cinema)
    theater_id = "t-" + cinema["title"].gsub(" ", "-").downcase
    if Cinema.where(cinema_id: theater_id).exists? == false
      cinema_created = Cinema.create!(title: cinema["title"],
                                      county: cinema["county"],
                                      uri: get_cinema_url(cinema["uri"].gsub("/filmat", "")),
                                      cinema_id: theater_id)
    else
      cinema_created = Cinema.find_by(cinema_id: theater_id)
    end
    cinema_created
  end

  def self.get_cinema_url(uri)
    cinema_url = nil
    content = get_additional_info(uri, "main div section div div p a")
    if content.start_with?("http")
      cinema_url = content
    end
    cinema_url
  end

  def self.create_schedule(screening, movie_id, cinema_id)
    schedule_id = "s-" + movie_id.to_s + "-" + cinema_id.to_s + "-" + screening["time"]
    begin
      schedule_created = Schedule.create!(time: screening["time"],
                                          three_d: screening["3d"],
                                          ov: screening["ov"],
                                          info: screening["info"],
                                          movie_id: movie_id,
                                          cinema_id: cinema_id,
                                          schedule_id: schedule_id)
    rescue Exception => ex
      Rails.logger.error "ERROR " + ex.to_s
      schedule_created = Schedule.find_by(schedule_id: schedule_id)
    end
    schedule_created
  end

  def self.create_tag(tag)
    if Tag.where(name: tag).exists? == false
      tag_id = "t-" + tag.downcase.gsub(" ", "-").downcase
      t = Tag.create!(name: tag, tag_id: tag_id)
    else
      t = Tag.find_by(name: tag)
    end
    t
  end
end
