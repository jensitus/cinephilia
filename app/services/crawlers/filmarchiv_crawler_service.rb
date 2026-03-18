require "net/http"

module Crawlers
  class FilmarchivCrawlerService < BaseCrawlerService
    CINEMA_ID     = "t-metro-kinokulturhaus"
    CINEMA_TITLE  = "Metro Kinokulturhaus"
    CINEMA_COUNTY = "Wien"
    CINEMA_URL    = "https://www.filmarchiv.at"
    CINEMA_STREET = "Johannesgasse 4"
    CINEMA_ZIP    = "1010"
    CINEMA_CITY   = "Wien"
    CINEMA_EMAIL  = "reservierung@filmarchiv.at"
    CINEMA_PHONE  = "+43 1 512 18 03"
    PROGRAM_PATH  = "/de/kino/programm"
    VIENNA_TZ     = ActiveSupport::TimeZone["Vienna"]
    USER_AGENT    = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

    def call
      @series_cache = {}
      cinema = find_or_create_cinema(id: CINEMA_ID, title: CINEMA_TITLE, county: CINEMA_COUNTY, url: CINEMA_URL)
      update_contact(cinema)
      fetch_screenings.each { |screening| process_screening(screening, cinema) }
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

    def fetch_screenings
      (0...Cinephilia::Config::DAYS_TO_FETCH).flat_map do |offset|
        date = Date.today + offset
        html = fetch_page("#{CINEMA_URL}#{PROGRAM_PATH}?day=#{date}")
        next [] unless html

        sleep(0.5)
        doc = Nokogiri::HTML(html)
        doc.css(".screening_card").filter_map { |card| extract_screening_data(card) }
      end
    end

    def extract_screening_data(card)
      datetime_text = card.css("div.mt-1.mb-2.text-s23").first&.text&.strip
      return nil unless datetime_text

      datetime = parse_datetime(datetime_text)
      return nil unless datetime

      title    = card.css("title-div").first&.text&.strip
      return nil if title.blank?

      # subtitle-div holds the international/English title — better for TMDB matching
      subtitle = card.css("subtitle-div").first&.text&.strip

      film_link = card.css('a[href*="/de/kino/film/"]').first&.[]("href")
      film_details = film_link ? fetch_film_details("#{CINEMA_URL}#{film_link}") : {}
      sleep(0.3)

      {
        title:          title,
        original_title: subtitle.presence || title,
        datetime:       datetime,
        year:           film_details[:year],
        country:        film_details[:country],
        runtime:        film_details[:runtime],
        description:    film_details[:description],
        series_name:    film_details[:series_name],
        series_url:     film_details[:series_url]
      }
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: error extracting screening data – #{e.message}"
      nil
    end

    def process_screening(screening, cinema)
      movie = find_or_create_movie(
        display_title:  screening[:title],
        original_title: screening[:original_title],
        year:           screening[:year].to_s
      )
      return unless movie

      fill_missing_fields(movie, screening)
      schedule = create_schedule(time: screening[:datetime].iso8601, three_d: false, ov: false, movie: movie, cinema: cinema)
      tag_series(schedule, screening[:series_name], screening[:series_url])
    end

    def fill_missing_fields(movie, screening)
      updates = {}
      # Filmarchiv curates its own descriptions — always prefer them over TMDB's.
      updates[:description] = screening[:description] if screening[:description].present?
      updates[:year]        = screening[:year]        if movie.year.blank?      && screening[:year].present?
      updates[:countries]   = screening[:country]     if movie.countries.blank? && screening[:country].present?
      updates[:runtime]     = screening[:runtime]     if movie.runtime.blank?   && screening[:runtime].present?
      movie.update(updates) if updates.any?
    end

    def parse_datetime(datetime_text)
      match = datetime_text.match(/(\d{1,2})\.(\d{1,2})\.,?\s*(\d{1,2}):(\d{2})/)
      return nil unless match

      day   = match[1].to_i
      month = match[2].to_i
      hour  = match[3].to_i
      min   = match[4].to_i
      year  = Date.today.year

      begin
        date = Date.new(year, month, day)
        year += 1 if date < Date.today - 180
      rescue ArgumentError
        year += 1
      end

      VIENNA_TZ.local(year, month, day, hour, min)
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: error parsing datetime '#{datetime_text}' – #{e.message}"
      nil
    end

    def fetch_film_details(film_url)
      html = fetch_page(film_url)
      return {} unless html

      doc = Nokogiri::HTML(html)

      series_link = doc.at_css("#submodule_id a[href*='/de/kino/filmreihe/']")
      series_url  = series_link ? "#{CINEMA_URL}#{series_link['href']}" : nil
      series_name = series_link&.text&.strip

      {
        country:            extract_meta(doc, "Land"),
        year:               extract_meta(doc, "Jahr"),
        runtime:            extract_runtime(doc),
        description:        extract_description(doc),
        series_url:         series_url,
        series_name:        series_name
      }
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: error fetching film details from #{film_url} – #{e.message}"
      {}
    end

    # Finds a metadata row by its <strong> label and returns the adjacent <span> text.
    def extract_meta(doc, label)
      doc.css("#submodule_id div.leading-tight").each do |div|
        strong = div.at_css("strong")
        next unless strong&.text&.strip&.start_with?(label)

        return div.at_css("span")&.text&.strip
      end
      nil
    end

    def extract_runtime(doc)
      value = extract_meta(doc, "Länge")
      value&.match(/(\d+)/)&.[](1)&.to_i
    end

    def extract_description(doc)
      grid = doc.css("#submodule_id > div")[1]
      grid&.at_css("p")&.text&.strip&.gsub(/\s+/, " ")
    end

    def tag_series(schedule, series_name, series_url)
      return unless schedule && series_name.present?

      description = fetch_series_description(series_url)
      tag = Tag.find_or_create_tag(series_name, description: description)
      schedule.tags << tag unless schedule.tags.include?(tag)
    end

    def fetch_series_description(series_url)
      return nil unless series_url
      return @series_cache[series_url] if @series_cache.key?(series_url)

      html = fetch_page(series_url)
      sleep(0.3)
      description = html ? Nokogiri::HTML(html).css("#submodule_id p").first&.text&.strip&.gsub(/\s+/, " ") : nil
      @series_cache[series_url] = description
    end

    def fetch_page(url)
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.get(uri.request_uri, "User-Agent" => USER_AGENT).body
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: fetch failed (#{url}) – #{e.message}"
      nil
    end
  end
end
