module Crawlers
  class LeokinoCrawlerService < BaseCrawlerService
    CINEMA_URL = "https://www.leokino.at"
    PROGRAMS_URL = "https://www.leokino.at/ajax/programm.php"
    VIENNA_TZ = ActiveSupport::TimeZone["Vienna"]

    LEO_ID = "t-leokino"
    LEO_TITLE = "Leokino"
    LEO_COUNTY = "Tirol"
    LEO_STREET = "Anichstraße 36"
    LEO_ZIP = "6020"
    LEO_CITY = "Innsbruck"
    LEO_EMAIL = "office@leokino.at"
    LEO_PHONE = "+43 512 56 04 70"

    CINE_ID = "t-cinematograph-innsbruck"
    CINE_TITLE = "Cinematograph Innsbruck"
    CINE_COUNTY = "Tirol"
    CINE_STREET = "Museumstraße 31"
    CINE_ZIP = "6020"
    CINE_CITY = "Innsbruck"
    CINE_EMAIL = "office@leokino.at"
    CINE_PHONE = "+43 512 56 04 70 50"

    SPECIAL_CLASSES = {
      "buttonKinderfilm" => { name: "Junges Kino", url: "https://www.leokino.at/programm/junges-kino/" },
      "buttonZeitreisen" => { name: "Kinozeitreisen", url: "https://www.leokino.at/festivals/kinozeitreisen/" },
      "buttonFilmstart" => { name: "Filmstart", url: nil },
      "buttonFestival" => { name: "Festival", url: nil }
    }.freeze

    def call
      @leo_cinema = find_or_create_cinema(id: LEO_ID, title: LEO_TITLE, county: LEO_COUNTY, url: CINEMA_URL)
      @cine_cinema = find_or_create_cinema(id: CINE_ID, title: CINE_TITLE, county: CINE_COUNTY, url: CINEMA_URL)
      update_contacts
      @tag_descriptions = {}
      @film_year_cache = {}

      (0...Cinephilia::Config::DAYS_TO_FETCH).each do |i|
        process_day(Date.today + i)
        sleep(0.3)
      end
    end

    private

    def update_contacts
      @leo_cinema.update(street: LEO_STREET, zip: LEO_ZIP, city: LEO_CITY, telephone: LEO_PHONE, email: LEO_EMAIL)
      @cine_cinema.update(street: CINE_STREET, zip: CINE_ZIP, city: CINE_CITY, telephone: CINE_PHONE, email: CINE_EMAIL)
    end

    def process_day(date)
      html = fetch_page("#{PROGRAMS_URL}?dateSet=#{date}")
      return unless html

      Nokogiri::HTML(html, nil, "UTF-8").css(".col.colpadding1").each { |card| process_card(card, date) }
    end

    def process_card(card, date)
      title_link = card.at_css("h4.filmtitel a")
      return unless title_link

      title = title_link.text.strip
      return if title.blank?

      time_node = card.at_css("h6.right")
      return unless time_node

      time = parse_time(date, time_node.text.strip)
      return unless time

      cinema = cinema_for(card)
      h6_text = card.at_css("h6.nomargin")&.text.to_s
      director = extract_director(h6_text)
      ov_info = if h6_text.include?("OmU")
                  "OmU"
      elsif h6_text.match?(/\bOV\b/)
                  "OV"
      end
      ov = ov_info.present?

      movie = find_or_create_movie(
        display_title: title,
        original_title: title,
        year: date.year.to_s,
        director_hint: director
      )
      return unless movie

      schedule = create_schedule(time: time, three_d: false, ov: ov, info: ov_info, movie: movie, cinema: cinema)
      tag_screening(schedule, card)
    end

    def cinema_for(card)
      card["class"].to_s.include?("bgcolorcinematograph") ? @cine_cinema : @leo_cinema
    end

    def extract_director(text)
      m = text.match(/R:\s*([^\n\r]+)/)
      m ? m[1].strip : nil
    end

    def parse_time(date, time_text)
      m = time_text.match(/(\d{1,2})[.:](\d{2})/)
      return nil unless m

      VIENNA_TZ.local(date.year, date.month, date.day, m[1].to_i, m[2].to_i).iso8601
    rescue ArgumentError, TZInfo::AmbiguousTime
      nil
    end

    def tag_screening(schedule, card)
      return unless schedule

      card.css("div.buttonFilm").each do |btn|
        classes = btn["class"].to_s.split
        SPECIAL_CLASSES.each do |css_class, tag_info|
          next unless classes.include?(css_class)

          description = fetch_tag_description(tag_info[:url])
          tag = Tag.find_or_create_tag(tag_info[:name], description: description)
          schedule.tags << tag unless schedule.tags.include?(tag)
        end
      end
    end

    def fetch_tag_description(url)
      return nil if url.blank?
      return @tag_descriptions[url] if @tag_descriptions.key?(url)

      html = fetch_page(url)
      return (@tag_descriptions[url] = nil) unless html

      doc = Nokogiri::HTML(html)
      description = doc.css(".entry-content p").map(&:text).map(&:squish).reject(&:blank?).first
      @tag_descriptions[url] = description
    end
  end
end
