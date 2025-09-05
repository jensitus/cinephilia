module TmdbUtility

  # TOKEN = Rails.configuration.tmdb_token
  TMDB_BASE_URL = "https://api.themoviedb.org/3".freeze
  TMDB_SEARCH_MOVIE_ENDPOINT = "#{TMDB_BASE_URL}/search/movie".freeze
  TMDB_MOVIE_ENDPOINT = "#{TMDB_BASE_URL}/movie".freeze

  def self.create_movie_search_url(query, movie_title_json)
    query_param = build_query_string(query, movie_title_json)
    generate_uri("#{TMDB_SEARCH_MOVIE_ENDPOINT}?query=#{query_param}&language=de-DE&region=DE")
  end

  def self.fetch_release_year(tmdb_result)
    return unless tmdb_result["release_date"]
    release_date = tmdb_result["release_date"].to_date rescue nil
    release_date&.strftime("%Y")
  end

  def self.change_umlaut_to_vowel(querystring)
    querystring = querystring.downcase.gsub("ä", "a").gsub("ö", "o").gsub("ü", "u").gsub("ß", "ss").gsub(" -", "").gsub(":", "").gsub("'", "")
    I18n.transliterate(querystring)
  end

  # # # # # # # # #
  # suggestion from AI:

  def self.fetch_tmdb_id(url, year, movie_query_title, movie_title_json)
    tmdb_results = get_tmdb_results(url)

    presumable_tmdb_id = nil

    tmdb_results["results"].each do |tmdb_result|
      if match_original_title?(tmdb_result, movie_query_title, year, movie_title_json)
        presumable_tmdb_id = tmdb_result["id"]
      elsif match_altered_title?(tmdb_result, movie_query_title, movie_title_json, year)
        presumable_tmdb_id = tmdb_result["id"]
      end
    end unless tmdb_results.nil?

    presumable_tmdb_id ||= attempt_single_result_resolution(tmdb_results, movie_title_json, year)
    presumable_tmdb_id ||= check_tmdb_id_if_original_title_not_possible(tmdb_results, movie_title_json, year)
    presumable_tmdb_id ||= check_tmdb_with_json_movie_title(movie_title_json, year)
    presumable_tmdb_id
  end

  # end suggestion from AI
  # # # # # # #

  def self.check_tmdb_id_if_original_title_not_possible(tmdb_results, movie_title_json, year)
    tmdb_results["results"].each do |tmdb_result_loop|
      url = URI("https://api.themoviedb.org/3/movie/#{tmdb_result_loop['id']}?language=de-DE&region=DE")
      tmdb_single_result = get_tmdb_results(url)
      tmdb_single_result_title = normalized_title(tmdb_single_result["title"])
      normalized_movie_title_json = normalized_title(movie_title_json)
      if tmdb_single_result_title.eql?(normalized_movie_title_json)
        tmdb_single_result_release_year = fetch_release_year(tmdb_single_result)
        if tmdb_single_result_release_year == year
          return tmdb_result_loop["id"]
        end
      end
    end
    nil
  end

  def self.check_tmdb_with_json_movie_title(movie_title_json, year)
    normalized = normalize_and_clean(movie_title_json)
    url = URI("#{TMDB_SEARCH_MOVIE_ENDPOINT}?query=#{normalized}&language=de-DE&region=DE")
    tmdb_results = get_tmdb_results(url)
    check_tmdb_id_if_original_title_not_possible(tmdb_results, movie_title_json, year)
  end

  def self.the_other_way_around(tmdb_id, movie_title, year)
    url = URI("https://api.themoviedb.org/3/movie/#{tmdb_id}?language=de-DE&region=DE")
    tmdb_results = get_tmdb_results(url)
    tmdb_release_year = fetch_release_year(tmdb_results)

    movie_title_normalized = change_umlaut_to_vowel(movie_title)
    tmdb_title_normalized = change_umlaut_to_vowel(tmdb_results["title"])
    tmdb_original_title_normalized = change_umlaut_to_vowel(tmdb_results["original_title"])

    if movie_title_normalized != tmdb_title_normalized
      # Check if original title matches and the years are the same
      return tmdb_id if tmdb_original_title_normalized == movie_title_normalized && year == tmdb_release_year
      return nil
    end

    # Check if the release year matches for exact title match
    return nil if tmdb_title_normalized == movie_title_normalized && tmdb_release_year != year

    tmdb_id
  end

  def self.fetch_movie_info_from_tmdb(movie, tmdb_id)
    if tmdb_id != nil
      description = get_additional_info_from_tmdb(tmdb_id.to_s, "overview")
      poster_path = get_additional_info_from_tmdb(tmdb_id.to_s, "poster_path")
      credits = fetch_credits(tmdb_id.to_s)
    end
    assign_movie_attributes(movie, tmdb_id, description, poster_path, credits)
  end

  def self.fetch_credits(tmdb_id)
    url = generate_uri("#{TMDB_MOVIE_ENDPOINT}/#{tmdb_id}/credits")
    get_tmdb_results(url)
  end

  def self.get_additional_info_from_tmdb(tmdb_id, kind_of_info)
    url = URI("https://api.themoviedb.org/3/movie/" + tmdb_id + "?language=de-DE&region=DE")
    tmdb_results = get_tmdb_results(url)
    additional_info = tmdb_results["#{kind_of_info}"]
    additional_info
  end

  def self.get_tmdb_results(url)
    TmdbResultService.call(url)
  end

  private

  def self.match_original_title?(tmdb_result, movie_query_title, year, movie_title_json)
    tmdb_title_to_compare = nil
    json_title_to_compare = nil
    if movie_query_title.match?(/\A\?*\z/)
      tmdb_title_to_compare = normalized_title(tmdb_result["title"])
      json_title_to_compare = normalized_title movie_title_json
    else
      tmdb_title_to_compare = normalized_title(tmdb_result["original_title"])
      json_title_to_compare = normalized_title movie_query_title
    end
    tmdb_release_year = fetch_release_year(tmdb_result)

    (tmdb_title_to_compare.eql?(json_title_to_compare) && [year.to_i, year.to_i + 1, year.to_i - 1].include?(tmdb_release_year.to_i))
  end

  def self.match_altered_title?(tmdb_result, movie_query_title, movie_title_json, year)
    tmdb_title = normalized_title(tmdb_result["title"])
    tmdb_release_year = fetch_release_year(tmdb_result)
    normalized_json_title = normalized_title(movie_title_json)

    (tmdb_title == movie_query_title && tmdb_release_year.to_i == year.to_i) ||
      (tmdb_title == normalized_json_title && tmdb_release_year.to_i == year.to_i)
  end

  def self.normalized_title(title)
    change_umlaut_to_vowel(title.downcase)
  end

  def self.attempt_single_result_resolution(tmdb_results, movie_title_json, year)
    return nil unless tmdb_results["results"].length == 1

    single_result = tmdb_results["results"].first
    the_other_way_around(single_result["id"], movie_title_json, year)
  end

  def self.generate_uri(url)
    URI(url)
  rescue URI::InvalidURIError
    Rails.logger.error "Invalid URI: #{url.inspect}"
    nil
  end

  def self.normalize_and_clean(query_string)
    normalized_string = I18n.transliterate(query_string).downcase
    normalized_string.gsub("ä", "a")
                     .gsub("ö", "o")
                     .gsub("ü", "u")
                     .gsub("ß", "ss")
                     .gsub(" -", "")
                     .gsub(":", "")
                     .gsub("'", "")
  end

  def self.fetch_movie_credits(tmdb_id)
    url = generate_uri("#{TMDB_MOVIE_ENDPOINT}/#{tmdb_id}/credits")
    get_tmdb_results(url)
  end

  def self.build_query_string(query, fallback_title)
    query.match?(/\A\?*\z/) ? normalize_and_clean(fallback_title) : query
  end

  def self.assign_movie_attributes(movie, tmdb_id, description, poster_path, credits)
    movie.update(tmdb_id: tmdb_id, description: description, poster_path: poster_path)
    assign_credits_to_movie(movie, credits) if credits
  end

  def self.assign_credits_to_movie(movie, credits)
    cast = extract_actors_from_credits(credits["cast"])
    crew = extract_directors_from_credits(credits["crew"])
    movie.update(actors: cast, director: crew)
  end

  def self.extract_actors_from_credits(cast_members)
    cast_members.select { |member| member["known_for_department"] == "Acting" }
                .map { |actor| actor["name"] }
                .join(", ")
  end

  def self.extract_directors_from_credits(crew_members)
    crew_members.select { |member| member["known_for_department"] == "Directing" && member["job"] == "Director" }
                .map { |director| director["name"] }
                .join(", ")
  end

end
