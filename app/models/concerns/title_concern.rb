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
      titles_match?(tmdb_result["original_title"], movie_query_title)
    end
  end

  def self.match_altered_title?(tmdb_result, movie_query_title, movie_title_json, year)
    tmdb_title = normalize_title(tmdb_result["title"])
    normalized_json_title = normalize_title(movie_title_json)
    if movie_query_title.match?(/\A\?*\z/)
      titles_match?(tmdb_title, movie_query_title)
    else
      titles_match?(tmdb_title, normalized_json_title)
    end
  end

  def self.normalize_title(title)
    NormalizeAndCleanService.call(title.downcase)
  end

end
