module Crawlers
  class FilmmuseumCrawlerService < BaseCrawlerService
    PROGRAMME_URL = "https://www.filmmuseum.at/kinoprogramm/spielplan"
    BASE_URL      = "https://www.filmmuseum.at"

    VIENNA_TZ = ActiveSupport::TimeZone["Vienna"]

    CINEMA_ID        = "t-filmmuseum"
    CINEMA_TITLE     = "Filmmuseum"
    CINEMA_COUNTY    = "Wien"
    CINEMA_URL       = "https://www.filmmuseum.at"
    CINEMA_STREET    = "Augustinerstraße 1"
    CINEMA_ZIP       = "1010"
    CINEMA_CITY      = "Wien"
    CINEMA_TELEPHONE = "+43 1 533 70 54"
    CINEMA_EMAIL     = "kontakt@filmmuseum.at"

    def call
      html = fetch_page(PROGRAMME_URL)
      return unless html

      setup_cinema
      setup_caches

      raw_screenings = collect_all_screenings(html)
      fetch_all_detail_pages(raw_screenings)
      fetch_all_schiene_descriptions

      raw_screenings.each { |screening| process_screening(screening) }
    end

    private

    def setup_cinema
      @cinema = find_or_create_cinema(id: CINEMA_ID, title: CINEMA_TITLE, county: CINEMA_COUNTY, url: CINEMA_URL)
      @cinema.update(street: CINEMA_STREET, zip: CINEMA_ZIP, city: CINEMA_CITY,
                     telephone: CINEMA_TELEPHONE, email: CINEMA_EMAIL) if @cinema.street.blank?
    end

    def setup_caches
      @tag_descriptions = {}
      @schiene_urls     = {}
      @detail_cache     = {}
    end

    def collect_all_screenings(first_html)
      cutoff = Date.today + Cinephilia::Config::DAYS_TO_FETCH
      screenings = []
      doc = Nokogiri::HTML(first_html)

      loop do
        screenings.concat(parse_spielplan(doc))
        break if screenings.any? && screenings.last[:time].to_date >= cutoff

        url = next_week_url(doc)
        break unless url

        html = fetch_page(url)
        break unless html

        doc = Nokogiri::HTML(html)
        sleep(0.3)
      end

      screenings
    end

    def next_week_url(doc)
      link = doc.at_css("div.prev_back_links.right a")
      return nil unless link&.text&.include?("Nächste Woche")
      absolute_url(link["href"])
    end

    def fetch_all_detail_pages(raw_screenings)
      raw_screenings.map { |s| s[:detail_url] }.uniq.each do |url|
        next if url.blank?
        @detail_cache[url] = fetch_detail_page(url)
        sleep(0.3)
      end
    end

    def fetch_all_schiene_descriptions
      @detail_cache.each_value do |detail|
        next unless detail
        name = detail[:schiene_name]
        url  = detail[:schiene_url]
        @schiene_urls[name] = url if name.present? && url.present? && !@schiene_urls.key?(name)
      end

      @schiene_urls.each do |name, url|
        desc = fetch_schiene_description(url)
        @tag_descriptions[name] = desc if desc.present?
        sleep(0.3)
      end
    end

    def process_screening(screening)
      detail   = @detail_cache[screening[:detail_url]]
      director = detail&.dig(:director) || screening[:director]
      year     = detail&.dig(:year).presence || screening[:year]

      movie = find_or_create_movie(
        display_title:  screening[:title],
        original_title: screening[:title],
        year:           year || "0",
        director_hint:  director
      )
      return unless movie

      update_description(movie, detail, screening[:detail_url])

      ov       = detail&.dig(:ov).nil? ? screening[:ov] : detail[:ov]
      schedule = create_schedule(time: screening[:time], three_d: false, ov: ov,
                                 movie: movie, cinema: @cinema, info: detail&.dig(:info))
      tag_screening(schedule, screening[:schiene]) if screening[:schiene].present?
    end

    def update_description(movie, detail, detail_url)
      filmmuseum_desc = detail&.dig(:description)
      short_films     = detail&.dig(:short_films)

      combined = short_films.present? ? format_short_films(short_films, filmmuseum_desc) : filmmuseum_desc

      updates = {}
      updates[:description] = combined if combined.present? && combined.length > movie.description.to_s.length
      updates[:source_url]  = detail_url if detail_url.present? && (short_films.present? || movie.source_url.blank?)

      movie.update(updates) if updates.any?
    end

    def format_short_films(entries, description = nil)
      film_list = entries.group_by { |e| e[:group] }.map do |group_name, films|
        lines = []
        lines << "#{group_name}:" if group_name.present?
        films.each do |film|
          line = film[:meta].present? ? "#{film[:title].strip} – #{film[:meta].strip}" : film[:title].strip
          lines << "– #{line}"
        end
        lines.join("\n")
      end.join("\n\n")

      description.present? ? "#{film_list}\n\n#{description}" : film_list
    end

    def parse_short_films(ver_text)
      entries = []
      current_group = nil
      prev_was_strong = false

      ver_text.children.each do |node|
        next if node.text?
        case node.name
        when "strong"
          next unless node["class"]&.include?("avtext")
          title = node.at_css("span.avtext")&.text&.strip
          entries << { group: current_group, title: title, meta: nil } if title.present?
          prev_was_strong = true
        when "span"
          next unless node["class"]&.include?("avtext")
          text = node.text.strip
          next if text.blank? || text == "\u00a0"
          if prev_was_strong && entries.any?
            entries.last[:meta] = text
          else
            current_group = text
          end
          prev_was_strong = false
        else
          prev_was_strong = false
        end
      end

      entries
    end

    def parse_spielplan(doc)
      today = Date.today
      screenings = []

      doc.css("div.col-tag").each do |day_col|
        date = parse_day_date(day_col)
        next unless date && date >= today

        day_col.css("div.tages-eintrag").each do |entry|
          screening = parse_entry(entry, date)
          screenings << screening if screening
        end
      end

      screenings
    end

    def parse_day_date(day_col)
      date_el = day_col.at_css("h2.datum")
      return nil unless date_el
      Date.parse(date_el["id"]) rescue nil
    end

    def parse_entry(entry, date)
      time_el = entry.at_css(".zeit")
      return nil unless time_el

      hour, min = time_el.text.strip.split(".").map(&:to_i)
      time = VIENNA_TZ.local(date.year, date.month, date.day, hour, min)

      film_link = entry.at_css("a.kalender-film-link")
      return nil unless film_link&.at_css("strong")

      title      = film_link.at_css("strong").text.strip
      detail_url = absolute_url(film_link["href"])
      return nil if detail_url.blank?

      year, director = parse_spielplan_meta(film_link, title)

      { title: title, year: year, director: director, time: time,
        ov: entry.at_css(".icon-ef").present?,
        schiene: entry.at_css(".schiene")&.text&.strip.presence,
        detail_url: detail_url }
    end

    # Link inner HTML: "<strong>Title</strong><br/>1990, Director Name<div></div>"
    def parse_spielplan_meta(link_el, title)
      segments = link_el.inner_html.split(/<br\s*\/?>/)
                        .map { |s| Nokogiri::HTML.fragment(s).text.strip }
                        .reject(&:blank?)
      meta = segments.find { |s| s != title && s.match?(/\d{4}/) }
      return [ "0", nil ] unless meta

      if meta =~ /^(\d{4}),?\s*(.+)$/
        [ $1, $2.strip.presence ]
      else
        year = meta.match(/\b(\d{4})\b/)&.captures&.first || "0"
        [ year, nil ]
      end
    end

    def fetch_detail_page(url)
      html = fetch_page(url)
      return nil unless html

      doc      = Nokogiri::HTML(html)
      ver_text = doc.at_css("div.ver-text")
      return nil unless ver_text

      schiene_link = doc.at_css("div.schiene a")
      schiene_name = doc.at_css("div.schiene a span")&.text&.strip
      schiene_url  = schiene_link ? absolute_url(schiene_link["href"]) : nil

      strong_spans = ver_text.css("strong.avtext span.avtext").map { |s| s.text.strip }.reject(&:blank?)
      compilation  = strong_spans.size > 1 && !strong_spans.first.match?(/\d{4}.*\d+\s*min/i)

      meta_text      = compilation ? nil : strong_spans.first
      director, year = parse_detail_meta(meta_text)
      short_films    = compilation ? parse_short_films(ver_text) : nil

      description   = parse_description(ver_text)
      language_meta = strong_spans.find { |s| s.match?(/\d+\s*min/i) }
      language_info = parse_language(language_meta)

      { director: director, year: year, description: description,
        schiene_name: schiene_name, schiene_url: schiene_url,
        ov: language_info[:ov], info: language_info[:info],
        short_films: short_films }
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: detail page failed (#{url}) – #{e.message}"
      nil
    end

    def parse_description(ver_text)
      nbsp_found = false
      parts = []

      ver_text.children.each do |node|
        if !nbsp_found && node.name == "span" && node.text == "\u00a0"
          nbsp_found = true
          next
        end
        parts << node.text if nbsp_found && node.text.present?
      end

      parts.join("").gsub(/\s+/, " ").strip.presence
    end

    # Format: "Alexander Payne, US 1996; Drehbuch: ..."
    def parse_detail_meta(text)
      return [ nil, "0" ] if text.blank?

      first_part = text.split(";").first.strip
      if first_part =~ /^(.+?),\s*[A-ZÄÖÜ]{1,3}(?:\/[A-ZÄÖÜ]{1,3})*\s+(\d{4})/
        [ $1.strip, $2 ]
      else
        year = first_part.match(/\b(\d{4})\b/)&.captures&.first || "0"
        [ nil, year ]
      end
    end

    # meta_text example: "Alexander Payne, US 1996; Drehbuch: ...; 99 min. Englisch mit dt. UT"
    def parse_language(text)
      return { ov: false, info: nil } if text.blank?

      lang = text.match(/\d+\s*min\.\s*(.+)$/i)&.captures&.first&.strip
      lang = lang.presence

      if lang.blank? || lang.match?(/\ADeutsch\z/i) || lang.match?(/\Astumm\z/i)
        { ov: false, info: nil }
      elsif lang.match?(/mit dt\. UT/i)
        { ov: true, info: "OmdU" }
      elsif lang.match?(/mit .+ UT/i)
        { ov: true, info: "OmU" }
      else
        { ov: true, info: "OV" }
      end
    end

    def fetch_schiene_description(url)
      html = fetch_page(url)
      return nil unless html

      Nokogiri::HTML(html).css("div.ver-text > span.avtext")
                          .map { |s| s.text.strip }
                          .reject { |t| t.blank? || t == "\u00a0" }
                          .first
    rescue StandardError => e
      Rails.logger.error "#{self.class.name}: schiene fetch failed (#{url}) – #{e.message}"
      nil
    end

    def tag_screening(schedule, schiene_name)
      return unless schedule && schiene_name.present?

      tag = Tag.find_or_create_tag(schiene_name, description: @tag_descriptions[schiene_name])
      schedule.tags << tag unless schedule.tags.include?(tag)
    end

    def absolute_url(href)
      return nil if href.blank?
      href.start_with?("http") ? href : "#{BASE_URL}#{href}"
    end
  end
end
