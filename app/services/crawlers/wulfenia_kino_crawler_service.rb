require "net/http"

module Crawlers
  class WulfeniaKinoCrawlerService < BaseCrawlerService
    CINEMA_ID = "t-wulfenia-kino"
    CINEMA_TITLE = "Wulfenia Kino"
    CINEMA_COUNTY = "Kärnten"
    CINEMA_URL = "https://www.wulfeniakino.at"
    PROGRAMME_URL = "https://www.wulfeniakino.at/programm"
    VIENNA_TZ = ActiveSupport::TimeZone["Vienna"]

    def call
      html = fetch_page
      return unless html

      programm = extract_programm_json(html)
      return unless programm

      cinema = find_or_create_cinema(id: CINEMA_ID, title: CINEMA_TITLE, county: CINEMA_COUNTY, url: CINEMA_URL)
      process_films(programm["filme"], cinema)
    end

    private

    def fetch_page
      uri = URI.parse(PROGRAMME_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get(uri.path).body
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: fetch failed - #{e.message}"
      nil
    end

    def extract_programm_json(html)
      doc = Nokogiri::HTML(html)
      script = doc.css("script").find { |s| s.text.include?("var programm =") }
      return nil unless script

      json_str = script.text.match(/var programm = (\{.+\});/m)&.captures&.first
      return nil unless json_str

      JSON.parse(json_str)
    rescue JSON::ParserError => e
      Rails.logger.error "#{self.class.name}: JSON parse failed - #{e.message}"
      nil
    end

    def process_films(filme, cinema)
      filme.each_value { |film_data| process_film(film_data, cinema) }
    end

    def process_film(film_data, cinema)
      fakten = film_data["filmfakten"]
      vorstellungen = film_data["vorstellungen"]
      return unless fakten && vorstellungen

      titel = fakten["titel"]
      return if titel.blank?

      year = fakten["KinoStart_hier"]&.split("-")&.first || Date.today.year.to_s
      movie = find_or_create_movie(display_title: titel, original_title: titel, year: year)
      return unless movie

      create_screenings(vorstellungen, movie, cinema)
    end

    def create_screenings(vorstellungen, movie, cinema)
      termine = vorstellungen["termine"] || {}
      ov = vorstellungen.dig("vorstellungen_fakten", "OrigVersion").present?
      three_d = vorstellungen.dig("vorstellungen_fakten", "DreiD").present?

      termine.each_value do |termin|
        datum = termin["datum"]
        zeit = termin["zeit"]
        next unless datum && zeit

        time = VIENNA_TZ.parse("#{datum} #{zeit}").iso8601
        create_schedule(time: time, three_d: three_d, ov: ov, movie: movie, cinema: cinema)
      end
    end
  end
end
