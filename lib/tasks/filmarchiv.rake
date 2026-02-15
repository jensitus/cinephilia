# lib/tasks/filmarchiv.rake
namespace :filmarchiv do
  desc "Inspect Filmarchiv HTML structure"
  task inspect: :environment do
    require "httparty"
    require "nokogiri"

    response = HTTParty.get("https://www.filmarchiv.at/de/kino/programm", {
      headers: {
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
      }
    })

    doc = Nokogiri::HTML(response.body)

    puts "=== Page Title ==="
    puts doc.css("title").text

    puts "\n=== Body Content (first 500 chars) ==="
    puts doc.css("body").text.strip[0..500]

    puts "\n=== All divs with classes ==="
    doc.css("div[class]").first(20).each do |div|
      puts "Classes: #{div['class']}"
    end

    puts "\n=== Looking for date patterns ==="
    doc.css("*").each do |elem|
      text = elem.text.strip
      # Look for German date patterns like "13.01" or "Mo, 13.01"
      if text.match?(/\d{1,2}\.\d{1,2}\.?\d{0,4}/) && text.length < 50
        puts "Found date pattern: '#{text}' in <#{elem.name} class='#{elem['class']}'>"
      end
    end

    puts "\n=== All links ==="
    doc.css('a[href*="programm"], a[href*="film"]').first(10).each do |link|
      puts "Link: #{link['href']} - Text: #{link.text.strip[0..50]}"
    end

    puts "\n=== Raw HTML sample ==="
    puts response.body[0..2000]
  end

  desc "Fetch Filmarchiv program"
  task fetch: :environment do
    service = FilmarchivCrawlerService.new
    screenings = service.fetch_program

    puts "Found #{screenings.count} screenings"
    screenings.first(10).each do |screening|
      puts "#{screening[:datetime]} - #{screening[:title]}"
      puts "  Description: #{screening[:description]&.truncate(80)}" if screening[:description]
      puts "---"
    end
  end

  desc "Import Filmarchiv program to database"
  task import: :environment do
    service = FilmarchivCrawlerService.new
    screenings = service.fetch_program

    # Find or create Filmarchiv cinema
    cinema = Cinema.find_or_create_by!(cinema_id: "t-metro-kinokulturhaus") do |c|
      c.title = "Metro Kinokulturhaus"
      c.street = "Johannesgasse 4"
      c.city = "Wien"
      c.zip = "1010"
      c.county = "Wien"
      c.telephone = "+43 1 512 18 03 "
      c.email = "reservierung@filmarchiv.at"
      c.uri = "https://www.filmarchiv.at"
    end

    imported_count = 0
    skipped_count = 0
    errors = []

    screenings.each do |screening_data|
      begin
        # Find or create movie
        movie = Movie.find_by(title: screening_data[:title])

        unless movie
          # Fetch additional details if we have a film URL

          movie = Movie.create!(
            movie_id: "m-#{screening_data[:title].parameterize}-#{SecureRandom.hex(4)}",
            title: screening_data[:title],
            description: screening_data[:description],
            year: screening_data[:year],
            director: screening_data[:director],
            countries: screening_data[:country] || "AT",
            runtime: screening_data[:runtime]
          )
        end

        # Create schedule
        schedule = Schedule.find_or_create_by!(
          movie: movie,
          cinema: cinema,
          time: screening_data[:datetime]
        ) do |s|
          s.schedule_id = "filmarchiv-#{screening_data[:datetime].to_i}-#{movie.id}"
        end

        imported_count += 1
        puts "✓ #{screening_data[:datetime]} - #{movie.title}"

      rescue ActiveRecord::RecordInvalid => e
        skipped_count += 1
        error_msg = "#{screening_data[:title]}: #{e.message}"
        errors << error_msg
        puts "✗ #{error_msg}"
      rescue StandardError => e
        skipped_count += 1
        error_msg = "#{screening_data[:title]}: #{e.class} - #{e.message}"
        errors << error_msg
        puts "✗ #{error_msg}"
      end
    end

    puts "\n" + "=" * 60
    puts "Import Summary"
    puts "=" * 60
    puts "Total screenings found: #{screenings.count}"
    puts "Successfully imported: #{imported_count}"
    puts "Skipped/Failed: #{skipped_count}"
    puts "=" * 60

    if errors.any?
      puts "\nErrors:"
      errors.first(10).each { |err| puts "  - #{err}" }
      puts "  ... and #{errors.size - 10} more" if errors.size > 10
    end
  end

  desc "Import Filmarchiv program for next 30 days"
  task import_month: :environment do
    service = FilmarchivCrawlerService.new
    screenings = service.fetch_program_range(Date.today, Date.today + 3)
    puts screenings.inspect

    # ... rest of import logic ...
  end

  desc "Enrich Filmarchiv movies with TMDB data"
  task enrich_with_tmdb: :environment do
    filmarchiv = Cinema.find_by(cinema_id: "t-metro-kinokulturhaus")
    movies = filmarchiv.movies.distinct.where(tmdb_id: nil)

    puts "Enriching #{movies.count} movies with TMDB data..."
    puts "=" * 60

    success_count = 0
    no_match_count = 0

    movies.each do |movie|
      puts "\nSearching for: #{movie.title} (#{movie.year})"
      puts "Director: #{movie.director}" if movie.director
      matcher = TmdbMatcherService.new(movie)
      best_match = matcher.find_best_match

      if best_match
        tmdb_id = best_match["id"]
        # Fetch full movie details (includes genres)
        movie_details = fetch_tmdb_movie_details(tmdb_id)

        # Fetch credits (cast and crew)
        credits = fetch_tmdb_credits(tmdb_id)

        # Update movie basic info
        movie.update(
          tmdb_id: tmdb_id,
          description: best_match["overview"].presence || movie.description,
          poster_path: best_match["poster_path"] ? "https://image.tmdb.org/t/p/w500#{best_match['poster_path']}" : nil,
          original_title: best_match["original_title"],
          year: movie.year.presence || best_match["release_date"]&.split("-")&.first,
          runtime: movie_details&.dig("runtime") || movie.runtime
        )

        # Add genres
        if movie_details && movie_details["genres"]
          add_genres_to_movie(movie, movie_details["genres"])
        end

        # Add credits (cast and crew)
        if credits
          add_credits_to_movie(movie, credits)
        end

        success_count += 1
        puts "✓ Matched to: '#{best_match['title']}' (#{best_match['release_date']&.split('-')&.first})"
        puts "  Added #{movie.genres.count} genres"
        puts "  Added #{movie.credits.where(role: 'cast').count} cast members"
        puts "  Added #{movie.credits.where(role: 'crew').count} crew members"
      else
        no_match_count += 1
        puts "✗ No good match for '#{movie.title}' (#{movie.year})"
      end

      sleep(0.3) # Rate limiting
    end

    puts "\n" + "=" * 60
    puts "Enrichment Summary"
    puts "=" * 60
    puts "Successfully matched: #{success_count}"
    puts "No match found: #{no_match_count}"
    puts "=" * 60
  end

  def fetch_tmdb_movie_details(tmdb_id)
    url = URI("https://api.themoviedb.org/3/movie/#{tmdb_id}")
    url.query = URI.encode_www_form({
                                      language: "de-DE"
                                    })

    TmdbResultService.new(url).call
  rescue StandardError => e
    Rails.logger.error "Failed to fetch movie details for TMDB ID #{tmdb_id}: #{e.message}"
    nil
  end

  def fetch_tmdb_credits(tmdb_id)
    url = URI("https://api.themoviedb.org/3/movie/#{tmdb_id}/credits")
    url.query = URI.encode_www_form({
                                      language: "de-DE"
                                    })

    TmdbResultService.new(url).call
  rescue StandardError => e
    Rails.logger.error "Failed to fetch credits for TMDB ID #{tmdb_id}: #{e.message}"
    nil
  end

  def add_genres_to_movie(movie, tmdb_genres)
    tmdb_genres.each do |genre_data|
      # Find or create genre
      genre = Genre.find_or_create_by!(genre_id: "g-#{genre_data['id']}") do |g|
        g.name = genre_data["name"]
      end

      # Associate with movie (avoid duplicates)
      movie.genres << genre unless movie.genres.include?(genre)
    end
  rescue StandardError => e
    Rails.logger.error "Failed to add genres for movie #{movie.title}: #{e.message}"
  end

  def add_credits_to_movie(movie, credits_data)
    # Add cast (limit to top 15 to avoid too much data)
    if credits_data["cast"]
      credits_data["cast"].first(15).each do |cast_member|
        add_cast_member(movie, cast_member)
      end
    end

    # Add crew (directors, writers, producers, cinematographers)
    if credits_data["crew"]
      important_jobs = [ "Director", "Writer", "Screenplay", "Producer", "Director of Photography", "Original Music Composer" ]

      credits_data["crew"].each do |crew_member|
        if important_jobs.include?(crew_member["job"])
          add_crew_member(movie, crew_member)
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to add credits for movie #{movie.title}: #{e.message}"
  end

  def add_cast_member(movie, cast_data)
    # Find or create person
    person = Person.find_or_create_by!(tmdb_id: cast_data["id"].to_s) do |p|
      p.name = cast_data["name"]
    end

    # Update name if changed
    person.update(name: cast_data["name"]) if person.name != cast_data["name"]

    # Create credit
    Credit.find_or_create_by!(
      movie: movie,
      person: person,
      role: "cast",
      character: cast_data["character"],
      order: cast_data["order"]
    )
  rescue ActiveRecord::RecordInvalid => e
    # Skip duplicate credits
    Rails.logger.debug "Skipped duplicate cast credit: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Failed to add cast member #{cast_data['name']}: #{e.message}"
  end

  def add_crew_member(movie, crew_data)
    # Find or create person
    person = Person.find_or_create_by!(tmdb_id: crew_data["id"].to_s) do |p|
      p.name = crew_data["name"]
    end

    # Update name if changed
    person.update(name: crew_data["name"]) if person.name != crew_data["name"]

    # Create credit
    Credit.find_or_create_by!(
      movie: movie,
      person: person,
      role: "crew",
      job: crew_data["job"]
    )
  rescue ActiveRecord::RecordInvalid => e
    # Skip duplicate credits
    Rails.logger.debug "Skipped duplicate crew credit: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Failed to add crew member #{crew_data['name']}: #{e.message}"
  end

  desc "Test film detail extraction"
  task test_extraction: :environment do
    service = FilmarchivCrawlerService.new

    # Get a film URL from the program
    screenings = service.fetch_program

    if screenings.any?
      test_screening = screenings.first
      puts "Testing extraction for: #{test_screening[:title]}"
      puts "URL: #{test_screening[:film_url]}"
      puts "-" * 60

      puts "Director: #{test_screening[:director]}"
      puts "Year: #{test_screening[:year]}"
      puts "Country: #{test_screening[:country]}"
      puts "Runtime: #{test_screening[:runtime]}"
      puts "\nDescription:"
      puts test_screening[:description]
    else
      puts "No screenings found"
    end
  end
end
