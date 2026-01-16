# app/services/filmarchiv_crawler_service.rb
class FilmarchivCrawlerService
  include HTTParty
  base_uri "https://www.filmarchiv.at"

  def initialize
    @headers = {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    }
  end

  def fetch_program
    response = self.class.get("/de/kino/programm", headers: @headers)

    if response.success?
      parse_program(response.body)
    else
      Rails.logger.error "Failed to fetch Filmarchiv program: #{response.code}"
      []
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching Filmarchiv program: #{e.message}"
    []
  end

  def fetch_program_range(start_date = Date.today, end_date = Date.today + 3)
    all_screenings = []

    (start_date..end_date).each do |date|
      url = "/de/kino/programm?day=#{date.strftime('%Y-%m-%d')}"
      response = self.class.get(url, headers: @headers)

      if response.success?
        screenings = parse_program(response.body)
        all_screenings.concat(screenings)
        puts "Fetched #{screenings.count} screenings for #{date}"
      end

      sleep(0.5) # Be nice to their server
    end

    all_screenings
  end

  private

  def parse_program(html)
    doc = Nokogiri::HTML(html)
    screenings = []

    doc.css(".screening_card").each do |card|
      screening_data = extract_screening_data(card)
      puts screening_data.inspect
      screenings << screening_data if screening_data
    end

    screenings
  end

  def extract_screening_data(card)
    # Extract date and time
    datetime_text = card.css("div.mt-1.mb-2.text-s23").first&.text&.strip
    return nil unless datetime_text

    datetime = parse_datetime(datetime_text)
    return nil unless datetime

    # Extract title - it's in the font-serif div
    # title = card.css(".font-serif").first&.text&.strip
    title = card.css("title-div").first&.text&.strip
    return nil unless title

    # Extract film link for more details
    film_link = card.css('a[href*="/de/kino/film/"]').first&.[]("href")

    film_details = film_link ? fetch_film_details("https://www.filmarchiv.at#{film_link}") : {}
    sleep(0.3)
    {
      title: title,
      datetime: datetime,
      date: datetime.to_date,
      time: datetime.strftime("%H:%M"),
      description: film_details[:description],
      director: film_details[:director],
      year: film_details[:year],
      country: film_details[:country],
      runtime: film_details[:runtime],
      film_url: film_link ? "https://www.filmarchiv.at#{film_link}" : nil
    }
  rescue StandardError => e
    Rails.logger.error "Error extracting screening data: #{e.message}"
    nil
  end

  def parse_datetime(datetime_text)
    # Example: "Mo, 12.1., 18:00"
    # Extract date and time parts
    match = datetime_text.match(/(\d{1,2})\.(\d{1,2})\.,?\s*(\d{1,2}):(\d{2})/)
    return nil unless match

    day = match[1].to_i
    month = match[2].to_i
    hour = match[3].to_i
    minute = match[4].to_i

    # Determine year - if month/day is before today, assume next year
    current_date = Date.today
    year = current_date.year

    # Try to create date with current year
    begin
      date = Date.new(year, month, day)
      # If the date is more than 6 months in the past, assume it's next year
      if date < current_date - 180
        year += 1
        date = Date.new(year, month, day)
      end
    rescue ArgumentError
      # Invalid date, try next year
      year += 1
      date = Date.new(year, month, day)
    end

    Time.zone.local(year, month, day, hour, minute)
  rescue StandardError => e
    Rails.logger.error "Error parsing datetime '#{datetime_text}': #{e.message}"
    nil
  end

  def fetch_film_details(film_url)
    return {} unless film_url

    response = self.class.get(film_url, headers: @headers)
    return {} unless response.success?

    doc = Nokogiri::HTML(response.body)

    {
      director: extract_director(doc),
      year: extract_year(doc),
      country: extract_country(doc),
      runtime: extract_runtime(doc),
      description: extract_description(doc)
    }
  rescue StandardError => e
    Rails.logger.error "Error fetching film details from #{film_url}: #{e.message}"
    {}
  end

  def extract_description(doc)
    # Find the description in the specific div
    description_div = doc.css("div.relative.px-4.py-3.leading-tight.prose.text-s20").first
    return nil unless description_div

    # Get the p tag content
    p_tag = description_div.css("p").first
    return nil unless p_tag

    # Return the full text, stripping extra whitespace
    p_tag.text.strip.gsub(/\s+/, " ")
  end

  def extract_director(doc)
    # Look for director in div.leading-tight with strong containing "Regie"
    doc.css("div.leading-tight").each do |div|
      strong = div.css("strong").find { |s| s.text.strip.match?(/Regie/i) }
      puts strong
      if strong
        # Get the next span sibling
        director_span = strong.next_element
        while director_span && director_span.name != "span"
          director_span = director_span.next_element
        end

        return director_span.text.strip if director_span
      end
    end

    nil
  end

  def extract_year(doc)
    # Look for 4-digit year
    doc.text.scan(/\b(19\d{2}|20\d{2})\b/).flatten.first
  end

  def extract_country(doc)
    # Common country indicators
    countries = doc.text.scan(/\b(AT|DE|US|FR|GB|IT|ES|CH)\b/).flatten.uniq.join(", ")
    countries.presence
  end

  def extract_runtime(doc)
    # Look for runtime like "90 min" or "1h 30min"
    match = doc.text.match(/(\d+)\s*min/)
    match ? match[1].to_i : nil
  end
end
