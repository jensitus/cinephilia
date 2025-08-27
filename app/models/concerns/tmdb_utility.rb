module TmdbUtility

  TOKEN = Rails.configuration.tmdb_token

  def self.create_url(query)
    begin
      url = URI("https://api.themoviedb.org/3/search/movie?query=" + query + "&language=de-DE&region=DE")
      return url
    rescue URI::InvalidURIError
      Rails.logger.error 'invalid uri'
      return nil
    end
  end

  def self.fetch_tmdb_id(url, year, movie_query_title, movie_title_json)
    tmdb_results = get_tmdb_results(url)
    presumable_tmdb_id = nil

    if tmdb_results != nil
      tmdb_results["results"].each do |tmdb_result|
        tmdb_original_title = change_umlaut_to_vowel(tmdb_result["original_title"].downcase)
        tmdb_title = change_umlaut_to_vowel(tmdb_result["title"].downcase)
        if movie_query_title.eql?(tmdb_original_title) or tmdb_title.eql?(movie_query_title)
          tmdb_release_year = fetch_release_year(tmdb_result)
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
          tmdb_release_year = fetch_release_year(tmdb_result)
          if year.to_i == tmdb_release_year.to_i
            presumable_tmdb_id = tmdb_result['id']
          end
        else
          puts false
          # presumable_tmdb_id = the_other_way_around(tmdb_result["id"], movie_title_json, year)
          # return presumable_tmdb_id unless presumable_tmdb_id.nil?
        end
      end
    end
    if presumable_tmdb_id.nil? and !tmdb_results.nil? and tmdb_results["results"].length == 1
      presumable_tmdb_id = the_other_way_around(tmdb_results["results"].first["id"], movie_title_json, year)
    end
    return presumable_tmdb_id
  end

  def self.fetch_release_year(tmdb_result)
    tmdb_release_date = tmdb_result["release_date"]
    if tmdb_release_date != nil
      if tmdb_release_date.to_date != nil
        tmdb_release_year = tmdb_release_date.to_date.strftime("%Y")
      end
    end
    return tmdb_release_year
  end

  def self.change_umlaut_to_vowel(querystring)
    I18n.transliterate(querystring).downcase.gsub("ä", "a").gsub("ö", "o").gsub("ü", "u").gsub("ß", "ss").gsub(" -", "").gsub(":", "").gsub("'", "")
  end

  def self.the_other_way_around(tmdb_id, movie_title, year)
    url = URI("https://api.themoviedb.org/3/movie/" + tmdb_id.to_s + "?language=de-DE&region=DE")
    tmdb_results = get_tmdb_results(url)
    puts tmdb_results.inspect
    tmdb_release_year = fetch_release_year(tmdb_results)
    if !change_umlaut_to_vowel(movie_title).eql?(change_umlaut_to_vowel(tmdb_results["title"]))
      if change_umlaut_to_vowel(tmdb_results["original_title"]).eql?(change_umlaut_to_vowel(movie_title)) and year == tmdb_release_year
        return tmdb_id
      else
        tmdb_id = nil
      end
    elsif change_umlaut_to_vowel(movie_title).eql?(change_umlaut_to_vowel(tmdb_results["title"]))
      if tmdb_release_year != year
        tmdb_id = nil
      end
    end
    return tmdb_id
  end

  def self.fetch_movie_info_from_tmdb(movie, tmdb_id)
    if tmdb_id != nil
      description = get_additional_info_from_tmdb(tmdb_id.to_s, "overview")
      poster_path = get_additional_info_from_tmdb(tmdb_id.to_s, "poster_path")
      credits = fetch_credits(tmdb_id.to_s)
      set_attributes_to_movie(movie, credits["cast"], "cast")
      set_attributes_to_movie(movie, credits["crew"], "crew")
    end
    movie.update(tmdb_id: tmdb_id) unless tmdb_id == nil
    movie.update(description: description) unless description == nil
    movie.update(poster_path: poster_path) unless poster_path == nil
  end

  def self.set_attributes_to_movie(movie, attribute_data, type)
    case type
    when "cast"
      actors = ""
      attribute_data.each do |c|
        if c["known_for_department"] == "Acting"
          actors << c["name"] + ", "
        end
      end
      movie.update(actors: actors.chomp(", "))
    when "crew"
      director = ""
      attribute_data.each do |c|
        if c["known_for_department"] == "Directing" and c["job"] == "Director"
          director << c["name"] + ", "
        end
      end
      movie.update(director: director.chomp(", "))
    else
      # type code here
    end
  end

  def self.fetch_credits(tmdb_id)
    url = URI("https://api.themoviedb.org/3/movie/#{tmdb_id}/credits")
    puts url
    tmdb_results = get_tmdb_results(url)
    tmdb_results
  end

  def self.get_additional_info_from_tmdb(tmdb_id, kind_of_info)
    url = URI("https://api.themoviedb.org/3/movie/" + tmdb_id + "?language=de-DE&region=DE")
    tmdb_results = get_tmdb_results(url)
    additional_info = tmdb_results["#{kind_of_info}"]
    additional_info
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

end