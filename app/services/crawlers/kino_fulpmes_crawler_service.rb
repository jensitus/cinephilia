require "net/http"

module Crawlers
  class KinoFulpmesCrawlerService < BaseCrawlerService
    CINEMA_ID     = "t-kino-fulpmes"
    CINEMA_TITLE  = "Kino Fulpmes"
    CINEMA_COUNTY = "Tirol"
    CINEMA_URL    = "https://www.kino-fulpmes.at"
    CINEMA_STREET = "Michael-Pfurtscheller-Weg 8"
    CINEMA_ZIP    = "6166"
    CINEMA_CITY   = "Fulpmes"
    CINEMA_EMAIL  = "info@kino-fulpmes.at"
    CINEMA_PHONE  = "+43 664 3003578"
    LISTING_URL   = "https://www.kino-fulpmes.at/filme/"
    VIENNA_TZ     = ActiveSupport::TimeZone["Vienna"]

    def call
      cinema = find_or_create_cinema(id: CINEMA_ID, title: CINEMA_TITLE, county: CINEMA_COUNTY, url: CINEMA_URL)
      update_contact(cinema)
      film_entries.each { |entry| process_film(entry, cinema) }
    end

    private

    def update_contact(cinema)
      cinema.update(
        street:    CINEMA_STREET,
        zip:       CINEMA_ZIP,
        city:      CINEMA_CITY,
        telephone: CINEMA_PHONE,
        email:     CINEMA_EMAIL
      )
    end

    # Returns [{title:, detail_url:, ov:, three_d:}, ...]
    def film_entries
      html = fetch_page(LISTING_URL)
      return [] unless html

      doc = Nokogiri::HTML(html)
      doc.css(".filterItem").filter_map do |item|
        link = item.at_css("a[href]")
        next unless link

        detail_url = link["href"]
        detail_url = "#{CINEMA_URL}#{detail_url}" if detail_url.start_with?("/")

        title = item.at_css(".title")&.text&.strip&.gsub(/\s*\(\d{4}\)\s*/, "")&.strip
        next if title.blank?

        classes = item["class"].to_s.split
        {
          title:      title,
          detail_url: detail_url,
          ov:         classes.include?("ov"),
          three_d:    classes.include?("dreiD")
        }
      end
    end

    def process_film(entry, cinema)
      times = fetch_showtimes(entry[:detail_url])
      if times.empty?
        Rails.logger.info "#{self.class.name}: no showtimes for '#{entry[:title]}'"
        return
      end

      movie = find_or_create_movie(
        display_title:  entry[:title],
        original_title: entry[:title],
        year:           times.first.to_date.year.to_s
      )
      return unless movie

      times.each do |t|
        create_schedule(time: t, three_d: entry[:three_d], ov: entry[:ov], movie: movie, cinema: cinema)
      end
    end

    # Returns an array of ISO8601 time strings parsed from the film detail page.
    def fetch_showtimes(url)
      html = fetch_page(url)
      return [] unless html

      doc = Nokogiri::HTML(html)
      showtimes = []

      doc.css(".dayItem").each do |day_item|
        date = parse_date(day_item.at_css(".day")&.text)
        next unless date

        day_item.css(".timeItem").each do |time_item|
          time_str = time_item.text.strip
          next unless time_str.match?(/\d{1,2}:\d{2}/)

          showtimes << VIENNA_TZ.parse("#{date} #{time_str}").iso8601
        rescue ArgumentError
          next
        end
      end

      showtimes
    end

    # Parses the day div text, e.g. "Do\n26.02.\n2026" → "2026-02-26"
    def parse_date(text)
      return nil unless text

      text = text.strip.gsub(/\s+/, " ")
      match = text.match(/(\d{1,2})\.(\d{2})\.\s*(\d{4})/)
      return nil unless match

      day, month, year = match[1].to_i, match[2].to_i, match[3].to_i
      Date.new(year, month, day).to_s
    rescue Date::Error
      nil
    end

    def fetch_page(url)
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get(uri.request_uri).body
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: fetch failed (#{url}) – #{e.message}"
      nil
    end
  end
end
