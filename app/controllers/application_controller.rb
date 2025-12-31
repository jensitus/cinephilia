class ApplicationController < ActionController::Base
  after_action :skip_session_cookie
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  protect_from_forgery

  protected

  def skip_session_cookie
    request.session_options[:skip] = true
  end
end
