require "net/http"

module Crawlers
  class CinepointCrawlerService < BaseCrawlerService
    CINEMA_ID     = "t-cinepoint-seefeld"
    CINEMA_TITLE  = "Cinepoint Seefeld"
    CINEMA_COUNTY = "Tirol"
    CINEMA_URL    = "https://www.cinepoint.at"
    CINEMA_STREET = "Klosterstraße 600"
    CINEMA_ZIP    = "6100"
    CINEMA_CITY   = "Seefeld in Tirol"
    CINEMA_PHONE  = "+43 (0)5212 3311"
    CINEMA_EMAIL  = "info@cinepoint.at"
    LISTING_URL   = "https://www.cinepoint.at/aktuelle-filme-im-kino/"
    VIENNA_TZ     = ActiveSupport::TimeZone["Vienna"]

    # "Sa. 21.02. um 15:20 Uhr"
    SHOWTIME_RE = /(?:Mo|Di|Mi|Do|Fr|Sa|So)\.\s+(\d{1,2})\.(\d{1,2})\.\s+um\s+(\d{1,2}:\d{2})\s+Uhr/i

    def call
      cinema = find_or_create_cinema(
        id: CINEMA_ID, title: CINEMA_TITLE, county: CINEMA_COUNTY, url: CINEMA_URL
      )
      update_contact(cinema)
      current_films.each { |title, start_date, detail_url| process_film(title, start_date, detail_url, cinema) }
    end

    private

    # ── Contact ───────────────────────────────────────────────────────────────

    def update_contact(cinema)
      cinema.update(
        street:    CINEMA_STREET,
        zip:       CINEMA_ZIP,
        city:      CINEMA_CITY,
        telephone: CINEMA_PHONE,
        email:     CINEMA_EMAIL
      )
    end

    # ── Listing page ──────────────────────────────────────────────────────────

    # Returns [[title, start_date, detail_url], ...] from the listing page.
    def current_films
      html = fetch_page(LISTING_URL)
      return [] unless html

      doc     = Nokogiri::HTML(html)
      results = []

      doc.css("p").each do |p_node|
        date_match = p_node.text.match(/ab\s+(\d{1,2})\.(\d{1,2})\.(\d{4})/)
        next unless date_match

        start_date = Date.new(date_match[3].to_i, date_match[2].to_i, date_match[1].to_i)
        card       = card_container(p_node)
        next unless card

        title      = card.at_css("h4")&.text&.strip
        detail_url = card.css("a[href]")
                         .map { |a| a["href"] }
                         .find { |href| href.start_with?(CINEMA_URL) }

        results << [ title, start_date, detail_url ] if title.present? && detail_url.present?
      end

      results
    end

    # Walk up the DOM to the movie-card container: first ancestor that holds
    # exactly one date-paragraph and at least one <h4>.
    def card_container(date_node)
      current = date_node.parent
      5.times do
        break unless current

        date_ps = current.css("p").select { |p| p.text.match?(/ab\s+\d{1,2}\.\d{1,2}\.\d{4}/) }
        return current if current.at_css("h4") && date_ps.length == 1

        current = current.parent
      end
      nil
    end

    # ── Movie detail page ─────────────────────────────────────────────────────

    def process_film(title, start_date, detail_url, cinema)
      times = fetch_showtimes(detail_url)
      if times.empty?
        Rails.logger.info "#{self.class.name}: no showtimes found for '#{title}' at #{detail_url}"
        return
      end

      three_d = title.match?(/3D/i)
      movie   = find_or_create_movie(
        display_title: title, original_title: title, year: start_date.year.to_s
      )
      return unless movie

      times.each { |t| create_schedule(time: t, three_d: three_d, ov: false, movie: movie, cinema: cinema) }
    end

    # Fetches a movie detail page and extracts all showtimes from the
    # "Wann läuft dieser Film?" section (ul > li structure).
    def fetch_showtimes(url)
      html = fetch_page(url)
      return [] unless html

      doc = Nokogiri::HTML(html)

      # Locate the schedule section by its heading text
      heading = doc.css("h3").find { |h| h.text.include?("Wann läuft dieser Film") }
      return [] unless heading

      # Collect all <li> text within the nearest following container
      section = heading.parent
      section.css("li").filter_map do |li|
        parse_showtime(li.text.strip)
      end
    end

    def parse_showtime(text)
      match = text.match(SHOWTIME_RE)
      return nil unless match

      day, month, time_str = match[1].to_i, match[2].to_i, match[3]
      year = resolve_year(day, month)
      VIENNA_TZ.parse("#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')} #{time_str}").iso8601
    rescue ArgumentError
      nil
    end

    # If the date is more than 60 days in the past, assume next year.
    def resolve_year(day, month)
      today     = Date.today
      candidate = Date.new(today.year, month, day) rescue nil
      return today.year unless candidate
      candidate < today - 60 ? today.year + 1 : today.year
    end

    # ── HTTP ──────────────────────────────────────────────────────────────────

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
