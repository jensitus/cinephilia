class ApplicationController < ActionController::Base
  include CountySelection

  after_action :skip_session_cookie
  after_action :track_page_view
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  protect_from_forgery

  protected

  def skip_session_cookie
    request.session_options[:skip] = true
  end

  def track_page_view
    ua = request.user_agent
    PageView.create!(
      path:        request.path,
      county:      current_county,
      viewable:    @_page_view_viewable,
      occurred_at: Time.current,
      user_agent:  ua,
      is_bot:      PageView.bot?(ua) || high_request_rate?(request.remote_ip)
    )
  rescue StandardError => e
    Rails.logger.warn "PageView tracking failed: #{e.message}"
  end

  def high_request_rate?(ip)
    return false if ip.blank?
    key = "pv_rate:#{ip}"
    count = Rails.cache.increment(key, 1, expires_in: 1.minute)
    count > 10
  end
end
