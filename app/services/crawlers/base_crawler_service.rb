module Crawlers
  class BaseCrawlerService < BaseService
    private

    def find_or_create_cinema(id:, title:, county:, url:)
      cinema = Cinema.find_or_create_by(cinema_id: id)
      cinema.update(title: title, county: county, uri: url) if cinema.title.blank?
      cinema
    end

    def find_or_create_movie(display_title:, original_title:, year:)
      movie_string_id = Movie.create_movie_id(display_title)
      movie = Movie.find_by(movie_id: movie_string_id)
      return movie if movie&.tmdb_id.present?

      movie ||= Movie.new(movie_id: movie_string_id, title: display_title)

      if movie.tmdb_id.blank?
        tmdb_id = lookup_tmdb_id(original_title, display_title, year)
        TmdbUtility.fetch_movie_info_from_tmdb(movie, tmdb_id) if tmdb_id.present?
      end

      movie.save if movie.new_record? || movie.changed?
      movie
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: movie '#{display_title}' failed - #{e.message}"
      nil
    end

    def lookup_tmdb_id(original_title, display_title, year)
      tmdb_url = TmdbUtility.create_movie_search_url(original_title, display_title)
      query_string = NormalizeAndCleanService.call(original_title)
      tmdb_id = TmdbUtility.fetch_tmdb_id(tmdb_url, year, query_string, display_title)
      return tmdb_id if tmdb_id

      Tmdb::MovieMatcher.new(
        original_title: original_title,
        display_title: display_title,
        year: year,
        film_at_uri: nil
      ).find_tmdb_id
    end

    def create_schedule(time:, three_d:, ov:, movie:, cinema:)
      screening = { "time" => time, "3d" => three_d, "ov" => ov }
      Schedule.create_schedule(screening, movie.id, cinema.id)
    end
  end
end
