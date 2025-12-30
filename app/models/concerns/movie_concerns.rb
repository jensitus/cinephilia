# frozen_string_literal: true

class MovieConcerns
  def self.build_query_string(query, fallback_title)
    query.match?(/\A\?*\z/) || query.match?(/\A.{4} .\z/) ? NormalizeAndCleanService.call(fallback_title) : query
  end

  def self.assign_movie_attributes(movie, tmdb_id, description, poster_path, credits, runtime)
    movie.update(tmdb_id: tmdb_id, description: description, poster_path: poster_path, runtime: runtime)
    # assign_credits_to_movie(movie, credits) if credits
    assign_cast_to_person(credits["cast"], movie)
    assign_crew_to_person(credits["crew"], movie)
  end

  def self.assign_credits_to_movie(movie, credits)
    cast = extract_actors_from_credits(credits["cast"])
    crew = extract_directors_from_credits(credits["crew"])
    movie.update(actors: cast, director: crew)
  end

  def self.assign_cast_to_person(cast_members, movie)
    if cast_members
      cast_members.each_with_index do |cast_member, index|
        begin
          person = Person.find_or_create_by!(tmdb_id: cast_member["id"].to_s) do |p|
            p.name = cast_member["name"]
          end

          # Update name if it changed
          person.update(name: cast_member["name"]) if person.name != cast_member["name"]

          Credit.find_or_create_by!(
            movie: movie,
            person: person,
            role: "cast",
            character: cast_member["character"],
            order: index,
            job: "Actor"
          )
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Movie #{movie.id} - Cast '#{cast_member['name']}': #{e.message}"
        rescue StandardError => e
          Rails.logger.error "Movie #{movie.id} - Cast '#{cast_member['name']}': #{e.class} - #{e.message}"
        end
      end
    end
  end

  def self.assign_crew_to_person(crew_members, movie)
    if crew_members
      directors = crew_members.select { |member| member["job"] == "Director" }
      directors.each do |director|
        begin
          person = Person.find_or_create_by!(tmdb_id: director["id"].to_s) do |p|
            p.name = director["name"]
          end

          # Update name if it changed
          person.update(name: director["name"]) if person.name != director["name"]

          Credit.find_or_create_by!(
            movie: movie,
            person: person,
            role: "crew",
            job: "Director"
          )

        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Movie #{movie.id} - Director '#{director['name']}': #{e.message}"
        rescue StandardError => e
          Rails.logger.error "Movie #{movie.id} - Director '#{director['name']}': #{e.class} - #{e.message}"
        end
      end
    end
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
