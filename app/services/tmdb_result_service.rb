class TmdbResultService < BaseService

  TOKEN = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI5MzNjZGQ3MTcxYzUxMDZlNDQ5MjU3N2YzZjAwOGM1ZCIsIm5iZiI6MTM2NDc1NzgxNy4wLCJzdWIiOiI1MTU4OGQzOTE5YzI5NTY3NDQwZDlhYWUiLCJzY29wZXMiOlsiYXBpX3JlYWQiXSwidmVyc2lvbiI6MX0.sNb6zKWkCKY600bpUOn2WKac1GUOJW6-E-0O0PIBfjc" # Rails.configuration.tmdb_token

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
