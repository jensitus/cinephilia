# frozen_string_literal: true

module TitleConcern
  def self.titles_match?(title_one, title_two)
    return false if title_one.nil? || title_two.nil?
    normalize_title(title_one).eql?(normalize_title(title_two))
  end

  def self.match_original_title?(tmdb_result, movie_query_title, movie_title_json)
    if movie_query_title.match?(/\A\?*\z/)
      titles_match?(tmdb_result["title"], movie_title_json)
    else
      titles_match?(tmdb_result["original_title"], movie_query_title) ||
        title_prefix_of?(movie_query_title, tmdb_result["original_title"])
    end
  end

  def self.match_altered_title?(tmdb_result, movie_query_title, movie_title_json, year)
    tmdb_title = normalize_title(tmdb_result["title"])
    normalized_json_title = normalize_title(movie_title_json)
    if movie_query_title.match?(/\A\?*\z/)
      titles_match?(tmdb_title, movie_query_title)
    else
      titles_match?(tmdb_title, normalized_json_title) ||
        title_prefix_of?(movie_title_json, tmdb_result["title"])
    end
  end

  def self.normalize_title(title)
    NormalizeAndCleanService.call(title.downcase)
  end

  # Returns true when +short_title+ is a word-boundary prefix of +long_title+
  # after normalization. E.g. "Winnetou 1" matches "Winnetou 1. Teil".
  def self.title_prefix_of?(short_title, long_title)
    return false if short_title.nil? || long_title.nil?

    normalized_short = normalize_title(short_title)
    normalized_long  = normalize_title(long_title)
    normalized_long.start_with?("#{normalized_short} ")
  end
end
