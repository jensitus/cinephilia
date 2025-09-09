class UriService < BaseService
  def initialize(url)
    @url = url
  end

  def call
    URI(@url)
  rescue URI::InvalidURIError
    Rails.logger.error "Invalid URI: #{url.inspect}"
    nil
  end
end
