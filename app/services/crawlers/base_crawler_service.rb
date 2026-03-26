module Crawlers
  class BaseCrawlerService < BaseService
    def self.all_crawlers
      Dir[Rails.root.join("app/services/crawlers/*_crawler_service.rb")].each do |file|
        class_name = "Crawlers::#{File.basename(file, ".rb").camelize}"
        class_name.constantize unless class_name == "Crawlers::BaseCrawlerService"
      end
      subclasses
    end

    private

    def find_or_create_cinema(id:, title:, county:, url:)
      cinema = Cinema.find_or_create_by(cinema_id: id)
      cinema.update(title: title, county: county, uri: url) if cinema.title.blank?
      cinema
    end

    def find_or_create_movie(display_title:, original_title:, year:, director_hint: nil)
      movie_string_id = Movie.create_movie_id(display_title)
      movie = Movie.find_by(movie_id: movie_string_id)
      if movie&.tmdb_id.present?
        if director_hint.present? && movie.credits.exists? && !director_in_credits?(movie, director_hint)
          movie.credits.destroy_all
          movie.update(tmdb_id: nil, description: nil, poster_path: nil, runtime: nil, year: nil, countries: nil)
        else
          TmdbUtility.fetch_movie_info_from_tmdb(movie, movie.tmdb_id) if incomplete?(movie)
          return movie
        end
      end

      movie ||= Movie.new(movie_id: movie_string_id, title: display_title)
      if movie.tmdb_id.blank?
        tmdb_id = lookup_tmdb_id(original_title, display_title, year, director_hint: director_hint)
        TmdbUtility.fetch_movie_info_from_tmdb(movie, tmdb_id) if tmdb_id.present?
      end

      movie.save if movie.new_record? || movie.changed?
      movie
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: movie '#{display_title}' failed - #{e.message}"
      nil
    end

    def lookup_tmdb_id(original_title, display_title, year, director_hint: nil)
      unless original_title.match?(/\s[–—]\s/)
        tmdb_url = TmdbUtility.create_movie_search_url(original_title, display_title)
        query_string = NormalizeAndCleanService.call(original_title)
        tmdb_id = TmdbUtility.fetch_tmdb_id(tmdb_url, year, query_string, display_title)
        return tmdb_id if tmdb_id
      end

      tmdb_id = Tmdb::MovieMatcher.new(
        original_title: original_title,
        display_title:  display_title,
        year:           year,
        film_at_uri:    nil,
        director_hint:  director_hint
      ).find_tmdb_id
      return tmdb_id if tmdb_id

      # Fallback for classic films re-screened years after release: retry without year constraint
      return nil if year == "0"
      Tmdb::MovieMatcher.new(
        original_title: original_title,
        display_title:  display_title,
        year:           "0",
        film_at_uri:    nil,
        director_hint:  director_hint
      ).find_tmdb_id
    end

    def create_schedule(time:, three_d:, ov:, movie:, cinema:, info: nil)
      screening = { "time" => time, "3d" => three_d, "ov" => ov, "info" => info }
      Schedule.create_schedule(screening, movie.id, cinema.id)
    end

    def director_in_credits?(movie, director_name)
      movie.people.joins(:credits)
                  .where(credits: { role: "crew", job: "Director" })
                  .where(people: { name: director_name })
                  .exists?
    end

    def incomplete?(movie)
      movie.year.blank? || movie.countries.blank? || !movie.credits.exists?
    end
  end
end
