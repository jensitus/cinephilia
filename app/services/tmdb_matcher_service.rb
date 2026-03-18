# app/services/tmdb_matcher_service.rb
class TmdbMatcherService
  LANGUAGE = "de-DE"
  REGION = "DE"
  YEAR_TOLERANCE = 1 # Allow +/- 1 year difference

  def initialize(movie)
    @movie = movie
  end

  def find_best_match
    return nil if @movie.title.blank?

    # Search TMDB
    search_results = search_tmdb(@movie.title)
    best_match = find_matching_result(search_results) if search_results.any?
    return best_match if best_match
    # Second try: Remove year from title if present (e.g., "Title (1974)" -> "Title")
    cleaned_title = remove_year_from_title(@movie.title)
    if cleaned_title != @movie.title
      Rails.logger.info "Retrying search without year: '#{cleaned_title}'"
      search_results = search_tmdb(cleaned_title)
      best_match = find_matching_result(search_results) if search_results.any?
      return best_match if best_match
    end

    nil
  end

  private

  def remove_year_from_title(title)
    # Remove patterns like "(1974)" or " 1974" at the end
    title.gsub(/\s*\(\d{4}\)\s*$/, "").gsub(/\s+\d{4}\s*$/, "").strip
  end

  def search_tmdb(query)
    url = URI("https://api.themoviedb.org/3/search/movie")
    url.query = URI.encode_www_form({
                                      query: query,
                                      language: LANGUAGE,
                                      region: REGION
                                    })

    tmdb_data = TmdbResultService.new(url).call
    tmdb_data&.dig("results") || []
  rescue StandardError => e
    Rails.logger.error "TMDB search failed for '#{query}': #{e.message}"
    []
  end

  def find_matching_result(results)
    # Strategy 1: Exact title match with year
    if @movie.year.present?
      exact_match = results.find do |result|
        title_matches?(result) && year_matches?(result)
      end
      return exact_match if exact_match
    end

    # Strategy 2: Exact title match (any year)
    exact_title = results.find { |result| title_matches?(result) }
    return exact_title if exact_title

    # Strategy 3: Close title match with year
    if @movie.year.present?
      close_match = results.find do |result|
        similar_title?(result) && year_matches?(result)
      end
      return close_match if close_match
    end

    # Strategy 4: Director match with year (NEW - most reliable)
    if @movie.director.present? && @movie.year.present?
      director_year_match = results.find do |result|
        year_matches?(result) && director_matches?(result)
      end
      return director_year_match if director_year_match
    end

    # Strategy 5: Director match (if we have director info)
    if @movie.director.present?
      director_match = results.find do |result|
        director_matches?(result)
      end
      return director_match if director_match
    end

    # Strategy 6: First result if original title is very similar
    first_result = results.first
    if first_result && similar_title?(first_result)
      return first_result
    end

    # No good match found
    nil
  end

  def title_matches?(result)
    # Clean both titles for comparison
    movie_title = normalize_title(@movie.title)
    movie_title_cleaned = normalize_title(remove_year_from_title(@movie.title))

    result_title = normalize_title(result["title"])
    result_original = normalize_title(result["original_title"])

    movie_title == result_title ||
      movie_title == result_original ||
      movie_title_cleaned == result_title ||
      movie_title_cleaned == result_original
  end

  def similar_title?(result)
    # Check if titles are very similar (allowing for minor differences)
    movie_title = normalize_title(remove_year_from_title(@movie.title))
    result_title = normalize_title(result["title"])
    original_title = normalize_title(result["original_title"])

    # Levenshtein distance or simple containment check
    result_title.include?(movie_title) ||
      movie_title.include?(result_title) ||
      original_title.include?(movie_title) ||
      movie_title.include?(original_title)
  end

  def year_matches?(result)
    return false unless @movie.year.present?

    result_year = extract_year(result["release_date"])
    return false unless result_year

    movie_year = @movie.year.to_i

    tolerance = if movie_year < 1980
                  2
    elsif movie_year < 2000
                  1
    else
                  YEAR_TOLERANCE
    end

    matches = (movie_year - result_year).abs <= tolerance

    # Debug logging
    Rails.logger.debug "Year match check: #{@movie.title} (#{movie_year}) vs #{result['title']} (#{result_year}): #{matches ? 'MATCH' : 'NO MATCH'} (tolerance: ±#{tolerance})"

    matches
  end

  def director_matches?(result)
    return false unless @movie.director.present?

    # Fetch movie credits to get director info
    credits = fetch_movie_credits(result["id"])
    return false unless credits

    crew = credits["crew"] || []
    directors = crew.select { |person| person["job"] == "Director" && person["department"] == "Directing" }

    # Check if any director name matches
    matches = directors.any? do |director|
      director_name_matches?(director["name"])
    end

    # Debug logging
    if directors.any?
      director_names = directors.map { |d| d["name"] }.join(", ")
      Rails.logger.debug "Director match: #{@movie.director} vs [#{director_names}]: #{matches}"
    end

    matches
  end

  def director_name_matches?(tmdb_director_name)
    movie_director = normalize_name(@movie.director)
    tmdb_director = normalize_name(tmdb_director_name)

    # Exact match
    return true if movie_director == tmdb_director

    # One contains the other (handles "John Smith" vs "John W. Smith")
    return true if movie_director.include?(tmdb_director) || tmdb_director.include?(movie_director)

    # Last name match (split by space and compare last parts)
    movie_last = movie_director.split.last
    tmdb_last = tmdb_director.split.last
    return true if movie_last == tmdb_last && movie_last.length > 3

    false
  end

  def fetch_movie_credits(tmdb_id)
    url = URI("https://api.themoviedb.org/3/movie/#{tmdb_id}/credits")
    url.query = URI.encode_www_form({
                                      language: LANGUAGE
                                    })

    TmdbResultService.new(url).call
  rescue StandardError => e
    Rails.logger.error "Failed to fetch TMDB credits for ID #{tmdb_id}: #{e.message}"
    nil
  end

  def fetch_movie_details(tmdb_id)
    url = URI("https://api.themoviedb.org/3/movie/#{tmdb_id}")
    url.query = URI.encode_www_form({
                                      append_to_response: "credits",
                                      language: LANGUAGE,
                                      region: REGION
                                    })

    TmdbResultService.new(url).call
  rescue StandardError => e
    Rails.logger.error "Failed to fetch TMDB details for ID #{tmdb_id}: #{e.message}"
    nil
  end

  def normalize_title(title)
    return "" if title.blank?

    title.downcase
         .gsub(/[[:punct:]]/, "") # Remove punctuation
         .gsub(/\s+/, " ")        # Normalize whitespace
         .strip
  end

  def normalize_name(name)
    return "" if name.blank?

    name.downcase
        .gsub(/[[:punct:]]/, "")
        .strip
  end

  def extract_year(release_date)
    return nil if release_date.blank?

    Date.parse(release_date).year
  rescue ArgumentError
    nil
  end
end
