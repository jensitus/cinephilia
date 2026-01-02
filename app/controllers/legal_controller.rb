class LegalController < ApplicationController
  def show
    @page_title = "Legal"
    @page_description = "Developed by: Jens Kornacker"
    @page_disclaimer = "cinephilia.at does not use any cookies and does not store any personal data"
  end
end
