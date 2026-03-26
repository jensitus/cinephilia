require "net/http"

module Crawlers
  class VotivKinoCrawlerService < BaseCrawlerService
    PROGRAM_URL  = "https://www.votivkino.at/programm/"
    SPECIALS_URL = "https://www.votivkino.at/specials/demnaechst/"
    VIENNA_TZ   = ActiveSupport::TimeZone["Vienna"]

    VOTIV_ID      = "t-votiv-kino"
    VOTIV_TITLE   = "Votiv Kino"
    VOTIV_COUNTY  = "Wien"
    VOTIV_STREET  = "Währinger Straße 12"
    VOTIV_ZIP     = "1090"
    VOTIV_CITY    = "Wien"
    VOTIV_PHONE   = "+43 1 317 35 71"
    VOTIV_EMAIL   = "office@votivkino.at"

    DEFRANCE_ID     = "t-de-france"
    DEFRANCE_TITLE  = "De France"
    DEFRANCE_COUNTY = "Wien"
    DEFRANCE_STREET = "Schottenring 5"
    DEFRANCE_ZIP    = "1010"
    DEFRANCE_CITY   = "Wien"
    DEFRANCE_PHONE  = "+43 1 317 52 36"
    DEFRANCE_EMAIL  = "office@defrance.at"

    def call
      @cinema_votiv    = find_or_create_cinema(id: VOTIV_ID,    title: VOTIV_TITLE,    county: VOTIV_COUNTY,    url: PROGRAM_URL)
      @cinema_defrance = find_or_create_cinema(id: DEFRANCE_ID, title: DEFRANCE_TITLE, county: DEFRANCE_COUNTY, url: PROGRAM_URL)
      update_contacts

      @tag_descriptions = fetch_tag_descriptions

      screenings, notes, category_urls = fetch_all_screenings
      fill_missing_tag_descriptions(category_urls)
      update_cinema_notes(notes)
      screenings.each { |screening| process_screening(screening) }
    end

    private

    def update_contacts
      @cinema_votiv.update(street: VOTIV_STREET, zip: VOTIV_ZIP, city: VOTIV_CITY, telephone: VOTIV_PHONE, email: VOTIV_EMAIL)
      @cinema_defrance.update(street: DEFRANCE_STREET, zip: DEFRANCE_ZIP, city: DEFRANCE_CITY, telephone: DEFRANCE_PHONE, email: DEFRANCE_EMAIL)
    end

    def fetch_all_screenings
      screenings    = []
      notes         = {}
      category_urls = {}
      visited       = Set.new
      url           = PROGRAM_URL

      loop do
        break if visited.include?(url)
        visited << url

        html = fetch_page(url)
        break unless html

        doc = Nokogiri::HTML(html)
        parsed, page_notes, page_category_urls = parse_screenings(doc)
        screenings += parsed
        notes.merge!(page_notes)
        category_urls.merge!(page_category_urls)
        sleep(0.5)

        next_url = next_week_url(doc)
        break if next_url.nil? || visited.include?(next_url) || screenings_cover_days_to_fetch?(screenings)

        url = next_url
      end

      [ screenings, notes, category_urls ]
    end

    def parse_screenings(doc)
      screenings    = []
      notes         = {}
      category_urls = {}

      doc.css("tr.week-film-row").each do |row|
        title_link = row.at_css("th.week-film-title a")
        next unless title_link

        title = title_link.at_css("strong")&.text&.strip
        next if title.blank?

        if title.include?("Kombiticket")
          cinema = row.css("a.week-show-item").filter_map { |s| cinema_for(s) }.first
          notes[cinema.cinema_id] = title if cinema
          next
        end

        href       = title_link["href"]
        detail_url = href.present? ? (href.start_with?("http") ? href : "https://www.votivkino.at#{href}") : nil

        row.css("a.week-show-item").each do |show|
          cinema = cinema_for(show)
          next unless cinema

          datetime = parse_datetime(show.at_css("time")&.[]("datetime"))
          next unless datetime

          omu_text     = show.at_css("abbr.omu")&.text&.strip
          category_el  = show.at_css("a.category") || show.at_css("span.category")
          category     = category_el&.text&.strip

          if category.present? && !category_urls.key?(category)
            cat_href = category_el&.[]("href")&.sub(/#.*$/, "")
            category_urls[category] = cat_href.start_with?("http") ? cat_href : "https://www.votivkino.at#{cat_href}" if cat_href.present?
          end

          screenings << {
            title:      title,
            datetime:   datetime,
            cinema:     cinema,
            ov:         omu_text.present?,
            info:       omu_text.presence,
            category:   category.presence,
            detail_url: detail_url
          }
        end
      end

      [ screenings, notes, category_urls ]
    end

    def update_cinema_notes(notes)
      notes.each do |cinema_id, note|
        Cinema.find_by(cinema_id: cinema_id)&.update(notes: note)
      end
    end

    def cinema_for(show_item)
      if show_item.at_css("span.tag_votiv")
        @cinema_votiv
      elsif show_item.at_css("span.tag_defrance")
        @cinema_defrance
      end
    end

    def parse_datetime(datetime_str)
      return nil if datetime_str.blank?

      # The site stores local Vienna time but marks it as Z — strip the timezone indicator
      local_str = datetime_str.gsub(/Z$/, "").gsub(/\+\d{2}:\d{2}$/, "")
      VIENNA_TZ.parse(local_str).iso8601
    rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
      nil
    end

    def next_week_url(doc)
      link = doc.at_css("a.bt-programm-next")
      return nil unless link

      href = link["href"]
      return nil if href.blank?

      href.start_with?("http") ? href : "https://www.votivkino.at#{href}"
    end

    def screenings_cover_days_to_fetch?(screenings)
      return false if screenings.empty?

      latest = screenings.map { |s| Time.parse(s[:datetime]).to_date }.max
      latest >= Date.today + Cinephilia::Config::DAYS_TO_FETCH - 1
    end

    def process_screening(screening)
      @director_cache ||= {}
      director_hint = @director_cache[screening[:title]] ||= scrape_director(screening[:detail_url])

      movie = find_or_create_movie(
        display_title:  screening[:title],
        original_title: screening[:title],
        year:           screening[:datetime].slice(0, 4),
        director_hint:  director_hint
      )
      return unless movie

      schedule = create_schedule(
        time:    screening[:datetime],
        three_d: false,
        ov:      screening[:ov],
        info:    screening[:info],
        movie:   movie,
        cinema:  screening[:cinema]
      )

      tag_screening(schedule, screening[:category])
    end

    def fetch_tag_descriptions
      html = fetch_page(SPECIALS_URL)
      return {} unless html

      doc = Nokogiri::HTML(html)
      series = {}
      doc.css("a.category").each do |link|
        name = link.at_css("i")&.text&.strip
        next if name.blank? || series.key?(name)

        href = link["href"]&.sub(/#.*$/, "")
        next if href.blank?

        series[name] = href.start_with?("http") ? href : "https://www.votivkino.at#{href}"
      end

      series.each_with_object({}) do |(name, url), descriptions|
        series_html = fetch_page(url)
        next unless series_html

        series_doc = Nokogiri::HTML(series_html)
        description = series_doc.at_css("div.content.cat-desc")&.text&.squish
        descriptions[name] = description if description.present?
        sleep(0.3)
      end
    end

    def fill_missing_tag_descriptions(category_urls)
      category_urls.each do |name, url|
        next if @tag_descriptions.key?(name)

        html = fetch_page(url)
        next unless html

        doc = Nokogiri::HTML(html)
        description = doc.at_css("div.content.cat-desc")&.text&.squish ||
                      doc.css("article.film-detail header div.fFGLight.fs23 p")
                         .map(&:text).map(&:squish).reject(&:blank?).join(" ")
        @tag_descriptions[name] = description if description.present?
        sleep(0.3)
      end
    end

    def tag_screening(schedule, category_name)
      return unless schedule && category_name.present?

      tag = Tag.find_or_create_tag(category_name, description: @tag_descriptions&.[](category_name))
      schedule.tags << tag unless schedule.tags.include?(tag)
    end

    def scrape_director(detail_url)
      return nil if detail_url.blank?

      html = fetch_page(detail_url)
      return nil unless html

      node = Nokogiri::HTML(html).at_css("p.fFGLight.fs20")
      return nil unless node

      node.inner_html.split(/<br\s*\/?>/).each do |segment|
        text = Nokogiri::HTML.fragment(segment).text.strip
        return text.sub(/^Regie:\s*/, "").strip if text.start_with?("Regie:")
      end

      nil
    end

    def fetch_page(url)
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get(uri.request_uri, "User-Agent" => "Mozilla/5.0").body
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: fetch failed (#{url}) – #{e.message}"
      nil
    end
  end
end
