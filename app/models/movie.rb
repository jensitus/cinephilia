class Movie < ApplicationRecord
  require 'nokogiri'
  require 'open-uri'
  require "net/http"
  require "json"

  has_and_belongs_to_many :genres
  has_many :schedules
  has_many :cinemas, through: :schedules

  VIENNA = "Wien"
  SEVEN_DAYS = 3
  TOKEN = Rails.configuration.tmdb_token

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
    Schedule.all.each do |schedule|
      today = Date.today
      if schedule.time.to_date < today
        schedule.delete
      end
    end
  end

  def self.delete_movies_without_schedules
    Movie.all.each do |movie|
      if movie.schedules.empty?
        movie.delete
      end
    end
  end

  def self.fetch_movie(url)

=begin
    file = File.read("./public/perfect.json")
    result = JSON.parse(file)
=end

    response = Net::HTTP.get(url)
    result = JSON.parse(response)

    result = result["result"]
    result.each do |movie_json|
      film_at_uri = movie_json["parent"]["uri"].gsub("/filmat", "")
      movie_string_id = "m-" + movie_json["parent"]["title"].downcase.gsub(" ", "-").gsub("---", "-")
      movie_created = find_or_create_movie(movie_string_id, film_at_uri, movie_json["parent"]["title"])
      if movie_json["parent"]["genres"] != nil
        create_genres(movie_json["parent"]["genres"], movie_created)
      end
      get_cinema_and_schedule(movie_json, movie_created.id)
    end
  end

  private

  def self.find_or_create_movie(movie_string_id, film_at_uri, movie_title)
    movie_exists = Movie.where(movie_id: movie_string_id).exists?
    if movie_exists == true
      movie_created = Movie.find_by(movie_id: movie_string_id)
      tmdb_id = movie_created.tmdb_id
      if movie_created.tmdb_id.nil?
        get_additional_info_for_movie(movie_created, film_at_uri)
      end
    else
      movie_created = Movie.create!(movie_id: movie_string_id, title: movie_title)
      get_additional_info_for_movie(movie_created, film_at_uri)
    end
    movie_created
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

  def self.get_additional_info(uri)
    docs = nil
    begin
      docs = Nokogiri::HTML(URI.open("https://film.at" + uri))
    rescue OpenURI::HTTPError => error
      Rails.logger.error error.message
    end
    docs
  end

  def self.get_additional_info_for_movie(movie, uri)
    docs = get_additional_info(uri)
    if docs != nil

      movie_query_title = get_movie_query_title(docs, movie.title)

      docs.css('article div p span.release').each do |link|
        additional_info = link.content.gsub(" ", "").split(",")
        year = additional_info[-1].gsub("\n", "")
        additional_info.delete_at(-1)
        countries = additional_info.join(", ")
        country_string = countries.chomp(', ').gsub("\n", "")
        movie.update(countries: country_string, year: year)
        tmdb_id = get_movie_query_tmdb_url_and_further_get_tmdb_id(movie_query_title, movie.title, year)
        if tmdb_id != nil
          description = get_additional_info_from_tmdb(tmdb_id.to_s, "overview")
          poster_path = get_additional_info_from_tmdb(tmdb_id.to_s, "poster_path")
          credits = get_cast(tmdb_id.to_s)
          set_cast_to_movie(movie, credits["cast"])
          set_crew_to_movie(movie, credits["crew"])
        end
        movie.update(tmdb_id: tmdb_id) unless tmdb_id == nil
        movie.update(description: description) unless description == nil
        movie.update(poster_path: poster_path) unless poster_path == nil
      end
    end
  end

  def self.create_url_tmdb_id(movie_query_string)
    begin
      url = URI("https://api.themoviedb.org/3/search/movie?query=" + movie_query_string + "&language=de-DE&region=DE")
      return url
    rescue URI::InvalidURIError
      Rails.logger.error 'invalid uri'
      return nil
    end
  end

  def self.set_cast_to_movie(movie, cast)
    actors = ""
    cast.each do |c|
      if c["known_for_department"] == "Acting"
        actors << c["name"] + ", "
      end
    end
    movie.update(actors: actors.chomp(", "))
  end

  def self.set_crew_to_movie(movie, crew)
    director = ""
    crew.each do |c|
      if c["known_for_department"] == "Directing" and c["job"] == "Director"
        director << c["name"] + ", "
      end
    end
    movie.update(director: director.chomp(", "))
  end

  def self.get_movie_query_title(docs, movie_title_json)
    movie_query_title = nil
    docs.css('article div p span.ov-title').each do |link|
      movie_query_title = link.content
    end
    if movie_query_title.nil? or movie_query_title == ""
      movie_query_title = movie_title_json
    end
    return movie_query_title
  end

  def self.get_movie_query_tmdb_url_and_further_get_tmdb_id(movie_query_title, movie_title_json, year)
    query_string = change_umlaut_to_vowel(movie_query_title)
    if create_url_tmdb_id(query_string).nil?
      query_string = change_umlaut_to_vowel(movie_title_json)
    end
    tmdb_query_url = create_url_tmdb_id(query_string)
    return get_tmdb_id(tmdb_query_url, year, query_string, movie_title_json)
  end

  def self.get_additional_info_from_tmdb(tmdb_id, kind_of_info)
    url = URI("https://api.themoviedb.org/3/movie/" + tmdb_id + "?language=de-DE&region=DE")
    tmdb_results = get_tmdb_results(url)
    additional_info = tmdb_results["#{kind_of_info}"]
    additional_info
  end

  def self.get_tmdb_id(url, year, movie_query_title, movie_title_json)
    tmdb_results = get_tmdb_results(url)
    presumable_tmdb_id = nil

    if tmdb_results != nil
      tmdb_results["results"].each do |tmdb_result|
        tmdb_original_title = change_umlaut_to_vowel(tmdb_result["original_title"].downcase)
        tmdb_title = change_umlaut_to_vowel(tmdb_result["title"].downcase)
        if movie_query_title.eql?(tmdb_original_title) or tmdb_title.eql?(movie_query_title)
          tmdb_release_year = get_tmdb_release_year(tmdb_result)
        end
        if tmdb_original_title == movie_query_title && tmdb_release_year == year
          presumable_tmdb_id = tmdb_result['id']
        elsif tmdb_original_title == movie_query_title && year.to_i == tmdb_release_year.to_i + 1
          presumable_tmdb_id = tmdb_result['id']
        elsif tmdb_original_title == movie_query_title && year.to_i == tmdb_release_year.to_i - 1
          presumable_tmdb_id = tmdb_result['id']
        elsif tmdb_original_title != movie_query_title and tmdb_title.eql?(movie_query_title) and year.to_i == tmdb_release_year.to_i
          presumable_tmdb_id = tmdb_result['id']
        elsif tmdb_original_title != movie_query_title and tmdb_title.eql?(change_umlaut_to_vowel(movie_title_json))
          tmdb_release_year = get_tmdb_release_year(tmdb_result)
          if year.to_i == tmdb_release_year.to_i
            presumable_tmdb_id = tmdb_result['id']
          end
        else
          puts false
        end
      end
    end
    if presumable_tmdb_id.nil? and !tmdb_results.nil? and tmdb_results["results"].length == 1
      presumable_tmdb_id = the_other_way_around(tmdb_results["results"].first["id"], movie_title_json, year)
    end
    return presumable_tmdb_id
  end

  def self.get_tmdb_release_year(tmdb_result)
    tmdb_release_date = tmdb_result["release_date"]
    if tmdb_release_date != nil
      if tmdb_release_date.to_date != nil
        tmdb_release_year = tmdb_release_date.to_date.strftime("%Y")
      end
    end
    return tmdb_release_year
  end

  def self.the_other_way_around(tmdb_id, movie_title, year)
    url = URI("https://api.themoviedb.org/3/movie/" + tmdb_id.to_s + "?language=de-DE&region=DE")
    tmdb_results = get_tmdb_results(url)
    puts tmdb_results.inspect
    tmdb_release_year = get_tmdb_release_year(tmdb_results)
    if !change_umlaut_to_vowel(movie_title).eql?(change_umlaut_to_vowel(tmdb_results["title"]))
      tmdb_id = nil
    elsif change_umlaut_to_vowel(movie_title).eql?(change_umlaut_to_vowel(tmdb_results["title"]))
      if !tmdb_release_year == year
        tmdb_id = nil
      end
    end
    return tmdb_id
  end

  def self.change_umlaut_to_vowel(querystring)
    q = I18n.transliterate(querystring).downcase.gsub("ä", "a").gsub("ö", "o").gsub("ü", "u").gsub("ß", "ss").gsub(" -", "").gsub(":", "").gsub("'", "")
    querystring = q
  end

  def self.get_cast(tmdb_id)
    url = URI("https://api.themoviedb.org/3/movie/#{tmdb_id}/credits")
    puts url
    tmdb_results = get_tmdb_results(url)
    tmdb_results
  end

  def self.get_tmdb_results(url)
    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true if url.scheme == 'https'
      request = Net::HTTP::Get.new(url)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{TOKEN}"
      response = http.request(request)
      tmdb_results = JSON.parse(response.body)
      return tmdb_results
    rescue NoMethodError
      Rails.logger.error 'no method error, because of invalid URI'
    end
    return nil
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
    docs = get_additional_info(uri)
    if docs != nil
      docs.css('main div section div div p a').each do |link|
        if link.content.start_with?("http")
          cinema_url = link.content
        end
      end
    end
    return cinema_url
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
