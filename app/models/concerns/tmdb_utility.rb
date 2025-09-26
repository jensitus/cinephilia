module TmdbUtility

  TMDB_BASE_URL = "https://api.themoviedb.org/3".freeze
  TMDB_SEARCH_MOVIE_ENDPOINT = "#{TMDB_BASE_URL}/search/movie".freeze
  TMDB_MOVIE_ENDPOINT = "#{TMDB_BASE_URL}/movie".freeze
  LANGUAGE_REGION = "language=de-DE&region=DE"

  def self.create_movie_search_url(query, movie_title_json)
    query_param = build_query_string(query, movie_title_json)
    UriService.call("#{TMDB_SEARCH_MOVIE_ENDPOINT}?query=#{query_param}&#{LANGUAGE_REGION}")
  end

  def self.fetch_release_year(tmdb_result)
    return unless tmdb_result["release_date"]
    release_date = tmdb_result["release_date"].to_date rescue nil
    release_date&.strftime("%Y")&.to_i
  end

  def self.fetch_movie_info_from_tmdb(movie, tmdb_id)
    if tmdb_id != nil
      description = get_additional_info_from_tmdb(tmdb_id.to_s, "overview")
      poster_path = get_additional_info_from_tmdb(tmdb_id.to_s, "poster_path")
      credits = fetch_credits(tmdb_id.to_s)
    end
    assign_movie_attributes(movie, tmdb_id, description, poster_path, credits)
  end

  def self.fetch_tmdb_id(url, year, movie_query_title, movie_title_json)
    tmdb_results = get_tmdb_results(url)
    return unless tmdb_results

    tmdb_results["results"].each do |tmdb_result|
      presumable_tmdb_id = process_tmdb_result(tmdb_result, movie_query_title, movie_title_json, year)
      return presumable_tmdb_id if presumable_tmdb_id
    end

    tmdb_id = resolve_tmdb_id_fallbacks(tmdb_results, movie_title_json, year)
    return tmdb_id unless tmdb_id.nil?
    cleaned_up_url(movie_query_title, movie_title_json, year)
  end

  private

  def self.cleaned_up_url(movie_query_title, movie_title_json, year)
    cleaned_up_query_string = movie_query_title.gsub(/\s*\(.*?\)/, "")
    uri = create_movie_search_url(cleaned_up_query_string, movie_title_json)
    tmdb_results = get_tmdb_results(uri)
    tmdb_results["results"].each do |tmdb_result|
      tmdb_id = process_tmdb_result(tmdb_result, cleaned_up_query_string, movie_title_json, year)
      return tmdb_id if tmdb_id
    end
    nil
  end

  def self.process_tmdb_result(tmdb_result, movie_query_title, movie_title_json, year)

    if match_original_title?(tmdb_result, movie_query_title, movie_title_json) ||
      match_altered_title?(tmdb_result, movie_query_title, movie_title_json, year)

      presumable_tmdb_id = tmdb_result["id"]
      tmdb_single_result = fetch_tmdb_single_result_by_tmdb_id(presumable_tmdb_id)
      tmdb_release_year = fetch_release_year(tmdb_single_result)
      return presumable_tmdb_id if release_year_valid?(tmdb_release_year, year)
    end

    nil
  end

  def self.resolve_tmdb_id_fallbacks(tmdb_results, movie_title_json, year)
    attempt_single_result_resolution(tmdb_results, movie_title_json, year) ||
      check_tmdb_id_if_original_title_not_possible(tmdb_results, movie_title_json, year) ||
      check_tmdb_with_json_movie_title(movie_title_json, year)
  end

  def self.fetch_tmdb_single_result_by_tmdb_id(tmdb_id)
    uri = UriService.call("#{TMDB_MOVIE_ENDPOINT}/#{tmdb_id}?#{LANGUAGE_REGION}")
    TmdbResultService.call(uri)
  end

  def self.check_tmdb_id_if_original_title_not_possible(tmdb_results, movie_title_json, year)
    tmdb_results["results"].each do |tmdb_result_loop|
      tmdb_id = tmdb_result_loop["id"]
      tmdb_single_result = fetch_tmdb_movie_details(tmdb_id)

      next unless titles_match?(tmdb_single_result["title"], movie_title_json)

      if release_year_valid?(tmdb_single_result, year)
        return tmdb_id
      else
        return nil
      end
    end
    nil
  end

  def self.check_tmdb_with_json_movie_title(movie_title_json, year)
    normalized = NormalizeAndCleanService.call(movie_title_json)
    url = URI("#{TMDB_SEARCH_MOVIE_ENDPOINT}?query=#{normalized}&language=de-DE&region=DE")
    tmdb_results = get_tmdb_results(url)
    check_tmdb_id_if_original_title_not_possible(tmdb_results, movie_title_json, year)
  end

  def self.the_other_way_around(tmdb_id, movie_title, year)
    tmdb_single_result = fetch_tmdb_single_result_by_tmdb_id(tmdb_id)
    tmdb_release_year = fetch_release_year(tmdb_single_result)

    movie_title_normalized = normalize_title(movie_title)
    tmdb_title_normalized = normalize_title(tmdb_single_result["title"])
    tmdb_original_title_normalized = normalize_title(tmdb_single_result["original_title"])

    return tmdb_id if titles_match?(movie_title_normalized, tmdb_original_title_normalized) && year == "0"

    return tmdb_id if titles_match?(movie_title_normalized, tmdb_original_title_normalized) && release_year_valid?(tmdb_release_year, year)
    return nil if titles_match?(movie_title_normalized, tmdb_title_normalized) && !release_year_valid?(tmdb_release_year, year)

    # if movie_title_normalized != tmdb_title_normalized
    #   # Check if original title matches and the years are the same
    #   return tmdb_id if tmdb_original_title_normalized == movie_title_normalized && year == tmdb_release_year
    #   return nil
    # end

    # Check if the release year matches for exact title match
    # return nil if tmdb_title_normalized == movie_title_normalized && tmdb_release_year != year

    tmdb_id
  end

  def self.fetch_credits(tmdb_id)
    url = UriService.call("#{TMDB_MOVIE_ENDPOINT}/#{tmdb_id}/credits")
    get_tmdb_results(url)
  end

  def self.get_additional_info_from_tmdb(tmdb_id, kind_of_info)
    uri = UriService.call("#{TMDB_MOVIE_ENDPOINT}/#{tmdb_id}?#{LANGUAGE_REGION}")
    return nil if uri.nil?
    tmdb_results = get_tmdb_results(uri)
    additional_info = tmdb_results["#{kind_of_info}"]
    additional_info
  end

  def self.get_tmdb_results(url)
    TmdbResultService.call(url)
  end

  def self.release_year_valid?(tmdb_release_year, year)
    # release_year = fetch_release_year(tmdb_result)&.to_i
    (year.to_i - 1..year.to_i + 1).include?(tmdb_release_year)
  end

  def self.fetch_tmdb_movie_details(tmdb_id)
    url = "#{TMDB_MOVIE_ENDPOINT}/#{tmdb_id}?language=de-DE&region=DE"
    uri = UriService.call(url)
    get_tmdb_results(uri)
  end

  def self.titles_match?(title_one, title_two)
    return false if title_one.nil? || title_two.nil?
    normalize_title(title_one).eql?(normalize_title(title_two))
  end

  def self.match_original_title?(tmdb_result, movie_query_title, movie_title_json)
    if movie_query_title.match?(/\A\?*\z/)
      titles_match?(tmdb_result["title"], movie_title_json)
    else
      titles_match?(tmdb_result["original_title"], movie_query_title)
    end
  end

  def self.match_altered_title?(tmdb_result, movie_query_title, movie_title_json, year)
    tmdb_title = normalize_title(tmdb_result["title"])
    tmdb_release_year = fetch_release_year(tmdb_result)
    normalized_json_title = normalize_title(movie_title_json)

    (tmdb_title == movie_query_title && tmdb_release_year.to_i == year.to_i) ||
      (tmdb_title == normalized_json_title && tmdb_release_year.to_i == year.to_i)
  end

  def self.normalize_title(title)
    NormalizeAndCleanService.call(title.downcase)
  end

  def self.attempt_single_result_resolution(tmdb_results, movie_title_json, year)
    return nil if tmdb_results.nil?
    return nil unless tmdb_results["results"].length == 1

    single_result = tmdb_results["results"].first
    the_other_way_around(single_result["id"], movie_title_json, year)
  end

  def self.build_query_string(query, fallback_title)
    query.match?(/\A\?*\z/) || query.match?(/\A.{4} .\z/) ? NormalizeAndCleanService.call(fallback_title) : query
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
    crew_members.select { |member| member["known_for_department"] == "Directing" && member["job"] == "Director" || member["department"] == "Directing" && member["job"] == "Director" }
                .map { |director| director["name"] }
                .join(", ")
  end

end
