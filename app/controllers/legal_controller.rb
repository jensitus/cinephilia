class LegalController < ApplicationController
  def show
    @page_title = "Legal"
    @page_description = "Developed by: Jens Kornacker"
    @page_disclaimer = "cinephilia.at uses a functional cookie to remember your selected county (Bundesland). This cookie is stored for 1 year and contains no personal data."
  end
end
