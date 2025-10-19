# frozen_string_literal: true

module ScrapeConcerns

  def self.get_director(uri, html_parse_string, director)
    NokogiriService.call(uri, html_parse_string, director)
  end

end
