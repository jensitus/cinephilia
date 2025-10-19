class NokogiriService < BaseService

  def initialize(url, css_to_parse, director = false)
    @url = url
    @css = css_to_parse
    @director = director
  end

  def call
    fetch_additional_info
  end

  private

  def fetch_additional_info
    docs = nil
    sleep 0.2
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
    if !@director
      parse_docs(docs) unless docs.nil?
    elsif @director
      parse_director_info(docs) unless docs.nil?
    end
  end

  def parse_docs(docs)
    content = nil
    docs.css(@css).each do |link|
      content = link.content
    end
    content
  end

  def parse_director_info(docs)
    director = nil
    docs.css(@css).each do |link|
      link_content = link.content
      puts link_content
      if link_content.include?("Regie")
        next_node = link.next_element
        director = next_node.content.strip unless next_node.nil? || next_node.content.strip.empty?
      end
    end
    director
  end

end
