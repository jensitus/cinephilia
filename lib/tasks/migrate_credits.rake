# lib/tasks/migrate_credits.rake
namespace :movies do
  desc "Migrate actors and directors from movies table to credits with TMDB IDs"
  task migrate_credits: :environment do
    success_count = 0
    error_count = 0
    errors = []
    api_calls = 0

    Movie.find_each do |movie|
      # Skip if movie doesn't have a TMDB ID
      unless movie.tmdb_id.present?
        puts "Skipping movie #{movie.id} '#{movie.title}' - no TMDB ID"
        next
      end

      begin
        # Use your existing service
        url = URI("https://api.themoviedb.org/3/movie/#{movie.tmdb_id}/credits")
        credits_data = TmdbResultService.call(url)
        api_calls += 1

        unless credits_data
          error_count += 1
          errors << "Movie #{movie.id} '#{movie.title}' - API call returned nil"
          next
        end

        # Process cast
        if credits_data["cast"]
          credits_data["cast"].each_with_index do |cast_member, index|
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
              success_count += 1
            rescue ActiveRecord::RecordInvalid => e
              error_count += 1
              errors << "Movie #{movie.id} - Cast '#{cast_member['name']}': #{e.message}"
            rescue StandardError => e
              error_count += 1
              errors << "Movie #{movie.id} - Cast '#{cast_member['name']}': #{e.class} - #{e.message}"
            end
          end
        end

        # Process crew (directors and other crew members)
        if credits_data["crew"]
          directors = credits_data["crew"].select { |member| member["job"] == "Director" }
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
              success_count += 1
            rescue ActiveRecord::RecordInvalid => e
              error_count += 1
              errors << "Movie #{movie.id} - Director '#{director['name']}': #{e.message}"
            rescue StandardError => e
              error_count += 1
              errors << "Movie #{movie.id} - Director '#{director['name']}': #{e.class} - #{e.message}"
            end
          end
        end

        print "."

        # Be nice to TMDB API - rate limiting
        sleep(0.25) # 4 requests per second max

      rescue StandardError => e
        error_count += 1
        errors << "Movie #{movie.id} '#{movie.title}' - Unexpected error: #{e.class} - #{e.message}"
      end
    end

    puts "\n\nMigration complete!"
    puts "=" * 50
    puts "Total movies processed: #{Movie.count}"
    puts "Total people created: #{Person.count}"
    puts "Successful credits: #{success_count}"
    puts "Failed credits: #{error_count}"
    puts "API calls made: #{api_calls}"
    puts "=" * 50

    if errors.any?
      puts "\nErrors encountered:"
      errors.first(20).each { |error| puts "  - #{error}" }
      puts "  ... and #{errors.size - 20} more" if errors.size > 20

      File.open(Rails.root.join("log", "credit_migration_errors.log"), "w") do |f|
        errors.each { |error| f.puts(error) }
      end
      puts "\nFull error log written to: log/credit_migration_errors.log"
    end
  end

  desc "Rollback credit migration - removes all credits and people"
  task rollback_credits: :environment do
    puts "Rolling back credit migration..."

    credit_count = Credit.count
    person_count = Person.count

    if Rails.env.production?
      print "Are you sure you want to delete #{credit_count} credits and #{person_count} people? (yes/no): "
      confirmation = STDIN.gets.chomp
      unless confirmation.downcase == "yes"
        puts "Rollback cancelled."
        exit
      end
    end

    Credit.destroy_all
    Person.destroy_all

    puts "Rollback complete!"
    puts "Deleted #{credit_count} credits"
    puts "Deleted #{person_count} people"
  end
end
