module TmdbUtility
  TMDB_BASE_URL = "https://api.themoviedb.org/3".freeze
  TMDB_SEARCH_MOVIE_ENDPOINT = "#{TMDB_BASE_URL}/search/movie".freeze
  TMDB_MOVIE_ENDPOINT = "#{TMDB_BASE_URL}/movie".freeze
  LANGUAGE_REGION = "language=de-DE&region=DE".freeze

  def self.create_movie_search_url(query, movie_title_json)
    query_param = MovieConcerns.build_query_string(query, movie_title_json)
    query_param = NormalizeAndCleanService.call(query_param)
    UriService.call("#{TMDB_SEARCH_MOVIE_ENDPOINT}?query=#{query_param}&#{LANGUAGE_REGION}")
  end

  def self.fetch_movie_info_from_tmdb(movie, tmdb_id)
    Tmdb::MovieEnricher.new(movie, tmdb_id).enrich
  end

  def self.fetch_tmdb_id(url, year, movie_query_title, movie_title_json)
    tmdb_results = TmdbResultService.call(url)
    return nil unless tmdb_results&.dig("results")

    tmdb_results["results"].each do |tmdb_result|
      tmdb_id = process_tmdb_result(tmdb_result, movie_query_title, movie_title_json, year)
      return tmdb_id if tmdb_id
    end

    nil
  end

  def self.fallback_tmdb_id(url, movie_query_title, movie_title_json, year, film_at_uri)
    matcher = Tmdb::MovieMatcher.new(
      original_title: movie_query_title,
      display_title: movie_title_json,
      year: year,
      film_at_uri: film_at_uri
    )
    matcher.find_tmdb_id
  end

  private

  def self.process_tmdb_result(tmdb_result, movie_query_title, movie_title_json, year)
    return nil unless title_matches?(tmdb_result, movie_query_title, movie_title_json, year)

    tmdb_id = tmdb_result["id"]
    return nil unless valid_release_year_for_tmdb_id?(tmdb_id, year)

    tmdb_id
  end

  def self.title_matches?(tmdb_result, movie_query_title, movie_title_json, year)
    TitleConcern.match_original_title?(tmdb_result, movie_query_title, movie_title_json) ||
      TitleConcern.match_altered_title?(tmdb_result, movie_query_title, movie_title_json, year)
  end

  def self.valid_release_year_for_tmdb_id?(tmdb_id, year)
    movie_details = Tmdb::Client.get_movie(tmdb_id)
    tmdb_release_year = fetch_release_year(movie_details)
    release_year_valid?(tmdb_release_year, year)
  end

  def self.fetch_release_year(tmdb_result)
    return nil unless tmdb_result["release_date"]
    release_date = tmdb_result["release_date"].to_date rescue nil
    release_date&.strftime("%Y")&.to_i
  end

  def self.release_year_valid?(tmdb_release_year, year)
    (year.to_i - 1..year.to_i + 1).include?(tmdb_release_year)
  end
end
