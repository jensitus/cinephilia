class TmdbResultService < BaseService

  TOKEN = Rails.configuration.tmdb_token

  attr_reader :url

  def initialize(url)
    @url = url
  end

  def call
    begin
      http = Net::HTTP.new(@url.host, @url.port)
      http.use_ssl = true if url.scheme == "https"
      request = Net::HTTP::Get.new(url)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{TOKEN}"
      response = http.request(request)
      tmdb_results = JSON.parse(response.body)
      return tmdb_results
    rescue NoMethodError
      Rails.logger.error "no method error, because of invalid URI"
    end
    nil
  end
end
