class LegalController < ApplicationController
  def show
    @page_title = "Legal"
    @page_description = "Developed by: Jens Kornacker"
    @page_contact = "Contact: info@service-b.org"
    @page_cookie_usage = "Cookies: cinephilia.at uses a functional cookie to remember your selected county (Bundesland). This cookie is stored for 1 year and contains no personal data."
    @page_disclaimer = "Disclaimer: This is a non-commercial project. The content of this website is provided for informational purposes only. All texts and dates on this website have been carefully checked. Nevertheless, no liability or guarantee can be assumed for the accuracy, completeness, and timeliness of the information."
  end
end
