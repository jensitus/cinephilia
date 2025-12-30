module CinemasHelper
  def safe_uri(url)
    uri = URI.parse(url)
    uri.to_s if uri.is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    nil
  end
end
