require "net/http"

module Crawlers
  class CineplexxSpittalCrawlerService < BaseCrawlerService
    API_V2_BASE = "https://app.cineplexx.at/api/v2"
    SPITTAL_CINEMA_ID = "1021"

    CINEMA_ID = "t-cineplexx-spittal"
    CINEMA_TITLE = "Cineplexx Spittal"
    CINEMA_COUNTY = "Kärnten"
    CINEMA_URL = "https://cineplexx.at/cinemas/Cineplexx-Spittal"

    def call
      movies = fetch_json("#{API_V2_BASE}/movies")
      return unless movies&.any?

      cinema = find_or_create_cinema(id: CINEMA_ID, title: CINEMA_TITLE, county: CINEMA_COUNTY, url: CINEMA_URL)

      movies.each do |movie_data|
        process_movie(movie_data, cinema)
        sleep 0.1
      end
    end

    private

    def fetch_json(url)
      response = Net::HTTP.get_response(URI.parse(url))
      JSON.parse(response.body)
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: fetch failed #{url} - #{e.message}"
      nil
    end

    def process_movie(movie_data, cinema)
      all_sessions = fetch_json("#{API_V2_BASE}/movies/#{movie_data['id']}/sessions")
      return unless all_sessions

      spittal_sessions = all_sessions
        .flat_map { |day| day["sessions"] }
        .select { |s| s["cinemaId"] == SPITTAL_CINEMA_ID }

      return if spittal_sessions.empty?

      display_title = movie_data["titleCalculated"].presence || movie_data["title"].delete_prefix("*")
      original_title = movie_data["titleOriginalCalculated"].presence || display_title
      year = movie_data["startDate"]&.split("-")&.first || Date.today.year.to_s

      movie = find_or_create_movie(display_title: display_title, original_title: original_title, year: year)
      return unless movie

      spittal_sessions.each do |session|
        three_d = session["technologies"]&.any? { |group| group.include?("3D") }
        create_schedule(time: session["showtime"], three_d: three_d, ov: false, movie: movie, cinema: cinema)
      end
    end
  end
end
