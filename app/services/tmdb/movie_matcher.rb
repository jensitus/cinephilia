module Tmdb
  class MovieMatcher
    attr_reader :original_title, :display_title, :year, :film_at_uri

    def initialize(original_title:, display_title:, year:, film_at_uri: nil)
      @original_title = original_title
      @display_title = display_title
      @year = year
      @film_at_uri = film_at_uri
    end

    def find_tmdb_id
      url = build_search_url(original_title)
      tmdb_id = search_and_match(url)
      return tmdb_id if tmdb_id.present?

      fallback_search
    end

    private

    def build_search_url(query)
      query_param = MovieConcerns.build_query_string(query, display_title)
      query_param = NormalizeAndCleanService.call(query_param)
      UriService.call("#{Tmdb::Client::SEARCH_MOVIE_ENDPOINT}?query=#{query_param}&#{Tmdb::Client::LANGUAGE_REGION}")
    end

    def search_and_match(url)
      results = Tmdb::Client.get_movie(nil) # This won't work, need to fetch search results
      results = TmdbResultService.call(url)
      return nil unless results&.dig("results")

      query_string = NormalizeAndCleanService.call(original_title)

      results["results"].each do |result|
        tmdb_id = match_result(result, query_string)
        return tmdb_id if tmdb_id
      end

      nil
    end

    def match_result(result, query_string)
      return nil unless title_matches?(result, query_string)

      tmdb_id = result["id"]
      return nil unless valid_release_year?(tmdb_id)

      tmdb_id
    end

    def title_matches?(result, query_string)
      TitleConcern.match_original_title?(result, query_string, display_title) ||
        TitleConcern.match_altered_title?(result, query_string, display_title, year)
    end

    def valid_release_year?(tmdb_id)
      movie_details = Tmdb::Client.get_movie(tmdb_id)
      tmdb_release_year = extract_release_year(movie_details)
      year_within_range?(tmdb_release_year)
    end

    def extract_release_year(result)
      return nil unless result["release_date"]
      release_date = result["release_date"].to_date rescue nil
      release_date&.strftime("%Y")&.to_i
    end

    def year_within_range?(tmdb_release_year)
      (year.to_i - 1..year.to_i + 1).include?(tmdb_release_year)
    end

    def fallback_search
      url = build_search_url(original_title)
      results = TmdbResultService.call(url)

      tmdb_id = attempt_single_result_resolution(results)
      return tmdb_id if tmdb_id

      tmdb_id = check_with_display_title(results)
      return tmdb_id if tmdb_id

      tmdb_id = search_with_display_title_only
      return tmdb_id if tmdb_id

      cleaned_query_search
    end

    def attempt_single_result_resolution(results)
      return nil if results.nil?
      return nil unless results["results"]&.length == 1

      single_result = results["results"].first
      verify_single_result(single_result["id"])
    end

    def verify_single_result(tmdb_id)
      movie_details = Tmdb::Client.get_movie(tmdb_id)

      if film_at_uri && director_matches?(tmdb_id)
        return tmdb_id
      end

      tmdb_release_year = extract_release_year(movie_details)
      movie_title_normalized = TitleConcern.normalize_title(display_title)
      tmdb_original_title_normalized = TitleConcern.normalize_title(movie_details["original_title"])

      return tmdb_id if TitleConcern.titles_match?(movie_title_normalized, tmdb_original_title_normalized) && year == "0"
      return tmdb_id if TitleConcern.titles_match?(movie_title_normalized, tmdb_original_title_normalized) && year_within_range?(tmdb_release_year)

      tmdb_title_normalized = TitleConcern.normalize_title(movie_details["title"])
      return nil if TitleConcern.titles_match?(movie_title_normalized, tmdb_title_normalized) && !year_within_range?(tmdb_release_year)

      tmdb_id
    end

    def director_matches?(tmdb_id)
      credits = Tmdb::Client.get_credits(tmdb_id)
      director = ScrapeConcerns.get_director(film_at_uri, "article div.movieDetail-cast dl dt", true)

      credits["crew"]&.any? { |credit| credit["job"] == "Director" && credit["name"] == director }
    end

    def check_with_display_title(results)
      return nil unless results&.dig("results")

      results["results"].each do |result|
        tmdb_id = result["id"]
        movie_details = Tmdb::Client.get_movie(tmdb_id)

        next unless TitleConcern.titles_match?(movie_details["title"], display_title)

        tmdb_release_year = extract_release_year(movie_details)
        return tmdb_id if year_within_range?(tmdb_release_year)
      end

      nil
    end

    def search_with_display_title_only
      normalized = NormalizeAndCleanService.call(display_title)
      url = URI("#{Tmdb::Client::SEARCH_MOVIE_ENDPOINT}?query=#{normalized}&language=de-DE&region=DE")
      results = TmdbResultService.call(url)
      check_with_display_title(results)
    end

    def cleaned_query_search
      cleaned_query = original_title.gsub(/\s*\(.*?\)/, "")
      url = build_search_url(cleaned_query)
      results = TmdbResultService.call(url)

      return nil unless results&.dig("results")

      results["results"].each do |result|
        tmdb_id = match_result(result, cleaned_query)
        return tmdb_id if tmdb_id
      end

      nil
    end
  end
end
