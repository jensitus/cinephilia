module TmdbUtility

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
    tmdb_results = Movie.get_tmdb_results(url)
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
    tmdb_results = Movie.get_tmdb_results(url)
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

end