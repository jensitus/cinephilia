# frozen_string_literal: true

class MovieConcerns
  def self.build_query_string(query, fallback_title)
    query.match?(/\A\?*\z/) || query.match?(/\A.{4} .\z/) ? NormalizeAndCleanService.call(fallback_title) : query
  end

  def self.assign_movie_attributes(movie, tmdb_id, description, poster_path, credits, runtime)
    movie.update(tmdb_id: tmdb_id, description: description, poster_path: poster_path, runtime: runtime)
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
                .join(", ") unless cast_members.nil?
  end

  def self.extract_directors_from_credits(crew_members)
    crew_members.select { |member| member["known_for_department"] == "Directing" && member["job"] == "Director" || member["department"] == "Directing" && member["job"] == "Director" }
                .map { |director| director["name"] }
                .join(", ") unless crew_members.nil?
  end

end
