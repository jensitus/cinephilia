module ApplicationHelper
  def safe_external_url(url)
    url if url&.match?(/\Ahttps?:\/\/.+\z/)
  end
end
