module CountySelection
  extend ActiveSupport::Concern

  included do
    helper_method :current_county, :available_counties
    before_action :set_county_cookie
  end

  def current_county
    @current_county ||= begin
      county = params[:county].presence || cookies[:county]
      available_counties.include?(county) ? county : Cinephilia::Config::DEFAULT_COUNTY
    end
  end

  def available_counties
    Cinephilia::Config::COUNTIES
  end

  private

  def set_county_cookie
    if params[:county].present? && available_counties.include?(params[:county])
      cookies[:county] = {
        value: params[:county],
        expires: 1.year.from_now,
        httponly: true
      }
      redirect_to_without_county_param if request.get?
    end
  end

  def redirect_to_without_county_param
    redirect_to request.path, status: :see_other
  end
end
