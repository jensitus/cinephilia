module TmdbUtility
  TMDB_BASE_URL = "https://api.themoviedb.org/3".freeze
  TMDB_SEARCH_MOVIE_ENDPOINT = "#{TMDB_BASE_URL}/search/movie".freeze
  TMDB_MOVIE_ENDPOINT = "#{TMDB_BASE_URL}/movie".freeze
  LANGUAGE_REGION = "language=de-DE&region=DE"

  def self.create_movie_search_url(query, movie_title_json)
    query_param = MovieConcerns.build_query_string(query, movie_title_json)
    query_param = NormalizeAndCleanService.call(query_param)
    UriService.call("#{TMDB_SEARCH_MOVIE_ENDPOINT}?query=#{query_param}&#{LANGUAGE_REGION}")
  end

  def self.fetch_release_year(tmdb_result)
    return unless tmdb_result["release_date"]
    release_date = tmdb_result["release_date"].to_date rescue nil
    release_date&.strftime("%Y")&.to_i
  end

  def self.fetch_movie_info_from_tmdb(movie, tmdb_id)
    id = tmdb_id || movie.tmdb_id
    return unless id

    id_string = id.to_s
    description = fetch_description(id_string)
    poster_path = get_additional_info_from_tmdb(id_string, "poster_path")
    runtime = get_additional_info_from_tmdb(id_string, "runtime")
    credits = fetch_credits(id_string)

    MovieConcerns.assign_movie_attributes(movie, tmdb_id, description, poster_path, credits, runtime)
  end

  def self.fetch_tmdb_id(url, year, movie_query_title, movie_title_json)
    tmdb_results = get_tmdb_results(url)
    return unless tmdb_results
    return unless tmdb_results["results"]

    tmdb_results["results"].each do |tmdb_result|
      presumable_tmdb_id = process_tmdb_result(tmdb_result, movie_query_title, movie_title_json, year)
      return presumable_tmdb_id if presumable_tmdb_id
    end

    nil
  end

  def self.fallback_tmdb_id(url, movie_query_title, movie_title_json, year, film_at_uri)
    tmdb_results = get_tmdb_results(url)
    tmdb_id = resolve_tmdb_id_fallbacks(tmdb_results, movie_title_json, year, film_at_uri)
    return tmdb_id unless tmdb_id.nil?
    cleaned_up_url(movie_query_title, movie_title_json, year)
  end

  private

  def self.fetch_description(tmdb_id)
    description = get_additional_info_from_tmdb(tmdb_id, "overview")
    return description if description.present?

    get_additional_info_from_tmdb(tmdb_id, "overview", true)
  end

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
    return unless title_matches?(tmdb_result, movie_query_title, movie_title_json, year)

    tmdb_id = tmdb_result["id"]
    return unless valid_release_year_for_tmdb_id?(tmdb_id, year)

    tmdb_id
  end

  def self.title_matches?(tmdb_result, movie_query_title, movie_title_json, year)
    TitleConcern.match_original_title?(tmdb_result, movie_query_title, movie_title_json) ||
      TitleConcern.match_altered_title?(tmdb_result, movie_query_title, movie_title_json, year)
  end

  def self.valid_release_year_for_tmdb_id?(tmdb_id, year)
    tmdb_single_result = fetch_tmdb_single_result_by_tmdb_id(tmdb_id)
    tmdb_release_year = fetch_release_year(tmdb_single_result)
    release_year_valid?(tmdb_release_year, year)
  end

  def self.resolve_tmdb_id_fallbacks(tmdb_results, movie_title_json, year, film_at_uri = nil)
    attempt_single_result_resolution(tmdb_results, movie_title_json, year, film_at_uri) ||
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

      next unless TitleConcern.titles_match?(tmdb_single_result["title"], movie_title_json)

      if release_year_valid?(fetch_release_year(tmdb_single_result), year)
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

  def self.the_other_way_around(tmdb_id, movie_title, year, film_at_uri = nil)
    tmdb_single_result = fetch_tmdb_single_result_by_tmdb_id(tmdb_id)
    if check_director(tmdb_id, film_at_uri)
      return tmdb_id
    end
    tmdb_release_year = fetch_release_year(tmdb_single_result)

    movie_title_normalized = TitleConcern.normalize_title(movie_title)
    tmdb_title_normalized = TitleConcern.normalize_title(tmdb_single_result["title"])
    tmdb_original_title_normalized = TitleConcern.normalize_title(tmdb_single_result["original_title"])

    return tmdb_id if TitleConcern.titles_match?(movie_title_normalized, tmdb_original_title_normalized) && year == "0"

    return tmdb_id if TitleConcern.titles_match?(movie_title_normalized, tmdb_original_title_normalized) && release_year_valid?(tmdb_release_year, year)
    return nil if TitleConcern.titles_match?(movie_title_normalized, tmdb_title_normalized) && !release_year_valid?(tmdb_release_year, year)

    tmdb_id
  end

  def self.check_director(tmdb_id, film_at_uri)
    credits = fetch_credits(tmdb_id)
    director = ScrapeConcerns.get_director(film_at_uri, "article div.movieDetail-cast dl dt", true)
    credits["crew"].each do |credit|
      if credit["job"] == "Director" && credit["name"] == director
        return true
      end
    end
    false
  end

  def self.fetch_credits(tmdb_id)
    url = UriService.call("#{TMDB_MOVIE_ENDPOINT}/#{tmdb_id}/credits")
    get_tmdb_results(url)
  end

  def self.get_additional_info_from_tmdb(tmdb_id, kind_of_info, without_language_region = false)
    if without_language_region
      uri = UriService.call("#{TMDB_MOVIE_ENDPOINT}/#{tmdb_id}")
    else
      uri = UriService.call("#{TMDB_MOVIE_ENDPOINT}/#{tmdb_id}?#{LANGUAGE_REGION}")
    end
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

  def self.attempt_single_result_resolution(tmdb_results, movie_title_json, year, film_at_uri = nil)
    return nil if tmdb_results.nil?
    return nil unless tmdb_results["results"].length == 1

    single_result = tmdb_results["results"].first
    the_other_way_around(single_result["id"], movie_title_json, year, film_at_uri)
  end
end
