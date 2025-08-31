class NokogiriService < BaseService

  def initialize(url, css_to_parse)
    @url = url
    @css = css_to_parse
  end

  def call
    fetch_additional_info
  end

  private

  def fetch_additional_info
    docs = nil
    begin
      docs = Nokogiri::HTML(URI.open("https://film.at" + @url))
    rescue OpenURI::HTTPError => error
      Rails.logger.error "open uri error detected: #{error.message}"
    rescue RuntimeError => e
      if e.message.include?("redirection loop")
        Rails.logger.error "Redirection loop detected: #{e.message}"
      else
        Rails.logger.error "RuntimeError: #{e.message}"
      end
    rescue StandardError => e
      Rails.logger.error "Unexpected error: #{e.message}"
    end
    parse_docs(docs) unless docs.nil?
  end

  def parse_docs(docs)
    docs.css(@css).each do |link|
      return link.content
    end
  end

end
